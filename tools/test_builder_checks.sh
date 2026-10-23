#!/usr/bin/env bash
# Known-answer tests for tools/builder_checks.sh (round 35, N3 follow-up): a full check is counted once per worktree, in every
# form it runs in (`make check`, `make native check`, the slot wrapper's `make --no-print-directory [native] check`), and
# nothing else (`make quick`, `make native test`, a check-perf-judge sub-stage) counts.
set -u
bc="$(cd "$(dirname "$0")" && pwd)/builder_checks.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
# "cwd<TAB>args" rows, as `builder_checks.sh --rows` reads them
rows=$'/t/godot-orders\tmake --no-print-directory check
/t/godot-orders\tbash /tmp/slot.sh.X make --no-print-directory check
/t/godot-orders\ttimeout --kill-after=30 5400 make --no-print-directory check
/t/godot-traffic-t7pair\tmake native check
/t/godot-traffic-t7pair\tmake --no-print-directory native check
/t/godot-native\tmake --no-print-directory check-perf-judge-stage
/t/godot-brains\tmake --no-print-directory quick
/t/godot-native-w1b-light\tmake --no-print-directory native test FILTER=test_native_
/t/godot-manoeuvre\tmake check
/t/godot-manoeuvre\tmake check WEB_PORT=8600 NET_PORT=9620'
out=$(printf '%s\n' "$rows" | bash "$bc" --rows)
[ "$(head -1 <<<"$out")" = 3 ] && ok "three worktrees checking (orders, traffic's native check, manoeuvre)" || bad "count" "$out"
grep -q "godot-traffic-t7pair" <<<"$out" && ok "  'make native check' counts (the form round 35's launcher missed)" || bad "native check" "$out"
! grep -q "godot-brains\|w1b-light" <<<"$out" && ok "  quick and native test don't" || bad "non-checks" "$out"
grep -q "godot-manoeuvre" <<<"$out" && ok "  a check with make variables after it counts" || bad "vars" "$out"
! grep -q "^/t/godot-native$" <<<"$out" && ok "  a check's own sub-stage (check-perf-judge-stage) alone doesn't" || bad "sub-stage" "$out"
out=$(printf '' | bash "$bc" --rows); [ "$(head -1 <<<"$out")" = 0 ] && ok "none running: 0" || bad "empty" "$out"
# Round 38 (R38.15): an ssh that fails (exit 255, the box off ZeroTier for a minute) is never "0 checks running". A fake ssh
# (BUILDER_CHECKS_SSH) fails its first $FAILS calls, then answers with no rows.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/ssh" <<'FAKE'
#!/usr/bin/env bash
n=$(cat "$FAKE_DIR/calls" 2>/dev/null || echo 0); echo $((n + 1)) > "$FAKE_DIR/calls"
[ "$n" -lt "$FAILS" ] && { echo "ssh: connect to host builder2: No route to host" >&2; exit 255; }
exit 0
FAKE
chmod +x "$tmp/ssh"
fake() { rm -f "$tmp/calls"; FAKE_DIR=$tmp FAILS=$1 BUILDER_CHECKS_SSH=$tmp/ssh BUILDER_CHECKS_POLL=0 "${@:2}"; }
out=$(fake 99 bash "$bc" 2>"$tmp/err"); status=$?
[ "$status" -ne 0 ] && [ -z "$out" ] && grep -q "cannot ask" "$tmp/err" && ok "ssh fails: no count, exit $status" \
	|| bad "plain mode on a failed ssh" "status $status, stdout '$out', stderr $(cat "$tmp/err")"
out=$(fake 2 bash "$bc" --wait-below 1 2>"$tmp/err"); status=$?
[ "$status" -eq 0 ] && [ "$(head -1 <<<"$out")" = 0 ] && [ "$(cat "$tmp/calls")" = 3 ] \
	&& ok "--wait-below retries a failed ssh (2 failures, then 0 running)" || bad "wait retry" "status $status, out '$out', calls $(cat "$tmp/calls")"
out=$(fake 99 env BUILDER_CHECKS_TRIES=3 bash "$bc" --wait-below 1 2>"$tmp/err"); status=$?
[ "$status" -ne 0 ] && [ -z "$out" ] && [ "$(cat "$tmp/calls")" = 3 ] && ok "--wait-below gives up after BUILDER_CHECKS_TRIES failed asks (exit $status)" \
	|| bad "wait give-up" "status $status, out '$out', calls $(cat "$tmp/calls")"
printf '\nbuilder-checks: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
