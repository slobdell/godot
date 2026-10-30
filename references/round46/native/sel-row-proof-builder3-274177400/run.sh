#!/usr/bin/env bash
# R46.6 proof: his two recordings replayed with the sel row (arm) and without (base = a734c2296's recorder), all crews, full length.
cd /home/slobdell/projects/godot-native || exit 1
out=~/native-r46/sel-proof
for arm in arm base; do
	if [ $arm = base ]; then git show a734c2296:game/match/match_recorder.gd > game/match/match_recorder.gd; fi
	for rec in "references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl 151" "references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl 107"; do
		set -- $rec
		tag=$(basename $1 .jsonl)
		tools/remote.sh --light replay-match RECORDING=$1 REPLAY_SECONDS=$2 CREWS=all > $out/$arm-$tag.log 2>&1
		cp build/light/build/replay-match/out/*.jsonl $out/$arm-$tag.replay.jsonl 2>/dev/null
	done
	if [ $arm = base ]; then git checkout -- game/match/match_recorder.gd; fi
done
echo PROOF_DONE >> $out/done
