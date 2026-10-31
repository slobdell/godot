#!/usr/bin/env bash
# Round 39 (native, the orchestrator's ask): ONE full check per builder at a time, claimed atomically. At ~10:3x PDT
# 2026-10-24 doctrine's and feedback's full checks both passed `tools/builder_checks.sh --wait-below 1` in the same poll
# window and ran together on builder0 ("a race, not a skip"): counting processes and then launching is check-then-act.
#
# The claim is a kernel flock(2) on one file per builder (~/tank_squad/.full-check.lock), taken by tools/remote.sh's
# builder-side script around `make` whenever the target list names `check`. The make INHERITS the descriptor, so the claim
# lives exactly as long as any process of the check does (feedback, 2026-10-24: a killed local wrapper left the remote check
# running; a lock held only by this script would have freed under it). The kernel drops it when the last of them exits, by
# any signal, SIGKILL included: there is no stale lock to clear and no pid to trust. A hang-up, INT or TERM to this script
# (the ssh session dropping) takes the check's whole process group down with it, so a lost session leaves no orphan check.
# An ssh with no terminal sends no hang-up when its client dies, so FULL_CHECK_LOCK_SESSION=<pid> (remote.sh: the sshd
# session's) is watched every FULL_CHECK_LOCK_POLL (5) s, and its exit counts as one.
#
#   full_check_lock.sh run <lock> <cmd...>      wait for the claim, run cmd holding it, exit with cmd's status
#   full_check_lock.sh run -n <lock> <cmd...>   claim now or exit 75 (busy) without running cmd
#   full_check_lock.sh holder <lock>            exit 0 and print the holder's line (folder pid since) if held; 1 if free
#   full_check_lock.sh queue <lock>             the waiters in claim order, oldest first (one "<ticket> <folder>" line each)
#
# Round 48 (native, the orchestrator's ask): waiters claim in ARRIVAL order. A bare blocking flock wakes whichever waiter the
# kernel picks: on builder3 engage's check (queued 12:30) kept waiting while manoeuvre's, queued later, took the claim at 13:06.
# Each waiter writes a ticket `<lock>.queue/<20-digit ns since epoch>.<pid>` and takes the claim only when its ticket is the
# oldest ticket of a LIVE process (a ticket whose pid is gone is deleted as it is met, so a dead waiter never blocks the queue),
# polling every FULL_CHECK_LOCK_QUEUE_POLL (1) s; its traps delete its ticket. `run -n` and the holder line are unchanged. A
# folder still running the old script claims with a bare flock (ahead of the queue) until it syncs this one.
#   full_check_lock.sh is-full-check <args...>  exit 0 if these make arguments run a full check (a word `check`)
set -uo pipefail
busy=75

case "${1:-}" in
queue)
	q="${2:?queue <lock>}.queue"
	[ -d "$q" ] || exit 0
	for t in $(ls "$q" 2>/dev/null | sort); do
		pid=${t##*.}
		kill -0 "$pid" 2>/dev/null || continue
		echo "$t $(readlink "/proc/$pid/cwd" 2>/dev/null || echo '?')"
	done
	exit 0 ;;
is-full-check)
	shift
	for a in "$@"; do [ "$a" = check ] && exit 0; done
	exit 1 ;;
holder)
	lock=${2:?holder <lock>}
	[ -e "$lock" ] || exit 1
	flock -n "$lock" true 2>/dev/null && exit 1
	line=$(head -1 "$lock" 2>/dev/null)
	echo "${line:-? (held, no holder line yet)}"
	exit 0 ;;
