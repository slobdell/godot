#!/usr/bin/env bash
# Round 35 (native, after N3's launcher missed traffic's `make native check`): how many FULL checks run on builder0, one per
# worktree (cwd), whatever form they run in: `make check`, `make native check`, and the slot wrapper's
# `make --no-print-directory [native] check` (make variables may follow). Prints the count, then one cwd a line.
#
#   tools/builder_checks.sh                    ask builder0 (REMOTE_HOST, default slobdell@builder0)
#   tools/builder_checks.sh --wait-below N     wait (60 s polls) until fewer than N run, then print the count (C35.1: two)
#   tools/builder_checks.sh --rows             read "cwd<TAB>args" rows on stdin instead (tools/test_builder_checks.sh)
# Round 38 (R38.15): an ssh that fails (255: builder2 off ZeroTier for under a minute at 18:40) is never "0 running". Plain mode
# exits 3 with no count; --wait-below asks again each poll, up to BUILDER_CHECKS_TRIES (30) failed asks in a row, then exits 3.
# BUILDER_CHECKS_SSH / BUILDER_CHECKS_POLL (seconds, 60) are for the tests.
# Round 39 (native): the holder of the builder's full-check lock (tools/full_check_lock.sh, taken by remote.sh around every
# full check) is a row too, so the count sees a claimed check even before its make shows in the process list. The gate is
# advisory now: the claim itself is the lock, and a check that loses the race waits for it on the builder.
set -euo pipefail
host=${REMOTE_HOST:-slobdell@builder0}

count() { # stdin: cwd<TAB>args rows -> the count, then the cwds
	awk -F'\t' '$2 ~ /(^|[ \/])make( --no-print-directory)?( native)? check( |$)/ { seen[$1] = 1 }
		END { n = 0; for (d in seen) n++; print n; for (d in seen) print d }'
}

rows() { # the rows, or a non-zero exit when the box could not be asked
	local got
	# shellcheck disable=SC2016
	got=$("${BUILDER_CHECKS_SSH:-ssh}" -o BatchMode=yes -o ConnectTimeout=10 "$host" \
		'for p in $(pgrep -f "make .*check"); do printf "%s\t%s\n" "$(readlink /proc/$p/cwd)" "$(tr "\0" " " < /proc/$p/cmdline)"; done
		l=~/tank_squad/.full-check.lock; if [ -e "$l" ] && ! flock -n "$l" true 2>/dev/null; then
			h=$(head -1 "$l"); printf "%s\t%s\n" "${h%% *}" "make check (holds .full-check.lock: $h)"; fi' \
		2>/dev/null) || return
	[ -z "$got" ] || sed 's/ *$//' <<<"$got"
}

poll=${BUILDER_CHECKS_POLL:-60}
case "${1:-}" in
--rows) count ;;
--wait-below)
	below=${2:?--wait-below N}
	failed=0
	while true; do
		if got=$(rows); then
			failed=0
			out=$(count <<<"$got")
			[ "$(head -1 <<<"$out")" -lt "$below" ] && { echo "$out"; exit 0; }
		else
			failed=$((failed + 1))
			echo "builder_checks: cannot ask $host (ssh failed, $failed in a row); asking again" >&2
			[ "$failed" -ge "${BUILDER_CHECKS_TRIES:-30}" ] && { echo "builder_checks: gave up on $host" >&2; exit 3; }
		fi
		sleep "$poll"
	done ;;
"") got=$(rows) || { echo "builder_checks: cannot ask $host (ssh failed): no count" >&2; exit 3; }
	count <<<"$got" ;;
*) echo "builder_checks.sh [--wait-below N | --rows]" >&2; exit 2 ;;
esac
