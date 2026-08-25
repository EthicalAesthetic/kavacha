// Verilator command file for Kavacha benchmark model
// All flags live here to avoid GNU Make vs Verilator argument parsing conflicts.
// Invoked via: verilator -f bench/verilator/kavacha.f <sources...>

--cc
--exe
--build
--timing
-O2
--public-flat-rw
-CFLAGS "-O2 -std=c++17"
--top-module bench_top
+incdir+/tmp/kavacha_workspace/rtl/common
+incdir+/tmp/kavacha_workspace/rtl
-Wno-lint
-Wno-UNOPTFLAT
-Wno-fatal
