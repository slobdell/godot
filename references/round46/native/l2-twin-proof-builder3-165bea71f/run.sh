#!/usr/bin/env bash
# L2 twin proof: his recordings replayed on engage 9446e1903 (lane cases decided in GDScript) v pair/native-l2 (all native).
cd /home/slobdell/projects/godot-native || exit 1
out=~/native-r46/l2-proof
for arm in pair base; do
	if [ $arm = base ]; then git checkout -q 9446e1903 || exit 1; fi
	for rec in "references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl 151" "references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl 107"; do
		set -- $rec
		tag=$(basename $1 .jsonl)
		tools/remote.sh --light replay-match RECORDING=$1 REPLAY_SECONDS=$2 CREWS=all > $out/$arm-$tag.log 2>&1
		cp build/light/build/replay-match/out/*.jsonl $out/$arm-$tag.replay.jsonl 2>/dev/null
	done
	if [ $arm = base ]; then git checkout -q pair/native-l2; fi
done
echo PROOF_DONE >> $out/done
