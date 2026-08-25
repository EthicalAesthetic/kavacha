# CoreMark Simulation Details

This document outlines the environment, toolchain, and calculations used to run and evaluate the Kavacha CoreMark simulation.

## Toolchain & Environment
- **Compiler**: `riscv64-elf-gcc (Arch Linux Repositories) 15.2.0`
- **Compiler Flags**: `-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles`
- **Simulation Engine**: `Verilator 5.018`
- **Target Memory**: `STATIC`
- **ISA**: `RV32IMC`

## Execution Parameters
- **Iterations**: 1,000 (the standard industry benchmark length)
- **Timeout**: 5,000,000,000 cycles (allows sufficient time for 1,000 iterations to complete in Verilator)
- **Approximate Simulation Time**: ~3 to 6 minutes (~785M simulation cycles in Verilator)
- **Fast Check**: For a quick sanity run, `run_coremark_10.sh` uses 10 iterations and takes ~2 to 5 seconds.

## Score Calculation
The CoreMark/MHz metric is derived from the number of clock cycles required to complete the workload. 

1. **Total Ticks**: 785,279,258 (the exact number of cycles spent in the benchmark loop)
2. **Cycles per Iteration**: `785,279,258 / 1,000 = 785,279.3 cycles`
3. **CoreMark/MHz Formula**: `1,000,000 / Cycles_Per_Iteration`
4. **Result**: `1,000,000 / 785,279.3 = 1.2734 CoreMark/MHz`

*Note: The `bench_top` simulation logs a slightly higher total cycle count (`785,356,069`) because it includes the `crt0` boot code and memory initialization. Hardware performance metrics traditionally exclude this boot overhead, using the timer-measured ticks instead.*

## Hardware-in-the-Loop (FPGA) Execution
CoreMark can also be executed directly on the Kavacha FPGA implementation.

### FPGA Environment
- **Board**: Arty A7-100T
- **Clock**: 50 MHz
- **Memory**: Internal BRAM (16 KB)
- **Runner**: `python3 sw/run_hil_bench.py --bench coremark`

### Differences from Simulation
Due to the lack of some advanced pipelining features and memory latency when running out of Vivado-synthesized BRAM, FPGA performance may vary based on synthesis flags. A previous run on the physical Arty A7-100T using different compiler flags resulted in:
- **Total Ticks**: 1,234,774,918
- **CoreMark/MHz**: 0.81 (@ 50 MHz)
