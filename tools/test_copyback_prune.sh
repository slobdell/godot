#!/usr/bin/env bash
# Known-answer tests for the copy-back's stale-log move (round 35, X5 (b)). The copy-back's `P *.log` keeps every local log,
# so an earlier run's series rows (manoeuvre-hull-rest's <task>-<seed>/run.log after the box cleared that arm) stayed beside
# this run's and a reader pooled both (brains' Bar E1 / E2 series). They are MOVED, not deleted: one may be filed evidence.
set -uo pipefail
cp="$(cd "$(dirname "$0")" && pwd)/copyback_prune.sh"
pass=0; fail=0
tmp=$(mktemp -d); trap 'exec 9>&-; rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# What the box sent this run: the arm new_drawn with seeds 801-802 (run.log + screen.json each), the arm base_drawn kept from
# an earlier call (still on the box, so in the manifest), and build/metrics/a.jsonl.
R="$tmp/root"; H="build/manoeuvre/hull-rest"
for d in new_drawn/gangs/move-801 new_drawn/gangs/move-802 base_drawn/gangs/move-601; do
	mkdir -p "$R/$H/$d"; printf 'run\n' > "$R/$H/$d/run.log"; printf '{}\n' > "$R/$H/$d/screen.json"
done
mkdir -p "$R/build/metrics"; printf 'm\n' > "$R/build/metrics/a.jsonl"
( cd "$R" && find build -type f | sort | xargs sha256sum > "$tmp/manifest" )
# What only this side still has (the box cleared new_drawn before this run; the copy-back deleted their screen.json but
# `P *.log` kept their run.log): seeds 601-602 in the arm this run wrote.
for d in new_drawn/gangs/move-601 new_drawn/gangs/move-602; do mkdir -p "$R/$H/$d"; printf 'earlier\n' > "$R/$H/$d/run.log"; done
printf 'earlier\n' > "$R/$H/new_drawn/gangs/notes.txt"
# Wrapper logs (the documented `> build/metrics/x.log` and `> build/x.log`), a local measurement in a folder the box never
# had, a protected path, and a wrapper log still being written inside the series folder itself (held open on fd 9).
printf 'w\n' > "$R/build/metrics/wrapper.log"; printf 'w\n' > "$R/build/wrapper.log"
mkdir -p "$R/build/local-only" "$R/build/look-parity/x"; printf 'l\n' > "$R/build/local-only/m.log"; printf 'p\n' > "$R/build/look-parity/x/p.log"
exec 9>"$R/$H/new_drawn/gangs/wrapper-now.log"

out=$(REMOTE_COPYBACK_PROTECT="look-parity/" bash "$cp" "$R" "$tmp/manifest" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "exit 0" || bad "exit 0" "exit $rc: $out"
stale=$(find "$R/build" -maxdepth 1 -type d -name '.stale-*' | head -1)
[ -n "$stale" ] && ok "a build/.stale-<timestamp>/ folder (outside every series root)" || bad "a build/.stale-<timestamp>/ folder" "$out"
[ -z "$(find "$R/$H" -name '.stale-*')" ] && ok "nothing dotted inside the series (os.listdir readers count folders)" \
	|| bad "nothing dotted inside the series"
[ ! -e "$R/$H/new_drawn/gangs/move-601/run.log" ] && [ -f "$stale/manoeuvre/hull-rest/new_drawn/gangs/move-601/run.log" ] \
	&& [ -f "$stale/manoeuvre/hull-rest/new_drawn/gangs/move-602/run.log" ] \
	&& ok "an earlier run's rows: moved, with their relative path" || bad "an earlier run's rows: moved" "$out"
[ "$(cat "$stale/manoeuvre/hull-rest/new_drawn/gangs/move-601/run.log" 2>/dev/null)" = earlier ] && ok "moved, not rewritten" || bad "moved, not rewritten"
[ ! -e "$R/$H/new_drawn/gangs/move-601" ] && ok "the emptied run folder is gone (a reader counts folders)" \
	|| bad "the emptied run folder is gone"
grep -q "move-601/run.log" <<<"$out" && grep -q "moved 2 " <<<"$out" && ok "the count and the files are printed" \
	|| bad "the count and the files are printed" "$out"
[ -f "$R/$H/new_drawn/gangs/move-801/run.log" ] && [ -f "$R/$H/base_drawn/gangs/move-601/run.log" ] \
	&& ok "this run's rows and the box's kept arm: untouched" || bad "this run's rows and the box's kept arm: untouched"
[ -e "$R/$H/new_drawn/gangs/wrapper-now.log" ] && ok "a log a process still has open: kept" || bad "a log a process still has open: kept"
[ -e "$R/build/metrics/wrapper.log" ] && [ -e "$R/build/wrapper.log" ] && ok "wrapper logs in build/ and build/metrics/: kept" \
	|| bad "wrapper logs in build/ and build/metrics/: kept"
[ -e "$R/build/local-only/m.log" ] && ok "a folder the box never had: kept" || bad "a folder the box never had: kept"
[ -e "$R/build/look-parity/x/p.log" ] && ok "REMOTE_COPYBACK_PROTECT: kept" || bad "REMOTE_COPYBACK_PROTECT: kept"
[ -e "$R/$H/new_drawn/gangs/notes.txt" ] && ok "not a log: kept" || bad "not a log: kept"

# A second pass: nothing left to move, silent; the .stale folder is not moved into itself.
out=$(REMOTE_COPYBACK_PROTECT="look-parity/" bash "$cp" "$R" "$tmp/manifest" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "second pass: silent, exit 0" || bad "second pass: silent, exit 0" "exit $rc: $out"

# No manifest (an older checkout on the box writes none): move nothing, say so, never fail the run.
mkdir -p "$R/$H/new_drawn/gangs/move-603"; printf 'earlier\n' > "$R/$H/new_drawn/gangs/move-603/run.log"
out=$(bash "$cp" "$R" "$tmp/no-such-manifest" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -e "$R/$H/new_drawn/gangs/move-603/run.log" ] && ok "no manifest: nothing moved, exit 0" \
	|| bad "no manifest: nothing moved, exit 0" "exit $rc"
grep -q "NOT CHECKED" <<<"$out" && ok "no manifest: says NOT CHECKED" || bad "no manifest: says NOT CHECKED" "$out"

# The light lane: the root is build/light and the manifest's paths start build/ under it.
L="$tmp/light"; mkdir -p "$L/build/fights" ; printf 'n\n' > "$L/build/fights/locks-9.log"
( cd "$L" && sha256sum build/fights/locks-9.log > "$tmp/manifest-l" ); printf 'o\n' > "$L/build/fights/locks-1.log"
bash "$cp" "$L" "$tmp/manifest-l" >/dev/null 2>&1
[ ! -e "$L/build/fights/locks-1.log" ] && [ -n "$(find "$L/build" -path '*/.stale-*/fights/locks-1.log')" ] \
	&& ok "a log beside this run's in the same folder: moved" || bad "a log beside this run's in the same folder: moved"

# A path with a space survives the trip through the manifest.
S="$tmp/sp"; mkdir -p "$S/build/two words"; printf 'n\n' > "$S/build/two words/a.log"
( cd "$S" && sha256sum "build/two words/a.log" > "$tmp/manifest-s" ); printf 'o\n' > "$S/build/two words/b.log"
bash "$cp" "$S" "$tmp/manifest-s" >/dev/null 2>&1
[ -e "$S/build/two words/a.log" ] && [ ! -e "$S/build/two words/b.log" ] && ok "a folder name with a space" \
	|| bad "a folder name with a space"

echo "copyback-prune: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
