# FPGA Bring-up

Kavacha ships a self-contained, board-independent FPGA SoC (`fpga/kavacha_fpga.sv`)
for real-hardware bring-up, along with constraint templates for the Digilent
Arty A7.

## FPGA SoC

The synthesizable SoC bundles everything needed to see the core run on a board:

| Component | Address | Notes |
|-----------|---------|-------|
| Unified RAM (code + data + stack) | `0x0000_0000` | distributed LUT-RAM, `$readmemh`-initialised from a firmware image |
| CLINT (msip / mtime / mtimecmp) | `0x0200_0000` | machine timer and software interrupt |
| UART | `0x1000_0000` | synthesizable 115200-8N1 console |
| `tohost` | `0x2000_0000` | simulation / bring-up handshake |
| LED register | `0x2000_1000` | low 8 bits drive user LEDs |
| Debug Module + JTAG DTM | — | attach OpenOCD for on-target debug |

The design is board-agnostic: give it **one clock and one reset** and it runs.
Board tops adapt pins, clocking, and I/O.

## Firmware image

The RAM is initialised from a `firmware.mem` image (`$readmemh` format, one
32-bit word per line). A prebuilt image is included; to rebuild it from the
bring-up assembly demo you need a RISC-V toolchain:

```bash
cd sw
bash build_fpga_hello.sh      # produces firmware.mem
```

## Simulating the SoC

```bash
./build.sh fpga
```

This elaborates the full SoC with the UART and Debug Module and runs it,
printing the firmware's UART banner and exercising the LED activity — a quick
confidence check before synthesis.

## Digilent Arty A7

`fpga/arty_a7/` targets the Arty A7-100T (`xc7a100tcsg324-1`) and runs the SoC
directly from the board's 100 MHz oscillator.

| Signal | Pin | Function |
|--------|-----|----------|
| `CLK100` | E3 | 100 MHz oscillator |
| `ck_rst` | C2 | reset push-button (active-low) |
| `led[3:0]` | H5 J5 T9 T10 | firmware activity pattern |
| `uart_txd_in` | A9 | host → FPGA (RX) |
| `uart_rxd_out` | D10 | FPGA → host (TX), 115200-8N1 |
| `jtag_*` | PMOD JA | RISC-V debug (attach OpenOCD) |

The provided `.xdc` constraints and `.tcl` build script drive a Vivado
project; supply `firmware.mem` to the project as described in the header.

!!! note
    The FPGA tops are starting points. Always confirm device part, pin
    assignments, and clocking against your specific board revision.
