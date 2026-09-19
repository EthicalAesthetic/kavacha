/* ============================================================================
 * kavacha_io.h — Hardware I/O macros for Kavacha bare-metal benchmarks.
 *
 * CSR addresses used:
 *   0xB00  mcycle   — machine-mode cycle counter low 32 bits
 *   0xB80  mcycleh  — machine-mode cycle counter high 32 bits
 * ============================================================================ */

#ifndef KAVACHA_IO_H
#define KAVACHA_IO_H

#include <stdint.h>

/* ---- tohost ---------------------------------------------------------------- */
#define TOHOST_ADDR  0x20000000UL

static inline void write_tohost(uint32_t val)
{
    volatile uint32_t* p = (volatile uint32_t*)TOHOST_ADDR;
    *p = val;
}

/* ---- 64-bit cycle counter ------------------------------------------------- */
/* Read mcycle / mcycleh with mid-rollover protection. */
static inline uint64_t read_mcycle64(void) {
    uint32_t lo, hi, hi_check;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (hi));
        __asm__ volatile ("csrr %0, mcycle"  : "=r" (lo));
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (hi_check));
    } while (hi != hi_check);
    return ((uint64_t)hi << 32) | lo;
}

static inline uint32_t read_mcycle(void)
{
    uint32_t v;
    __asm__ volatile ("csrrs %0, 0xC00, zero" : "=r"(v)); /* cycle */
    return v;
}

#endif /* KAVACHA_IO_H */
