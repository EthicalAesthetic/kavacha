#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
KAVACHA_DIR="$(dirname "$SCRIPT_DIR")"
VERIF_TOOLS_DIR="$KAVACHA_DIR/verification/tools"

# Add bundled tools to PATH (if present); fall back to system toolchain
export PATH="$VERIF_TOOLS_DIR/gcc/bin:$PATH"

# Detect RISC-V GCC (same fallback chain as dhrystone/run_dhrystone.sh)
if command -v riscv-none-elf-gcc &>/dev/null; then
    RISCV_GCC="riscv-none-elf-gcc"
elif [[ -x "/home/yash/toolchains/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-gcc" ]]; then
    RISCV_GCC="/home/yash/toolchains/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-gcc"
elif command -v riscv64-elf-gcc &>/dev/null; then
    RISCV_GCC="riscv64-elf-gcc"
elif command -v riscv64-unknown-elf-gcc &>/dev/null; then
    RISCV_GCC="riscv64-unknown-elf-gcc"
elif command -v riscv32-unknown-elf-gcc &>/dev/null; then
    RISCV_GCC="riscv32-unknown-elf-gcc"
else
    echo "ERROR: No RISC-V GCC found. Install riscv-none-elf-gcc or riscv64-elf-gcc."
    exit 1
fi
echo "[BUILD] Toolchain: $RISCV_GCC"

cd "$KAVACHA_DIR/bench"

echo "========================================="
echo " Building EMBench with -O2               "
echo "========================================="
# Clean previous builds for a fresh start
rm -f build/*.hex build/*.elf build/*.bin

# Build all EMBench tests using the same compiler and flags as we did for CoreMark originally
make embench \
    RISCV_GCC="$RISCV_GCC" \
    COMMON_CFLAGS="-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles" \
    LDFLAGS="-T \$(BENCH_DIR)/common/bench.ld -Wl,--gc-sections"

echo ""
echo "========================================="
echo " Running Simulations in Parallel         "
echo "========================================="
mkdir -p results/kavacha/embench_O2

BENCHMARKS="aha-mont64 crc32 depthconv edn huffbench matmult-int md5sum nettle-aes nettle-sha256 nsichneu picojpeg qrduino sglib-combined slre statemate tarfind ud wikisort xgboost"

# Portable path to the Verilator simulation binary (mirrors bench/Makefile V_BUILD_DIR)
SIM_BIN="/tmp/kavacha_sim_${USER}/Vbench_obj/Vbench_top"
if [[ ! -x "$SIM_BIN" ]]; then
    echo "ERROR: Verilator simulation binary not found at $SIM_BIN"
    echo "       Build it first with: make -C bench verilator-kavacha"
    exit 1
fi

# Start all simulations in parallel in the background
for b in $BENCHMARKS; do
    (
        "$SIM_BIN" --hex build/$b.hex --name $b --max-cycles 2000000000 > results/kavacha/embench_O2/$b.log 2>&1
        
        # Check if it passed
        if grep -q "PASS" results/kavacha/embench_O2/$b.log; then
            CYCLES=$(grep -oP "(?<=sim_cycles=)\d+" results/kavacha/embench_O2/$b.log)
            echo "  [PASS] $b - Cycles: $CYCLES"
        else
            echo "  [FAIL] $b - (See log: results/kavacha/embench_O2/$b.log)"
        fi
    ) &
done

# Wait for all background jobs to finish
wait

echo ""
echo "========================================="
echo " All EMBench simulations completed!      "
echo "========================================="

# Compute Geomean using a small Python script
python3 -c '
import os
import re
import math

log_dir = "results/kavacha/embench_O2"
cycles = []

print("  ╔══════════════════════════════════════╗")
print("  ║  EMBench-IoT Metrics                 ║")
print("  ╠══════════════════════════════════════╣")

for f in sorted(os.listdir(log_dir)):
    if not f.endswith(".log"): continue
    b = f.replace(".log", "")
    with open(os.path.join(log_dir, f)) as fp:
        content = fp.read()
        if "PASS" in content:
            m = re.search(r"sim_cycles=(\d+)", content)
            if m:
                c = int(m.group(1))
                cycles.append(c)
                print(f"  ║  {b:<20} : {c:<12}║")
        else:
            print(f"  ║  {b:<20} : FAILED/TIMEOUT║")

if cycles:
    # Geometric mean = exp( sum(log(x)) / n )
    geomean = math.exp(sum(math.log(c) for c in cycles) / len(cycles))
    print("  ╠══════════════════════════════════════╣")
    print(f"  ║  GEOMEAN (Cycles)     : {geomean:<12.1f}║")

print("  ╚══════════════════════════════════════╝")
'
