#!/usr/bin/env bash
# tools/scoreboard/guard.sh COMMIT [HOST]: the guard lines (CP37.1) of COMMIT in ONE rolling remote call, resumable per fight.
#
# builder2 is a Spot box, and on 2026-10-21 it was preempted every ~2 minutes for a while, so one long run would never finish.
# Each seed is GUARD_KINDS x the five arenas x both sides (20 fights); one remote call runs them all (GUARD_CHUNK, below). It runs in a scratch worktree of its own
# (../godot-native-guard, COMMIT checked out detached, THIS tree's probe and make target laid over it, as run.sh does), so this
# stream's own checks never collide with it. A chunk counts only on the wrapper's `exited 0 (build/ copied back)` and a
# verified copy-back; its logs then go to $GUARD_OUT/<short commit>/<kind>/ (outside build/: a check's copy-back deletes
# build/'s non-.log files). A chunk whose logs are all there with a GUARD_RESULT is skipped, so re-running the script resumes.
# An exit 255 (the box gone) starts builder2 again and retries, GUARD_TRIES times a chunk. Every attempt is a line in
# driver.txt; `lost` there counts the attempts preemption cost. Long: run it under systemd-run (or setsid nohup).
#   GUARD_SEEDS="2601 ... 2608 2701 ... 2708" (default the two blocks), GUARD_KINDS="blob turtle", GUARD_JOBS=20 (fights at
#   once; 20 already keeps builder2's 16 cores busy, the base read ran 20 fights a chunk),
#   GUARD_ARGS="--cover-on=hulldown" GUARD_TAG=hulldown (an arm: its switches, its own folder; pair it with guard.py --pair).
#   GUARD_OVERRIDES=path/to/candidate.json (round 40, N3: balance's search): the file is laid into the scratch tree as
#   overrides/<sha12>.json and every fight gets --unit-overrides=res://overrides/<sha12>.json (Army.ensure_overrides; COMMIT
#   must carry it); the folder is <commit>-ov-<sha12> unless GUARD_TAG names it. GUARD_RESULT's overrides_sha says which file.
set -uo pipefail
export PATH=$HOME/projects/bin:$PATH  # gcloud, for gcp-start (remote_builds.md: a systemd-run unit lacks it)
commit=${1:?usage: tools/scoreboard/guard.sh COMMIT [HOST]}
host=${2:-slobdell@builder2}
src=$(git rev-parse --show-toplevel)
short=$(git -C "$src" rev-parse --short=9 "$commit") || { echo "guard: no such commit $commit" >&2; exit 2; }
wt=${GUARD_WORKTREE:-$(dirname "$src")/godot-native-guard}
# GUARD_ARGS (an arm's switches, e.g. --cover-on=hulldown) go to every fight; GUARD_TAG names the arm's folder (<commit>-<tag>).
args=${GUARD_ARGS:-}
overrides=${GUARD_OVERRIDES:-}
ov_sha=""
if [ -n "$overrides" ]; then
	[ -f "$overrides" ] || { echo "guard: no overrides file $overrides" >&2; exit 2; }
	python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d, dict)' "$overrides" 2>/dev/null \
		|| { echo "guard: $overrides is not a JSON object" >&2; exit 2; }
	ov_sha=$(sha256sum "$overrides" | cut -c1-12)
	args="$args --unit-overrides=res://overrides/$ov_sha.json"
	GUARD_TAG=${GUARD_TAG:-ov-$ov_sha}
fi
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
if [ -n "$ov_sha" ]; then
	grep -q 'func ensure_overrides' "$wt/game/units/army.gd" \
		|| { echo "guard: $short has no --unit-overrides (Army.ensure_overrides, round 40 N3): run a commit that carries it" >&2; exit 2; }
	mkdir -p "$wt/overrides" && cp "$overrides" "$wt/overrides/$ov_sha.json"
fi
overlay_from=$(git -C "$src" rev-parse --short=9 HEAD)
mkdir -p "$out"
say() { echo "$*" | tee -a "$out/driver.txt"; }
say ">> guard: $short on $host, probe from $overlay_from, kinds '$kinds', args '$args'${ov_sha:+, overrides $overrides}, seeds $(echo $seeds | wc -w) ($(date '+%F %T'))"

