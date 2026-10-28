#!/usr/bin/env bash
# Bar B2s v2 (FILED 8165a8830, R40.19; R40.20: BASE = the CP42.1 main): lines 8801-8840 + 8901-8940, none 8801-8820, G8 mono 8801-8820.
# Usage: sed c0b61be2e/7aceba95f in, run only after the ARM's full check is green-but-sim-baseline. builder2 J24, nothing else on it.
set -u
BASE=c0b61be2e ARM=7aceba95f
cd /home/slobdell/projects/godot-balance
export PATH=$HOME/projects/bin:$PATH GUARD_CHUNK=8 GUARD_JOBS=24
O=$HOME/balance-guard-raw/bar-b2s-v2
for c in $BASE $ARM; do
  echo "start lines $c $(date)"
  GUARD_OUT=$O GUARD_TAG=lines GUARD_WORKTREE=/home/slobdell/projects/godot-balance-guard \
    GUARD_SEEDS="$(seq 8801 8840 | tr '\n' ' ') $(seq 8901 8940 | tr '\n' ' ')" bash tools/scoreboard/guard.sh $c
  echo "start none $c $(date)"
  GUARD_OUT=$O GUARD_TAG=none GUARD_KINDS=none GUARD_WORKTREE=/home/slobdell/projects/godot-balance-guard \
    GUARD_SEEDS="$(seq 8801 8820 | tr '\n' ' ')" bash tools/scoreboard/guard.sh $c
  for f in gangs syndicate law condemned; do for team in player enemy; do
    GUARD_OUT=$O GUARD_TAG=mono-$f-$team GUARD_KINDS=none GUARD_WORKTREE=/home/slobdell/projects/godot-balance-guard \
      GUARD_ARGS="--player-faction=$f --enemy-faction=$f --$team=cpu:mono_tank" \
      GUARD_SEEDS="$(seq 8801 8820 | tr '\n' ' ')" bash tools/scoreboard/guard.sh $c
  done; done
  echo "end $c $(date)"
done
echo "BAR B2S V2 DONE $(date)"
