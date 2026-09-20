#!/usr/bin/env bash
# Run a command while holding one of N machine-wide "heavy run" slots.
#
# Several worktree agents share one machine, and one Godot test run peaks at ~735 MB. Without a
# limit, five agents running `make check` at once run out of memory. The root Makefile routes every
# non-interactive goal through this script, so parallel agents queue instead of crashing each other.
# Use it directly for heavy commands run outside make:
#
#     tools/slot.sh python3 tools/match_series.py ...
#
# THE SLOT COUNT IS DERIVED FROM THE MACHINE, NOT HARD-CODED (2026-09-19). It used to default to a
# flat 2, sized for "8 cores, 7.6 GB RAM" -- a note written 2026-09-14 and already stale, because
# the two machines this runs on are not the same machine:
#
#     laptop     8 cores, 2.4 GB AVAILABLE (7.6 GB total, most of it held by six agent sessions)
#     builder0  12 cores, 11.9 GB available
#
# At ~735 MB a run, the laptop can barely hold three and builder0 can hold a dozen. **A flat default
# is therefore wrong in BOTH directions at once** -- the lead asked to raise concurrency after seeing
# builder0 98% idle across 12 cores, and raising a global constant would have starved builder0 anyway
# while pushing the laptop into OOM. So the default now reads what the machine actually has, which is
# Invariant 0 applied to a constant: a value with a single owner is READ, not mirrored. The owner here
# is `/proc/meminfo`, and it cannot go stale when the hardware changes again.
#
# Budget: 2.5 GB per slot, capped at 4. The cap is not RAM, it is the FAN-OUT INSIDE a slot -- heavy
# targets run `xargs -P 6`, so one slot can already hold ~4.4 GB of Godot. Four such targets at once
# would exceed any of our machines. **Raising the cap above 4 requires capping that inner -P first**,
# and the real win is elsewhere: a `make check` is mostly ONE single-threaded Godot grinding ticks for
# 30-50 minutes, which is why 12 cores sit idle during it. More slots shortens the QUEUE; only inner
# parallelism shortens the RUN.
#
# Knobs (environment): TANK_SQUAD_SLOTS (overrides the derived value), TANK_SQUAD_SLOT_TIMEOUT
# (seconds, default 5400).
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

# T1 (metrics, round 9): the same question one level down. A slot holds ONE `make check`; this says how many of
# check's targets that check may run at once INSIDE its slot. Same principle and same owner as `default_slots`,
# because "how much can this machine take" is one fact with one home (Invariant 0: a value with a single owner is
# READ, not mirrored) -- and lesson 148 is that hard-coding it was wrong in both directions at once.
#
#     tools/slot.sh --jobs <mb-per-job> [max]
#
# The caller supplies the per-job footprint it MEASURED, because the answer differs per workload: a plain headless
# match is ~735 MB, but `net-smoke` and `relay-smoke` each hold three Godot processes at once.
if [ "${1:-}" = "--jobs" ]; then
	per_job_mb=${2:-1024}
	max_jobs=${3:-12}
	avail_mb=$(awk '/^MemAvailable:/ {print int($2 / 1024); exit}' /proc/meminfo 2>/dev/null)
	cores=$(nproc 2>/dev/null || echo 2)
	# A machine we cannot measure gets the conservative answer, never the loud one.
	[ -n "${avail_mb:-}" ] || { echo 2; exit 0; }
	# Leave a quarter of what is available as headroom: the figure is a peak of one process, and several peaking
	# together is exactly the case that OOMs a laptop with six agent sessions up.
	n=$(( (avail_mb * 3 / 4) / per_job_mb ))
	[ "$n" -gt "$cores" ] && n=$cores
	[ "$n" -gt "$max_jobs" ] && n=$max_jobs
	[ "$n" -lt 1 ] && n=1
	echo "$n"
	exit 0
fi

if [ -n "${TANK_SQUAD_SLOT:-}" ]; then
	exec "$@"  # already inside a slot (nested make)
fi

# Derived from available RAM at ~2.5 GB a slot, clamped to [2, 4]. Falls back to 2 if MemAvailable
# cannot be read, because a machine we cannot measure gets the conservative answer, never the loud one.
default_slots() {
	local avail_mb
	avail_mb=$(awk '/^MemAvailable:/ {print int($2 / 1024); exit}' /proc/meminfo 2>/dev/null)
	[ -n "${avail_mb:-}" ] || { echo 2; return; }
	local n=$((avail_mb / 2500))
	[ "$n" -lt 2 ] && n=2
	[ "$n" -gt 4 ] && n=4
	echo "$n"
}

slots=${TANK_SQUAD_SLOTS:-$(default_slots)}
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
