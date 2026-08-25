/* ============================================================================
 * boardsupport.h — EMBench-IoT board support header for Kavacha.
 *
 * EMBench expects this file to be on the include path and to define
 * board_init() / initialise_board() / start_trigger() / stop_trigger().
 * All timing is done externally via mcycle CSR; triggers are no-ops.
 * ============================================================================ */

#ifndef BOARDSUPPORT_H
#define BOARDSUPPORT_H

#ifdef __cplusplus
extern "C" {
#endif

void initialise_board(void);
void start_trigger(void);
void stop_trigger(void);

#ifdef __cplusplus
}
#endif

#endif /* BOARDSUPPORT_H */
