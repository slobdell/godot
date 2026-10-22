#!/usr/bin/env bash
# tools/scoreboard/run.sh COMMIT [HOST]: the round scoreboard's fixed workload (mk/scoreboard.mk) against COMMIT, on HOST
# (default builder2), raw logs into $SCORE_OUT/<short commit>/ (default build/scoreboard-raw/), then the row read by
# tools/scoreboard/score.py into references/scoreboard/rows/<short commit>.json. Round 35 extension X5 (a).
#
# COMMIT is checked out (detached) in a scratch worktree of its own, ../godot-native-score, never this one. THIS tree's
# workload and probes are laid over it, so every main runs the same thing:
#   mk/scoreboard.mk, tests/scoreboard/jam_census.gd (traffic's census, one read guarded), tests/orders_probe.gd, tests/control/orders_probe_*.json,
#   and tools/remote.sh with its helpers (the copy-back's manifest and verify).
# The probes only READ the game (Movement, Traffic, ElementSituation, RtsControls); a field an older main lacks reads
# as absent and the table prints n/a, never a guess. The overlay is recorded in the row (`overlay`), and the tree is
# restored to COMMIT afterwards. Long: run it under systemd-run.
# SCORE_VARS="SCORE_FIGHT_SEEDS=2601 ..." passes make variables (a smoke run: one of each); SCORE_ROWS puts the row
# elsewhere than references/scoreboard/rows (a smoke's row is not a main's).
# Round 36 (the noise column): a second seed block on one main is SCORE_VARS=SCORE_SEED_BASE=2700 SCORE_TAG=b2700
# SCORE_EXPECT="40 fights, 48 moves, 36 orders": the row is rows/<commit>-<tag>.json (named in noise.txt, not mains.txt).
set -uo pipefail
commit=${1:?usage: tools/scoreboard/run.sh COMMIT [HOST]}
host=${2:-slobdell@builder2}
# SCORE_JOBS: fights at once (mk/scoreboard.mk's default 10). builder2 (16 physical cores) takes 14, the orchestrator's
# 2026-10-21 machine note; a SCORE_JOBS= in SCORE_VARS still wins.
case "$host" in *builder2*) jobs=${SCORE_JOBS:-14} ;; *) jobs=${SCORE_JOBS:-} ;; esac
src=$(git rev-parse --show-toplevel)
short=$(git -C "$src" rev-parse --short=9 "$commit") || { echo "scoreboard: no such commit $commit" >&2; exit 2; }
wt=${SCORE_WORKTREE:-$(dirname "$src")/godot-native-score}
# Round 36: the raw logs live OUTSIDE build/. A check's copy-back (tools/remote.sh) rsyncs build/ with --delete, protecting
# only *.log, so a later check in the same tree deleted the raw screen.json and run.txt the moves and the verdict read.
out=${SCORE_OUT:-$(dirname "$src")/godot-native-score-raw}/$short${SCORE_TAG:+-$SCORE_TAG}
rows=${SCORE_ROWS:-$src/references/scoreboard/rows}
overlay=(mk/scoreboard.mk tests/scoreboard/jam_census.gd tests/orders_probe.gd tools/remote.sh tools/remote_guard.sh
	tools/slot.sh tools/quiet_window.sh tools/worktree.sh tools/copyback_verify.sh tools/copyback_prune.sh)
for f in "$src"/tests/control/orders_probe_*.json; do overlay+=("tests/control/$(basename "$f")"); done

if [ ! -e "$wt/.git" ]; then
	git -C "$src" worktree add --detach "$wt" "$short" >/dev/null || { echo "scoreboard: worktree add failed" >&2; exit 3; }
fi
# The scratch tree is this script's alone: anything tracked is reset to COMMIT, untracked files from a previous overlay
# removed (build/, the import cache and the native build are kept: they are the box's warm state, and local.mk's ports).
git -C "$wt" checkout -q --force --detach "$short" || exit 3
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg || exit 3
[ -e "$src/local.mk" ] && cp "$src/local.mk" "$wt/local.mk"
[ -e "$wt/.tools" ] || ln -s "$src/.tools" "$wt/.tools"
for f in "${overlay[@]}"; do mkdir -p "$(dirname "$wt/$f")"; cp "$src/$f" "$wt/$f"; done
overlay_from=$(git -C "$src" rev-parse --short=9 HEAD)

mkdir -p "$out"
echo ">> scoreboard: $short on $host, workload and probes from $overlay_from ($(date '+%F %T'))" | tee "$out/driver.txt"
# Round 36 (remote_builds.md, the Spot rule): builder2 idle-stops after 20 min and can be preempted mid-run. Each attempt
# starts from no local build/scoreboard (a dead copy-back must not leave an earlier main's files to score), a stopped box
# is started first, an exit 255 (the box gone) is tried again, and a row is written only on verdict.sh's ok.
expect=any; [ -z "${SCORE_VARS:-}" ] && expect="40 fights, 48 moves, 36 orders"
expect=${SCORE_EXPECT:-$expect}
name=$short${SCORE_TAG:+-$SCORE_TAG}
tries=${SCORE_TRIES:-3}
for try in $(seq 1 "$tries"); do
	case "$host" in *builder2*|*10.115.229.9)
		ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" true 2>/dev/null || make -C "$src" --no-print-directory gcp-start 2>&1 | tail -2 | tee -a "$out/driver.txt" ;;
	esac
	rm -rf "$wt/build/scoreboard"
	( cd "$wt" && TANK_SQUAD_COMMIT=$short REMOTE_HOST=$host bash tools/remote.sh native scoreboard-run ${jobs:+SCORE_JOBS=$jobs} ${SCORE_VARS:-} ) > "$out/remote.log" 2>&1
	status=$?
	grep -E "^>> (remote|scoreboard-run)|MISSING" "$out/remote.log" | tail -20 | tee -a "$out/driver.txt"
	rm -rf "$out/raw" && cp -r "$wt/build/scoreboard" "$out/raw" 2>/dev/null
	[ "$status" = 255 ] && [ "$try" -lt "$tries" ] && { echo ">> scoreboard: attempt $try of $tries ended 255 (the box gone?): again" | tee -a "$out/driver.txt"; continue; }
	break
done
git -C "$wt" checkout -q --force --detach "$short"   # the overlay undone
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg

bash "$src/tools/scoreboard/verdict.sh" "$out/remote.log" "$out/raw/run.txt" "$short" "$expect" | tee -a "$out/driver.txt"
[ "${PIPESTATUS[0]}" = 0 ] || { echo ">> scoreboard: NO ROW for $short (exit $status)" | tee -a "$out/driver.txt"; [ "$status" = 0 ] && exit 4; exit "$status"; }
host_name=${host#*@}
python3 -I "$src/tools/scoreboard/score.py" "$out/raw" --commit "$short" --machine "$host_name" --overlay "$overlay_from" \
	--remote-status "$status" > "$rows/$name.json.tmp" && mv "$rows/$name.json.tmp" "$rows/$name.json" \
	&& echo ">> scoreboard: row $rows/$name.json" | tee -a "$out/driver.txt"
exit "$status"
