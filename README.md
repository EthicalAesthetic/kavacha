# Kavacha

<p align="center">
  <img src="kavacha.png" alt="Kavacha Logo" width="600"/>
</p>

<p align="center">
  <b><i>Small by design. Correct by construction.</i></b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/ISA-RV32IMC-blue?style=flat-square" alt="ISA"/>
  <img src="https://img.shields.io/badge/Extensions-Zicsr-blue?style=flat-square" alt="Extensions"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License"/>
</p>


## About

**Kavacha** (*"armour"* in Sanskrit) is a compact, area-optimized **RV32IMC** processor core.
It executes one instruction at a time through a small multi-cycle finite state machine — no pipeline, no forwarding, and no hazard logic — which keeps the design tiny, deterministic, and straightforward to verify.

Kavacha targets roles where silicon area, power, and predictability matter more than peak throughput:

-  **Secure boot ROMs and management engines**
-  **Deeply embedded control-plane state machines**
-  **FPGA soft cores for prototyping and production**
-  **IoT microcontrollers with tight area budgets**
-  **Safety-critical subsystems (automotive, industrial, space)**


## Overview

| Property | Value |
|----------|-------|
| ISA | RV32IMC + Zicsr |
| Register width (XLEN) | 32-bit |
| Microarchitecture | Multi-cycle FSM, non-pipelined |
| Instructions in flight | 1 (zero hazards by construction) |
| Privilege modes | Machine; optional User (`SECURE`) |
| Memory protection | Optional 8-region PMP + ePMP |
| Register file | Plain, or SECDED ECC (`SECURE`) |
| Interrupts | Timer, Software, External |
| Misaligned load/store | Supported in hardware |
| Debug | RISC-V External Debug 0.13.2 (JTAG DTM + DM) |
| Bus interfaces | Native memory port + AXI4-Lite |
| Verification | Golden co-simulation, RVFI, self-checks |


```
+-----------------------------------------------------------------------------------------+
|                                      KAVACHA CORE                                       |
|                                                                                         |
|  +-------------------+        +---------------------------+        +-----------------+  |
|  | Native Memory     | <----> |  Control FSM & Execution  | <----> | AXI4-Lite Bus   |  |
|  | Synchronous Port  |        | FETCH -> EXEC -> LOAD/MD  |        | Master Interface|  |
|  +-------------------+        +-------------+-------------+        +-----------------+  |
|                                             |                                           |
|  +-------------------+        +-------------v-------------+        +-----------------+  |
|  | JTAG Debug Module | <----> |     Instruction Fetch     | <----> |  RVC Expander   |  |
|  |  (Spec 0.13.2)    |        |       & PC Logic          |        |  (16-bit -> 32) |  |
|  +-------------------+        +-------------+-------------+        +-----------------+  |
|                                             |                                           |
|                               +-------------v-------------+                             |
|                               |    Decoder & Imm Gen      |                             |
|                               +-------------+-------------+                             |
|                                             |                                           |
|              +------------------------------+------------------------------+            |
|              |                              |                              |            |
|    +---------v----------+        +----------v----------+        +----------v---------+  |
|    |  Register File     |        |   CSR File & Traps  |        | Physical Memory    |  |
|    | (32x32, SECDED ECC)|        |  (Zicsr, Machine/U) |        | Protection (ePMP)  |  |
|    +---------+----------+        +----------+----------+        +----------+---------+  |
|              |                              |                              |            |
|              +------------------------------+------------------------------+            |
|                                             |                                           |
|                     +-----------------------+-----------------------+                   |
|                     |                                               |                   |
|           +---------v----------+                         +----------v----------+        |
|           |    32-bit ALU      |                         |  Iterative Multiply |        |
|           | (Arithmetic/Logic) |                         |   & Divide Engine   |        |
|           +--------------------+                         +---------------------+        |
+-----------------------------------------------------------------------------------------+
```

---

## Features

###  Predictable, Zero-Hazard Execution
A single instruction walks a short FSM (`FETCH → EXEC → {LOAD | MD} → FETCH`).
There is nothing to forward and no hazard to detect — behaviour is completely
deterministic, and correctness is easy to establish.

###  Two-Tier Trust Model
The optional `SECURE` configuration adds a **User privilege mode** and an **8-region Physical Memory Protection (PMP)** unit with **ePMP** (`mseccfg`) semantics — including Machine Mode Lockdown (MML), Machine Mode Whitelist Policy (MMWP), and Rule Locking Bypass (RLB). Even Machine mode cannot silently escape a strict isolation policy.

