#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
KAVACHA_DIR="$(dirname "$SCRIPT_DIR")"
VERIF_TOOLS_DIR="$KAVACHA_DIR/verification/tools"

# Add tools to PATH
export PATH="$VERIF_TOOLS_DIR/gcc/bin:$VERIF_TOOLS_DIR/verilator/bin:$PATH"

echo "========================================="
echo " Building FPGA HIL Firmware (CoreMark)   "
echo "========================================="
# Use the official HIL build script which compiles with crt0_fpga.S (prints READY)
# and core_portme_fpga.c (prints CYCLES/ITERS expected by the python script)
"$KAVACHA_DIR/sw/build_hil_bench.sh" coremark

echo ""
echo "========================================="
echo " Preparing Firmware for Vivado Synthesis "
echo "========================================="
cp "$KAVACHA_DIR/sw/hil_build/coremark.mem" "$KAVACHA_DIR/sw/firmware.mem"
echo "Copied sw/hil_build/coremark.mem to sw/firmware.mem"

echo ""
echo "========================================="
echo " Building FPGA Bitstream                 "
echo "========================================="
echo "Vivado will now synthesize the design. This process typically takes 5-10 minutes."
echo "Running..."

cd "$KAVACHA_DIR/fpga/arty_a7"
# Launch Vivado in batch mode
vivado -mode batch -source kavacha_arty_a7.tcl

echo ""
echo "========================================="
echo " Bitstream Generation Complete!          "
echo "========================================="
echo ""
echo "To program the Arty A7-100T FPGA:"
echo "  openFPGALoader -b arty_a7_100t ../fpga/arty_a7/build/kavacha_arty_a7.bit"
echo ""
echo "To view CoreMark output via UART (requires Python pyserial):"
echo "  python3 ../sw/run_hil_bench.py --port /dev/ttyUSB1 --freq 50 --bench coremark --no-flash"
echo "  (Make sure to adjust /dev/ttyUSB1 to your actual FPGA serial port)"
