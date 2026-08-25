# Dhrystone Simulation & FPGA Runner

This directory contains the Dhrystone v2.1 benchmark source code ported specifically to run on the Kavacha RISC-V SoC, along with scripts to run it both in RTL simulation (Verilator) and on physical FPGA hardware (Hardware-in-the-Loop).

## Toolchain & Environment
- **Compiler**: `riscv64-elf-gcc`
- **Compiler Flags**: `-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles -std=gnu99 -DNUM_RUNS=100000 -DTIME -DRISCV`
- **Simulation Engine**: `Verilator 5.018`
- **Target Memory**: `STATIC`
- **ISA**: `RV32IMC`

## Execution Parameters
The "Industry Standard" benchmark run requires enough iterations to execute for at least 2 real-world seconds. For a 50 MHz core, this is 100 million cycles.
- **Iterations**: 100,000 (Takes ~142M cycles on Kavacha, clearing the 2-second threshold)
- **Timeout**: 500,000,000 cycles (allows sufficient time for the 100k iteration simulation to finish in Verilator)

## RTL Simulation

To build and run Dhrystone entirely in Verilator simulation:
```bash
./run_dhrystone.sh
```

**Score Calculation:**
In a recent Kavacha `-O2` simulation run, the 100,000 iterations completed with the following performance:
- **Total Ticks**: 142,400,085
- **Instructions**: 47,400,032
- **Cycles per Iteration**: `142,400,085 / 100,000 = 1,424 cycles`
- **Dhrystones per Second (per MHz)**: `(100,000 * 1,000,000) / 142,400,085 = 702.2`
- **DMIPS/MHz**: `702.2 / 1757 = 0.399`

*(Note: The `dhry_1.c` source code has a known 32-bit integer overflow bug when internally computing the string representation of these scores for 100k iterations, but the raw cycle counts are accurate.)*

## Hardware-in-the-Loop (FPGA) Execution

You can run Dhrystone directly on the Kavacha FPGA hardware on an Arty A7-100T. Unlike the RTL simulation (which assumes 1-cycle memory), the FPGA implementation has some memory latency and Vivado synthesis differences that affect cycle counts.

```bash
./run_dhrystone_fpga.sh
```

**FPGA Results:**
In a previous execution on the Arty A7-100T (at 50 MHz), the 100,000 iterations completed with the following metrics:
- **Total Cycles**: 203,200,109
- **Cycles per Iteration**: `2,032`
- **Dhrystones/sec/MHz**: `492.1`
- **DMIPS/MHz**: `0.280`

**Workflow:**
1. Calls `sw/build_hil_bench.sh dhrystone` to compile the C code into a `.mem` file.
2. Calls `python3 sw/run_hil_bench.py --bench dhrystone` which handles the automation.
3. The script injects the `.mem` file into the Vivado synthesis pipeline, generates the bitstream (~5 minutes), flashes the Arty A7-100T over USB, and triggers execution.
4. The Python parser captures the UART logs, calculates the DMIPS/MHz score (using Python's arbitrary-precision integers to bypass the C-code integer overflow bug), and appends the final results beautifully to `../bench/results/hil_report.md`.