complete() {  # complete SEED: every log of the chunk is in $out with its GUARD_RESULT
	local seed=$1 kind arena side
	for kind in $kinds; do for arena in $arenas; do for side in green rust; do
		grep -q '^GUARD_RESULT' "$out/$kind/$arena-$seed-$side.log" 2>/dev/null || return 1
	done; done; done
}

lost=0
todo=()
for seed in $seeds; do
	if complete "$seed"; then say ">> guard: seed $seed already read"; else todo+=("$seed"); fi
done
# Round 38 (N4, the rolling queue): every seed still needed goes in ONE call (GUARD_CHUNK=0, the default), so the remote
# xargs keeps GUARD_JOBS fights running across seeds and the box idles once, at the very end. Each call passes GUARD_RESUME=1:
# the remote folder's build/guards/ (kept between calls, stamped with commit, kinds, args, seconds) skips every fight that
# already printed its GUARD_RESULT, so a call cut by a preemption (255) is retried for the fights it had not finished. The
# copy-back still counts seed by seed, and a re-run of this script skips seeds already read here. GUARD_CHUNK=N: N seeds a
# call (round 37's 1 or 2).
chunk=${GUARD_CHUNK:-0}
[ "$chunk" -gt 0 ] 2>/dev/null || chunk=${#todo[@]}
[ "$chunk" -gt 0 ] || chunk=1
for ((i = 0; i < ${#todo[@]}; i += chunk)); do
	group=("${todo[@]:i:chunk}")
	tag=${group[0]}; [ ${#group[@]} -gt 1 ] && tag=$tag-${group[-1]}  # first-last (a whole run would be a long name)
	done_ok=""
	for try in $(seq 1 "$tries"); do
		case "$host" in *builder2*)
			ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" true 2>/dev/null \
				|| TANK_SQUAD_SLOT=1 make -C "$src" --no-print-directory gcp-start 2>&1 | tail -1 | tee -a "$out/driver.txt" ;;
		esac
		rm -rf "$wt/build/guards"
		( cd "$wt" && TANK_SQUAD_COMMIT=$short REMOTE_HOST=$host bash tools/remote.sh native guard-run \
			GUARD_KINDS="$kinds" GUARD_AT="$arenas" GUARD_SEEDS="${group[*]}" GUARD_JOBS="$jobs" GUARD_ARGS="$args" GUARD_RESUME=1 ) > "$out/remote-$tag.log" 2>&1
		status=$?
		exited=$(grep -E '^>> remote: make .*guard-run.* exited ' "$out/remote-$tag.log" | tail -1)
		load=$(grep -E '^>> guard-run on ' "$wt/build/guards/run.txt" 2>/dev/null | head -1 | sed 's/.*| load /load /')
		if [ "$status" = 0 ] && [[ "$exited" == *"exited 0 (build/ copied back)"* ]] \
				&& grep -q '^>> remote: copy-back verified' "$out/remote-$tag.log"; then
			cp "$wt/build/guards/run.txt" "$out/run-$tag.txt" 2>/dev/null
			done_ok=1
			for seed in "${group[@]}"; do
				for kind in $kinds; do mkdir -p "$out/$kind"; cp "$wt"/build/guards/"$kind"/*-"$seed"-*.log "$out/$kind/" 2>/dev/null; done
				if complete "$seed"; then
					say ">> guard: seed $seed read (call $tag, attempt $try, $load)"
				else
					say ">> guard: seed $seed exited 0 but some fight printed no GUARD_RESULT: $(grep -c MISSING "$out/remote-$tag.log") missing in the call"
					done_ok=partial
				fi
			done
			break
		fi
		lost=$((lost + 1))
		say ">> guard: seeds $tag attempt $try LOST (exit $status: ${exited#>> remote: })"
		[ "$status" = 255 ] || [ -z "$exited" ] || break
	done
	[ -n "$done_ok" ] || say ">> guard: seeds $tag NOT READ after $tries attempts"
done
git -C "$wt" checkout -q --force --detach "$short"
git -C "$wt" clean -fdq -e build/ -e .godot/ -e .tools/ -e native/bin/ -e native/build/ -e local.mk -e override.cfg
read_n=0; for seed in $seeds; do complete "$seed" && read_n=$((read_n + 1)); done
say ">> guard: done $short: $read_n of $(echo $seeds | wc -w) seeds read, $lost attempts lost ($(date '+%F %T'))"
[ "$read_n" = "$(echo $seeds | wc -w)" ]
