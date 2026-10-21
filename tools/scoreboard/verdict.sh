#!/usr/bin/env bash
# Round 36 (remote_builds.md, the Spot rule): does a scoreboard run count? tools/scoreboard/run.sh writes a row only on
# exit 0 here. builder2 is a Spot box: a preemption ends the wrapper with 255 and a "copied back: FAILED", and the local
# build/scoreboard then still holds an EARLIER run (2026-10-20: e45bb6632's row was scored from 1c82d6d1e's files).
#
#     tools/scoreboard/verdict.sh REMOTE_LOG RUN_TXT COMMIT [EXPECT]
#
# Counts only when ALL hold: the wrapper's own `>> remote: make ... scoreboard-run exited 0 (build/ copied back)` line;
# the copy-back verified; RUN_TXT (the copied-back build/scoreboard/run.txt) opens with this COMMIT and closes with its
# `scoreboard-run done:` line; and that line's counts are EXPECT ("40 fights, 48 moves, 36 orders", the fixed workload),
# or, with EXPECT "any" (a smoke's SCORE_VARS), every part non-zero. Prints "scoreboard verdict: ok" or the reason.
set -uo pipefail
log=${1:?usage: verdict.sh REMOTE_LOG RUN_TXT COMMIT [EXPECT]}
run=${2:?usage: verdict.sh REMOTE_LOG RUN_TXT COMMIT [EXPECT]}
commit=${3:?usage: verdict.sh REMOTE_LOG RUN_TXT COMMIT [EXPECT]}
expect=${4:-40 fights, 48 moves, 36 orders}

no() { echo "scoreboard verdict: NOT COUNTED: $*"; exit 1; }

[ -s "$log" ] || no "no wrapper log ($log)"
# The make variables a second seed block passes sit between the target and "exited" (2026-10-20: SCORE_SEED_BASE=2700).
exited=$(grep -E '^>> remote: make .*scoreboard-run( [^ ]+)* exited ' "$log" | tail -1)
[ -n "$exited" ] || no "the wrapper never printed its exited line (killed or preempted)"
case "$exited" in
	*"exited 0 (build/ copied back)"*) ;;
	*) no "the wrapper says: ${exited#>> remote: }" ;;
esac
grep -q '^>> remote: copy-back verified' "$log" || no "the copy-back was not verified"
grep -q 'NOT RUN' "$log" && no "a target was NOT RUN"
[ -s "$run" ] || no "no run.txt copied back ($run)"
head -1 "$run" | grep -q "| commit $commit |" || no "run.txt is another commit's: $(head -1 "$run")"
done_line=$(grep -E '^>> scoreboard-run done: ' "$run" | tail -1)
[ -n "$done_line" ] || no "run.txt has no done line (the run stopped part way)"
counts=${done_line#>> scoreboard-run done: }
counts=${counts% runs}
if [ "$expect" = any ]; then
	echo "$counts" | grep -qE '^[1-9][0-9]* fights, [1-9][0-9]* moves, [1-9][0-9]* orders$' || no "a part ran nothing: $counts"
else
	[ "$counts" = "$expect" ] || no "ran $counts, the workload is $expect"
fi
echo "scoreboard verdict: ok ($counts)"
