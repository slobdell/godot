#!/usr/bin/env bash
# L2 twin re-proof on engage's frozen efe4d8ba9 + R46.11's acceptance (efe4d8ba9 + stream/native 882c62d7c).
cd /home/slobdell/projects/godot-native || exit 1
out=~/native-r46/l2-reproof
recs=("references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl 151" "references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl 107")
replays() {  # $1 = arm tag
	for rec in "${recs[@]}"; do
		set -- $1 $rec
		tag=$(basename $2 .jsonl)
		tools/remote.sh --light replay-match RECORDING=$2 REPLAY_SECONDS=$3 CREWS=all > $out/$1-$tag.log 2>&1
		cp build/light/build/replay-match/out/*.jsonl $out/$1-$tag.replay.jsonl 2>/dev/null
	done
}
git checkout -q efe4d8ba9 || exit 1
tools/remote.sh --light test 'FILTER=test_native_decide|fire_lanes_crowd|engage_lane_line' > $out/frozen-tests.log 2>&1
replays frozen
python3 - <<'PY'
p='game/ai/tank_brain.gd'
s=open(p).read()
old="	if NativeDecide.usable():\n		return NativeBridge.impl.decide(s, current)"
assert s.count(old) == 1
s=s.replace(old, "	if not (LANE_CLEAR and TankBrain.lane_case(s)) and NativeDecide.usable():\n		return NativeBridge.impl.decide(s, current)")
open(p,'w').write(s)
PY
replays guard
git checkout -q -- game/ai/tank_brain.gd
git checkout -q -B pair/native-r4611 efe4d8ba9 && git merge -q --no-edit 882c62d7c || exit 1
replays r4611
git checkout -q stream/native
echo PROOF_DONE >> $out/done
