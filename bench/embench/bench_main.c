/* ============================================================================
 * bench_main.c — Generic EMBench-IoT main() wrapper for Kavacha.
 *
 * This file is compiled once per benchmark. The benchmark-specific functions
 * (initialise_benchmark, benchmark, verify_benchmark) are provided by the
 * upstream EMBench source files linked in from embench-iot/src/<name>/.
 *
 * Timing protocol:
 *   1. Call initialise_benchmark() (benchmark warm-up / init).
 *   2. Read mcycle, loop LOCAL_SCALE_FACTOR × benchmark(), read mcycle.
 *   3. Report elapsed cycles via two tohost side-channel writes.
 *   4. Verify result; write tohost=1 (PASS) or tohost=2 (FAIL).
 *
 * LOCAL_SCALE_FACTOR defaults to 100 (EMBench standard).
 * Override at compile time: -DLOCAL_SCALE_FACTOR=N
 * ============================================================================ */

#include <stdint.h>
#include "../../common/kavacha_io.h"
#include "../support/boardsupport.h"

/* Provided by each EMBench benchmark's source files */
extern void initialise_benchmark(void);
extern int  benchmark(void);
extern int  verify_benchmark(int result);

#ifndef LOCAL_SCALE_FACTOR
#define LOCAL_SCALE_FACTOR  100
#endif

int main(void)
{
    initialise_board();
    initialise_benchmark();

    /* ---- timed section --------------------------------------------------- */
    uint64_t t0 = read_mcycle64();

    volatile int result = benchmark();

    uint64_t t1       = read_mcycle64();
    uint64_t elapsed  = t1 - t0;

    /* ---- report elapsed cycles via side-channel -------------------------- */
    report_cycles(elapsed);

    /* ---- verify correctness ---------------------------------------------- */
    int ok = verify_benchmark(result);

    /* ---- signal done ------------------------------------------------------- */
    write_tohost(ok ? 1u : 2u);
    return ok ? 0 : 1;
}
