# Privilege & Security

Kavacha's default configuration runs entirely in **Machine mode** — the smallest
footprint. The optional **`SECURE`** configuration adds a User privilege mode,
Physical Memory Protection (PMP) with ePMP semantics, and a register file
protected by error-correcting code.

Enable it with the `SECURE` RTL parameter, or at compile time with
`-DKAVACHA_SECURE`.

## Privilege modes

| Mode | Default build | `SECURE` build |
|------|---------------|----------------|
| Machine (M) | ✓ | ✓ |
| User (U) | — | ✓ |

With User mode present, `misa` sets the `U` bit and `mstatus` tracks the
previous privilege level across traps. Software drops to User mode by setting
the previous-privilege field and executing `MRET`; a trap returns control to
Machine mode.

## Physical Memory Protection (PMP)

The `SECURE` configuration includes an **8-region PMP** that checks every
instruction fetch, load, and store:

- **Matching modes:** `OFF`, `TOR` (top-of-range), `NA4` (naturally aligned
  4-byte), and `NAPOT` (naturally aligned power-of-two).
- **Permissions:** independent read (`R`), write (`W`), and execute (`X`) bits
  per region.
- **Locking:** the `L` bit locks a region's configuration and applies it to
  Machine mode as well as User mode.
- **Priority:** the lowest-numbered matching region wins, per the RISC-V
  privileged specification.
- **Defaults:** Machine mode may access memory not covered by any region; User
  mode is denied unless a region grants access.

The region configuration and address state live in the `pmpcfg`/`pmpaddr` CSRs.

## Enhanced PMP (ePMP)

The `mseccfg` CSR enables **ePMP** behaviour, which tightens the default rules:

- **Machine Mode Whitelist Policy (`MMWP`)** makes any access not matching a PMP
  region fault, rather than defaulting to allow for Machine mode (enforced in hardware).
- **Rule Locking Bypass (`RLB`)** controls whether locked rules can be modified while locked.
- *Note on MML:* `mseccfg.MML` (Machine Mode Lockdown) bit is provided in the CSR register interface; full MML re-encoded permission semantics in the hardware address checker are reserved for future hardware revision.

Together, ePMP lets a Machine-mode supervisor build a strict memory-isolation
policy that even Machine mode cannot silently escape.

## Register file ECC

The `SECURE` configuration replaces the plain register file with a **SECDED**
(single-error-correct, double-error-detect) protected version. Each register is
stored with check bits so that a single-bit upset is corrected on read and a
double-bit upset is detected — useful for reliability-sensitive deployments. The
`ecc` build target runs a dedicated unit test for this cell.

## Building the secure configuration

```bash
./build.sh pmp     # User mode + PMP, running the PMP test program
./build.sh epmp    # exercises the ePMP (mseccfg) rules
./build.sh ecc     # register-file SECDED ECC unit test
```
