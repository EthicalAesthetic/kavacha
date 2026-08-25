/* ============================================================================
 * support.c — EMBench-IoT board support implementation for Kavacha.
 * ============================================================================ */

#include "boardsupport.h"

void initialise_board(void) { /* nothing — no GPIO or peripheral init */ }
void start_trigger(void)    { /* timing is done via mcycle CSR in bench_main.c */ }
void stop_trigger(void)     { /* ditto */ }
