#!/usr/bin/env bash
# Known answers for tools/remote_native_first.sh (shell-tools-test).
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
want() {
	local expect=$1; shift
	local got; got=$(bash tools/remote_native_first.sh "$@")
	if [ "$got" = "$expect" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $* -> $got (want $expect)"; fi
}
want yes control-timing
want yes control-timing WEB_PORT=8600
want yes test FILTER=test_native_assign
want yes perf-judge
want no check
want no check-fast
want no native
want no native-fresh control-timing
want no bootstrap
want no control-timing NATIVE=off
want no
REMOTE_NATIVE_FRESH=0 want no control-timing
echo "remote_native_first: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
