#!/bin/bash
# Bar S v6 series (round 46, manoeuvre M2; filed before any number on 12001-12048). Run from the FROZEN worktree (WT) at the tip whose check is green (FROZEN_HASH),
# builder3 light. Arms: base = --shape-latch=off; s6 = --shape-latch=off --seat-bound=on --seat-order=on --seat-last=open.
export PATH=$HOME/projects/bin:$PATH
out=~/overnight-manoeuvre/r46/bars_s6; mkdir -p $out
WT=${WT:-/home/slobdell/projects/godot-manoeuvre-s6}
cd $WT || exit 1
echo "bar s6 hash $(git rev-parse --short HEAD) dirty '$(git status --short | tr '\n' ' ')' start $(date)" > $out/meta.txt
S6='--seat-bound=on,--seat-order=on,--seat-last=open'
cells=""; for m in locks terminus crossing; do for s in $(seq 12001 12024); do cells="$cells $m:$s"; done; done
tools/remote.sh --light native-fresh native manoeuvre-bar-s "BS_CELLS=$cells" "BS_ARMS=base:--shape-latch=off s6:--shape-latch=off,$S6" BS_JOBS=8 BS_DIR=build/barss6-deciding TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/deciding-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/deciding-wrapper.log
rm -rf $out/deciding; cp -r build/light/build/barss6-deciding $out/deciding 2>/dev/null
echo "workload done $(date)" >> $out/meta.txt
gcells=""; for m in crossing locks sumps terminus; do for s in $(seq 12025 12036); do gcells="$gcells $m:click:$s"; done; done
tools/remote.sh --light native-fresh native manoeuvre-probe-jam "PJ_CELLS=$gcells" 'PJ_HEADINGS=crew' "PJ_ARMS=base:--shape-latch=off s6:--shape-latch=off,$S6" PJ_JOBS=8 PJ_DIR=build/barss6-group TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/group-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/group-wrapper.log
rm -rf $out/group; cp -r build/light/build/barss6-group $out/group 2>/dev/null
echo "group done $(date)" >> $out/meta.txt
S6SP='--seat-bound=on --seat-order=on --seat-last=open'
for arm in base s6; do f="--shape-latch=off"; [ $arm = s6 ] && f="--shape-latch=off $S6SP"
  tools/remote.sh --light native-fresh native manoeuvre-wedge-trace WEDGE_AT=locks,terminus,sumps WEDGE_RANGE=12037-12042 WEDGE_JOBS=8 WEDGE_DIR=build/barss6-wedge-$arm "WEDGE_FLAGS=$f" TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/wedge-$arm.log 2>&1
  echo "WRAPPER_DONE $?" >> $out/wedge-$arm.log
  mkdir -p $out/wedge-$arm; cp build/light/build/barss6-wedge-$arm/*.log $out/wedge-$arm/ 2>/dev/null
  echo "wedge $arm done $(date)" >> $out/meta.txt
done
tools/remote.sh --light native-fresh native orders-probe 'ORDERS_PROBE_MAPS=locks crossing terminus' ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_ROUTES=click "ORDERS_PROBE_ARMS=base:--shape-latch=off s6:--shape-latch=off,$S6" "ORDERS_PROBE_SEEDS=$(seq 12025 12036 | tr '\n' ' ')" ORDERS_PROBE_JOBS=8 ORDERS_PROBE_DIR=build/barss6-orders TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/orders-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/orders-wrapper.log
rm -rf $out/orders; cp -r build/light/build/barss6-orders $out/orders 2>/dev/null
echo "orders done $(date)" >> $out/meta.txt
python3 tests/manoeuvre/s_judge.py $out/deciding --base=base --arm=s6 --cells > $out/judge-workload.txt 2>&1
python3 tests/manoeuvre/q3_judge.py $out/group --base=base --arm=s6 > $out/judge-group.txt 2>&1
grep -h '^ORDERS_PROBE_SQUAD ' $out/group/*.log | sed 's/^ORDERS_PROBE_SQUAD //' > $out/group-rows.jsonl
python3 tests/manoeuvre/follow_judge.py $out/wedge-base $out/wedge-s6 $out/group-rows.jsonl --on-arm=s6 > $out/judge-fights.txt 2>&1
cat $out/orders/logs/*.log | grep -h '^ORDERS_PROBE {' | sed 's/^ORDERS_PROBE //' > $out/orders-runs.jsonl
python3 tests/control/orders_judge.py g1v8 $out/orders/rows.jsonl base s6 $out/orders-runs.jsonl > $out/judge-g1v9.txt 2>&1
rm -rf build/light/build/barss6-*
echo "end $(date)" >> $out/meta.txt
