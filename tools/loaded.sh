#!/usr/bin/env bash
# tools/loaded.sh [PER_CORE]: is this box too loaded to judge a wall-clock bound? Exit 0 = loaded (a miss is NOT JUDGED),
# 1 = quiet (a miss FAILs). Prints "load L on C cores (P per core)" either way.
#
# Round 38 (R38.19): the bound is 1-minute load per PHYSICAL core (lscpu), default 1.5. Round 33's gates divided by nproc,
# which counts hyperthreads: builder2 (32 vCPUs on 16 cores) then read "quiet" up to load 48, and web-smoke's first-sound
# bound FAILed four checks at load 31-38 that solo re-runs passed; builder0 (12 threads on 10 cores) barely moved.
# A reference-workload ratio (perf-judge's rule) needs a per-host nominal, and round 38's N3 trial showed builder2's is
# not builder0's scaled; cores need none. LOADED_LOAD / LOADED_CORES stand in for /proc/loadavg and lscpu (the tests).
set -u
per_core=${1:-1.5}
load=${LOADED_LOAD:-$(cut -d' ' -f1 /proc/loadavg)}
cores=${LOADED_CORES:-$(lscpu -p=CORE,SOCKET 2>/dev/null | grep -v '^#' | sort -u | wc -l)}
[ "${cores:-0}" -gt 0 ] 2>/dev/null || cores=$(nproc)
awk -v l="$load" -v c="$cores" -v t="$per_core" 'BEGIN { printf "load %s on %d cores (%.2f per core)\n", l, c, l / c; exit !(l >= t * c) }'
