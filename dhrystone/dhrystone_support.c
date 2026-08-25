#include "dhry.h"
#include <stddef.h>
#include <stdint.h>

/* Minimal bare-metal support for Dhrystone */

/* 1. Malloc replacement (Dhrystone only allocates two structs at the beginning) */
Rec_Type rec1, rec2;
void* malloc(size_t size) {
    static int alloc_count = 0;
    if (alloc_count == 0) { alloc_count++; return &rec1; }
    if (alloc_count == 1) { alloc_count++; return &rec2; }
    return NULL;
}

/*
 * 2. Timer functions using RISC-V mcycle / minstret CSRs.
 * We read only the 32-bit low halves — Dhrystone with 100,000 iterations
 * takes ~144M cycles, which fits in 32 bits (max ~4.29B).
 * The metric calculation in dhry_1.c uses explicit (long long) casts
 * to avoid overflow in the intermediate products.
 */
long time(long* tloc) {
    uint32_t cycles;
    __asm__ volatile ("csrr %0, mcycle" : "=r" (cycles));
    if (tloc) *tloc = (long)cycles;
    return (long)cycles;
}

long insn(long* tloc) {
    uint32_t instret;
    __asm__ volatile ("csrr %0, minstret" : "=r" (instret));
    if (tloc) *tloc = (long)instret;
    return (long)instret;
}


