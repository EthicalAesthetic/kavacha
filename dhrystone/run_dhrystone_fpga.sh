#!/bin/bash
set -euo pipefail

echo "==================================================="
echo " Dhrystone Hardware-in-the-Loop (FPGA) Runner      "
echo "==================================================="

# Move to repo root
cd "$(dirname "$0")/.."

echo ""
echo "[1/2] Building Dhrystone HIL firmware image..."
echo "---------------------------------------------------"
./sw/build_hil_bench.sh dhrystone

echo ""
echo "[2/2] Flashing and running Dhrystone on Arty A7-100T..."
echo "---------------------------------------------------"
echo "Running Vivado synthesis to bake firmware into BRAM (~5 mins)..."
echo ""

# Run the python HIL runner script for dhrystone
python3 sw/run_hil_bench.py --port /dev/ttyUSB1 --freq 50 --bench dhrystone
