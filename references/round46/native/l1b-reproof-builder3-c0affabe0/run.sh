#!/usr/bin/env bash
# L2 twin re-proof on engage's Bar L1b freeze c0affabe0 (builder3 light): twins + lane tests, then his replays native v the GDScript route.
cd /home/slobdell/projects/godot-native || exit 1
out=~/native-r46/l1b-reproof
recs=("references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl 151" "references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl 107")
replays() {
	for rec in "${recs[@]}"; do
		set -- $1 $rec
		tag=$(basename $2 .jsonl)
		tools/remote.sh --light replay-match RECORDING=$2 REPLAY_SECONDS=$3 CREWS=all REPLAY_FLAGS=--lane-clear=on > $out/$1-$tag.log 2>&1
		cp build/light/build/replay-match/out/*.jsonl $out/$1-$tag.replay.jsonl 2>/dev/null
	done
}
git checkout -q c0affabe0 || exit 1
tools/remote.sh --light test 'FILTER=test_native_decide|test_native_drive|fire_lanes' > $out/frozen-tests.log 2>&1
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
git checkout -q stream/native
echo PROOF_DONE >> $out/done
