#!/bin/bash
# Bar shortfwd (round 46, manoeuvre M5; filed before any number on 12121-12144). Frozen ../godot-manoeuvre-sf (wip/manoeuvre-shortfwd-bar
# cec4e499f), builder3: its full check first, then every leg on builder3 light only if the check reads exited 0.
export PATH=$HOME/projects/bin:$PATH
out=~/overnight-manoeuvre/r46/bars_sf; mkdir -p $out
cd /home/slobdell/projects/godot-manoeuvre-sf || exit 1
h=$(git rev-parse --short HEAD); echo "series start $h $(date) host ${REMOTE_HOST:-devia@builder3}" >> $out/meta.txt
grep -q '>> remote: make check exited 0' $out/check-$h.log || { echo "check not green: no series" >> $out/meta.txt; echo ENDMARK >> $out/meta.txt; exit 0; }
tools/remote.sh --light native-fresh native test FILTER=short_move SHORT_CORPUS=on SHORT_SEEDS=12121-12132 SHORT_POSES=0,2 > $out/deciding.log 2>&1
echo "deciding done $(date)" >> $out/meta.txt
tools/remote.sh --light native-fresh native test FILTER=short_move SHORT_CORPUS=on SHORT_SEEDS=12133-12144 SHORT_POSES=1,3,4,5,6 > $out/guard.log 2>&1
echo "guard done $(date)" >> $out/meta.txt
seeds="$(seq 12121 12144 | tr '\n' ' ')"
for arm in base sf; do f=""; [ $arm = sf ] && f="--traffic-on=shortfwd"
  tools/remote.sh --light native-fresh engage-authority-probe "AUTH_SEEDS=$seeds" AUTH_ARM=on "AUTH_PROBE_FLAGS=$f" AUTH_PROBE_TAG=$arm AUTH_JOBS=8 > $out/auth-$arm.log 2>&1
  rm -rf $out/auth-$arm; cp -r build/light/build/engage/authority/$arm $out/auth-$arm
done
echo "authority done $(date)" >> $out/meta.txt
tools/remote.sh --light native-fresh native orders-probe ORDERS_PROBE_DIR=build/sfprobe > $out/orders-sf.log 2>&1
cp build/light/build/sfprobe/rows.jsonl $out/orders-sf-rows.jsonl
cd /home/slobdell/projects/godot-manoeuvre && echo "base tree $(git rev-parse --short HEAD)" >> $out/meta.txt
tools/remote.sh --light native-fresh native orders-probe ORDERS_PROBE_DIR=build/sfprobe > $out/orders-base.log 2>&1
cp build/light/build/sfprobe/rows.jsonl $out/orders-base-rows.jsonl
echo "orders done $(date)" >> $out/meta.txt
cd /home/slobdell/projects/godot-manoeuvre-sf
python3 tests/engage/authority_table.py --pair $out/auth-base $out/auth-sf > $out/judge-authority.txt 2>&1
cmp -s $out/orders-sf-rows.jsonl $out/orders-base-rows.jsonl && echo "orders probe: byte-identical ($(wc -l < $out/orders-sf-rows.jsonl) rows)" > $out/judge-orders.txt || echo "orders probe: DIFFER" > $out/judge-orders.txt
echo "end $(date)" >> $out/meta.txt; echo ENDMARK >> $out/meta.txt
