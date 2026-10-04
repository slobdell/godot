#!/usr/bin/env bash
# Known-answer tests for the engine-message gate on a check target's own log (tools/engine_log_gate.py), and for the
# REAL check wrapper (mk/core.mk `_cp-<target>`) that runs it -- driven with a stub target, no Godot, a few seconds.
#
# The defect it closes (round 17, found by the lead): a `"\u0000"` literal made the engine print
# `Unicode parsing error, ...: Unexpected NUL character` 38-46 times in every check log on main from f93f3cb4 to
# f5b2226c, and every one of those checks read `ALL JUDGED`: the line reached no gate at all.
set -uo pipefail
unset TANK_SQUAD_SLOT_DIR
export TANK_SQUAD_SLOT=1   # already "inside a slot": the root Makefile runs the goal directly

repo="$(cd "$(dirname "$0")/.." && pwd)"
gate="$repo/tools/engine_log_gate.py"
pass=0; fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

UNI='Unicode parsing error, some characters were replaced with � (U+FFFD): Unexpected NUL character'
printf '# reason: the test\nJolt Physics job system exceeded\n' > "$tmp/expected.txt"
printf '# reason: the test\nnet-smoke | ERROR: 2 resources still in use at exit\n' > "$tmp/allowed.txt"
export ENGINE_LOG_EXPECTED="$tmp/expected.txt" ENGINE_LOG_ALLOWED="$tmp/allowed.txt"

run() {  # run <target> <log text> -> prints the gate's output; leaves its exit in $rc
	printf '%s\n' "$2" > "$tmp/log"; out=$(python3 "$gate" "$1" "$tmp/log" --out "$tmp/out" 2>&1); rc=$?
}

# ---- the class that started it: fails EVERY target, self-judged ones included --------------------------------------
run match-smoke "MATCH ok"$'\n'"$UNI"$'\n'"$UNI"
[ "$rc" = 1 ] && grep -q 'x2 "Unicode parsing error' <<<"$out" && ok "a smoke's Unicode parsing error fails it, quoted and counted" || bad "smoke unicode" "rc=$rc $out"
grep -q 'engine message x2: "Unicode parsing error' "$tmp/out" && ok "the quoted line is written for the verdict row" || bad "--out" "$(cat "$tmp/out")"
run test "  PASS  a::b"$'\n'"$UNI"
[ "$rc" = 1 ] && ok "the test runner's log fails on it too (the runner cannot see it: _log_message, and errors.take())" || bad "test unicode" "rc=$rc"
run test-shard-3 "   $UNI"
[ "$rc" = 1 ] && ok "a shard's log, indented, fails on it" || bad "shard unicode" "rc=$rc"

# ---- the prefixed shapes: every target except the ones that judge them themselves ------------------------------------
run net-smoke "ERROR: Trying to call an RPC via a multiplayer peer which is not connected."
[ "$rc" = 1 ] && ok "a smoke's ERROR: line fails it" || bad "smoke ERROR" "rc=$rc"
run web-smoke "WARNING: something" ; [ "$rc" = 1 ] && ok "a smoke's WARNING: line fails it" || bad "smoke WARNING" "rc=$rc"
run combat-smoke "SCRIPT ERROR: Invalid call" ; [ "$rc" = 1 ] && ok "a smoke's SCRIPT ERROR: fails it" || bad "SCRIPT ERROR" "rc=$rc"
run test "WARNING: deliberate warning from test_engine_warnings"
[ "$rc" = 0 ] && ok "the test runner's declared warning does not (it judges those itself)" || bad "test WARNING" "rc=$rc $out"
run lint "ERROR: res://x.gd:1 - Parse Error" ; [ "$rc" = 0 ] && ok "lint's ERROR: lines are lint's to judge" || bad "lint" "rc=$rc"

# ---- what must NOT fail -------------------------------------------------------------------------------------------
run net-smoke "grep -E 'NET_CHECK|ERROR' build/x.log || true; \\"$'\n'"NET_CHECK PASS"
[ "$rc" = 0 ] && ok "the recipe's own echoed command (it names ERROR mid-line) passes" || bad "echo" "rc=$rc $out"
run net-smoke "ERROR: 2 resources still in use at exit (run with --verbose for details)."
[ "$rc" = 0 ] && ok "a line allowed for this target passes" || bad "allowed scoped" "rc=$rc $out"
run match-smoke "ERROR: 2 resources still in use at exit (run with --verbose for details)."
[ "$rc" = 1 ] && ok "... and still fails a target it was not allowed for" || bad "scope" "rc=$rc"
run match-smoke "WARNING: Jolt Physics job system exceeded the maximum number of jobs"
[ "$rc" = 0 ] && ok "engine_expected.txt applies to every target" || bad "expected" "rc=$rc $out"
run match-smoke "" ; [ "$rc" = 0 ] && ok "an empty log passes" || bad "empty" "rc=$rc"

# ---- the REAL check wrapper, with a stub target ----------------------------------------------------------------------
# The stubs reach the wrapper's sub-make through MAKE (a command-line variable, so every sub-make gets it; `-f` alone
# is not inherited and MAKEFILES loads BEFORE the Makefile, which then wins). `lint` is stubbed too: every other
# wrapper is ordered after `_cp-lint`. make warns about the overridden recipes; harmless.
cat > "$tmp/stub.mk" <<EOF
lint: ; @echo "stub lint"
stub-noisy: ; @echo "stub ran"; printf '%s\n' '$UNI' >&2
stub-quiet: ; @echo "stub ran"
EOF
B="$tmp/b"
wrap() {  # wrap <target>
	( cd "$repo" && make -s --no-print-directory -f Makefile -f "$tmp/stub.mk" "_cp-$1" MAKE="make -f Makefile -f $tmp/stub.mk" CHECK_TARGETS="lint $1" BUILD_DIR="$B" \
		>"$tmp/wrap.out" 2>&1 ); echo $?
}
rc=$(wrap stub-noisy)
[ "$rc" != 0 ] && ok "the wrapper fails a target whose make exited 0 but printed the line (on stderr)" || bad "wrapper noisy" "rc=$rc $(cat "$tmp/wrap.out")"
[ ! -e "$B/check/done/stub-noisy" ] && [ ! -e "$B/check/running/stub-noisy" ] && ok "... no done marker, and running is cleared" || bad "markers" "$(ls -R "$B/check")"
v=$("$repo/tools/check_verdict.sh" "$B/check" lint stub-noisy 2>&1)
grep -q 'FAIL     stub-noisy: engine message x1: "Unicode parsing error' <<<"$v" && ok "the verdict's FAIL row quotes the line" || bad "verdict row" "$v"
grep -q 'stub ran' "$B/check/logs/stub-noisy.log" && ok "the target's own log is kept in check/logs/" || bad "log kept" ""
grep -q 'engine-log-gate: stub-noisy FAILED' "$tmp/wrap.out" && ok "the target's output says why it failed" || bad "says why" "$(cat "$tmp/wrap.out")"
rc=$(wrap stub-quiet)
[ "$rc" = 0 ] && [ -e "$B/check/done/stub-quiet" ] && [ ! -s "$B/check/engine/stub-quiet" ] && ok "a quiet target passes through the wrapper" || bad "wrapper quiet" "rc=$rc $(cat "$tmp/wrap.out")"

echo
echo "engine-log-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
