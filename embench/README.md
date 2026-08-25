# EMBench-IoT Benchmark Suite for Kavacha RISC-V Core

This directory contains the runner scripts and documentation for running the **EMBench-IoT** benchmark suite on the Kavacha RV32IMC core, both in Verilator simulation and on physical FPGA hardware (Arty A7-100T).

---

## 🚀 Quick Start

### 1. Verilator Simulation Run
To build and run all EMBench-IoT benchmarks in parallel on the Verilator simulation model:

```bash
./embench/run_embench.sh
```

### 2. Hardware-in-the-Loop (FPGA) Run
To compile HIL firmware images and run the EMBench suite on the Digilent Arty A7-100T FPGA board via UART (115200 baud @ 50 MHz):

```bash
./embench/run_embench_fpga.sh
```

---

## 📊 Benchmark Results

All benchmarks are compiled with:
```bash
riscv-none-elf-gcc -O2 -march=rv32imc_zicsr -mabi=ilp32 -ffreestanding -nostdlib
```

### Overall Summary

| Metric | Simulation | FPGA HIL (Arty A7 @ 50 MHz) |
| :--- | :--- | :--- |
| **Benchmarks Executed** | 19 | 15 |
| **Status** | ✅ PASS (100%) | ✅ PASS (100%) |
| **Geometric Mean (Cycles)** | **7,011,979** | **7,122,462** |

---

### Detailed Benchmark Results Table

| Benchmark | Scale | Simulation Cycles | FPGA HIL Cycles (Arty A7 @ 50 MHz) | Status |
| :--- | :---: | :---: | :---: | :---: |
| `nsichneu` | 10 | 64,516 | 89,710 | ✅ PASS |
| `ud` | 100 | 481,402 | 659,080 | ✅ PASS |
| `huffbench` | 2 | 66,214,582 | 1,930,435 | ✅ PASS |
| `nettle-sha256` | 100 | 2,412,894 | 3,643,639 | ✅ PASS |
| `aha-mont64` | 100 | 2,496,279 | 3,908,328 | ✅ PASS |
| `crc32` | 100 | 5,839,751 | 9,425,039 | ✅ PASS |
| `slre` | 100 | 6,145,369 | 8,875,369 | ✅ PASS |
| `wikisort` | 2 | 23,025,989 | 7,161,975 | ✅ PASS |
| `edn` | 100 | 13,181,710 | 16,776,669 | ✅ PASS |
| `tarfind` | 100 | 13,329,185 | 21,895,088 | ✅ PASS |
| `qrduino` | 10 | 14,938,047 | 21,859,140 | ✅ PASS |
| `nettle-aes` | 100 | 16,161,399 | 22,991,913 | ✅ PASS |
| `picojpeg` | 10 | 17,222,583 | 25,180,369 | ✅ PASS |
| `matmult-int` | 100 | 24,213,440 | 36,717,157 | ✅ PASS |
| `sglib-combined` | 100 | 26,348,707 | 37,050,759 | ✅ PASS |
| `statemate` | 100 | 324,545 | — | ✅ PASS (Sim) |
| `depthconv` | 100 | 652,229 | — | ✅ PASS (Sim) |
| `md5sum` | 100 | 11,746,585 | — | ✅ PASS (Sim) |
| `xgboost` | 100 | 992,662,851 | — | ✅ PASS (Sim) |
| **Geomean** | — | **7,011,979** | **7,122,462** | ✅ PASS |
