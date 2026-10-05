#!/usr/bin/env bash
# `check`'s exit status is the verdict's, whatever the heartbeat is doing (the orchestrator, round 18).
#
# The check recipe runs a once-a-minute heartbeat in the background and kills it from an EXIT trap. The heartbeat also
# ends BY ITSELF when a poll finds nothing left to wait for. Under the Makefile's `bash -eu -o pipefail`, a `kill` of a
# pid that is already gone fails inside the trap and the shell exits 1 AFTER `exit 0`: a check whose fan-out ended
# exactly on a poll printed "23 targets, all passed, ALL JUDGED" and then `make check exited 2` (main, e57dba92,
# builder0, 2026-10-04: 1380 s = 23 m 00 s). This drives the recipe's OWN trap line, read out of mk/core.mk, with a
# heartbeat that has already ended and with one still running, for a passing and a failing verdict.
set -u
cd "$(dirname "$0")/.."
passed=0; failed=0
ok() { echo "  ok   $1"; passed=$((passed + 1)); }
bad() { echo "  FAIL $1"; failed=$((failed + 1)); }

line=$(grep -m1 -E "^[[:space:]]*trap '.*heartbeat" mk/core.mk | sed -e 's/\$\$/$/g' -e 's/;[[:space:]]*\\$//')
if [ -z "$line" ]; then bad "the check recipe's heartbeat trap line was not found in mk/core.mk"; fi

run() {  # $1 = heartbeat body, $2 = verdict status -> prints the shell's exit status
	bash -eu -o pipefail -c "( $1 ) & heartbeat=\$!; $3 $line; status=$2; exit \$status" >/dev/null 2>&1
	echo $?
}

[ "$(run 'exit 0' 0 'wait $heartbeat;')" = 0 ] && ok "heartbeat already ended, verdict 0: the check exits 0" \
	|| bad "heartbeat already ended, verdict 0: the check must exit 0 (the trap's kill of a dead pid failed it)"
[ "$(run 'exit 0' 1 'wait $heartbeat;')" = 1 ] && ok "heartbeat already ended, verdict 1: the check exits 1" \
	|| bad "heartbeat already ended, verdict 1: the check must exit 1"
[ "$(run 'sleep 20' 0 '')" = 0 ] && ok "heartbeat still running, verdict 0: the check exits 0" \
	|| bad "heartbeat still running, verdict 0: the check must exit 0"
[ "$(run 'sleep 20' 1 '')" = 1 ] && ok "heartbeat still running, verdict 1: the check exits 1" \
	|| bad "heartbeat still running, verdict 1: the check must exit 1"

echo "check-trap: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
