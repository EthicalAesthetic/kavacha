/* ============================================================================
 * bench_main_fpga.c — EMBench-IoT main() wrapper for FPGA HIL targets.
 *
 * Replaces bench_main.c when building for the Arty A7 hardware target.
 * Key differences:
 *   - Reports elapsed cycles over UART via printf (→ syscalls_fpga.c → MMIO UART)
 *     instead of the tohost side-channel (which is invisible on real hardware).
 *   - Output lines parsed by run_hil_bench.py:
 *       BENCH:<name>
 *       CYCLES:<decimal>
 *       SCALE:<decimal>
 *       RESULT:PASS  or  RESULT:FAIL
 *
 * LOCAL_SCALE_FACTOR and BENCHMARK_NAME are supplied at compile time by the
 * Makefile (same as the simulation build).
 * ============================================================================ */

#include <stdint.h>
#include <stdio.h>
#include "../../common/kavacha_io.h"
#include "../support/boardsupport.h"

/* Provided by each EMBench benchmark's source files */
extern void initialise_benchmark(void);
extern int  benchmark(void);
extern int  verify_benchmark(int result);

#ifndef LOCAL_SCALE_FACTOR
#define LOCAL_SCALE_FACTOR 100
#endif

#ifndef BENCHMARK_NAME
#define BENCHMARK_NAME "unknown"
#endif

int main(void)
{
    initialise_board();
    initialise_benchmark();

    /* ---- announce benchmark name ----------------------------------------- */
    printf("BENCH:%s\r\n", BENCHMARK_NAME);

    /* ---- timed section ---------------------------------------------------- */
    uint64_t t0 = read_mcycle64();

    volatile int result = benchmark();

    uint64_t t1      = read_mcycle64();
    uint64_t elapsed = t1 - t0;

    /* ---- report over UART (machine-readable) ------------------------------ */
    printf("CYCLES:%u\r\n", (uint32_t)elapsed);
    printf("SCALE:%d\r\n",    (int)LOCAL_SCALE_FACTOR);

    /* ---- verify correctness ----------------------------------------------- */
    int ok = verify_benchmark(result);
    printf("RESULT:%s\r\n", ok ? "PASS" : "FAIL");

    /* ---- signal done (tohost for any attached debug probe) ---------------- */
    write_tohost(ok ? 1u : 2u);
    return ok ? 0 : 1;
}
