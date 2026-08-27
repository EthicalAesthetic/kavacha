# Memory Interface & Alignment

Kavacha communicates with memory through a synchronous, native memory interface (`kavacha_core.sv`). This interface supports zero-latency tightly-coupled memories (TCM), sub-word byte enables, and hardware-managed misaligned memory accesses.

---

## Native Memory Interface Signal Map

```mermaid
flowchart LR
    subgraph Core [Kavacha Core]
        IMEM_A[imem_addr]
        IMEM_D[imem_rdata]
        DMEM_A[dmem_addr]
        DMEM_RE[dmem_re]
        DMEM_WE[dmem_we]
        DMEM_BE[dmem_be 3:0]
        DMEM_WD[dmem_wdata]
        DMEM_RD[dmem_rdata]
        MEM_REQ[mem_req]
        MEM_STALL[mem_stall]
    end
    
    subgraph Memory [Memory System / Fabric]
        RAM[(Tightly-Coupled RAM / Bus Bridge)]
    end
    
    IMEM_A --> RAM
    RAM --> IMEM_D
    DMEM_A --> RAM
    DMEM_RE --> RAM
    DMEM_WE --> RAM
    DMEM_BE --> RAM
    DMEM_WD --> RAM
    RAM --> DMEM_RD
    MEM_REQ --> RAM
    RAM --> MEM_STALL
```

### Complete Interface Signal Specifications

| Signal Name | Direction | Bit Width | Description |
|-------------|:---------:|:---------:|-------------|
| `imem_addr` | Output | 32 | Instruction fetch address (word/halfword aligned) |
| `imem_rdata` | Input | 32 | Instruction fetch read data bus |
| `dmem_addr` | Output | 32 | Data load/store access target address |
| `dmem_re` | Output | 1 | Data memory read strobe (active high during `STATE_LOAD`) |
| `dmem_we` | Output | 1 | Data memory write strobe (active high during `STATE_EXEC` store) |
| `dmem_be[3:0]` | Output | 4 | Byte enable strobes for byte, halfword, and word stores |
| `dmem_wdata` | Output | 32 | Store data bus (aligned to target byte lane) |
| `dmem_rdata` | Input | 32 | Load data bus returned from memory |
| `mem_req` | Output | 1 | Active high when a memory request (`IMEM` or `DMEM`) is active |
| `mem_stall` | Input | 1 | Hold signal from memory; freezes FSM state while high |

---

## Byte Enables & Sub-Word Access Alignment

Kavacha is **little-endian**. Sub-word stores (`SB`, `SH`) compute the 4-bit byte enable mask (`dmem_be`) based on the lower address bits `dmem_addr[1:0]`:

| Store Type | `dmem_addr[1:0]` | Active Bytes | `dmem_be[3:0]` | `dmem_wdata[31:0]` Placement |
|------------|:----------------:|:------------:|:--------------:|------------------------------|
| **`SB` (Byte)** | `2'b00` | Byte 0 | `4'b0001` | `{24'b0, rs2_data[7:0]}` |
| **`SB` (Byte)** | `2'b01` | Byte 1 | `4'b0010` | `{16'b0, rs2_data[7:0], 8'b0}` |
| **`SB` (Byte)** | `2'b10` | Byte 2 | `4'b0100` | `{8'b0, rs2_data[7:0], 16'b0}` |
| **`SB` (Byte)** | `2'b11` | Byte 3 | `4'b1000` | `{rs2_data[7:0], 24'b0}` |
| **`SH` (Halfword)** | `2'b00` | Bytes 0, 1 | `4'b0011` | `{16'b0, rs2_data[15:0]}` |
| **`SH` (Halfword)** | `2'b10` | Bytes 2, 3 | `4'b1100` | `{rs2_data[15:0], 16'b0}` |
| **`SW` (Word)** | `2'b00` | Bytes 0..3 | `4'b1111` | `rs2_data[31:0]` |

### Boolean Logic Equations for `dmem_be[3:0]`

```verilog
// Byte enable mask calculation in kavacha_core.sv
always_comb begin
  case (funct3)
    3'b000, 3'b100: begin // SB / LB / LBU (Byte Access)
      dmem_be = 4'b0001 << dmem_addr[1:0];
    end
    3'b001, 3'b101: begin // SH / LH / LHU (Halfword Access)
      dmem_be = 4'b0011 << {dmem_addr[1], 1'b0};
    end
    default: begin        // SW / LW (Word Access)
      dmem_be = 4'b1111;
    end
  endcase
end
```

---

## Load Data Formatting & Sign Extension

For load operations (`STATE_LOAD`), the core aligns returned data according to `dmem_addr[1:0]` and applies sign- or zero-extension:

* **`LB` (Load Byte, Signed):** Selects byte from lane `dmem_addr[1:0]`, sign-extends bit 7 across bits 31..8.
* **`LBU` (Load Byte, Unsigned):** Selects byte from lane `dmem_addr[1:0]`, zero-extends bits 31..8.
* **`LH` (Load Halfword, Signed):** Selects halfword from lane `dmem_addr[1]`, sign-extends bit 15 across bits 31..16.
* **`LHU` (Load Halfword, Unsigned):** Selects halfword from lane `dmem_addr[1]`, zero-extends bits 31..16.
* **`LW` (Load Word):** Passes 32-bit word directly to register file writeback.

---

## Hardware Misaligned Access Handling

Unlike cores that raise a misaligned load/store exception, Kavacha supports **misaligned memory accesses in hardware**. 

When a 16-bit or 32-bit load/store crosses a 32-bit word boundary (e.g. `LW` at address `0x1003`):

```
Word Boundary Crossing (e.g. 32-bit LW at 0x1003):
Address 0x1000: [ B0 ][ B1 ][ B2 ][ B3* ]  -> Beat 1: Capture Byte 3
Address 0x1004: [ B4*][ B5*][ B6*][ B7  ]  -> Beat 2: Capture Bytes 4, 5, 6
Result Word   : { B6, B5, B4, B3 }
```

### Execution Steps for Misaligned Accesses
1. **Beat 1 (Lower Word):** FSM drives `dmem_addr = addr & ~3'b011`, reads/writes lower bytes, and saves partial data in an internal holding register (`misalign_hold_reg`).
2. **Beat 2 (Upper Word):** FSM increments `dmem_addr = (addr & ~3'b011) + 4`, reads/writes upper bytes.
3. **Reassembly:** Datapath shifts and merges bytes from Beat 1 and Beat 2 into a single 32-bit value before register writeback.

This multi-beat handling is completely transparent to software — no trap handler overhead or `mtval` exception processing is required.

---

## AXI4-Lite Bridge Handshake (`mem_stall` Interaction)

When Kavacha connects to an AXI4-Lite bus fabric via `kavacha_axil_master.sv`:

```
CLK        :  _  / \  _  / \  _  / \  _  / \  _  
dmem_re    : [      HIGH       ]_________________
ARVALID    : [      HIGH       ]_________________
ARREADY    : ___________[ HIGH ]_________________
RVALID     : ___________________[ HIGH ]_________
mem_stall  : _____[ STALL HIGH ]_____[ LOW ]_____
FSM State  : [ LOAD ][ FROZEN  ][ LOAD ][ FETCH ]
```

1. Core issues `dmem_re = 1` during `STATE_LOAD`.
2. `kavacha_axil_master` asserts `mem_stall = 1` to freeze the core until the AXI4-Lite read handshake completes (`ARVALID & ARREADY` followed by `RVALID`).
3. Once `RVALID` returns data, `mem_stall` drops low, allowing the core to capture read data and transition back to `STATE_FETCH`.
