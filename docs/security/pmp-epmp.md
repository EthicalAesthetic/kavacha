# 8-Region PMP & ePMP Rules

Kavacha features a hardware-enforced **8-Region Physical Memory Protection (PMP)** unit (`kavacha_pmp.sv`) and **Enhanced PMP (ePMP)** extension when compiled in the **SECURE** configuration (`SECURE = 1`).

PMP checks every instruction fetch, memory load, and memory store against 8 programmable address regions, enforcing strict memory isolation between Machine mode and User mode.

---

## 1. PMP Configuration & Address Registers

PMP rules are configured through `pmpcfg0`–`pmpcfg1` and `pmpaddr0`–`pmpaddr7` CSRs:

```
pmpcfg0 CSR (0x3A0) - Configuration for Regions 0 to 3:
 31         24 23         16 15          8 7           0
|  pmp3cfg    |  pmp2cfg    |  pmp1cfg    |  pmp0cfg    |

Individual 8-bit PMP Region Entry (pmpNcfg):
 7   6  5   4   3   2   1   0
| L | Res  |  A[1:0] | X | W | R |
```

### PMP Entry Bitfield Specifications

| Bit Field | Name | Description / Function |
|:---------:|:----:|------------------------|
| **0** | `R` | **Read Permission:** `1` = Read allowed, `0` = Read denied |
| **1** | `W` | **Write Permission:** `1` = Write allowed, `0` = Write denied |
| **2** | `X` | **Execute Permission:** `1` = Instruction fetch allowed, `0` = Fetch denied |
| **4:3** | `A` | **Address Matching Mode:** `00`=OFF, `01`=TOR, `10`=NA4, `11`=NAPOT |
| **7** | `L` | **Lock Bit:** `1` = Region locked and enforced on M-mode; `0` = Unlocked (U-mode only) |

---

## 2. Address Matching Modes (`A` Field)

| Mode | `A[1:0]` | Region Size | Address Range Calculation |
|------|:-------:|:-----------:|---------------------------|
| **`OFF`** | `2'b00` | Disabled | Region inactive. |
| **`TOR`** (Top of Range) | `2'b01` | Arbitrary | `pmpaddr[i-1] <= addr < pmpaddr[i]` (For region 0: `0 <= addr < pmpaddr[0]`). |
| **`NA4`** (Naturally Aligned 4-Byte) | `2'b10` | 4 Bytes | `addr[31:2] == pmpaddr[i][29:0]` |
| **`NAPOT`** (Power of Two) | `2'b11` | $\ge 8$ Bytes ($2^{N+3}$) | Address mask computed from trailing `1`s in `pmpaddr[i]`. |

### NAPOT Encoding Example
To cover a **64 KB region** starting at `0x80000000`:
* `pmpaddr[i]` is loaded with `{0x80000000[31:3], 13'b0111111111111}`.
* Trailing `1` bits define the power-of-two span ($2^{13+3} = 2^{16} = 64\text{ KB}$).

---

## 3. Region Matching Priority Logic

1. **Lowest-Numbered Win:** The hardware checks all 8 regions in parallel. If an address matches multiple regions, the **lowest-numbered matching region** (e.g. Region 0 over Region 3) determines access permission.
2. **Default Policy (No Region Matches):**
   * **User Mode (`priv_mode == 2'b00`):** Access is **denied by default** (raises Access Fault).
   * **Machine Mode (`priv_mode == 2'b11`):** Access is **allowed by default** (unless `MMWP` is enabled).

---

## 4. Enhanced PMP (ePMP `mseccfg` CSR)

The `mseccfg` CSR (`0x747`) introduces Enhanced PMP rules, providing tighter security controls for embedded systems:

```
mseccfg CSR Layout (0x747):
 31                         3   2     1     0
|         Reserved           | RLB | MMWP | MML |
```

| Bit | Name | Description & Security Impact |
|:---:|:----:|-------------------------------|
| **0** | **`MML`** (Machine Mode Lockdown) | Changes permission interpretation for locked (`L=1`) rules. Enables shared read-only code/data regions and prevents Machine mode from silently bypassing locked memory protection rules. |
| **1** | **`MMWP`** (Machine Mode Whitelist Policy) | When set, any memory access from **Machine mode** that does not match an active PMP region is **denied**, changing Machine mode default from allow-all to deny-all. |
| **2** | **`RLB`** (Rule Locking Bypass) | Controls whether locked PMP regions can be dynamically reconfigured by Machine-mode software. |

---

## 5. SystemVerilog Priority Checker (`kavacha_pmp.sv`)

```verilog
// 8-Region Parallel Address & Permission Checker
always_comb begin
  access_fault = 1'b0;
  match_found  = 1'b0;
  
  for (int i = 7; i >= 0; i--) begin
    if (region_match[i]) begin
      match_found = 1'b1;
      // Enforce L bit, privilege level, and requested access type (R/W/X)
      if (priv_mode == 2'b00 || pmp_cfg[i].L) begin
        if ((req_type == PMP_READ  && !pmp_cfg[i].R) ||
            (req_type == PMP_WRITE && !pmp_cfg[i].W) ||
            (req_type == PMP_EXEC  && !pmp_cfg[i].X)) begin
          access_fault = 1'b1;
        end
      end
    end
  end
  
  // Default deny for User mode if no region matches
  if (!match_found && priv_mode == 2'b00) begin
    access_fault = 1'b1;
  end
end
```

---

## 6. Access Fault Exceptions

When a PMP/ePMP check fails, access to memory is blocked and a precise exception is generated:

| Denied Memory Access Type | Exception Raised (`mcause`) | `mtval` Contents |
|---------------------------|:--------------------------:|------------------|
| **Instruction Fetch** | **Instruction Access Fault** (`mcause = 32'h00000001`) | Faulting fetch PC address |
| **Data Memory Load** | **Load Access Fault** (`mcause = 32'h00000005`) | Faulting data memory load address |
| **Data Memory Store** | **Store/AMO Access Fault** (`mcause = 32'h00000007`) | Faulting data memory store address |