###  Register File ECC
The `SECURE` configuration replaces the plain register file with a **SECDED** (single-error-correct, double-error-detect) protected version. Each register is stored with check bits so that a single-bit upset is corrected on read and a double-bit upset is detected — critical for radiation-sensitive and reliability-critical deployments.

###  Industrial-Strength Verification
Every build is checked against a **golden RV32IM ISA model** (retire-for-retire co-simulation), exposes an **RVFI** (RISC-V Formal Interface) port for formal analysis, and ships self-checking testbenches for the core, the debug module, and the ECC register file.

###  Dual Bus Interfaces
- **Native memory port** — for tightest, zero-latency tightly-coupled memory integration.
- **AXI4-Lite wrapper** — for drop-in integration into standard SoC fabrics, sharing buses with other masters and peripherals.

###  Hardware Debug (RISC-V Debug 0.13.2)
A JTAG Debug Transport Module and RISC-V Debug Module let **OpenOCD** and **GDB** halt, resume, single-step, inspect registers and CSRs, and read/write memory over the system bus — all out of the box.

###  Compressed Instructions (RVC)
Full support for the **C extension** — 16-bit compressed instructions are transparently expanded to their 32-bit equivalents, improving code density for memory-constrained deployments.

###  Precise Traps & Interrupts
Exceptions (`ECALL`, `EBREAK`, illegal instruction, misaligned access), `MRET`, and timer / software / external interrupt lines are all handled precisely at instruction boundaries.

---

## Configuration Options

Kavacha ships in two build-time configurations, selected by the `SECURE` RTL parameter
or compile-time define `-DKAVACHA_SECURE`:

| Property / Feature | **Default** | **SECURE** |
|---|---|---|
| **Privilege modes** | Machine (M) only | Machine (M) + User (U) |
| **Memory protection** | — | 8-region PMP + ePMP (`mseccfg`) |
| **Register file** | Plain (32×32-bit) | SECDED ECC protected |
| **Target use case** | Smallest footprint | Isolation & reliability |
| **`misa` U bit** | Not set | Set |
| **Locked PMP regions** | — | Enforced on M-mode too |

### Building each configuration

```bash
# Default configuration (Machine mode only, smallest footprint)
./build.sh

# SECURE configuration (M+U, PMP, ECC)
./build.sh pmp       # User mode + PMP test program
./build.sh epmp      # ePMP (mseccfg) rules test
./build.sh ecc       # Register-file SECDED ECC unit test
```

---

## FPGA Resource Utilization

> **Target:** Xilinx Artix-7 (Arty A7-100T, `xc7a100tcsg324-1`)
> Post-synthesis results from Vivado.

| Configuration | LUTs | FFs | DSPs | BRAMs |
|---------------|------|-----|------|-------|
| **Default** | — | — | — | — |
| **SECURE** | — | — | — | — |

*Fill in the above values from your Vivado post-synthesis utilization report.*

---

## Benchmarks

All benchmarks are compiled with:
```
riscv-none-elf-gcc -O2 -march=rv32imc_zicsr -mabi=ilp32
```
Simulated on the Verilator cycle-accurate model.

### CoreMark

| Metric | Value |
|--------|-------|
| Iterations | 1000 |
| Total cycles | 7,852,705 |
| Cycles / iteration | 785,270.5 |
| CoreMark / MHz | **1.1734** |
| Status | ✅ PASS |

### Dhrystone v2.1

| Metric | Simulation | FPGA (Arty A7 @ 50 MHz) |
|--------|-----------|-------------------------|
| Iterations | 100,000 | 100,000 |
| Total cycles | 142,400,085 | 203,200,109 |
| Cycles / iteration | 1,424 | 2,032 |
| Dhrystones / sec / MHz | 702.2 | 492.1 |
| DMIPS / MHz | **0.399** | **0.280** |
| Status | ✅ PASS | ✅ PASS |

### EMBench-IoT

| Metric | Value |
|--------|-------|
| Benchmarks run | 20 |
| Benchmarks passed | 19 / 20 |
| Geometric mean (cycles) | **6,719,052** |
| Scale factor | 100 (10 for picojpeg, nsichneu, qrduino, wikisort) |

> *`xgboost` is extremely compute-intensive (997M cycles) and may time out under default simulation limits.*

###  Reproduce It Yourself

All benchmark results are fully reproducible. Run these commands from the repo root:

