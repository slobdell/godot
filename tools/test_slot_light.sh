#!/usr/bin/env bash
# Known-answer tests for `tools/slot.sh`'s light lane (TANK_SQUAD_LIGHT=1; ship, round 17).
#
# The property: a one-process job no longer holds a check's slot. It queues in its own small pool, it cannot fan
# out (`--jobs` answers 1 inside it), the pool has its own limit, and it still yields to a quiet window. Against a
# private slot directory with `sleep` standing in for the work -- no Godot, a few seconds.
set -uo pipefail
unset TANK_SQUAD_SLOT TANK_SQUAD_EXCLUSIVE TANK_SQUAD_SLOTS TANK_SQUAD_SLOT_DIR TANK_SQUAD_SLOT_TIMEOUT \
	TANK_SQUAD_LIGHT TANK_SQUAD_LIGHT_SLOT TANK_SQUAD_LIGHT_SLOTS

slot="$(cd "$(dirname "$0")" && pwd)/slot.sh"
loaded="$(cd "$(dirname "$0")" && pwd)/loaded.sh"
pass=0; fail=0; notjudged=0; kids=()
tmp=$(mktemp -d)
cleanup() { local p; for p in ${kids[@]+"${kids[@]}"}; do pkill -TERM -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done; rm -rf "$tmp"; }
trap cleanup EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
fresh() { G="$tmp/slots"; rm -rf "$G"; mkdir -p "$G"; rm -f "$tmp"/flag.*; }
wait_for() { local i=0; while [ "$i" -lt "${2:-150}" ]; do eval "$1" && return 0; sleep 0.1; i=$((i + 1)); done; return 1; }
heavy_full() { [ "$(ls "$G"/slot*.owner 2>/dev/null | wc -l)" = 3 ]; }
light_owner() { [ -n "$(ls "$G"/light/slot*.owner 2>/dev/null)" ]; }

# ---- 1. a light run starts while every heavy slot is held ----------------------------------------
fresh
for i in 1 2 3; do TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 bash "$slot" sleep 15 >/dev/null 2>&1 & kids+=($!); done
wait_for heavy_full || bad "light: (setup) three heavy runs hold every slot"
timeout 4 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 TANK_SQUAD_LIGHT=1 bash '$slot' touch '$tmp/flag.light'" >/dev/null 2>&1
[ -e "$tmp/flag.light" ] && ok "light: starts while all three heavy slots are held" \
	|| bad "light: starts while all three heavy slots are held" "it queued behind the checks"

# ---- 2. and an ordinary run still queues behind them (the light lane is not a back door) ---------
timeout 2 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 bash '$slot' touch '$tmp/flag.heavy'" >/dev/null 2>&1
[ ! -e "$tmp/flag.heavy" ] && ok "light: a heavy run still waits for a heavy slot" \
	|| bad "light: a heavy run still waits for a heavy slot" "it started with every heavy slot held"

# ---- 2b. round 40: a dry run (make -n: MAKEFLAGS's first word holds n) takes no slot -------------
timeout 4 bash -c "MAKEFLAGS='n --no-print-directory' TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 bash '$slot' touch '$tmp/flag.dry'" >/dev/null 2>&1
[ -e "$tmp/flag.dry" ] && ok "dry run: make -n starts while every heavy slot is held" \
	|| bad "dry run: make -n starts while every heavy slot is held" "it queued for a slot"
timeout 2 bash -c "MAKEFLAGS='--no-print-directory -j4' TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 bash '$slot' touch '$tmp/flag.long'" >/dev/null 2>&1
[ ! -e "$tmp/flag.long" ] && ok "dry run: a long-option MAKEFLAGS (no n) still waits" \
	|| bad "dry run: a long-option MAKEFLAGS (no n) still waits" "--no-print-directory read as a dry run"

# ---- 2c. round 40 (R40.11): a REAL nested make through slot.sh under -n does not re-enter it -----
# The Makefile's own shape: a goal re-runs itself through slot.sh unless TANK_SQUAD_SLOT is set. 6538aa16a's slot.sh exec'd the
# dry run without setting it and recursed without bound (builder0's OOM). The fake recipe carries its own depth cap (past 4 it
# prints RECURSED and exits 3), so a regression fails this case and never runs away; `timeout 30` is the second fence.
cat > "$tmp/rec.mk" <<'MK'
ifeq ($(TANK_SQUAD_SLOT),)
probe:
	@d=$${REC_DEPTH:-0}; [ $$d -lt 4 ] || { echo RECURSED; exit 3; }; REC_DEPTH=$$((d + 1)) bash @SLOT@ $(MAKE) --no-print-directory -f @MK@ probe
else
probe:
	@echo inner-ran
endif
MK
sed -i "s|@SLOT@|$slot|; s|@MK@|$tmp/rec.mk|" "$tmp/rec.mk"
out=$(cd "$tmp" && TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 timeout 30 make -n --no-print-directory -f "$tmp/rec.mk" probe 2>&1); rc=$?
# -n prints the outer recipe line too (it names RECURSED), so the cap firing is a line that IS "RECURSED"; one inner level runs.
if [ "$rc" = 124 ]; then bad "dry run: a nested make runs inside the slot, no re-entry" "timed out after 30 s"
elif printf '%s\n' "$out" | grep -qx 'RECURSED' || printf '%s\n' "$out" | grep -q 'REFUSED: nested'; then
	bad "dry run: a nested make runs inside the slot, no re-entry" "it re-entered slot.sh (rc $rc)"
