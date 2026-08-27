# Machine Mode CSRs

Kavacha implements the full set of RISC-V Machine-Mode Control and Status Registers (CSRs) required for system initialization, interrupt gating, trap handling, and performance profiling (`kavacha_csr.sv`).

---

## 1. Machine Information Registers

These read-only registers identify the vendor, architecture, implementation version, and hardware thread ID.

| CSR Name | Address | Access | Reset Value | Bitfield Specifications |
|----------|:-------:|:------:|:-----------:|-------------------------|
| `mvendorid` | `0xF11` | RO | `32'h00000000` | **Vendor ID:** `0` indicates an open-source / non-commercial core. |
| `marchid` | `0xF12` | RO | `32'h00000030` | **Architecture ID:** `48` (`0x30`) identifies the Kavacha microarchitecture family. |
| `mimpid` | `0xF13` | RO | `32'h00010000` | **Implementation ID:** Encodes release version `v1.0.0`. |
| `mhartid` | `0xF14` | RO | `32'h00000000` | **Hardware Thread ID:** `0` (Kavacha is a single-hart processor core). |

---

## 2. Machine Status Register (`mstatus`, CSR `0x300`)

The `mstatus` register tracks global interrupt state and privilege transitions:

```
mstatus Register Layout (0x300):
 31       13 12 11 8 7   6 5 4 3   2 1 0
| Reserved  | MPP | Res | MPIE | Res | MIE |
```

| Bit Field | Name | Access | Reset | Functional Description |
|:---------:|:----:|:------:|:-----:|------------------------|
| **3** | `MIE` | RW | `0` | **Machine Interrupt Enable:** `1` = Global M-mode interrupts enabled; `0` = Disabled. |
| **7** | `MPIE` | RW | `0` | **Machine Previous Interrupt Enable:** Stores `MIE` state prior to entering a trap. |
| **12:11** | `MPP` | RW | `2'b00` | **Machine Previous Privilege:** Stores privilege level prior to trap (`2'b11` = M-mode, `2'b00` = U-mode). |

---

## 3. Machine ISA Register (`misa`, CSR `0x301`)

Reports the base architecture capabilities to software and compilers:

```
misa Register Layout (0x301):
 31 30 29              20 19      12 11 10      2 1 0
| MXL |    Reserved      | U | Reserved | M | C | Res | I |
```

* **`MXL[31:30]`:** `2'b01` (32-bit native XLEN).
* **Extensions Enabled:** `I` (bit 8 = 1), `M` (bit 12 = 1), `C` (bit 2 = 1).
* **Security Tier (`SECURE=1`):** `U` bit 20 = 1 (User mode enabled).
* **Value:** `32'h40001104` (`SECURE = 0`) or `32'h40101104` (`SECURE = 1`).

---

## 4. Machine Interrupt & Trap Control Registers

### `mie` (Interrupt Enable, CSR `0x304`) & `mip` (Interrupt Pending, CSR `0x344`)

```
mie / mip Bit Layout (0x304 / 0x344):
 31          12 11   10 9   8 7   6 5   4 3   2 1 0
|  Reserved    | MEIE | Res | SEIE | Res | MTIE | Res | MSIE |
```

| Bit | Field | Access | Typical Source | Function |
|:---:|:-----:|:------:|----------------|----------|
| **3** | `MSIE` / `MSIP` | RW | CLINT `msip` register | Software Interrupt Enable / Pending |
| **7** | `MTIE` / `MTIP` | RW | CLINT `mtime` $\ge$ `mtimecmp` | Machine Timer Interrupt Enable / Pending |
| **11** | `MEIE` / `MEIP` | RW | External PLIC / Interrupt Line | External Interrupt Enable / Pending |

### `mtvec` (Trap Vector Base Address, CSR `0x305`)

```
mtvec Register Layout (0x305):
 31                                         2 1    0
|                BASE[31:2]                  | MODE |
```

* **`BASE[31:2]`:** 4-byte aligned base address of the Machine trap handler.
* **`MODE[1:0]`:**
  * `2'b00` (**Direct Mode**): All traps vector to `BASE`.
  * `2'b01` (**Vectored Mode**): Exceptions vector to `BASE`; interrupt $i$ vectors to `BASE + (i * 4)`.

---

## 5. Machine Trap Save & State Registers

| CSR Name | Address | Access | Reset | Description & Trap Flow Behavior |
|----------|:-------:|:------:|:-----:|----------------------------------|
| `mscratch` | `0x340` | RW | `32'h0` | **Scratch Register:** Dedicated 32-bit register for trap handlers to swap context stack pointers. |
| `mepc` | `0x341` | RW | `32'h0` | **Exception PC:** Captures `pc` on trap entry. Restored to `pc` when executing `MRET`. |
| `mcause` | `0x342` | RW | `32'h0` | **Trap Cause:** Bit 31 = `1` for interrupts, `0` for exceptions. Bits 30:0 hold trap code (e.g. `2` = Illegal Instr, `8` = ECALL, `7` = Timer Int). |
| `mtval` | `0x343` | RW | `32'h0` | **Trap Value:** Holds faulting address (on access faults) or instruction word (on illegal instruction). |

---

## 6. Performance Counters (`mcycle` & `minstret`)

| CSR Name | Address | Access | Reset | Counter Increment Behavior |
|----------|:-------:|:------:|:-----:|----------------------------|
| `mcycle` | `0xB00` | RW | `32'h0` | Increments on every clock cycle (`clk`) when core is un-stalled. |
| `minstret` | `0xB02` | RW | `32'h0` | Increments on every retired instruction (`rvfi_valid == 1`). |
