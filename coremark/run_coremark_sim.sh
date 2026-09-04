#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
KAVACHA_DIR="$(dirname "$SCRIPT_DIR")"
VERIF_TOOLS_DIR="$KAVACHA_DIR/verification/tools"

# Add tools to PATH
export PATH="$VERIF_TOOLS_DIR/gcc/bin:$VERIF_TOOLS_DIR/verilator/bin:$PATH"

# Detect RISC-V GCC
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
    echo "ERROR: No RISC-V GCC found."
    exit 1
fi
echo "[BUILD] Toolchain: $RISCV_GCC"

# Move to bench directory
cd "$KAVACHA_DIR/bench"

echo "========================================="
echo " Building and Running CoreMark Simulation"
echo " (1,000 iterations: ~785M cycles, approx. 10-15 mins)"
echo "========================================="

# Clean previous builds
rm -f build/coremark.hex build/coremark.elf

# Build CoreMark (reduced iterations for fast sim)
make coremark ITERATIONS=1000 RISCV_GCC="$RISCV_GCC"

# Run simulation
make run-kavacha-coremark TIMEOUT_CYCLES=5000000000

echo ""
echo "========================================="
echo " CoreMark Results"
echo "========================================="
python3 -c '
import re

log_path = "results/kavacha/coremark.log"
try:
    text = open(log_path).read()
    
    # Extract total ticks from CoreMark output
    ticks_match = re.search(r"Total ticks\s*:\s*(\d+)", text)
    iter_match = re.search(r"Iterations\s*:\s*(\d+)", text)
    
    if ticks_match and iter_match:
        ticks = int(ticks_match.group(1))
        iterations = int(iter_match.group(1))
        
        cpi = ticks / iterations
        cm_per_mhz = 1_000_000 / cpi
        
        print(f"  ╔══════════════════════════════════════╗")
        print(f"  ║  CoreMark Metrics                    ║")
        print(f"  ╠══════════════════════════════════════╣")
        print(f"  ║  Iterations    : {iterations:<20}║")
        print(f"  ║  Total Ticks   : {ticks:<20,}║")
        print(f"  ║  Cycles/Iter   : {cpi:<20,.1f}║")
        print(f"  ║  CoreMark/MHz  : {cm_per_mhz:<20.4f}║")
        print(f"  ╚══════════════════════════════════════╝")
    else:
        print("Could not find ticks/iterations in the log.")
except Exception as e:
    print(f"Error parsing log: {e}")
'