elif [ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -cx 'echo inner-ran')" = 1 ]; then
	ok "dry run: a nested make runs inside the slot, no re-entry"
else bad "dry run: a nested make runs inside the slot, no re-entry" "rc $rc: $out"; fi

# ---- 2d. round 40 (R40.11): the depth backstop refuses a fourth level with one line --------------
out=$(TANK_SQUAD_SLOT_DEPTH=3 TANK_SQUAD_SLOT=1 timeout 10 bash "$slot" touch "$tmp/flag.deep" 2>&1); rc=$?
[ "$rc" = 2 ] && [ ! -e "$tmp/flag.deep" ] && [ "$(printf '%s\n' "$out" | grep -c 'REFUSED: nested 4 deep')" = 1 ] \
	&& ok "depth: a fourth nested slot.sh exits 2 with one REFUSED line" || bad "depth: a fourth nested slot.sh exits 2 with one REFUSED line" "rc $rc: $out"
out=$(TANK_SQUAD_SLOT_DEPTH=2 TANK_SQUAD_SLOT=1 timeout 10 bash "$slot" touch "$tmp/flag.third" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -e "$tmp/flag.third" ] && ok "depth: a third level still runs" || bad "depth: a third level still runs" "rc $rc: $out"

# ---- 3. inside the light lane nothing fans out ---------------------------------------------------
fresh
out=$(TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_LIGHT=1 bash "$slot" bash "$slot" --jobs 10 12 2>/dev/null)
[ "$out" = 1 ] && ok "light: --jobs answers 1 inside a light slot" || bad "light: --jobs answers 1 inside a light slot" "got '$out'"

# ---- 4. the light pool has its own limit ---------------------------------------------------------
fresh
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_LIGHT=1 TANK_SQUAD_LIGHT_SLOTS=1 bash "$slot" sleep 5 >/dev/null 2>&1 & kids+=($!)
wait_for light_owner || bad "light: (setup) the first light run took the one light slot"
timeout 2 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_LIGHT=1 TANK_SQUAD_LIGHT_SLOTS=1 bash '$slot' touch '$tmp/flag.second'" >/dev/null 2>&1
[ ! -e "$tmp/flag.second" ] && ok "light: a second light run waits when the light pool is full" \
	|| bad "light: a second light run waits when the light pool is full" "it started anyway"

# ---- 5. a light run yields to a quiet window -----------------------------------------------------
fresh
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 TANK_SQUAD_SLOT_CEILING=3 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" sleep 5 >/dev/null 2>&1 & kids+=($!)
# Round 26: 30 s, not 15: on a loaded builder0 (load 15-18) the EXCLUSIVE holder can miss its first sweep and only
# retries after slot.sh's 5 s sleep; one check failed here with every game target green.
# Round 33 overnight (native, item 3): the window opening in time is wall-clock, and on a shared live box it failed twice
# ("the quiet window opened", then "it ran while EXCLUSIVE held the box", which follows from it). When it does not open
# and the box is loaded (1-minute load >= SLOT_LOADED_PER_CORE per physical core: tools/loaded.sh, round 38), case 5 is
# NOT JUDGED, as perf-judge refuses;
# on a quiet box it is a FAIL as before. Round 39 (N5): the line here is 1.0 per core, not the bounds' 1.5. This setup WAITS
# for quiet, it measures no bound, so a lower line costs no judging power (R38: orders' check FAILed it at 1.49 per core,
# the same red a solo re-run cleared at R38.18). The reason goes to $NOT_JUDGED_FILE when check's target names one.
if wait_for heavy_full 300; then
	timeout 2 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_LIGHT=1 bash '$slot' touch '$tmp/flag.during'" >/dev/null 2>&1
	[ ! -e "$tmp/flag.during" ] && ok "light: does not start inside a quiet window" \
		|| bad "light: does not start inside a quiet window" "it ran while EXCLUSIVE held the box"
else
	if box=$(bash "$loaded" "${SLOT_LOADED_PER_CORE:-1.0}"); then
		notjudged=$((notjudged + 1))
		why="slot-light case 5: the quiet window did not open in 30 s at $box"
		printf '  NOT JUDGED %s\n' "$why"
		[ -n "${NOT_JUDGED_FILE:-}" ] && echo "$why" >> "$NOT_JUDGED_FILE"
	else
		bad "light: (setup) the quiet window opened" "not in 30 s, at $box (a quiet box)"
	fi
fi

# ---- 6. light and exclusive together are refused, loudly -----------------------------------------
fresh
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_LIGHT=1 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" true >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "light: LIGHT + EXCLUSIVE exits 2" || bad "light: LIGHT + EXCLUSIVE exits 2" "exit $rc"

echo
echo "slot-light: $pass passed, $fail failed$([ "$notjudged" -gt 0 ] && echo ", $notjudged NOT JUDGED")"
[ "$fail" -eq 0 ]
