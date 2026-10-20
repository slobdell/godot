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
set -uo pipefail
commit=${1:?usage: tools/scoreboard/run.sh COMMIT [HOST]}
host=${2:-slobdell@builder2}
src=$(git rev-parse --show-toplevel)
short=$(git -C "$src" rev-parse --short=9 "$commit") || { echo "scoreboard: no such commit $commit" >&2; exit 2; }
wt=${SCORE_WORKTREE:-$(dirname "$src")/godot-native-score}
out=${SCORE_OUT:-$src/build/scoreboard-raw}/$short
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
( cd "$wt" && TANK_SQUAD_COMMIT=$short REMOTE_HOST=$host bash tools/remote.sh native scoreboard-run ${SCORE_VARS:-} ) > "$out/remote.log" 2>&1
status=$?
grep -E "^>> (remote|scoreboard-run)|MISSING" "$out/remote.log" | tail -20 | tee -a "$out/driver.txt"
rm -rf "$out/raw" && cp -r "$wt/build/scoreboard" "$out/raw" 2>/dev/null
git -C "$wt" checkout -q --force --detach "$short"   # the overlay undone
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg

host_name=${host#*@}
python3 -I "$src/tools/scoreboard/score.py" "$out/raw" --commit "$short" --machine "$host_name" --overlay "$overlay_from" \
	--remote-status "$status" > "$rows/$short.json.tmp" && mv "$rows/$short.json.tmp" "$rows/$short.json" \
	&& echo ">> scoreboard: row $rows/$short.json" | tee -a "$out/driver.txt"
exit "$status"
