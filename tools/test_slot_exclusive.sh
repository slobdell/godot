#!/usr/bin/env bash
# Known-answer tests for `tools/slot.sh`'s TANK_SQUAD_EXCLUSIVE mode -- the quiet window.
#
# A quiet window is only quiet if it is HELD. "Wait until the box looks idle, then launch" leaves a race the
# width of the whole run, and the measurement it produces is worthless in a way nobody can see afterwards
# (show's back-to-back pair once reported the instrumented arm 43% FASTER than its control, on a loaded box).
# So these pin the property that matters: while an exclusive run is up, nothing else can start.
#
# They run against a private slot directory with `sleep` standing in for the work -- no Godot, ~15 s.
set -uo pipefail

# ESCAPE THE SLOT WE ARE INSIDE. `slot.sh` short-circuits to `exec "$@"` when TANK_SQUAD_SLOT is set, which
# is correct -- a nested make must not queue behind itself -- but it means that run from inside `make check`,
# where slot.sh exported it, every test below would exercise nothing and six of them failed on builder0 while
# passing on an idle laptop. Unsetting it here affects only this script's children; the real slot stays held.
unset TANK_SQUAD_SLOT TANK_SQUAD_EXCLUSIVE TANK_SQUAD_SLOTS TANK_SQUAD_SLOT_DIR TANK_SQUAD_SLOT_TIMEOUT

slot="$(cd "$(dirname "$0")" && pwd)/slot.sh"
pass=0; fail=0; kids=()
tmp=$(mktemp -d)
cleanup() { local p; for p in ${kids[@]+"${kids[@]}"}; do kill "$p" 2>/dev/null; done; rm -rf "$tmp"; }
trap cleanup EXIT

ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

fresh() { G="$tmp/slots"; rm -rf "$G"; mkdir -p "$G"; rm -f "$tmp"/flag.*; }

