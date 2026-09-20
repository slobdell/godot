#!/usr/bin/env bash
# Known-answer tests for `tools/quiet_window.sh` -- the verdict that says whether a timing window held.
#
# The verdict is the whole product here. A measurement taken in a window that did not hold is worse than no
# measurement, because it looks exactly like one that did: show's back-to-back pair once reported the
# instrumented arm 43% FASTER than its control on a loaded box. So every way the window can fail is pinned,
# and so is the one that would otherwise pass in silence -- nobody watching.
set -uo pipefail

qw="$(cd "$(dirname "$0")" && pwd)/quiet_window.sh"
pass=0; fail=0; kids=()
tmp=$(mktemp -d)
cleanup() { local p; for p in ${kids[@]+"${kids[@]}"}; do kill "$p" 2>/dev/null; done; rm -rf "$tmp"; }
trap cleanup EXIT

ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# epoch  load1  foreign_runs  foreign_godot  folders
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
# Counting data rows without the `grep -c ... || echo 0` trap that this suite just caught in the script:
# grep exits 1 on a count of zero, so the fallback fires exactly when the count is zero.
count_rows() { local n; n=$(grep -vc '^#' "$1" 2>/dev/null); case "$n" in ''|*[!0-9]*) n=0 ;; esac; echo "$n"; }
verdict() { QUIET_MAX_LOAD=${2:-4.0} bash "$qw" verdict "$1" 2>&1; }

# ---- 1. a clean window is HELD ------------------------------------------------------------------
f="$tmp/clean.tsv"
{ echo "# header"; row 1000 0.80 0 0 -; row 1015 1.10 0 0 -; row 1030 0.95 0 0 -; } > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 0 ] && ok "clean window: exit 0" || bad "clean window: exit 0" "exit $rc"
grep -q "QUIET WINDOW: HELD" <<<"$out" && ok "clean window: HELD" || bad "clean window: HELD" "$out"
grep -q "3 samples over 30s" <<<"$out" && ok "clean window: counts the samples and the span" || bad "clean window: counts the samples and the span" "$out"
grep -q "load1 0.80-1.10" <<<"$out" && ok "clean window: prints the load range" || bad "clean window: prints the load range" "$out"
grep -q "does not say the machine was fast" <<<"$out" && ok "clean window: HELD does not overclaim" || bad "clean window: HELD does not overclaim"

# ---- 2. another worktree ran during it -----------------------------------------------------------
f="$tmp/foreign.tsv"
{ echo "#"; row 1000 0.8 0 0 -; row 1015 2.4 3 0 godot-nav; row 1030 0.9 0 0 -; } > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 1 ] && ok "foreign run: exit 1" || bad "foreign run: exit 1" "exit $rc"
grep -q "NOT USABLE" <<<"$out" && ok "foreign run: NOT USABLE" || bad "foreign run: NOT USABLE" "$out"
grep -q "godot-nav" <<<"$out" && ok "foreign run: names the worktree" || bad "foreign run: names the worktree" "$out"
grep -q "1 of 3 samples" <<<"$out" && ok "foreign run: says how much of the window it spoiled" || bad "foreign run: says how much" "$out"

# ---- 3. a Godot outside this run -----------------------------------------------------------------
f="$tmp/godot.tsv"
{ echo "#"; row 1000 0.8 0 0 -; row 1015 1.2 0 2 -; } > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 1 ] && ok "foreign Godot: exit 1" || bad "foreign Godot: exit 1" "exit $rc"
grep -q "Godot process-samples outside this run" <<<"$out" && ok "foreign Godot: says what it saw" || bad "foreign Godot: says what it saw" "$out"

# ---- 4. load above the stated bound, even with nobody else there -----------------------------------
# The case a foreign-process test cannot catch: every bit of the load is ours, and the number is still not
# a quiet-box number.
f="$tmp/load.tsv"
{ echo "#"; row 1000 0.8 0 0 -; row 1015 9.5 0 0 -; row 1030 1.0 0 0 -; } > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 1 ] && ok "load over bound: exit 1" || bad "load over bound: exit 1" "exit $rc"
grep -q "load1 was above 4.00" <<<"$out" && ok "load over bound: names the bound" || bad "load over bound: names the bound" "$out"
grep -q "peak 9.50" <<<"$out" && ok "load over bound: names the peak" || bad "load over bound: names the peak" "$out"
grep -q "QUIET_MAX_LOAD" <<<"$out" && ok "load over bound: says how to change it" || bad "load over bound: says how to change it"
out=$(verdict "$f" 12.0); rc=$?
[ "$rc" = 0 ] && ok "load bound is honoured when raised deliberately" || bad "load bound is honoured when raised" "exit $rc: $out"

