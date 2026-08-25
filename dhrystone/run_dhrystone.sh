#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GCC_BIN="$ROOT/verification/tools/gcc/bin/riscv-none-elf-gcc"
OBJCOPY_BIN="$ROOT/verification/tools/gcc/bin/riscv-none-elf-objcopy"

if command -v "$GCC_BIN" &>/dev/null; then
    GCC="$GCC_BIN"
    OBJCOPY="$OBJCOPY_BIN"
elif command -v riscv-none-elf-gcc &>/dev/null; then
    GCC="riscv-none-elf-gcc"
    OBJCOPY="riscv-none-elf-objcopy"
elif command -v riscv64-elf-gcc &>/dev/null; then
    GCC="riscv64-elf-gcc"
    OBJCOPY="riscv64-elf-objcopy"
else
    echo "ERROR: RISC-V GCC not found."
    exit 1
fi

echo "========================================="
echo " Building Dhrystone for Kavacha          "
echo "========================================="

cd "$SCRIPT_DIR"
mkdir -p build

COMMON_CFLAGS="-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles"
INCLUDES="-I. -I../bench/common"

# Dhrystone specific defines:
# -DTIME: Use time() function
# -DRISCV: Print RISC-V specific metrics
# -Wno-implicit-int -Wno-return-type: Dhrystone 2.1 is old K&R C
DHRY_CFLAGS="-std=gnu99 -DNUM_RUNS=100000 -DTIME -DRISCV -Wno-implicit-int -Wno-return-type -Wno-implicit-function-declaration"

# Source files
SRCS=(
    "../bench/common/crt0.S"
    "../bench/common/syscalls.c"
    "../bench/common/printf.c"
    "dhrystone_support.c"
    "dhry_1.c"
    "dhry_2.c"
)

# Compile (link libgcc for 64-bit division support, e.g. __divdi3 on RV32)
$GCC $COMMON_CFLAGS $INCLUDES $DHRY_CFLAGS -T ../bench/common/bench.ld -Wl,--gc-sections -o build/dhrystone.elf "${SRCS[@]}" -lgcc

# Convert to hex
$OBJCOPY -O binary build/dhrystone.elf build/dhrystone.bin
python3 ../sw/bin2hex.py build/dhrystone.bin build/dhrystone.hex

echo "[BUILD] Created build/dhrystone.hex"
echo ""

echo "========================================="
echo " Running Dhrystone Simulation            "
echo "========================================="

make -C "$ROOT/bench" run-kavacha-dhrystone HEX_FILE="$SCRIPT_DIR/build/dhrystone.hex" TIMEOUT_CYCLES=300000000 || true

echo "Done."

