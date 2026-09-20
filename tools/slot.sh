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
# (seconds, default 5400), TANK_SQUAD_EXCLUSIVE (hold EVERY slot -- see below).
#
# ---- TANK_SQUAD_EXCLUSIVE=1: a quiet window, held rather than hoped for ------------------------
# A frame-time measurement needs a quiet machine (lesson 179), and "wait until the box looks quiet, then
# launch" does not deliver one: another stream can start two seconds later, in the middle of the run. The
# only way to hold a window is to OWN it, so an exclusive run takes every slot and gives them back when it
# finishes. Other streams then queue normally -- they are not refused, they wait, which is what slots are for.
# It cannot livelock: only the OLDEST live ticket may attempt a lock, so an exclusive run at the head of the
# queue accumulates the slots as they free with nobody racing it, and it keeps its ticket until it has them
# all. Holding some while waiting for the rest is deliberate and the heartbeat says so, because a box that
# looks half-idle for ten minutes otherwise reads as the starvation bug this queue was built to fix.
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
#
# ---- The work runs in the BACKGROUND and is waited on, and that is not a style choice ----------
# bash defers a trap until the current foreground command finishes. So with the work in the foreground, a
# `kill` aimed at this script did nothing for as long as the work ran -- the handler, the one that removes
# the owner file, waited for a `make check` that nobody had signalled. That is exactly the stale-`.owner`
# failure in remote_builds.md, where a dead holder went on looking alive to every waiter and one of two
# slots sat held with nothing inside it. `wait` is interruptible, so the handler runs AT ONCE: it kills the
# work, gives the slot back, and exits. Found by the exclusive mode's own tests (metrics, 2026-09-20), and
# it was already true of the single-slot path every stream uses all day.
set -uo pipefail

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
	# DIVIDE BY THE SLOT COUNT. This process holds one slot of N, and the other N-1 are entitled to their share.
	# Without this the two budgets multiply: after T1 a single `check` is no longer one Godot process but a
	# sharded test suite plus a fanned-out lint plus concurrent targets, so raising the slot count and raising
	# the inner fan-out at the same time is how a box that was 95% idle goes straight to OOM. MemAvailable alone
	# does not catch it, because N runs starting together all read the machine before any of them has grown.
	holders=${TANK_SQUAD_SLOTS:-$(default_slots)}
	[ "$holders" -ge 1 ] 2>/dev/null || holders=1
	share_mb=$(( avail_mb / holders ))
	# Leave a quarter of the share as headroom: the figure is a peak of one process, and several peaking together
	# is exactly the case that OOMs a laptop with six agent sessions up.
	n=$(( (share_mb * 3 / 4) / per_job_mb ))
	# Cores are NOT divided by the slot count, and memory is not the same kind of constraint as CPU here. These
	# runs are latency-bound, not compute-bound: `make test` awaits physics frames at real time, so builder0 sat
	# 90-99% IDLE with three whole checks running (references/round9/metrics/t1-builder0-idle.txt). Oversubscribing
	# cores costs nothing for work that is mostly waiting; oversubscribing memory kills the box. So: divide the
	# memory, cap at the core count, and let the memory share be what binds.
	[ "$n" -gt "$cores" ] && n=$cores
	[ "$n" -gt "$max_jobs" ] && n=$max_jobs
	[ "$n" -lt 1 ] && n=1
	echo "$n"
	exit 0
fi

if [ -n "${TANK_SQUAD_SLOT:-}" ]; then
	exec "$@"  # already inside a slot (nested make)
fi


# ---- Pin this script against a mid-run rewrite -------------------------------------------------
# `git merge` / `git checkout` rewrite a working-tree file IN PLACE -- same inode, verified -- and bash reads a
# script LAZILY, from a file offset. So a merge landing while this is running makes it jump into the middle of
# the NEW text. Demonstrated rather than assumed: a running script printed its line 1, then "command not found"
# from the replacement's line 2, then executed the replacement's lines 3-5; its own lines 3 and 4 never ran.
#
# That is not hypothetical here. Every stream is being told to merge `main` between runs, and `main` carries this
# file -- so a merge lands on a wrapper that may be holding a slot for forty minutes. Re-exec from a private copy
# and unlink it immediately: the kernel keeps the text alive for this process through its open fd, and nobody --
# not even git -- can reach it by name to change it.
if [ -z "${TANK_SQUAD_PINNED_SELF:-}" ]; then
	pinned=$(mktemp -t "$(basename "$0").XXXXXX") || exit 1
	cat "$0" > "$pinned" && chmod +x "$pinned" || { rm -f "$pinned"; exit 1; }
	TANK_SQUAD_PINNED_SELF="$pinned" exec bash "$pinned" "$@"
fi
rm -f "$TANK_SQUAD_PINNED_SELF"

slots=${TANK_SQUAD_SLOTS:-$(default_slots)}
limit=${TANK_SQUAD_SLOT_TIMEOUT:-5400}
dir=${TANK_SQUAD_SLOT_DIR:-/tmp/tank_squad_slots}   # overridable so the queue can be tested in isolation
mkdir -p "$dir"

# Ticket name sorts by arrival: a fixed-width nanosecond stamp, then the pid to break ties.
ticket="$dir/wait.$(date +%s%N).$$"
: > "$ticket"
# THE HANDLER MUST EXIT. A `trap ... TERM` whose handler falls through does not stop the script: bash runs the
# handler and carries on, so `kill <pid>` on a queued waiter removed its ticket and left it polling for a slot
# forever -- ticketless, so `live_tickets` could not even see it to prune it, and only SIGKILL stopped it.
# (Found by the orchestrator on the laptop, 2026-09-20.) Same family as remote_builds.md's stale-.owner trap,
# and the same family as `make lint`'s killed wrapper leaving its Godot children: **a signal that reaches the
# wrapper has to end the wrapper.**
trap 'rm -f "$ticket"' EXIT
trap 'rm -f "$ticket"; exit 130' INT
trap 'rm -f "$ticket"; exit 143' TERM

