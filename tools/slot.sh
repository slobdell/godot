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
#
# The queue is FIFO, and it says so out loud (both added 2026-09-18, found by combat: a pilot run
# sat 41 minutes without ever starting while builder0's load average was 1.35).
#
#   * Before this, every waiter woke each 5 s and RACED for whichever lock happened to be free.
#     No ticket, no ageing: a job queuing for 41 minutes had exactly the same chance as one that
#     arrived 5 seconds ago, so with four or more waiters a run could lose indefinitely. That is
#     starvation, not contention, and it got worse the more streams were live -- precisely when
#     fairness matters most. Each waiter now takes a ticket on arrival and only attempts the locks
#     when it holds the OLDEST live one.
#   * And the "waiting" banner printed ONCE, then went silent forever, so a starved job and a
#     running job looked identical in the log -- which is how an hour went into misdiagnosing this
#     as "builder0 is slow". A wait with no heartbeat is indistinguishable from a hang, so the wait
#     now reports itself every minute with its age, its queue position and who holds the slots.
#
# Stale tickets are pruned by checking the owning pid, because a waiter killed between taking a
# ticket and getting a slot must never block the queue: a deadlock here stops every agent at once.
set -uo pipefail

if [ -n "${TANK_SQUAD_SLOT:-}" ]; then
	exec "$@"  # already inside a slot (nested make)
fi

slots=${TANK_SQUAD_SLOTS:-2}
limit=${TANK_SQUAD_SLOT_TIMEOUT:-5400}
dir=${TANK_SQUAD_SLOT_DIR:-/tmp/tank_squad_slots}   # overridable so the queue can be tested in isolation
mkdir -p "$dir"

# Ticket name sorts by arrival: a fixed-width nanosecond stamp, then the pid to break ties.
ticket="$dir/wait.$(date +%s%N).$$"
: > "$ticket"
trap 'rm -f "$ticket"' EXIT INT TERM

holders() { cat "$dir"/slot*.owner 2>/dev/null | sed 's/^/     /'; }

# Every live ticket, oldest first. A ticket whose process is gone is removed rather than waited on.
live_tickets() {
	local t base pid
	for t in "$dir"/wait.*; do
		[ -e "$t" ] || continue
		base=${t##*/}
		pid=${base##*.}
		if [ "$pid" = "$$" ] || kill -0 "$pid" 2>/dev/null; then
			echo "$t"
		else
			rm -f "$t"
		fi
	done | sort
}

announced=0
started=$(date +%s)
last_beat=$started

while true; do
	# Wait our turn: only the oldest live ticket may try for a lock.
	mapfile -t queue < <(live_tickets)
	if [ "${#queue[@]}" -eq 0 ] || [ "${queue[0]}" = "$ticket" ]; then
		for i in $(seq 1 "$slots"); do
			exec {fd}>"$dir/slot$i.lock"
			if flock -n "$fd"; then
				echo "$(date +%H:%M:%S) $(basename "$PWD"): $*" > "$dir/slot$i.owner"
				rm -f "$ticket"          # holding a slot, no longer queuing
				trap - EXIT INT TERM
				[ "$announced" -eq 1 ] && echo ">> got heavy-run slot $i after $((($(date +%s) - started) / 60)) min" >&2
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
	fi

	now=$(date +%s)
	if [ "$announced" -eq 0 ]; then
		echo ">> waiting for a heavy-run slot ($slots in use by other worktrees):" >&2
		holders
		announced=1
		last_beat=$now
	elif [ $((now - last_beat)) -ge 60 ]; then
		# A wait with no heartbeat looks exactly like a hang. Say where we are in the queue.
		mapfile -t queue < <(live_tickets)
		pos=1
		for t in "${queue[@]}"; do
			[ "$t" = "$ticket" ] && break
			pos=$((pos + 1))
		done
		echo ">> still waiting for a heavy-run slot: $(((now - started) / 60)) min, position $pos of ${#queue[@]}; holders:" >&2
		holders
		last_beat=$now
	fi
	sleep 5
done
