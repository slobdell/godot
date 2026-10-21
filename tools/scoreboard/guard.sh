#!/usr/bin/env bash
# tools/scoreboard/guard.sh COMMIT [HOST]: the guard lines (CP37.1) of COMMIT, one SEED a remote call, resumable.
#
# builder2 is a Spot box, and on 2026-10-21 it was preempted every ~2 minutes for a while, so one long run would never finish.
# Each chunk is one seed: GUARD_KINDS x the five arenas x both sides (20 fights). It runs in a scratch worktree of its own
# (../godot-native-guard, COMMIT checked out detached, THIS tree's probe and make target laid over it, as run.sh does), so this
# stream's own checks never collide with it. A chunk counts only on the wrapper's `exited 0 (build/ copied back)` and a
# verified copy-back; its logs then go to $GUARD_OUT/<short commit>/<kind>/ (outside build/: a check's copy-back deletes
# build/'s non-.log files). A chunk whose logs are all there with a GUARD_RESULT is skipped, so re-running the script resumes.
# An exit 255 (the box gone) starts builder2 again and retries, GUARD_TRIES times a chunk. Every attempt is a line in
# driver.txt; `lost` there counts the attempts preemption cost. Long: run it under systemd-run (or setsid nohup).
#   GUARD_SEEDS="2601 ... 2608 2701 ... 2708" (default the two blocks), GUARD_KINDS="blob turtle", GUARD_JOBS=20,
#   GUARD_ARGS="--cover-on=hulldown" GUARD_TAG=hulldown (an arm: its switches, its own folder; pair it with guard.py --pair).
set -uo pipefail
export PATH=$HOME/projects/bin:$PATH  # gcloud, for gcp-start (remote_builds.md: a systemd-run unit lacks it)
commit=${1:?usage: tools/scoreboard/guard.sh COMMIT [HOST]}
host=${2:-slobdell@builder2}
src=$(git rev-parse --show-toplevel)
short=$(git -C "$src" rev-parse --short=9 "$commit") || { echo "guard: no such commit $commit" >&2; exit 2; }
wt=${GUARD_WORKTREE:-$(dirname "$src")/godot-native-guard}
# GUARD_ARGS (an arm's switches, e.g. --cover-on=hulldown) go to every fight; GUARD_TAG names the arm's folder (<commit>-<tag>).
args=${GUARD_ARGS:-}
out=${GUARD_OUT:-$(dirname "$src")/godot-native-guard-raw}/$short${GUARD_TAG:+-$GUARD_TAG}
seeds=${GUARD_SEEDS:-$(seq 2601 2608; seq 2701 2708)}
kinds=${GUARD_KINDS:-blob turtle}
arenas=${GUARD_AT:-terminus locks sumps gorge parade}
jobs=${GUARD_JOBS:-20}
tries=${GUARD_TRIES:-6}
overlay=(mk/scoreboard.mk tests/ai_scenarios/guard_line.gd tests/ai_scenarios/guard_line.gd.uid tools/remote.sh
	tools/remote_guard.sh tools/slot.sh tools/quiet_window.sh tools/worktree.sh tools/copyback_verify.sh tools/copyback_prune.sh)

if [ ! -e "$wt/.git" ]; then
	git -C "$src" worktree add --detach "$wt" "$short" >/dev/null || { echo "guard: worktree add failed" >&2; exit 3; }
fi
git -C "$wt" checkout -q --force --detach "$short" || exit 3
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg || exit 3
[ -e "$src/local.mk" ] && cp "$src/local.mk" "$wt/local.mk"
[ -e "$wt/.tools" ] || ln -s "$src/.tools" "$wt/.tools"
for f in "${overlay[@]}"; do [ -e "$src/$f" ] && { mkdir -p "$(dirname "$wt/$f")"; cp "$src/$f" "$wt/$f"; }; done
overlay_from=$(git -C "$src" rev-parse --short=9 HEAD)
mkdir -p "$out"
say() { echo "$*" | tee -a "$out/driver.txt"; }
say ">> guard: $short on $host, probe from $overlay_from, kinds '$kinds', args '$args', seeds $(echo $seeds | wc -w) ($(date '+%F %T'))"

complete() {  # complete SEED: every log of the chunk is in $out with its GUARD_RESULT
	local seed=$1 kind arena side
	for kind in $kinds; do for arena in $arenas; do for side in green rust; do
		grep -q '^GUARD_RESULT' "$out/$kind/$arena-$seed-$side.log" 2>/dev/null || return 1
	done; done; done
}

lost=0
for seed in $seeds; do
	if complete "$seed"; then say ">> guard: seed $seed already read"; continue; fi
	done_ok=""
	for try in $(seq 1 "$tries"); do
		case "$host" in *builder2*)
			ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" true 2>/dev/null \
				|| TANK_SQUAD_SLOT=1 make -C "$src" --no-print-directory gcp-start 2>&1 | tail -1 | tee -a "$out/driver.txt" ;;
		esac
		rm -rf "$wt/build/guards"
		( cd "$wt" && TANK_SQUAD_COMMIT=$short REMOTE_HOST=$host bash tools/remote.sh native guard-run \
			GUARD_KINDS="$kinds" GUARD_AT="$arenas" GUARD_SEEDS="$seed" GUARD_JOBS="$jobs" GUARD_ARGS="$args" ) > "$out/remote-$seed.log" 2>&1
		status=$?
		exited=$(grep -E '^>> remote: make .*guard-run.* exited ' "$out/remote-$seed.log" | tail -1)
		load=$(grep -E '^>> guard-run on ' "$wt/build/guards/run.txt" 2>/dev/null | head -1 | sed 's/.*| load /load /')
		if [ "$status" = 0 ] && [[ "$exited" == *"exited 0 (build/ copied back)"* ]] \
				&& grep -q '^>> remote: copy-back verified' "$out/remote-$seed.log"; then
			for kind in $kinds; do mkdir -p "$out/$kind"; cp "$wt"/build/guards/"$kind"/*-"$seed"-*.log "$out/$kind/" 2>/dev/null; done
			cp "$wt/build/guards/run.txt" "$out/run-$seed.txt" 2>/dev/null
			if complete "$seed"; then
				say ">> guard: seed $seed read (attempt $try, $load)"; done_ok=1; break
			fi
			say ">> guard: seed $seed exited 0 but some fight printed no GUARD_RESULT: $(grep -c MISSING "$out/remote-$seed.log") missing"
			done_ok=partial; break
		fi
		lost=$((lost + 1))
		say ">> guard: seed $seed attempt $try LOST (exit $status: ${exited#>> remote: })"
		[ "$status" = 255 ] || [ -z "$exited" ] || break
	done
	[ -n "$done_ok" ] || say ">> guard: seed $seed NOT READ after $tries attempts"
done
git -C "$wt" checkout -q --force --detach "$short"
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg
read_n=0; for seed in $seeds; do complete "$seed" && read_n=$((read_n + 1)); done
say ">> guard: done $short: $read_n of $(echo $seeds | wc -w) seeds read, $lost attempts lost ($(date '+%F %T'))"
[ "$read_n" = "$(echo $seeds | wc -w)" ]