# Poll for a condition instead of sleeping a guessed interval. builder0 runs this with four test shards and a
# fanned-out lint beside it, so "1.2 s is surely enough" is not a property of the code -- it is a property of
# an idle laptop, and it failed on the machine that matters.
wait_for() { local i=0; while [ "$i" -lt "${2:-150}" ]; do eval "$1" && return 0; sleep 0.1; i=$((i + 1)); done; return 1; }
window_up() { [ -n "$(ls "$G"/slot*.owner 2>/dev/null)" ]; }
window_full() { [ "$(ls "$G"/slot*.owner 2>/dev/null | wc -l)" = 3 ]; }
run_excl() { TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" "$@"; }
run_norm() { TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 bash "$slot" "$@"; }

# ---- 1. an exclusive run holds EVERY slot while it runs -------------------------------------------
fresh
run_excl bash -c "ls '$G'/slot*.owner 2>/dev/null | wc -l > '$tmp/n'" >/dev/null 2>&1
[ "$(cat "$tmp/n" 2>/dev/null)" = 3 ] && ok "exclusive: holds all 3 slots while running" \
	|| bad "exclusive: holds all 3 slots while running" "held $(cat "$tmp/n" 2>/dev/null)"

# ---- 2. and gives every one of them back ----------------------------------------------------------
[ -z "$(ls "$G"/slot*.owner 2>/dev/null)" ] && ok "exclusive: releases every slot afterwards" \
	|| bad "exclusive: releases every slot afterwards" "$(ls "$G"/slot*.owner 2>/dev/null)"

# ---- 3. the owner file says it is a quiet window, not an ordinary run ------------------------------
fresh
run_excl bash -c "cat '$G'/slot1.owner > '$tmp/owner'" >/dev/null 2>&1
grep -q "EXCLUSIVE (quiet window)" "$tmp/owner" 2>/dev/null && ok "exclusive: the owner file names the window" \
	|| bad "exclusive: the owner file names the window" "$(cat "$tmp/owner" 2>/dev/null)"

# ---- 4. THE PROPERTY THAT MATTERS: nothing else starts while it is up -------------------------------
fresh
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" sleep 8 >/dev/null 2>&1 &
kids+=($!)
wait_for window_full || bad "exclusive: (setup) the window opened within 15s"
timeout 2 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 bash '$slot' touch '$tmp/flag.intruder'" >/dev/null 2>&1
[ ! -e "$tmp/flag.intruder" ] && ok "exclusive: another run cannot start during the window" \
	|| bad "exclusive: another run cannot start during the window"
wait "${kids[-1]}" 2>/dev/null

# ---- 5. and the moment it ends, the box is usable again ---------------------------------------------
timeout 10 bash -c "TANK_SQUAD_SLOT_DIR='$G' TANK_SQUAD_SLOTS=3 bash '$slot' touch '$tmp/flag.after'" >/dev/null 2>&1
[ -e "$tmp/flag.after" ] && ok "exclusive: an ordinary run starts again once it ends" \
	|| bad "exclusive: an ordinary run starts again once it ends"

# ---- 6. it waits for a run already in flight rather than trampling it ---------------------------------
fresh
run_norm bash -c "sleep 3; touch '$tmp/flag.normal_done'" >/dev/null 2>&1 &
kids+=($!)
wait_for window_up || bad "exclusive: (setup) the ordinary run took a slot"
run_excl bash -c "[ -e '$tmp/flag.normal_done' ] && touch '$tmp/flag.waited'" >/dev/null 2>&1
[ -e "$tmp/flag.waited" ] && ok "exclusive: waits for a run already in flight" \
	|| bad "exclusive: waits for a run already in flight"

# ---- 7. the child inherits none of the lock fds -------------------------------------------------------
# A background server left by the command would otherwise hold the WHOLE box, not one slot of it.
fresh
run_excl bash -c "ls -l /proc/self/fd 2>/dev/null | grep -c 'slot[0-9]*\.lock' > '$tmp/fds'" >/dev/null 2>&1
[ "$(cat "$tmp/fds" 2>/dev/null)" = 0 ] && ok "exclusive: the command holds none of the lock fds" \
	|| bad "exclusive: the command holds none of the lock fds" "$(cat "$tmp/fds" 2>/dev/null) inherited"

# ---- 8. a signalled window releases every slot ---------------------------------------------------------
# The same trap discipline as the single-slot path: a handler that falls through does not stop the script,
# and a slot whose owner file outlives it lies to every waiter.
fresh
# NOT `run_excl ... &`: backgrounding a shell FUNCTION with redirections forks a subshell, so $! would be
# the subshell and the signal would never reach slot.sh at all -- the test would pass or fail for the wrong
# reason. Run it as a simple command so $! is the script itself, which is also the pid remote_builds.md
# tells you to kill ("the slot.sh wrapper, not the make inside it").
rm -f "$tmp/workpid"
TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=3 TANK_SQUAD_EXCLUSIVE=1 bash "$slot" \
	bash -c "echo \$\$ > '$tmp/workpid'; exec sleep 30" >/dev/null 2>&1 &
excl_pid=$!; kids+=("$excl_pid")
wait_for window_full || bad "exclusive: (setup) the window was up" "no owner files after 15s"
kill -TERM "$excl_pid" 2>/dev/null
wait_for '! window_up' 100
[ -z "$(ls "$G"/slot*.owner 2>/dev/null)" ] && ok "exclusive: a signalled window releases every slot" \
	|| bad "exclusive: a signalled window releases every slot" "left $(ls "$G"/slot*.owner 2>/dev/null)"
# And the work itself must be gone. A slot given back while its Godot still runs is the WORSE half of this
# bug: the box looks free and is not (lesson 15 -- the remote run kept executing after its wrapper died).
# By ITS OWN pid, not by command name: several runs of this file share the name `sleep`, and a leftover
# from an earlier run would answer for this one -- the `pgrep -f` phantom in a different coat.
work=$(cat "$tmp/workpid" 2>/dev/null)
if [ -n "$work" ] && kill -0 "$work" 2>/dev/null; then
	bad "exclusive: a signalled window kills the work it was running" "pid $work still alive"
	kill "$work" 2>/dev/null
else
	ok "exclusive: a signalled window kills the work it was running"
fi

# ---- 9. the exit status is the command's ----------------------------------------------------------------
fresh
run_excl bash -c "exit 7" >/dev/null 2>&1
[ $? = 7 ] && ok "exclusive: the command's exit status is returned" || bad "exclusive: the command's exit status is returned"

# ---- 10. an ordinary run is unchanged -------------------------------------------------------------------
# The single-slot path is what every other stream uses all day; the exclusive branch must not touch it.
fresh
run_norm bash -c "ls '$G'/slot*.owner 2>/dev/null | wc -l > '$tmp/n1'" >/dev/null 2>&1
[ "$(cat "$tmp/n1" 2>/dev/null)" = 1 ] && ok "ordinary run: still takes exactly one slot" \
	|| bad "ordinary run: still takes exactly one slot" "took $(cat "$tmp/n1" 2>/dev/null)"
[ -z "$(ls "$G"/slot*.owner 2>/dev/null)" ] && ok "ordinary run: still releases it" || bad "ordinary run: still releases it"

printf '\nslot-exclusive: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
