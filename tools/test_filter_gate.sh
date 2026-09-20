#!/usr/bin/env bash
# Known-answer tests for `make test FILTER=...`.
#
# `make test FILTER="a|b"` handed the pipe to a shell and exited 127 without running either suite (combat,
# twice on 2026-09-20). The fix is not just quoting: the filter is a SUBSTRING, so a quoted "a|b" would have
# matched nothing and reported success, which is worse than the crash. So the runner takes `|` as
# alternation and fails a filter that matches nothing, and the one character single-quoting cannot carry is
# refused by name rather than silently becoming a different filter.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export TANK_SQUAD_SLOT=1
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# A stub that records the arguments it was handed and nothing else.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/argv"\nexit 0\n' "$tmp" > "$tmp/godot"
chmod +x "$tmp/godot"
run_test() { rm -f "$tmp/argv"; ( cd "$repo" && make --no-print-directory -o import test \
	GODOT="$tmp/godot" BUILD_DIR="$tmp/build" TEST_SHARDS=1 FILTER="$1" 2>&1 ); }

out=$(run_test 'a|b'); rc=$?
[ "$rc" = 0 ] && ok "a filter with a pipe runs at all (it used to exit 127)" || bad "pipe filter runs" "exit $rc: $out"
grep -qx -- '--filter=a|b' "$tmp/argv" 2>/dev/null && ok "the pipe reaches the runner as ONE argument" \
	|| bad "the pipe reaches the runner intact" "$(cat "$tmp/argv" 2>/dev/null)"

out=$(run_test 'needs space'); rc=$?
grep -qx -- '--filter=needs space' "$tmp/argv" 2>/dev/null && ok "a filter with a space survives" || bad "space survives" "$(cat "$tmp/argv" 2>/dev/null)"

out=$(run_test 'a`id`b'); rc=$?
grep -qx -- '--filter=a`id`b' "$tmp/argv" 2>/dev/null && ok "backticks are NOT expanded" \
	|| bad "backticks are not expanded" "$(cat "$tmp/argv" 2>/dev/null)"

# MAKE expands $ before any shell sees it, so it cannot be carried and is refused by name.
out=$(run_test '$HOME'); rc=$?
[ "$rc" = 2 ] && ok "a filter containing a dollar sign is refused (exit 2)" || bad "dollar refused" "exit $rc: $out"
grep -q 'MAKE expands it first' <<<"$out" && ok "and says it is make, not the shell, that ate it" || bad "says make ate it" "$out"

# The one character single-quoting cannot carry is refused BY NAME, and refused before Godot is reached.
out=$(run_test "it's"); rc=$?
[ "$rc" = 2 ] && ok "a filter containing a single quote is refused (exit 2)" || bad "single quote refused" "exit $rc: $out"
grep -q 'may not contain a single quote' <<<"$out" && ok "and says exactly which character" || bad "says which character" "$out"
[ ! -e "$tmp/argv" ] && ok "and refuses BEFORE running the checker" || bad "refuses before running the checker"

out=$(run_test ''); rc=$?
[ "$rc" = 0 ] && ok "an empty FILTER still runs the whole suite" || bad "empty FILTER runs" "exit $rc"
grep -qx -- '--filter=' "$tmp/argv" 2>/dev/null && ok "and passes an empty filter, not a missing one" \
	|| bad "passes an empty filter" "$(cat "$tmp/argv" 2>/dev/null)"

helpline=$( cd "$repo" && make help 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^[[:space:]]+test[[:space:]]' )
grep -q 'fails if it matches nothing' <<<"$helpline" && ok "the help line says what FILTER does" \
	|| bad "the help line says what FILTER does" "$helpline"

printf '\nfilter-gate: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
