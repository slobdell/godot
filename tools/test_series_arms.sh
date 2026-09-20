#!/usr/bin/env bash
# `faction-matrix`'s output name must carry the ARM, or a two-run series overwrites itself.
#
# `-tuned` was the suffix for ANY value of TUNE, so control-then-treatment wrote one file, the second
# overwrote the first, and `compare-arms` compared a file with itself: every cell zero, a perfect null,
# nothing saying so. A null that looks like a measurement is the one kind of bug that running more of them
# cannot catch, because every extra run reproduces it.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
name() { ( cd "$repo" && make -n faction-matrix "$@" 2>/dev/null | grep -oE '\-\-json [^ ]+' | head -1 | cut -d' ' -f2 ); }

control=$(name)
treatment=$(name TUNE=switch.cost=1)
other=$(name TUNE=switch.price=0)
[ -n "$control" ] && ok "the control arm has a name" || bad "the control arm has a name"
[ "$control" != "$treatment" ] && ok "control and treatment DIFFER (the bug: they did not)" \
	|| bad "control and treatment differ" "both $control"
[ "$treatment" != "$other" ] && ok "two different TUNE specs differ from each other" \
	|| bad "two TUNE specs differ" "both $treatment"
grep -q 'switch.cost' <<<"$treatment" && ok "the name carries the TUNE spec, not just 'tuned'" \
	|| bad "the name carries the spec" "$treatment"

# A filename must stay a filename -- tested on the BASENAME, since the path itself contains `build/`.
case "${treatment##*/}" in *[' ,/=']*) bad "the slug is filesystem-safe" "$treatment";; *) ok "the slug is filesystem-safe";; esac
multi=$(name TUNE=a=1,b=2)
case "${multi##*/}" in *[' ,/=']*) bad "a multi-key TUNE is sanitised" "$multi";; *) ok "a multi-key TUNE is sanitised";; esac
[ "$multi" != "$treatment" ] && ok "a multi-key TUNE is still distinct" || bad "multi-key TUNE distinct"

labelled=$(name OUT=a4on TUNE=switch.cost=1)
grep -q '/a4on.json$' <<<"$labelled" && ok "OUT=<label> names the arm outright" || bad "OUT names the arm" "$labelled"
[ "$labelled" != "$(name OUT=a4off TUNE=switch.cost=1)" ] && ok "two OUT labels differ" || bad "two OUT labels differ"

# ARENA and ABLATE must still compose, or this fix breaks the existing series.
a=$(name ARENA=pit); b=$(name ARENA=yard)
[ "$a" != "$b" ] && [ "$a" != "$control" ] && ok "ARENA still varies the name" || bad "ARENA still varies the name" "$a vs $b"
p=$(name ABLATE=1)
[ "$p" != "$control" ] && grep -q 'plainroles' <<<"$p" && ok "ABLATE still varies the name" || bad "ABLATE still varies the name" "$p"
both=$(name ARENA=pit TUNE=switch.cost=1)
[ "$both" != "$a" ] && [ "$both" != "$treatment" ] && ok "ARENA and TUNE compose" || bad "ARENA and TUNE compose" "$both"

printf '\nseries-arms: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
