# Benchmarks & Resource Utilization

Kavacha features a complete benchmarking and resource utilization evaluation suite covering **EEMBC CoreMark**, **Dhrystone v2.1**, **EMBench™-IoT**, and **Vivado FPGA Synthesis**.

---

## Performance Summary

All software benchmarks are compiled with freestanding optimization flags (`-O2 -march=rv32imc_zicsr -mabi=ilp32`) and simulated on the cycle-accurate Verilator C++ model.

| Benchmark Suite | Metric / Workloads | Score / Result | Target Environment | Status |
|-----------------|-------------------|----------------|--------------------|:------:|
| **CoreMark** | 1,000 Iterations | **1.18 CoreMark / MHz** | Verilator 5.018+ | ✅ PASS |
| **Dhrystone v2.1** | 100,000 Iterations | **0.401 DMIPS / MHz** (706 Dhry/sec/MHz) | Verilator 5.018+ | ✅ PASS |
| **EMBench™-IoT** | 20 Embedded Workloads | **7,011,979 Cycles** (Geomean) | Verilator 5.018+ | ✅ PASS |
| **CoreMark (FPGA HIL)** | 1,000 Iterations | **0.810 CoreMark / MHz** | Arty A7-100T @ 50 MHz | ✅ PASS |
| **Dhrystone (FPGA HIL)** | 100,000 Iterations | **0.274 DMIPS / MHz** | Arty A7-100T @ 50 MHz | ✅ PASS |

---

## 1. CoreMark

CoreMark measures core execution performance across matrix manipulation, linked-list processing, state machine traversal, and CRC calculations.

### Execution & Scoring
* **Iterations**: 1,000 (EEMBC minimum required workload)
* **Cycles / Iteration**: ~847,547 cycles
* **CoreMark / MHz**:
  $$\text{CoreMark / MHz} = \frac{1,000,000}{\text{Cycles / Iteration}} = \frac{1,000,000}{847,547.1} \approx \mathbf{1.18}$$

### Running CoreMark
```bash
# Run 1,000 iterations on Verilator
cd coremark && ./run_coremark_sim.sh

# Quick 10-iteration sanity check
cd coremark && ./run_coremark_10.sh
```

---

## 2. Dhrystone v2.1

Dhrystone evaluates integer arithmetic, string operations, and control-flow performance.

### Execution & Scoring
* **Iterations**: 100,000 runs (~141.6 million execution cycles)
* **Cycles / Iteration**: 1,416.0 cycles
* **DMIPS / MHz**:
  $$\text{DMIPS / MHz} = \frac{\text{Dhrystones / sec / MHz}}{1,757} = \frac{706.2}{1,757} = \mathbf{0.401}$$

### Running Dhrystone
```bash
cd dhrystone && ./run_dhrystone.sh
```

---

## 3. EMBench™-IoT Suite

EMBench™-IoT consists of 20 real-world embedded algorithms spanning cryptography, signal processing, compression, sorting, and control loops:

| Workload | Category / Description | Sim Cycles | Status |
|----------|------------------------|-----------:|:------:|
| `nsichneu` | Petri net simulation | 64,516 | ✅ PASS |
| `statemate` | Statechart code for automotive controllers | 324,545 | ✅ PASS |
| `ud` | Diagonal matrix decomposition | 481,402 | ✅ PASS |
| `depthconv` | Depthwise 2D separable convolution | 652,229 | ✅ PASS |
| `nettle-sha256` | SHA-256 secure hash | 2,412,894 | ✅ PASS |
| `aha-mont64` | 64-bit Montgomery multiplication | 2,496,279 | ✅ PASS |
| `crc32` | 32-bit standard cyclic redundancy check | 5,839,751 | ✅ PASS |
| `slre` | Super Light Regular Expression parser | 6,145,369 | ✅ PASS |
| `md5sum` | MD5 cryptographic hash | 11,746,585 | ✅ PASS |
| `edn` | FIR filter & vector mathematics | 13,181,710 | ✅ PASS |
| `tarfind` | POSIX tar archive lookup | 13,329,185 | ✅ PASS |
| `qrduino` | QR code matrix decoder | 14,938,047 | ✅ PASS |
| `nettle-aes` | AES-128 block cipher | 16,161,399 | ✅ PASS |
| `picojpeg` | JPEG image decompressor | 17,222,583 | ✅ PASS |
| `wikisort` | Fast in-place stable merge sort | 23,025,989 | ✅ PASS |
| `matmult-int` | 32-bit integer matrix multiplication | 24,213,440 | ✅ PASS |
| `sglib-combined` | Red-black tree / data containers | 26,348,707 | ✅ PASS |
| `huffbench` | Huffman compression | 66,214,582 | ✅ PASS |
| `xgboost` | Decision tree inference | 992,662,851 | ✅ PASS |
| **Geometric Mean** | **Consolidated EMBench Score** | **7,011,979** | **✅ PASS** |

### Running EMBench
```bash
cd embench && ./run_embench.sh
```

---

### Standalone Processor Core (`kavacha_core`)

| Configuration | LUTs | FFs | DSPs | BRAMs |
|---------------|-----:|----:|-----:|------:|
| **Default** (Machine mode only) | **2,491** | **749** | **4** | **0** |
| **SECURE** (M+U, PMP/ePMP, ECC) | **4,362** | **1,400** | **4** | **0** |

### Full Synthesized SoC (`kavacha_arty_a7`)

| Configuration | LUTs | FFs | DSPs | BRAMs (128 KB) |
|---------------|-----:|----:|-----:|---------------:|
| **Default** | **2,816** | **1,335** | **4** | **32** |
| **SECURE** | **5,226** | **1,980** | **4** | **32** |

### Core Hierarchical Utilization Breakdown

| Sub-Module / Unit | Description | Default LUTs (FFs) | SECURE LUTs (FFs) |
|-------------------|-------------|--------------------|-------------------|
| `kavacha_regfile` | GPR File (32×32-bit, plain vs SECDED ECC) | 1,403 (0 FFs) | 1,596 (0 FFs) |
| `kavacha_csr` | CSR File (Zicsr, Machine/User, 8-region PMP/ePMP) | 389 (320 FFs) | 2,054 (965 FFs) |
| `kavacha_muldiv` | 32-bit Iterative Multiply & Divide Engine | 437 (237 FFs) | 458 (237 FFs) |
| `kavacha_pmp` | Physical Memory Protection Checker | — | 21 (0 FFs) |
| Control & Exec | FSM, 32-bit ALU, Decoder, RVC Expander, ImmGen | 262 (192 FFs) | 269 (198 FFs) |

### Running Vivado Resource Suite
```bash
./fpga/run_utilization.sh
```
*(Requires Vivado 2023.2+ sourced in environment).*