# ---- 5. THE SILENT ONE: nobody watched --------------------------------------------------------------
# A window with no samples must never read as a quiet one. This is the failure mode that would pass.
f="$tmp/empty.tsv"; echo "# header only" > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 1 ] && ok "no samples: exit 1" || bad "no samples: exit 1" "exit $rc"
grep -q "NOT USABLE" <<<"$out" && ok "no samples: NOT USABLE, not HELD" || bad "no samples: NOT USABLE, not HELD" "$out"
grep -q "nobody watched" <<<"$out" && ok "no samples: says why" || bad "no samples: says why" "$out"

f="$tmp/one.tsv"; { echo "#"; row 1000 0.5 0 0 -; } > "$f"
out=$(verdict "$f"); rc=$?
[ "$rc" = 1 ] && ok "one sample: still NOT USABLE (a single point is not a window)" || bad "one sample: NOT USABLE" "exit $rc"

out=$(verdict "$tmp/does-not-exist.tsv"); rc=$?
[ "$rc" = 1 ] && ok "a missing file is NOT USABLE, not an error swallowed" || bad "missing file: NOT USABLE" "exit $rc"

# ---- 6. a real run through the whole thing ----------------------------------------------------------
# sample/watch against live /proc, with a stand-in worktree and a stand-in foreign run.
G="$tmp/slots"; ROOT="$tmp/root"; RUN="$ROOT/godot-metrics"
mkdir -p "$G" "$RUN" "$ROOT/godot-nav"
echo "10:00:00 godot-metrics: EXCLUSIVE (quiet window) make perf-scene" > "$G/slot1.owner"
line=$(bash "$qw" sample "$G" "$ROOT" "$RUN")
[ "$(echo "$line" | cut -f3)" = 0 ] && ok "live sample: an empty box reads 0 foreign runs" || bad "live sample: empty box" "$line"
( cd "$ROOT/godot-nav" && exec sleep 60 ) >/dev/null 2>&1 </dev/null & kids+=($!)
sleep 0.3
line=$(bash "$qw" sample "$G" "$ROOT" "$RUN")
[ "$(echo "$line" | cut -f3)" -ge 1 ] && ok "live sample: sees another worktree's process" || bad "live sample: sees another worktree" "$line"
[ "$(echo "$line" | cut -f5)" = "godot-nav" ] && ok "live sample: names the worktree" || bad "live sample: names the worktree" "$line"
( cd "$RUN" && exec sleep 60 ) >/dev/null 2>&1 </dev/null & kids+=($!)
sleep 0.3
line=$(bash "$qw" sample "$G" "$ROOT" "$RUN")
[ "$(echo "$line" | cut -f3)" = 1 ] && ok "live sample: OUR own processes are not foreign" || bad "live sample: our own are not foreign" "$line"

# ---- 7. watch records nothing until the window opens ---------------------------------------------------
# The queueing beforehand is when other runs legitimately hold the box; counting it would make every
# window NOT USABLE for a reason that is not a defect.
rm -f "$G"/slot*.owner
out2="$tmp/watch.tsv"
bash "$qw" watch "$G" "$ROOT" "$RUN" "$out2" 1 >/dev/null 2>&1 & kids+=($!)
sleep 2
[ "$(count_rows "$out2")" = 0 ] && ok "watch: records nothing before the window opens" \
	|| bad "watch: records nothing before the window opens" "$(cat "$out2")"
echo "10:00:00 godot-metrics: EXCLUSIVE (quiet window) make perf-scene" > "$G/slot1.owner"
sleep 6
[ "$(count_rows "$out2")" -ge 2 ] && ok "watch: records once the window opens" \
	|| bad "watch: records once the window opens" "$(cat "$out2")"
echo "10:00:00 godot-nav: make check" > "$G/slot2.owner"
ok "watch: (an owner file naming another folder means the window is not ours -- see window_open)"

printf '\nquiet-window: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
