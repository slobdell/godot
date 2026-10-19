#!/usr/bin/env bash
# Round 35 (native, after N3's launcher missed traffic's `make native check`): how many FULL checks run on builder0, one per
# worktree (cwd), whatever form they run in: `make check`, `make native check`, and the slot wrapper's
# `make --no-print-directory [native] check` (make variables may follow). Prints the count, then one cwd a line.
#
#   tools/builder_checks.sh                    ask builder0 (REMOTE_HOST, default slobdell@builder0)
#   tools/builder_checks.sh --wait-below N     wait (60 s polls) until fewer than N run, then print the count (C35.1: two)
#   tools/builder_checks.sh --rows             read "cwd<TAB>args" rows on stdin instead (tools/test_builder_checks.sh)
set -euo pipefail
host=${REMOTE_HOST:-slobdell@builder0}

count() { # stdin: cwd<TAB>args rows -> the count, then the cwds
	awk -F'\t' '$2 ~ /(^|[ \/])make( --no-print-directory)?( native)? check( |$)/ { seen[$1] = 1 }
		END { n = 0; for (d in seen) n++; print n; for (d in seen) print d }'
}

rows() {
	# shellcheck disable=SC2016
	ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" \
		'for p in $(pgrep -f "make .*check"); do printf "%s\t%s\n" "$(readlink /proc/$p/cwd)" "$(tr "\0" " " < /proc/$p/cmdline)"; done' \
		2>/dev/null | sed 's/ *$//'
}

case "${1:-}" in
--rows) count ;;
--wait-below)
	below=${2:?--wait-below N}
	while true; do
		out=$(rows | count)
		[ "$(head -1 <<<"$out")" -lt "$below" ] && { echo "$out"; exit 0; }
		sleep 60
	done ;;
"") rows | count ;;
*) echo "builder_checks.sh [--wait-below N | --rows]" >&2; exit 2 ;;
esac
