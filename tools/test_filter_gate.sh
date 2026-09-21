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

# ---- `make remote T=` is word-split, so it cannot carry metacharacters either ---------------------
# `T='ai-scenarios-record REASON=... (held > 3x chased)'` died on `syntax error near unexpected token ('`
# in the RECIPE's shell, before remote.sh ran. T must stay word-split (`T="test FILTER=combat"` is two
# arguments), so the answer is to refuse by name and say what to do instead.
rem() { ( cd "$repo" && TANK_SQUAD_SLOT=1 make --no-print-directory remote T="$1" 2>&1 ); }
for bad in 'x A=(b)' "x A=it's" 'x A=a;b' 'x A=a|b' 'x A=`id`' 'x A=$HOME' 'x A=a&b' 'x A=a"b'; do
	out=$(rem "$bad"); rc=$?
	[ "$rc" = 2 ] && grep -q "may not contain" <<<"$out" \
		|| bad "T is refused: $bad" "exit $rc: $(head -2 <<<"$out")"
done
ok "T containing ( ) ' \" ; & | \` or \$ is refused by name"
out=$(rem 'x A=(b)')
grep -q "tools/remote.sh <target>" <<<"$out" && ok "and the refusal says what to do instead" || bad "says what to do instead" "$out"
grep -q "word-split" <<<"$out" && ok "and why T cannot simply be quoted" || bad "says why" "$out"

# The ordinary form must still work, or this guard breaks every stream's launch.
out=$( cd "$repo" && TANK_SQUAD_SLOT=1 make -n --no-print-directory remote T="test FILTER=combat" 2>&1 )
grep -q "tools/remote.sh test FILTER=combat" <<<"$out" && ok "an ordinary T is unaffected and still splits" \
	|| bad "ordinary T unaffected" "$out"
out=$( cd "$repo" && TANK_SQUAD_SLOT=1 make -n --no-print-directory remote T="check" 2>&1 )
grep -q "tools/remote.sh check" <<<"$out" && ok "T=check is unaffected" || bad "T=check unaffected" "$out"

printf '\nfilter-gate: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