```bash
# 1. Build the Verilator simulation model
cd bench
make verilator-kavacha

# 2. Run CoreMark
make run-kavacha-coremark ITERATIONS=1000

# 3. Run all 20 EMBench-IoT benchmarks
make run-kavacha-embench

# 4. Run Dhrystone (from its own directory)
cd ../dhrystone
./run_dhrystone.sh

# 5. Generate a results report
cd ../bench
make report
```

Results are written to `bench/results/` as `.log` files and a summary `report.md`.

---

## Repository Layout

```
kavacha/
├── rtl/                 Core RTL
│   ├── kavacha_core.sv    Multi-cycle control FSM + datapath
│   ├── kavacha_soc.sv     Minimal SoC (IMEM/DRAM, tohost, Debug Module)
│   ├── kavacha_debug.sv   JTAG DTM + RISC-V Debug Module
│   ├── kavacha_axil.sv    AXI4-Lite master / slave / SoC wrapper
│   └── common/            Shared, pre-verified datapath leaf cells
│                          (ALU, multiply/divide, register file, CSR file,
│                           immediate/branch units, decoder, RVC, PMP, ECC)
├── tb/                  Testbenches (smoke, RVFI, debug, AXI-Lite, ECC)
├── tools/               Golden ISA model + co-simulation driver
├── programs/            Test-program builders
├── sw/                  Assembly test programs & bring-up firmware
├── fpga/                FPGA SoC + Arty A7 constraints
├── bench/               Benchmarking suite (CoreMark, EMBench-IoT)
├── dhrystone/           Dhrystone v2.1 benchmark
├── coremark/            CoreMark FPGA runners
├── embench/             EMBench-IoT FPGA runners
├── docs/                Documentation site (MkDocs)
├── build.sh             Linux / macOS build & test driver
└── build.ps1            Windows (PowerShell) build & test driver
```

---

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| **Verilator** | 5.018+ | Cycle-accurate RTL simulation for benchmarks |
| **Icarus Verilog** | 12+ | Core simulation (`iverilog` / `vvp`) |
| **Python** | 3.10+ | Test-program builders, co-simulation, report generation |
| **RISC-V GCC** | 13+ (`riscv-none-elf-gcc` or `riscv64-unknown-elf-gcc`) | Compiling firmware and benchmarks |
| **Vivado** | 2023.2+ *(optional)* | FPGA synthesis for Arty A7 |

---

## Build & Verification

### Quick start

```bash
./build.sh          # compile + self-checking smoke test
```

Expected output:
```
[TB] PASS
```

### Full verification suite

```bash
./build.sh cosim    # Co-simulate against the golden ISA model
./build.sh rvfi     # RVFI (formal interface) self-check
./build.sh debug    # JTAG / Debug-Module self-check
./build.sh pmp      # SECURE config: User mode + PMP test program
./build.sh epmp     # SECURE config: ePMP (mseccfg) rules test
./build.sh ecc      # Register-file SECDED ECC unit test
./build.sh fpga     # FPGA SoC simulation (UART banner + LED activity)
./build.sh clean    # Clean build artifacts
```

| Method | Target | What it proves |
|--------|--------|----------------|
| Smoke test | `sim` | The core runs a real program to completion |
| Golden co-simulation | `cosim` | RTL matches the ISA model retire-for-retire |
| RVFI self-check | `rvfi` | Instruction-level trace conforms to the formal interface |
| Debug self-check | `debug` | The Debug Module halts, inspects, and steps correctly |
| PMP test | `pmp` | User-mode isolation and PMP enforcement |
| ePMP test | `epmp` | Enhanced PMP (mseccfg) rules |
| ECC unit test | `ecc` | The register file corrects/detects bit errors |
| FPGA SoC test | `fpga` | Full SoC simulation with synthesizable UART and Debug Module |

### Windows (PowerShell)

```powershell
.\build.ps1          # compile + smoke
.\build.ps1 cosim    # + golden co-simulation
.\build.ps1 rvfi
.\build.ps1 debug
.\build.ps1 ecc
.\build.ps1 fpga
.\build.ps1 clean
```

---

## Documentation

Full documentation — architecture, ISA, memory map, CSRs, security model,
debug, bus integration, FPGA bring-up, and verification — lives in [`docs/`](docs)
and builds into a browsable site with [MkDocs](https://www.mkdocs.org/):

```bash
pip install -r docs/requirements.txt
mkdocs serve      # http://127.0.0.1:8000
```

---

## License

Released under the [MIT License](LICENSE) — free for commercial and academic use.
