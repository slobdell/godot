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
printf '\nbuilder-checks: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