holders() { cat "$dir"/slot*.owner 2>/dev/null | sed 's/^/     /'; }

# TERM a whole process tree, deepest first. `kill $child` is not enough: the work may sit under a subshell
# and a `timeout`, and killing the top of that leaves the Godot underneath running while the slot is given
# back -- the box then looks free and is not (lesson 15: a remote run kept executing after its wrapper died).
# Walked by PARENT, never by pattern: seven checkouts run the same command lines, and a pattern kill here
# took out three other streams' wrappers in one night (remote_builds.md, trip-up 19).
kill_tree() {
	local pid=$1 kid
	for kid in $(pgrep -P "$pid" 2>/dev/null); do
		kill_tree "$kid"
	done
	kill -TERM "$pid" 2>/dev/null
}

exclusive=${TANK_SQUAD_EXCLUSIVE:-}
held_slots=()
held_fds=()
# Give back every slot this process holds. The lock itself dies with the fd; it is the human-readable owner
# file that needs an owner, exactly as in the single-slot path below.
release_exclusive() {
	local i
	for i in ${held_slots[@]+"${held_slots[@]}"}; do
		rm -f "$dir/slot$i.owner"
	done
}

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
		if [ -n "$exclusive" ]; then
			for i in $(seq 1 "$slots"); do
				case " ${held_slots[*]-} " in *" $i "*) continue ;; esac
				exec {fd}>"$dir/slot$i.lock"
				if flock -n "$fd"; then
					held_slots+=("$i"); held_fds+=("$fd")
					echo "$(date +%H:%M:%S) $(basename "$PWD"): EXCLUSIVE (quiet window) $*" > "$dir/slot$i.owner"
					trap 'release_exclusive' EXIT
					trap 'release_exclusive; exit 130' INT
					trap 'release_exclusive; exit 143' TERM
				else
					exec {fd}>&-
				fi
			done
			if [ "${#held_slots[@]}" -eq "$slots" ]; then
				rm -f "$ticket"
				echo ">> quiet window: holding all $slots heavy-run slots$([ "$announced" -eq 1 ] && echo " after $((($(date +%s) - started) / 60)) min")" >&2
				# The child must inherit none of the lock fds: a stray background server would hold the whole
				# box. There are N of them, so the redirections are built rather than written out.
				redir=""
				for f in ${held_fds[@]+"${held_fds[@]}"}; do redir="$redir $f>&-"; done
				export TANK_SQUAD_SLOT=exclusive
				# Entitled to the whole machine, because nobody else is on it: `--jobs` divides its memory
				# budget by the live slot count, and the live slot count for this run is one.
				export TANK_SQUAD_SLOTS=1
				eval timeout --kill-after=30 "$limit" '"$@"' "$redir" &
				child=$!
				trap 'kill_tree $child; release_exclusive; exit 130' INT
				trap 'kill_tree $child; release_exclusive; exit 143' TERM
				wait "$child"
				status=$?
				[ "$status" -eq 124 ] && echo ">> slot.sh: killed after ${limit}s: $*" >&2
				release_exclusive
				exit "$status"
			fi
		else
		for i in $(seq 1 "$slots"); do
			exec {fd}>"$dir/slot$i.lock"
			if flock -n "$fd"; then
				echo "$(date +%H:%M:%S) $(basename "$PWD"): $*" > "$dir/slot$i.owner"
				rm -f "$ticket"          # holding a slot, no longer queuing
				# Hand the traps over from the ticket to the OWNER file. `trap - EXIT INT TERM` used to clear
				# them outright, so a slot holder killed mid-run left `slot$i.owner` behind and every later
				# waiter printed a holder that was not there (remote_builds.md's stale-.owner trap). The lock
				# itself is released by the kernel when the fd closes; it is only the human-readable owner file
				# that needed an owner.
				trap 'rm -f "$dir/slot'"$i"'.owner"' EXIT
				trap 'rm -f "$dir/slot'"$i"'.owner"; exit 130' INT
				trap 'rm -f "$dir/slot'"$i"'.owner"; exit 143' TERM
				[ "$announced" -eq 1 ] && echo ">> got heavy-run slot $i after $((($(date +%s) - started) / 60)) min" >&2
				export TANK_SQUAD_SLOT=$i
				# The child must not inherit the lock fd: a stray background server would otherwise
				# hold the slot forever.
				timeout --kill-after=30 "$limit" "$@" {fd}>&- &
				child=$!
				trap 'kill_tree $child; rm -f "$dir/slot'"$i"'.owner"; exit 130' INT
				trap 'kill_tree $child; rm -f "$dir/slot'"$i"'.owner"; exit 143' TERM
				wait "$child"
				status=$?
				[ "$status" -eq 124 ] && echo ">> slot.sh: killed after ${limit}s: $*" >&2
				rm -f "$dir/slot$i.owner"
				exit "$status"
			fi
			exec {fd}>&-
		done
		fi
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
		if [ -n "$exclusive" ]; then
			echo ">> quiet window: holding ${#held_slots[@]} of $slots slots, waiting $(((now - started) / 60)) min for the rest; holders:" >&2
		else
			echo ">> still waiting for a heavy-run slot: $(((now - started) / 60)) min, position $pos of ${#queue[@]}; holders:" >&2
		fi
		holders
		last_beat=$now
	fi
	sleep 5
done
