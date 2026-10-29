#!/usr/bin/env bash
# Round 45 (native N1): a Godot import that stops making progress is killed and retried once, never left to a slot timeout.
#
#     tools/import_watchdog.sh [--then <command> ...]   # watched import in $PWD, then exec the command (its status is ours)
#
# Why: Bar B1 lost 4 h on 2026-10-28 when builder2's fresh godot-manoeuvre-b1-light hung on its FIRST import. Godot printed
# `[   0% ] reimport | Oswald-Latin.ttf` once a second from 18:21 to 22:23 (14,369 identical lines) until slot.sh's 14400 s
# limit killed it, and nothing said so until then. A hang still prints, so "no output" is not the signal: NO CHANGE in the
# last progress line is.
#
# The limit, IMPORT_WATCH_STALL (default 600 s): in 20 builder logs from rounds 40-44 (~/overnight-manoeuvre) no import step's
# progress line repeated more than 6 times (~6 s; `uniq -c` on the reimport lines), while the hang repeated for 4 h. 600 s is
# ~100x the longest honest step, and the worst a double hang can cost is two of them (20 min) instead of the slot's 4 h.
#
# On a stall: kill the import, clear this folder's .godot/ import cache, import once more. A second stall ends the run with
# `>> remote: import hung on <file>` and exit 75 (EX_TEMPFAIL), before the command runs. An import that EXITS (any status)
# is not ours to judge: the command runs and make's own `import` reports it as it always has.
#
# Called by tools/slot.sh inside the slot it grants, when TANK_SQUAD_IMPORT_WATCH is set (tools/remote.sh sets it on both
# builders), so the watched import queues nowhere extra; make's own `import` after it finds a warm cache (seconds).
# Knobs: IMPORT_WATCH_STALL, IMPORT_WATCH_POLL (default 5 s), IMPORT_WATCH_CMD (a stand-in for the import: the known-answer
# tests' fake hang), IMPORT_WATCH_LOG (default build/import-watch.log). Known-answer tests: tools/test_import_watchdog.sh.
set -uo pipefail

then_cmd=()
if [ "${1:-}" = --then ]; then shift; then_cmd=("$@"); fi
unset TANK_SQUAD_IMPORT_WATCH   # one watched import per run: nothing below this run starts another

stall=${IMPORT_WATCH_STALL:-600}
poll=${IMPORT_WATCH_POLL:-5}
log=${IMPORT_WATCH_LOG:-build/import-watch.log}

run_then() {
	[ ${#then_cmd[@]} -gt 0 ] || exit "${1:-0}"
	exec "${then_cmd[@]}"
}

if [ -n "${IMPORT_WATCH_CMD:-}" ]; then
	import_cmd=(bash -c "$IMPORT_WATCH_CMD")
else
	godot=$(ls .tools/godot-*/Godot_v*_linux.x86_64 2>/dev/null | head -1)
	# No toolchain yet (a first run bootstraps inside make): nothing to watch, make imports as before.
	[ -n "$godot" ] && [ -x "$godot" ] && [ -f project.godot ] || run_then 0
	import_cmd=("$godot" --headless --path . --import)
fi

mkdir -p "$(dirname "$log")" build && touch build/.gdignore   # as mk/core.mk's import: build/ is never a resource
child=""
stop_child() {
	[ -n "$child" ] || return 0
	kill -TERM "$child" 2>/dev/null
	local i=0
	while kill -0 "$child" 2>/dev/null && [ "$i" -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
	kill -KILL "$child" 2>/dev/null
	wait "$child" 2>/dev/null
	child=""
}
trap 'stop_child; exit 130' INT
trap 'stop_child; exit 143' TERM

# The last progress line Godot printed ("[ 45% ] reimport | foo.png", "[ DONE ] ..."), colours stripped; the byte count when
# there is none yet, so a silent start that never prints also counts as no progress.
progress_key() {
	local line
	line=$(tail -c 4096 "$log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -aE '^\[ *([0-9]+% |DONE )\]' | tail -1)
	if [ -n "$line" ]; then printf '%s\n' "$line"; else printf 'bytes %s\n' "$(stat -c %s "$log" 2>/dev/null || echo 0)"; fi
}

# 0 = the import exited (its status in $import_status), 1 = it stalled (the last progress line in $stalled_on).
attempt() {
	: > "$log"
	"${import_cmd[@]}" >> "$log" 2>&1 &
	child=$!
	local key last now changed
	last=$(progress_key); changed=$(date +%s)
	while kill -0 "$child" 2>/dev/null; do
		sleep "$poll"
		key=$(progress_key); now=$(date +%s)
		if [ "$key" != "$last" ]; then last=$key; changed=$now; fi
		if [ $((now - changed)) -ge "$stall" ]; then
			stalled_on=$last
			stop_child
			return 1
		fi
	done
	wait "$child"; import_status=$?
	child=""
	return 0
}

file_of() {   # "[   0% ] reimport | Oswald-Latin.ttf" -> Oswald-Latin.ttf
	case "$1" in
		"bytes "*) echo "(no progress line: silent from the start)" ;;
		*"| "*) echo "${1##*| }" ;;
		*) echo "$1" ;;
	esac
}

started=$(date +%s)
if attempt; then
	echo ">> import-watch: import exited $import_status in $(( $(date +%s) - started )) s ($log)" >&2
	run_then 0
fi
first=$(file_of "$stalled_on")
echo ">> import-watch: no progress for ${stall}s on '$first' ($stalled_on): killed; clearing .godot/ and importing once more" >&2
cp "$log" "$log.hung1" 2>/dev/null
rm -rf .godot
started=$(date +%s)
if attempt; then
	echo ">> import-watch: the retry worked: import exited $import_status in $(( $(date +%s) - started )) s (first attempt hung on $first; $log.hung1)" >&2
	run_then 0
fi
cp "$log" "$log.hung2" 2>/dev/null
echo ">> remote: import hung on $(file_of "$stalled_on") (no progress for ${stall}s, twice; .godot/ cleared between; first hang on $first; $log.hung1, $log.hung2)" >&2
exit 75
