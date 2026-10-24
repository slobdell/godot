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
#   full_check_lock.sh is-full-check <args...>  exit 0 if these make arguments run a full check (a word `check`)
set -uo pipefail
busy=75

case "${1:-}" in
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
	guarded=
	guard() { # the hang-up traps and the session watchdog, from before the wait: a check queued for the claim when its
		# session dies must not wake later and run as an orphan
		[ -n "$guarded" ] && return; guarded=1
		trap 'trap - HUP INT TERM; kill -TERM 0 2>/dev/null; exit 129' HUP
		trap 'trap - HUP INT TERM; kill -TERM 0 2>/dev/null; exit 130' INT
		trap 'trap - HUP INT TERM; kill -TERM 0 2>/dev/null; exit 143' TERM
		if [ -n "${FULL_CHECK_LOCK_SESSION:-}" ]; then
			( while kill -0 "$FULL_CHECK_LOCK_SESSION" 2>/dev/null; do sleep "${FULL_CHECK_LOCK_POLL:-5}"; done
			  echo ">> full-check lock: the session (pid $FULL_CHECK_LOCK_SESSION) is gone: stopping this check" >&2; kill -HUP $$ ) 9>&- &
			watchdog=$!
		fi
	}
	if ! flock -n 9; then
		[ -n "$nowait" ] && { echo "full_check_lock: busy: $(head -1 "$lock" 2>/dev/null)" >&2; exit $busy; }
		guard
		echo ">> full-check lock: another full check holds this builder ($(head -1 "$lock" 2>/dev/null)); waiting" >&2
		t0=$(date +%s)
		flock 9 || exit 2
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
	echo "usage: full_check_lock.sh run [-n] <lock> <cmd...> | holder <lock> | is-full-check <make args...>" >&2
	exit 2 ;;
esac
