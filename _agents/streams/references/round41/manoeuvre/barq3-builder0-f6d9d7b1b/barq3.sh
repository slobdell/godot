#!/bin/bash
# Bar Q3 series (filed in _agents/streams/manoeuvre.md Status; R41.3 + R41.6). HASH = the bar's frozen tree (set below at launch).
# 1. gate: make remote T=check on HASH (heavy lane) -- run separately first; this script assumes it is green.
# 2. bridge, deciding: bridge-pooled on seeds 9025-9036 x ticks {1,8,15} x both sides, OFF / ON, main tree and the overrides tree.
# 3. group order, guards: orders' O1 probe cells crossing/locks/sumps/terminus x 9037-9048 crew, OFF / ON, both GDScript drive.
# 4. fights, guards: manoeuvre-wedge-trace locks,terminus,sumps x 9037-9042, OFF / ON, both GDScript drive.
export PATH=$HOME/projects/bin:$PATH
out=~/overnight-manoeuvre/r41/barq3; mkdir -p $out
cd /home/slobdell/projects/godot-manoeuvre
echo "bar hash $(git rev-parse --short HEAD) start $(date) builder0" > $out/meta.txt
SEEDS="9025 9026 9027 9028 9029 9030 9031 9032 9033 9034 9035 9036"
(
  cd /home/slobdell/projects/godot-manoeuvre-bt
  echo "overrides tree $(git rev-parse --short HEAD)" >> $out/meta.txt
  for arm in off on; do f=""; [ $arm = on ] && f="--traffic-on=wait"
    tools/remote.sh --light native bridge-pooled "BRIDGE_POOLED_SEEDS=$SEEDS" "BRIDGE_FLAGS=$f --brains-off=native_drive" TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/bridge-arm-$arm.log 2>&1
    echo "WRAPPER_DONE $?" >> $out/bridge-arm-$arm.log
    cp build/light/build/bridge-series.jsonl $out/bridge-arm-$arm.jsonl 2>/dev/null
    echo "bridge arm $arm done $(date)" >> $out/meta.txt
  done
) &
for arm in off on; do f=""; [ $arm = on ] && f="--traffic-on=wait"
  tools/remote.sh --light native bridge-pooled "BRIDGE_POOLED_SEEDS=$SEEDS" "BRIDGE_FLAGS=$f --brains-off=native_drive" TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/bridge-main-$arm.log 2>&1
  echo "WRAPPER_DONE $?" >> $out/bridge-main-$arm.log
  cp build/light/build/bridge-series.jsonl $out/bridge-main-$arm.jsonl 2>/dev/null
  echo "bridge main $arm done $(date)" >> $out/meta.txt
done
cells=""; for m in crossing locks sumps terminus; do for s in 9037 9038 9039 9040 9041 9042 9043 9044 9045 9046 9047 9048; do cells="$cells $m:click:$s"; done; done
tools/remote.sh --light native manoeuvre-probe-jam "PJ_CELLS=$cells" 'PJ_HEADINGS=crew' 'PJ_ARMS=main:--brains-off=native_drive wait:--traffic-on=wait,--brains-off=native_drive' PJ_JOBS=4 PJ_DIR=build/barq3-group TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/group-wrapper.log 2>&1
echo "WRAPPER_DONE $?" >> $out/group-wrapper.log
rm -rf $out/group; cp -r build/light/build/barq3-group $out/group 2>/dev/null
echo "group done $(date)" >> $out/meta.txt
for arm in off on; do f="--brains-off=native_drive"; [ $arm = on ] && f="--traffic-on=wait --brains-off=native_drive"
  tools/remote.sh --light native manoeuvre-wedge-trace WEDGE_AT=locks,terminus,sumps WEDGE_RANGE=9037-9042 WEDGE_JOBS=4 WEDGE_DIR=build/barq3-wedge-$arm "WEDGE_FLAGS=$f" TANK_SQUAD_SLOT_TIMEOUT=14400 > $out/wedge-$arm.log 2>&1
  echo "WRAPPER_DONE $?" >> $out/wedge-$arm.log
  mkdir -p $out/wedge-$arm; cp build/light/build/barq3-wedge-$arm/*.log $out/wedge-$arm/ 2>/dev/null
  echo "wedge $arm done $(date)" >> $out/meta.txt
done
wait
python3 tests/manoeuvre/bridge_lab_table.py main-off=$out/bridge-main-off.jsonl main-on=$out/bridge-main-on.jsonl --pair=main-off,main-on > $out/judge-bridge-main.txt 2>&1
python3 tests/manoeuvre/bridge_lab_table.py arm-off=$out/bridge-arm-off.jsonl arm-on=$out/bridge-arm-on.jsonl --pair=arm-off,arm-on > $out/judge-bridge-overrides.txt 2>&1
python3 tests/manoeuvre/q3_judge.py $out/group > $out/judge-group.txt 2>&1
python3 tests/manoeuvre/probe_jam_table.py $out/group --top=8 > $out/group-table.txt 2>&1
grep -h '^ORDERS_PROBE_SQUAD ' $out/group/*.log | sed 's/^ORDERS_PROBE_SQUAD //' > $out/group-rows.jsonl
python3 tests/manoeuvre/follow_judge.py $out/wedge-off $out/wedge-on $out/group-rows.jsonl --on-arm=wait > $out/judge-fights.txt 2>&1
echo "end $(date)" >> $out/meta.txt
