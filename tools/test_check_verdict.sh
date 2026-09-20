#!/usr/bin/env bash
# Known-answer tests for `check_verdict.sh` — every target's verdict after a `make check`.
#
# It exists because `check` used to stop at the first failure, so two combat checks in a row produced no
# `sim-baseline` reading at all: the number that gates every merge went missing behind an unrelated shard
# failure, and a target that never ran looked exactly like one that passed.
set -uo pipefail
cv="$(cd "$(dirname "$0")" && pwd)/check_verdict.sh"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

setup() { rm -rf "$tmp/check"; mkdir -p "$tmp/check/started" "$tmp/check/done"; }
started() { touch "$tmp/check/started/$1"; }
done_()   { touch "$tmp/check/started/$1" "$tmp/check/done/$1"; }
verdict() { bash "$cv" "$tmp/check" "$@" 2>&1; }

setup; done_ lint; done_ test; done_ sim-baseline
out=$(verdict lint test sim-baseline); rc=$?
[ "$rc" = 0 ] && ok "all passed: exit 0" || bad "all passed: exit 0" "exit $rc: $out"
grep -q '3 targets, all passed' <<<"$out" && ok "all passed: one line, no wall of PASS" || bad "all passed: one line" "$out"

# THE CASE THIS EXISTS FOR: test failed, and sim-baseline still ran and passed.
setup; done_ lint; started test; done_ sim-baseline; done_ determinism
out=$(verdict lint test sim-baseline determinism); rc=$?
[ "$rc" = 1 ] && ok "a failure exits non-zero" || bad "a failure exits non-zero" "exit $rc"
grep -qE '^   FAIL +test$' <<<"$out" && ok "the failure is named" || bad "the failure is named" "$out"
grep -q '3 passed, 1 FAILED, 0 NOT RUN' <<<"$out" && ok "the counts are right" || bad "the counts are right" "$out"
grep -q 'failed: test' <<<"$out" && ok "a one-line list of what failed" || bad "a one-line list of what failed"
grep -qE '^   (PASS|FAIL|NOT RUN) +sim-baseline$' <<<"$out" && bad "a passing target is not listed in a failing run" \
	|| ok "passing targets stay out of the way when something failed"

# NOT RUN is its own state, and must never read as a pass.
setup; started lint          # lint failed, so everything ordered after it was skipped
out=$(verdict lint test sim-baseline determinism); rc=$?
[ "$rc" = 1 ] && ok "lint failing exits non-zero" || bad "lint failing exits non-zero" "exit $rc"
grep -q '0 passed, 1 FAILED, 3 NOT RUN' <<<"$out" && ok "skipped targets count as NOT RUN" || bad "skipped targets count as NOT RUN" "$out"
grep -qE '^   NOT RUN +sim-baseline$' <<<"$out" && ok "sim-baseline is NOT RUN, not PASS" || bad "sim-baseline is NOT RUN" "$out"
grep -q 'a NOT RUN target is not a passing one' <<<"$out" && ok "it says so in words" || bad "it says so in words"
grep -q 'never ran: lint' <<<"$out" && bad "the failing target is not listed as never run" || ok "the failing target is not also 'never ran'"

# A target with no markers at all, in an otherwise fine run.
setup; done_ lint; done_ test
out=$(verdict lint test sim-baseline); rc=$?
grep -q '2 passed, 0 FAILED, 1 NOT RUN' <<<"$out" && ok "a target that never started is NOT RUN" || bad "a target that never started is NOT RUN" "$out"
[ "$rc" = 1 ] && ok "and it still exits non-zero" || bad "and it still exits non-zero" "exit $rc"

# An empty check directory must not report success.
setup
out=$(verdict lint test); rc=$?
[ "$rc" = 1 ] && ok "no markers at all: exit 1, not a vacuous pass" || bad "no markers at all: exit 1" "exit $rc: $out"

# A done marker without a started marker cannot happen, but must not crash or read as NOT RUN.
setup; touch "$tmp/check/done/test"
out=$(verdict test); rc=$?
grep -q '1 targets, all passed' <<<"$out" && ok "done wins over a missing started marker" || bad "done wins over missing started" "$out"

bash "$cv" >/dev/null 2>&1;            [ $? = 2 ] && ok "no arguments: exit 2" || bad "no arguments: exit 2"
bash "$cv" "$tmp/check" >/dev/null 2>&1; [ $? = 2 ] && ok "no targets: exit 2, rather than passing over an empty list" || bad "no targets: exit 2"

printf '\ncheck-verdict: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
