# Verification

Kavacha's correctness is established with several complementary methods, all
runnable from the build drivers.

## Self-checking smoke test

The default build assembles a small RV32IMC program that exercises arithmetic,
memory, branches, and traps, then checks the result via the `tohost` handshake:

```bash
./build.sh          # -> [TB] PASS
```

## Golden co-simulation

The strongest functional check runs the same program on the RTL and on an
independent **golden RV32IM ISA model** (`tools/golden_rv32im.py`), then compares
every retired instruction — PC, instruction word, and register write-back —
one for one:

```bash
./build.sh cosim
# [cosim] MATCH — 142 retires identical. RTL is ISA-correct.
```

Any divergence between the RTL and the reference model is reported at the first
mismatching retire, which makes functional bugs easy to localise.

## RVFI (RISC-V Formal Interface)

Kavacha exposes an **RVFI** port, the standard interface consumed by formal
verification frameworks. The `rvfi` target builds a self-checking harness around
that interface:

```bash
./build.sh rvfi     # -> RVFI: PASS
```

The RVFI signals (valid, order, PC, instruction, register and memory accesses)
can also be fed into an external formal flow to prove instruction-level
properties.

## Debug-Module self-check

The `debug` target verifies the external-debug path end to end — halt, GPR
access through the Access-Register command, single-step, and re-halt:

```bash
./build.sh debug    # -> DEBUG: PASS
```

## Register-file ECC unit test

The `ecc` target drives the SECDED-protected register file with injected
single- and double-bit errors and checks correction and detection:

```bash
./build.sh ecc      # -> ECC: PASS
```

## PMP and ePMP verification

The `pmp` and `epmp` targets compile and simulate dedicated assembly suites
testing User-mode privilege transitions, PMP access enforcement, and ePMP
`mseccfg` locking/whitelist rules:

```bash
./build.sh pmp      # -> [TB] PASS (cycle 132)
./build.sh epmp     # -> [TB] PASS (cycle 78)
```

## AXI4-Lite bridge verification

The `axil` target exercises `kavacha_axil.sv`, verifying read/write transactions,
burst translation, and response channel handshaking:

```bash
./build.sh axil     # -> [TB] PASS (AXI4-Lite)
```

## FPGA SoC simulation

The `fpga` target verifies the full synthesizable board SoC with integrated UART,
CLINT, unified RAM, and user LEDs:

```bash
./build.sh fpga     # -> FPGA: PASS
```

## Summary

| Method | Target | What it proves |
|--------|--------|----------------|
| Smoke test | `sim` | the core runs a real program to completion |
| Golden co-simulation | `cosim` | RTL matches the ISA model retire-for-retire |
| RVFI self-check | `rvfi` | instruction-level trace conforms to the formal interface |
| Debug self-check | `debug` | the Debug Module halts, inspects, and steps correctly |
| PMP test | `pmp` | User-mode isolation and PMP enforcement |
| ePMP test | `epmp` | Enhanced PMP (mseccfg) rules |
| ECC unit test | `ecc` | the register file corrects/detects bit errors |
| AXI4-Lite test | `axil` | native memory bus to AXI4-Lite conversion |
| FPGA SoC test | `fpga` | full SoC simulation with UART and Debug Module |
