#!/bin/bash
# Round 25 pace (the determinism hunt): his bridge drill (both sides) at start ticks 1..18, --fixed-fps 30
G=${GODOT:-.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64}
mkdir -p build/pace/sweep
for t in ${PACE_SWEEP_TICKS:-$(seq 1 18)}; do
  $G --headless --fixed-fps 30 --path . --script res://tests/run_tests.gd -- '--filter=test_tactics_bridge' --lab-start-tick=$t > build/pace/sweep/$t.log 2>&1
  for side in green rust; do
    m=$(grep -h "MEASURE bridge locks $side" build/pace/sweep/$t.log | python3 -c "import sys,json; l=sys.stdin.read(); d=json.loads(l.split(': ',1)[1]) if l else {}; print(d.get('deck_jam_s'), d.get('rim_crews'), d.get('crossed'), d.get('crossed_s'))")
    echo "tick $t $side: jam/rim_crews/crossed/crossed_s $m"
  done
  grep -hE "^  (PASS|FAIL)" build/pace/sweep/$t.log | sed "s/^/tick $t /"
done
