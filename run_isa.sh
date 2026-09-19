#!/usr/bin/env bash
# run_isa.sh -- build & run the OFFICIAL riscv-tests ISA suites on Kavacha.
#
# Each test is linked with third_party/riscv-tests/env (code at 0x0 in IMEM,
# data at 0x8000_0000 in DRAM, tohost at 0x2000_0000), split into an IMEM and
# a DRAM image, and run on the core's own testbench (tb/tb_kavacha.sv) and SoC.
# PASS = the test writes 1 to tohost. The testbench runs with +IMEM_WRITABLE so
# data stores also reach IMEM: riscv-tests assume one read/write memory and
# rv32uc/rvc stores into data inside its code section.
#
#   ./run_isa.sh                   default build: rv32ui rv32um rv32uc rv32mi
#   ./run_isa.sh default rv32ui    one config, chosen suites
#   ./run_isa.sh secure            SECURE build (U-mode + PMP): rv32u* run in U-mode
#   ./run_isa.sh all               both configs (what CI and run_tests.sh use)
#
# Prints PASS / FAIL / SKIP per test, a total per config, and exits non-zero
# if any test fails or fails to build. Skipped tests are listed with a reason.
set -uo pipefail
cd "$(dirname "$0")"

TC="${RISCV_TC:-}"
if [[ -n "$TC" && -x "$TC/riscv-none-elf-gcc" ]]; then
  GCC="$TC/riscv-none-elf-gcc"; OBJCOPY="$TC/riscv-none-elf-objcopy"
elif command -v riscv-none-elf-gcc &>/dev/null; then
  GCC=riscv-none-elf-gcc; OBJCOPY=riscv-none-elf-objcopy
elif command -v riscv64-unknown-elf-gcc &>/dev/null; then
  GCC=riscv64-unknown-elf-gcc; OBJCOPY=riscv64-unknown-elf-objcopy
else
  echo "run_isa.sh: no RISC-V GCC found (set RISCV_TC)"; exit 1
fi
IVL="${IVERILOG:-iverilog}"; VVP="${VVP:-vvp}"
RT=third_party/riscv-tests
MARCH=rv32imc_zicsr

CONFIGS="${1:-default}"
[[ "$CONFIGS" == "all" ]] && CONFIGS="default secure"
shift || true
SUITES="${*:-rv32ui rv32um rv32uc rv32mi}"

# Tests that cannot run on Kavacha, with the reason. Never dropped silently:
# each is printed as SKIP and counted.
skip_reason() {  # $1 = config, $2 = suite/test
  case "$2" in
    rv32ui/fence_i) echo "Zifencei is not implemented: FENCE.I raises an illegal-instruction trap" ;;
    rv32mi/pmpaddr) [[ "$1" == default ]] && echo "test assumes PMP; the default build has none (runs on the SECURE build)" ;;
  esac
}

R=rtl; C=rtl/common
CELLS="$C/kavacha_pkg.sv $C/kavacha_alu.sv $C/kavacha_regfile.sv \
       $C/kavacha_muldiv.sv $C/kavacha_csr.sv $C/kavacha_rvc.sv \
       $C/kavacha_immgen.sv $C/kavacha_branch.sv $C/kavacha_decode.sv $C/kavacha_pmp.sv"
CORE="$R/kavacha_core.sv $R/kavacha_debug.sv $R/kavacha_soc.sv"

status=0
for cfg in $CONFIGS; do
  case "$cfg" in
    default) DEFS="";                EXTRA="" ;;
    secure)  DEFS="-DKAVACHA_SECURE"; EXTRA="$C/kavacha_regfile_ecc.sv" ;;
    *) echo "unknown config: $cfg"; exit 1 ;;
  esac
  B=build/isa/$cfg
  mkdir -p "$B" sim
  if ! "$IVL" -g2012 $DEFS -I "$C" -I "$R" -o "sim/tb_isa_$cfg" \
         $CELLS $EXTRA $CORE tb/tb_kavacha.sv > "$B/iverilog.log" 2>&1; then
    cat "$B/iverilog.log"; echo "run_isa.sh: $cfg: simulator build FAILED"; exit 1
  fi
  echo "==== Kavacha ($cfg build): official riscv-tests $SUITES ===="
  pass=0; fail=0; skip=0; failed=""
  for d in $SUITES; do
    for src in $RT/isa/$d/*.S; do
      [[ -f "$src" ]] || continue
      t=$(basename "$src" .S)
      why=$(skip_reason "$cfg" "$d/$t")
      if [[ -n "$why" ]]; then
        printf "  %-26s SKIP (%s)\n" "$d/$t" "$why"; skip=$((skip+1)); continue
      fi
      elf=$B/$d-$t.elf
      if ! "$GCC" -march=$MARCH -mabi=ilp32 -nostdlib -nostartfiles -static -fno-pic \
             -Wl,--no-relax -I $RT/env -I $RT/isa/macros/scalar \
             -T $RT/env/link.ld "$src" -o "$elf" > "$B/$d-$t.cc.log" 2>&1; then
        printf "  %-26s FAIL (build error, see %s)\n" "$d/$t" "$B/$d-$t.cc.log"
        fail=$((fail+1)); failed="$failed $d/$t"; continue
      fi
      "$OBJCOPY" -O binary -j .text.init -j .text "$elf" "$B/$d-$t.imem.bin"
      "$OBJCOPY" -O binary -j .data "$elf" "$B/$d-$t.dram.bin"
      python3 sw/bin2hex.py "$B/$d-$t.imem.bin" "$B/$d-$t.imem.hex" > /dev/null
      python3 sw/bin2hex.py "$B/$d-$t.dram.bin" "$B/$d-$t.dram.hex" > /dev/null
      "$VVP" "sim/tb_isa_$cfg" +IMEM="$B/$d-$t.imem.hex" +DRAM="$B/$d-$t.dram.hex" \
             +MAXCYC=2000000 +IMEM_WRITABLE > "$B/$d-$t.log" 2>&1
      if grep -q '^\[TB\] PASS' "$B/$d-$t.log"; then
        printf "  %-26s PASS\n" "$d/$t"; pass=$((pass+1))
      else
        code=$(grep -oE 'tohost write: 0x[0-9a-f]+' "$B/$d-$t.log" | head -1 | sed 's/.*: //')
        if [[ -z "$code" ]]; then why="no tohost write (TIMEOUT)"
        else
          v=$((code))
          if (( (v & 1337) == 1337 && v != 1 )); then why="unexpected trap (tohost=$code)"
          else why="test case $((v >> 1)) failed (tohost=$code)"; fi
        fi
        printf "  %-26s FAIL %s\n" "$d/$t" "$why"; fail=$((fail+1)); failed="$failed $d/$t"
      fi
    done
  done
  echo "==== $cfg: $pass passed, $fail failed, $skip skipped of $((pass+fail+skip)) ===="
  if [[ -n "$failed" ]]; then echo "FAILED ($cfg):$failed"; status=1; fi
  (( pass > 0 )) || { echo "run_isa.sh: $cfg: no test passed"; status=1; }
done
exit $status
