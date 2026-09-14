#!/usr/bin/env bash
# Run a command while holding one of N machine-wide "heavy run" slots.
#
# Several worktree agents share one machine (2026-09-14: 8 cores, 7.6 GB RAM; one Godot test run
# peaks at ~735 MB). Without a limit, five agents running `make check` at once run out of memory.
# The root Makefile routes every non-interactive goal through this script, so parallel agents
# queue instead of crashing each other. Use it directly for heavy commands run outside make:
#
#     tools/slot.sh python3 tools/match_series.py ...
#
# Knobs (environment): TANK_SQUAD_SLOTS (default 2), TANK_SQUAD_SLOT_TIMEOUT (seconds, default 5400).
# A command that exceeds the timeout is killed, so one hung run can't starve every agent overnight.
set -uo pipefail

if [ -n "${TANK_SQUAD_SLOT:-}" ]; then
	exec "$@"  # already inside a slot (nested make)
fi

slots=${TANK_SQUAD_SLOTS:-2}
limit=${TANK_SQUAD_SLOT_TIMEOUT:-5400}
dir=/tmp/tank_squad_slots
mkdir -p "$dir"
announced=0

while true; do
	for i in $(seq 1 "$slots"); do
		exec {fd}>"$dir/slot$i.lock"
		if flock -n "$fd"; then
			echo "$(date +%H:%M:%S) $(basename "$PWD"): $*" > "$dir/slot$i.owner"
			[ "$announced" -eq 1 ] && echo ">> got heavy-run slot $i" >&2
			export TANK_SQUAD_SLOT=$i
			# The child must not inherit the lock fd: a stray background server would otherwise
			# hold the slot forever.
			timeout --kill-after=30 "$limit" "$@" {fd}>&-
			status=$?
			[ "$status" -eq 124 ] && echo ">> slot.sh: killed after ${limit}s: $*" >&2
			rm -f "$dir/slot$i.owner"
			exit "$status"
		fi
		exec {fd}>&-
	done
	if [ "$announced" -eq 0 ]; then
		echo ">> waiting for a heavy-run slot ($slots in use by other worktrees):" >&2
		cat "$dir"/slot*.owner 2>/dev/null | sed 's/^/     /' >&2
		announced=1
	fi
	sleep 5
done