run)
	shift
	nowait=
	[ "${1:-}" = -n ] && { nowait=1; shift; }
	lock=${1:?run [-n] <lock> <cmd...>}; shift
	[ $# -gt 0 ] || { echo "full_check_lock: run needs a command" >&2; exit 2; }
	mkdir -p "$(dirname "$lock")"
	exec 9<>"$lock" || exit 2
	ticket=
	guarded=
	guard() { # the hang-up traps and the session watchdog, from before the wait: a check queued for the claim when its
		# session dies must not wake later and run as an orphan
		[ -n "$guarded" ] && return; guarded=1
		trap 'trap - HUP INT TERM; [ -n "$ticket" ] && rm -f "$ticket"; kill -TERM 0 2>/dev/null; exit 129' HUP
		trap 'trap - HUP INT TERM; [ -n "$ticket" ] && rm -f "$ticket"; kill -TERM 0 2>/dev/null; exit 130' INT
		trap 'trap - HUP INT TERM; [ -n "$ticket" ] && rm -f "$ticket"; kill -TERM 0 2>/dev/null; exit 143' TERM
		if [ -n "${FULL_CHECK_LOCK_SESSION:-}" ]; then
			# SIGPIPE ignored: once the session is gone, stderr is a pipe with no reader, and writing the message killed
			# the watchdog by SIGPIPE before it stopped anything (feedback's queued waiter, builder2, 2026-10-24).
			( trap '' PIPE
			  while kill -0 "$FULL_CHECK_LOCK_SESSION" 2>/dev/null; do sleep "${FULL_CHECK_LOCK_POLL:-5}"; done
			  echo ">> full-check lock: the session (pid $FULL_CHECK_LOCK_SESSION) is gone: stopping this check" >&2
			  kill -HUP $$ ) 9>&- &
			watchdog=$!
		fi
	}
	if ! flock -n 9; then
		[ -n "$nowait" ] && { echo "full_check_lock: busy: $(head -1 "$lock" 2>/dev/null)" >&2; exit $busy; }
		guard
		echo ">> full-check lock: another full check holds this builder ($(head -1 "$lock" 2>/dev/null)); waiting" >&2
		t0=$(date +%s)
		# In the background, because bash runs a trap only when its foreground command returns: a queued waiter blocked
		# in a foreground flock heard its dead session's hang-up only once the claim was free (feedback, builder2,
		# 2026-10-24: a waiter outlived its stopped wrapper). `wait` is interrupted by a trapped signal. The lock is on the
		# open file both share, so the child's claim is this script's too.
		# Arrival order (round 48): my ticket, then wait until it is the oldest live one and the claim is free. Each sleep is in
		# the background for the same reason as the old flock was: a trapped signal interrupts `wait`, not a foreground sleep.
		queue="$lock.queue"
		mkdir -p "$queue"
		ticket="$queue/$(printf '%020d' "$(date +%s%N)").$$"
		: > "$ticket"
		while true; do
			first=""
			for t in $(ls "$queue" 2>/dev/null | sort); do
				if kill -0 "${t##*.}" 2>/dev/null; then first=$t; break; fi
				rm -f "$queue/$t"  # its waiter is gone: it must not hold the queue
			done
			if [ "$first" = "${ticket##*/}" ] && flock -n 9; then break; fi
			[ -e "$ticket" ] || : > "$ticket"  # never lose my place to a cleaner that misread me
			sleep "${FULL_CHECK_LOCK_QUEUE_POLL:-1}" & wait $! 2>/dev/null
		done
		rm -f "$ticket"; ticket=
		echo ">> full-check lock: claimed after $(( $(date +%s) - t0 )) s" >&2
	fi
	# The holder line, rewritten in place (the flock is on the open file, so truncating through a path keeps it).
	printf '%s %s %s pgid %s\n' "$PWD" "$$" "$(date '+%F %T')" "$(ps -o pgid= -p $$ | tr -d ' ')" > "$lock"
	guard
	"$@" &
	child=$!
	while true; do wait "$child"; status=$?; kill -0 "$child" 2>/dev/null || break; done
	[ -n "${watchdog:-}" ] && kill "$watchdog" 2>/dev/null
	: > "$lock"
	exit $status ;;
*)
	echo "usage: full_check_lock.sh run [-n] <lock> <cmd...> | holder <lock> | queue <lock> | is-full-check <make args...>" >&2
	exit 2 ;;
esac
