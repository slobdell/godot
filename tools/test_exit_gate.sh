#!/usr/bin/env bash
# Known-answer tests for tools/exit_gate.sh (ship, round 18).
set -u
eg="$(cd "$(dirname "$0")" && pwd)/exit_gate.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
printf 'MARKER ok\ncorrupted size vs. prev_size in fastbins\n' > "$tmp/log"
out=$(bash "$eg" t 0 "$tmp/log"); [ $? = 0 ] && [ -z "$out" ] && ok "0: passes silently" || bad "zero" "$out"
out=$(bash "$eg" t 134 "$tmp/log"); [ $? = 1 ] && grep -q 't FAILED: the game exited 134 -- aborted' <<<"$out" && grep -q 'corrupted size' <<<"$out" \
	&& ok "134: FAILED, named, last lines shown" || bad "134" "$out"
out=$(bash "$eg" t 124 "$tmp/log"); [ $? = 1 ] && grep -q 'timed out' <<<"$out" && ok "124: FAILED as a timeout" || bad "124" "$out"
out=$(bash "$eg" t 143 "$tmp/log" 143); [ $? = 0 ] && grep -q 'exited 143 (expected' <<<"$out" && ok "a named expected code passes, and says so" || bad "expected" "$out"
out=$(bash "$eg" t 1 "$tmp/log" 143); [ $? = 1 ] && ok "an unnamed code still fails" || bad "unnamed" "$out"
printf '\nexit-gate: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
