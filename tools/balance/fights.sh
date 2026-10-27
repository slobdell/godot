#!/usr/bin/env bash
# B7 (round 42, balance): play a fight LIST on builder2 in one remote call (mk/balance.mk `balance-fights-run`), the way
# tools/scoreboard/guard.sh plays a guard series: the commit checked out in a scratch worktree, guard.sh's overlay, Spot
# preemption retried with GUARD_RESUME (fights already read are not replayed), the copy-back verified. Each fight's log lands in
# OUT/<short>-<folder>/none/<arena>-<seed>-green.log, the folder shape search.py reads (`mono` takes <..>mono-<faction>-<team>).
#   tools/balance/fights.sh COMMIT FIGHTS.txt OUT [HOST]     (FIGHTS: `<folder> <arena> <seed> <switches...>` a line)
# It waits before its call while BALANCE_PAUSE (default ~/balance-runs/PAUSE) exists, so builder2 can be handed over.
set -uo pipefail
commit=${1:?commit}; list=${2:?fight list}; out=${3:?out folder}; host=${4:-slobdell@builder2}
src=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
short=$(git -C "$src" rev-parse --short=9 "$commit") || { echo "fights: no such commit $commit" >&2; exit 2; }
wt=${GUARD_WORKTREE:-$(dirname "$src")/godot-balance-guard}
jobs=${GUARD_JOBS:-24}; seconds=${GUARD_SECONDS:-600}; tries=${GUARD_TRIES:-6}
pause=${BALANCE_PAUSE:-$HOME/balance-runs/PAUSE}
overlay=(mk/scoreboard.mk tests/ai_scenarios/guard_line.gd tests/ai_scenarios/guard_line.gd.uid tools/remote.sh
	tools/remote_guard.sh tools/slot.sh tools/quiet_window.sh tools/worktree.sh tools/copyback_verify.sh tools/copyback_prune.sh)
[ -s "$list" ] || { echo "fights: empty list $list" >&2; exit 2; }
total=$(grep -cv '^\s*\(#\|$\)' "$list")
mkdir -p "$out"
say() { echo "$*" | tee -a "$out/fights-$short.txt"; }
if [ -e "$pause" ]; then say "fights: paused while $pause exists ($(date '+%F %T'))"; while [ -e "$pause" ]; do sleep 30; done; say "fights: resumed"; fi
if [ ! -e "$wt/.git" ]; then git -C "$src" worktree add --detach "$wt" "$short" >/dev/null || exit 3; fi
git -C "$wt" checkout -q --force --detach "$short" || exit 3
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg || exit 3
git -C "$wt" grep -q '^balance-fights-run:' "$short" -- mk/balance.mk || { echo "fights: $short has no balance-fights-run target" >&2; exit 2; }
[ -e "$src/local.mk" ] && cp "$src/local.mk" "$wt/local.mk"
[ -e "$wt/.tools" ] || ln -s "$src/.tools" "$wt/.tools"
for f in "${overlay[@]}"; do [ -e "$src/$f" ] && { mkdir -p "$(dirname "$wt/$f")"; cp "$src/$f" "$wt/$f"; }; done
mkdir -p "$wt/fights" && cp "$list" "$wt/fights/fights.txt"
say ">> fights: $short on $host, $total fights from $list, J$jobs, ${seconds}s ($(date '+%F %T'))"
read_n=0
for try in $(seq 1 "$tries"); do
	case "$host" in *builder2*)
		ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" true 2>/dev/null \
			|| TANK_SQUAD_SLOT=1 make -C "$src" --no-print-directory gcp-start 2>&1 | tail -1 | tee -a "$out/fights-$short.txt" ;;
	esac
	rm -rf "$wt/build/guards"
	( cd "$wt" && TANK_SQUAD_COMMIT=$short REMOTE_HOST=$host bash tools/remote.sh native balance-fights-run \
		FIGHTS=fights/fights.txt GUARD_JOBS="$jobs" GUARD_SECONDS="$seconds" GUARD_RESUME=1 ) > "$out/remote-$short-$try.log" 2>&1
	status=$?
	exited=$(grep -E "^>> remote: make .*balance-fights-run.* exited " "$out/remote-$short-$try.log" | tail -1)
	if [ "$status" = 0 ] && [[ "$exited" == *"exited 0 (build/ copied back)"* ]] \
			&& grep -q '^>> remote: copy-back verified' "$out/remote-$short-$try.log"; then
		for d in "$wt"/build/guards/fights/*/; do
			folder=$(basename "$d"); mkdir -p "$out/$short-$folder/none"; cp "$d"*.log "$out/$short-$folder/none/" 2>/dev/null
		done
		cp "$wt/build/guards/run.txt" "$out/run-$short.txt" 2>/dev/null
		read_n=$(grep -v '^\s*\(#\|$\)' "$list" | while read -r folder arena seed _; do
			grep -qs '^GUARD_RESULT' "$out/$short-$folder/none/$arena-$seed-green.log" && echo; done | wc -l)
		say ">> fights: attempt $try read $read_n of $total"
		break
	fi
	say ">> fights: attempt $try LOST (exit $status: ${exited#>> remote: })"
	[ "$status" = 255 ] || [ -z "$exited" ] || break
done
git -C "$wt" checkout -q --force --detach "$short"
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg
say ">> fights: done $short: $read_n of $total read ($(date '+%F %T'))"
[ "$read_n" = "$total" ]
