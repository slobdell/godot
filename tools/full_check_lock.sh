#!/usr/bin/env bash
# Round 39 (native, the orchestrator's ask): ONE full check per builder at a time, claimed atomically. At ~10:3x PDT
# 2026-10-24 doctrine's and feedback's full checks both passed `tools/builder_checks.sh --wait-below 1` in the same poll
# window and ran together on builder0 ("a race, not a skip"): counting processes and then launching is check-then-act.
#
# The claim is a kernel flock(2) on one file per builder (~/tank_squad/.full-check.lock), taken by tools/remote.sh's
# builder-side script around `make` whenever the target list names `check`, and held by this script's own process (the
# make it runs does not inherit the descriptor, so a stray child left behind cannot hold the box). The kernel drops it
# the moment the holder dies, by any signal, SIGKILL included: there is no stale lock to clear and no pid to trust.
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
	if ! flock -n 9; then
		[ -n "$nowait" ] && { echo "full_check_lock: busy: $(head -1 "$lock" 2>/dev/null)" >&2; exit $busy; }
		echo ">> full-check lock: another full check holds this builder ($(head -1 "$lock" 2>/dev/null)); waiting" >&2
		t0=$(date +%s)
		flock 9 || exit 2
		echo ">> full-check lock: claimed after $(( $(date +%s) - t0 )) s" >&2
	fi
	# The holder line, rewritten in place (the flock is on the open file, so truncating through a path keeps it).
	printf '%s %s %s\n' "$PWD" "$$" "$(date '+%F %T')" > "$lock"
	"$@" 9>&-
	status=$?
	: > "$lock"
	exit $status ;;
*)
	echo "usage: full_check_lock.sh run [-n] <lock> <cmd...> | holder <lock> | is-full-check <make args...>" >&2
	exit 2 ;;
esac
