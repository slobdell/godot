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
pass=0; fail=0; kids=()
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
wait_for heavy_full || bad "light: (setup) the quiet window opened"
timeout 2 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_LIGHT=1 bash '$slot' touch '$tmp/flag.during'" >/dev/null 2>&1
[ ! -e "$tmp/flag.during" ] && ok "light: does not start inside a quiet window" \
	|| bad "light: does not start inside a quiet window" "it ran while EXCLUSIVE held the box"

# ---- 6. light and exclusive together are refused, loudly -----------------------------------------
fresh
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_LIGHT=1 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" true >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "light: LIGHT + EXCLUSIVE exits 2" || bad "light: LIGHT + EXCLUSIVE exits 2" "exit $rc"

echo
echo "slot-light: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
