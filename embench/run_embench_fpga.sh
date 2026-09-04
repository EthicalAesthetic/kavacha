#!/bin/bash
set -euo pipefail

echo "==================================================="
echo " EMBench-IoT Hardware-in-the-Loop (FPGA) Runner    "
echo "==================================================="

# Move to repo root
cd "$(dirname "$0")/.."

echo ""
echo "[1/2] Building EMBench HIL firmware images..."
echo "---------------------------------------------------"
./sw/build_hil_bench.sh all

echo ""
echo "[2/2] Running EMBench suite on Arty A7-100T..."
echo "---------------------------------------------------"
echo "WARNING: Since the firmware is loaded into Block RAM via synthesis,"
echo "Vivado must re-synthesize the bitstream for each benchmark."
echo "This will take approximately 5 minutes per benchmark (19 benchmarks = ~1.5 hours)."
echo "Sit back and relax!"
echo ""

# Run the python HIL runner script for all EMBench tests
python3 sw/run_hil_bench.py --port /dev/ttyUSB1 --freq 50 --bench embench
