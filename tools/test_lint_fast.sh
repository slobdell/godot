#!/usr/bin/env bash
# Known answers for tools/lint_fast.py (round 41 native N5): engine output in the shape builder0 printed (2026-10-26) -> verdict.
set -uo pipefail
lf="$(cd "$(dirname "$0")" && pwd)/lint_fast.py"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
P=build/lint-fast-selftest/broken.gd,build/lint-fast-selftest/uses_broken.gd,build/lint-fast-selftest/typeerr.gd

planted() { cat <<'LOG'
SCRIPT ERROR: Parse Error: Expected expression for variable initial value after "=".
          at: GDScript::reload (res://build/lint-fast-selftest/broken.gd:4)
          GDScript backtrace (most recent call first):
              [0] _init (res://tests/lint/lint_fast.gd:30)
ERROR: Failed to load script "res://build/lint-fast-selftest/broken.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
SCRIPT ERROR: Parse Error: Could not resolve script "res://build/lint-fast-selftest/broken.gd".
          at: GDScript::reload (res://build/lint-fast-selftest/uses_broken.gd:3)
LINT_FAST_NOLOAD build/lint-fast-selftest/uses_broken.gd
SCRIPT ERROR: Parse Error: Cannot assign a value of type "String" as "int".
          at: GDScript::reload (res://build/lint-fast-selftest/typeerr.gd:4)
LOG
}
{ echo "Godot Engine v4.7.2.stable.official"; planted; echo "LINT_FAST_DONE files=1215 ms=13900"; } > "$tmp/clean.log"
out=$(python3 "$lf" "$tmp/clean.log" --files 1215 --selftest "$P" --out "$tmp/f" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "a clean tree with every planted error seen: exit 0" || bad "clean: exit 0" "exit $rc: $out"
grep -q "all 1215 scripts load in one process (13.9 s, 3 planted errors seen)" <<<"$out" && ok "clean: the summary line" || bad "clean: summary" "$out"
[ ! -s "$tmp/f" ] && ok "clean: the planted errors are not the tree's findings" || bad "clean: findings file empty" "$(cat "$tmp/f")"

{ planted; printf 'SCRIPT ERROR: Parse Error: Identifier "foo" not declared in the current scope.\n          at: GDScript::reload (res://game/ai/movement.gd:528)\n'; echo "LINT_FAST_DONE files=1215 ms=14000"; } > "$tmp/real.log"
out=$(python3 "$lf" "$tmp/real.log" --files 1215 --selftest "$P" --out "$tmp/f" 2>&1); rc=$?
[ "$rc" = 1 ] && ok "a real parse error in the tree: exit 1" || bad "real: exit 1" "exit $rc: $out"
grep -q 'game/ai/movement.gd:528: SCRIPT ERROR: Parse Error: Identifier "foo"' "$tmp/f" && ok "real: named with file:line" || bad "real: file:line" "$(cat "$tmp/f")"

{ planted; echo 'SCRIPT ERROR: something with no location'; echo "LINT_FAST_DONE files=1215 ms=14000"; } > "$tmp/unat.log"
out=$(python3 "$lf" "$tmp/unat.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q '?:0: SCRIPT ERROR: something' <<<"$out" && ok "an error with no file: a finding, never dropped" || bad "unattributed" "exit $rc: $out"

{ planted; echo 'LINT_FAST_NOLOAD game/x.gd'; echo "LINT_FAST_DONE files=1215 ms=14000"; } > "$tmp/nl.log"
out=$(python3 "$lf" "$tmp/nl.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q 'game/x.gd:0: did not load' <<<"$out" && ok "a file that did not load, silently: a finding" || bad "noload" "exit $rc: $out"

{ planted; printf 'ERROR: res://game/tank/tank.tscn:12 - Parse Error: [ext_resource] referenced non-existent resource at: res://x.gd.\n'; echo "LINT_FAST_DONE files=1215 ms=14000"; } > "$tmp/inl.log"
out=$(python3 "$lf" "$tmp/inl.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q 'game/tank/tank.tscn:12: Parse Error: \[ext_resource\]' <<<"$out" && ok "an ERROR: line carrying its own res:// Parse Error" || bad "inline" "exit $rc: $out"

{ echo "LINT_FAST_DONE files=1215 ms=14000"; } > "$tmp/blind.log"
out=$(python3 "$lf" "$tmp/blind.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q "NOT reported" <<<"$out" && ok "planted errors unseen: FAILED, not a clean tree" || bad "blind" "exit $rc: $out"

planted > "$tmp/killed.log"
out=$(python3 "$lf" "$tmp/killed.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q "never finished" <<<"$out" && ok "no LINT_FAST_DONE (killed): FAILED, says nothing" || bad "killed" "exit $rc: $out"

{ planted; echo "LINT_FAST_DONE files=12 ms=100"; } > "$tmp/short.log"
out=$(python3 "$lf" "$tmp/short.log" --files 1215 --selftest "$P" 2>&1); rc=$?
[ "$rc" = 1 ] && grep -q "counted 12 files, the list had 1215" <<<"$out" && ok "a short count: FAILED" || bad "short" "exit $rc: $out"

grep -q '_cp-$(t): | _cp-lint-fast' "$(dirname "$lf")/../mk/core.mk" && grep -q '^CHECK_TARGETS := lint-fast lint test' "$(dirname "$lf")/../mk/core.mk" \
	&& ok "core.mk: lint-fast gates every other check target; lint stays in check" || bad "core.mk wiring"

printf '\nlint-fast: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
