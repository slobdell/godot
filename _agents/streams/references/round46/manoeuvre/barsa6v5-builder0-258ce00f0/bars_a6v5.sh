#!/bin/bash
# Bar A6 v5 series (round 46, manoeuvre M3; filed before any number on 12049-12096). From the FROZEN worktree (WT) at the green hash,
# builder0 light (REMOTE_HOST exported by check_a6.sh).
export PATH=$HOME/projects/bin:$PATH
out=~/overnight-manoeuvre/r46/bars_a6v5; mkdir -p $out
WT=${WT:-/home/slobdell/projects/godot-manoeuvre-a6}
cd $WT || exit 1
h=$(git rev-parse --short HEAD)
grep -q ">> remote: make check exited 0" ~/overnight-manoeuvre/r46/check_a6/check-$h.log || { echo "check of $h not green: no series"; exit 1; }
echo "bar a6v5 hash $(git rev-parse --short HEAD) dirty '$(git status --short | tr '\n' ' ')' start $(date)" > $out/meta.txt
seeds="$(seq 12049 12072 | tr '\n' ' ')"
tools/remote.sh --light native-fresh native engage-hold "ENGAGE_HOLD_SEEDS=$seeds" ENGAGE_HOLD_ARM=off ENGAGE_HOLD_TAG=off ENGAGE_JOBS=10 TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/hold-off-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/hold-off-wrapper.log
rm -rf $out/hold-off; cp -r build/light/build/engage/hold/off $out/hold-off 2>/dev/null
tools/remote.sh --light native-fresh native engage-hold "ENGAGE_HOLD_SEEDS=$seeds" ENGAGE_HOLD_ARM=on ENGAGE_HOLD_SWITCH=holdway ENGAGE_HOLD_TAG=w ENGAGE_JOBS=10 TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/hold-w-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/hold-w-wrapper.log
rm -rf $out/hold-w; cp -r build/light/build/engage/hold/w $out/hold-w 2>/dev/null
echo "hold done $(date)" >> $out/meta.txt
python3 tests/engage/hold_table.py --pair $out/hold-off $out/hold-w --by-stage > $out/judge-hold.txt 2>&1
eseeds="$(seq 12073 12096 | tr '\n' ' ')"
for arm in base w; do f=""; [ $arm = w ] && f="--traffic-on=holdway"
  tools/remote.sh --light native-fresh native engage-probe "ENGAGE_SEEDS=$eseeds" ENGAGE_ARM=on "ENGAGE_FLAGS=$f" ENGAGE_TAG=a6v5-$arm ENGAGE_JOBS=10 TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/e1-$arm-wrapper.log 2>&1
  echo "WRAPPER_DONE $?" >> $out/e1-$arm-wrapper.log
  rm -rf $out/e1-$arm; cp -r build/light/build/engage/probe/a6v5-$arm $out/e1-$arm 2>/dev/null
done
echo "end $(date)" >> $out/meta.txt
python3 tests/engage/attack_shot_table.py --pair $out/e1-base $out/e1-w > $out/judge-e1.txt 2>&1
grep -l 'SCRIPT ERROR' $out/hold-off/*.log $out/hold-w/*.log $out/e1-*/*.log > $out/script-errors.txt 2>/dev/null
touch $out/done
