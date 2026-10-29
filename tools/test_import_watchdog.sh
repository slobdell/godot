#!/usr/bin/env bash
# Known-answer tests for tools/import_watchdog.sh (round 45, native N1) and its seam in tools/slot.sh.
#
# The property: an import whose progress line stops changing is killed, .godot/ is cleared and it is imported once more; a
# second hang ends with `>> remote: import hung on <file>` (exit 75) and the command never runs. An import that makes
# progress, however slowly, is left alone. Fake imports (IMPORT_WATCH_CMD) in a scratch folder stand in for Godot: they
# print Godot's own progress lines, the hang the same line forever as builder2's did (2026-10-28). No Godot, ~25 s.
set -uo pipefail
unset TANK_SQUAD_SLOT TANK_SQUAD_EXCLUSIVE TANK_SQUAD_SLOTS TANK_SQUAD_SLOT_DIR TANK_SQUAD_SLOT_TIMEOUT \
	TANK_SQUAD_LIGHT TANK_SQUAD_LIGHT_SLOT TANK_SQUAD_LIGHT_SLOTS TANK_SQUAD_IMPORT_WATCH IMPORT_WATCH_CMD IMPORT_WATCH_LOG \
	TANK_SQUAD_SLOT_DEPTH

tools="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
tmp=$(mktemp -d)
# Only the fakes, by the unique mktemp path they carry in argv[0] (never a name pattern: worker contract rule 7).
trap 'pgrep -f "$tmp/fake-" | xargs -r kill -KILL 2>/dev/null; rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# A scratch "project" with a warm cache to clear, and the watchdog where slot.sh looks for it (tools/ under $PWD).
fresh() {
	P="$tmp/proj"; rm -rf "$P"; mkdir -p "$P/tools" "$P/.godot"
	cp "$tools/import_watchdog.sh" "$P/tools/"
	echo warm > "$P/.godot/marker"
}
# Fakes. HANG prints Godot's hung line every 0.1 s forever (tagged with $tmp so the cleanup and the orphan check find it).
HANG="exec -a '$tmp/fake-hang' bash -c 'printf \"[   0%% ] \\033[90mreimport\\033[0m | Oswald-Latin.ttf\\n\"; while :; do printf \"[   0%% ] reimport | Oswald-Latin.ttf\\n\"; sleep 0.1; done'"
GOOD="printf '[   0%% ] first_scan_filesystem | Started\n[  50%% ] reimport | a.png\n[ DONE ] reimport\n'"
SILENT="exec -a '$tmp/fake-silent' sleep 600"
# Hangs while the warm cache is there, imports once it is cleared: the case the retry exists for.
ONCE="if [ -e .godot/marker ]; then $HANG; else $GOOD; fi"
# Honest but slow: a NEW line every 0.6 s for ~3 s, under a 3 s stall limit (date +%s is whole seconds).
SLOW="for f in a b c d e; do printf '[ %d0%% ] reimport | %s.glb\n' \$RANDOM \$f; sleep 0.6; done"
run() {   # run <cmd> <then...>: the watchdog in $P, stall limit $STALL (1 s)
	local cmd=$1; shift
	(cd "$P" && IMPORT_WATCH_STALL=${STALL:-1} IMPORT_WATCH_POLL=0.2 IMPORT_WATCH_CMD="$cmd" timeout 40 bash tools/import_watchdog.sh --then "$@") \
		> "$tmp/out" 2>&1
	echo $?
}

# ---- 1. an import that finishes: the command runs, its status is the run's ----------------------
fresh
st=$(run "$GOOD" bash -c 'touch ran; exit 7')
[ "$st" = 7 ] && [ -e "$P/ran" ] && [ -e "$P/.godot/marker" ] && ok "a finished import runs the command (status 7 passed through, cache kept)" \
	|| bad "a finished import runs the command" "status $st; $(cat "$tmp/out")"
grep -q "a.png" "$P/build/import-watch.log" && [ -e "$P/build/.gdignore" ] && ok "the import's output is in build/import-watch.log; build/.gdignore written" \
	|| bad "the import's output is in build/import-watch.log" "$(ls -la "$P/build" 2>&1)"

# ---- 2. the staged hang, twice: one clear line, exit 75, the command never runs, no orphan -------
fresh
t0=$(date +%s)
st=$(run "$HANG" touch ran)
el=$(( $(date +%s) - t0 ))
[ "$st" = 75 ] && ok "a double hang exits 75" || bad "a double hang exits 75" "status $st; $(tail -5 "$tmp/out")"
grep -q '^>> remote: import hung on Oswald-Latin.ttf ' "$tmp/out" && ok "it says '>> remote: import hung on Oswald-Latin.ttf'" \
	|| bad "it says '>> remote: import hung on Oswald-Latin.ttf'" "$(tail -3 "$tmp/out")"
[ ! -e "$P/ran" ] && ok "the command did not run after the double hang" || bad "the command did not run after the double hang"
[ ! -e "$P/.godot/marker" ] && ok ".godot/ was cleared before the retry" || bad ".godot/ was cleared before the retry"
[ "$(grep -c 'no progress for' "$tmp/out")" = 2 ] && ok "two attempts, each named (kill, clear, retry; then the verdict)" \
	|| bad "two attempts, each named" "$(cat "$tmp/out")"
[ "$el" -lt 20 ] && ok "caught at the limit, not at a timeout ($el s for two 1 s stalls)" || bad "caught at the limit" "$el s"
sleep 0.3
pgrep -f "$tmp/fake-hang" >/dev/null && bad "no hung import is left running" "$(pgrep -af "$tmp/fake-hang")" || ok "no hung import is left running"
[ -s "$P/build/import-watch.log.hung1" ] && [ -s "$P/build/import-watch.log.hung2" ] && ok "both hung logs are kept" \
	|| bad "both hung logs are kept"

grep -q '^>> remote: import hung on Oswald-Latin.ttf ' "$P/build/import-watch.verdict" 2>/dev/null \
	&& ok "the verdict line is in build/import-watch.verdict (remote.sh ends on it, exit 75)" || bad "the verdict line is in build/import-watch.verdict"

# ---- 3. a hang that clears with the cache: the retry imports and the command runs ----------------
fresh
st=$(run "$ONCE" bash -c 'touch ran; exit 0')
[ "$st" = 0 ] && [ -e "$P/ran" ] && grep -q 'the retry worked' "$tmp/out" && [ ! -e "$P/build/import-watch.verdict" ] \
	&& ok "one hang, then a clean retry: the command runs (status 0, no verdict file)" \
	|| bad "one hang, then a clean retry: the command runs" "status $st; $(cat "$tmp/out")"

# ---- 4. a silent hang (no output at all) is a hang too -------------------------------------------
fresh
st=$(run "$SILENT" touch ran)
[ "$st" = 75 ] && grep -q 'import hung on (no progress line' "$tmp/out" && ok "a silent import is caught (exit 75, 'no progress line')" \
	|| bad "a silent import is caught" "status $st; $(tail -3 "$tmp/out")"

# ---- 5. slow but moving is not a hang ------------------------------------------------------------
fresh
st=$(STALL=3 run "$SLOW" bash -c 'touch ran')
[ "$st" = 0 ] && [ -e "$P/ran" ] && ! grep -q 'no progress' "$tmp/out" && ok "a slow import whose line keeps changing is left alone" \
	|| bad "a slow import whose line keeps changing is left alone" "status $st; $(cat "$tmp/out")"

# ---- 6. a TERM to the watchdog (slot.sh's timeout, a killed wrapper) takes the import with it ----
fresh
(cd "$P" && IMPORT_WATCH_STALL=60 IMPORT_WATCH_POLL=0.2 IMPORT_WATCH_CMD="$HANG" exec bash tools/import_watchdog.sh --then true) >/dev/null 2>&1 &
wd=$!
i=0; while ! pgrep -f "$tmp/fake-hang" >/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
kill -TERM "$wd"; wait "$wd"; st=$?
sleep 0.5
! pgrep -f "$tmp/fake-hang" >/dev/null && [ "$st" = 143 ] && ok "TERM to the watchdog stops the import (exit 143)" \
	|| bad "TERM to the watchdog stops the import" "status $st; $(pgrep -af "$tmp/fake-hang")"

# ---- 7. slot.sh's seam: on with TANK_SQUAD_IMPORT_WATCH, absent without it, never when nested ----
fresh
G="$tmp/slots"; mkdir -p "$G"
(cd "$P" && TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=1 TANK_SQUAD_IMPORT_WATCH=1 IMPORT_WATCH_CMD="$GOOD" IMPORT_WATCH_POLL=0.2 \
	timeout 30 bash "$tools/slot.sh" bash -c 'echo "inner=${TANK_SQUAD_IMPORT_WATCH:-unset}" > ran') > "$tmp/out" 2>&1
grep -q 'import-watch: import exited 0' "$tmp/out" && [ "$(cat "$P/ran" 2>/dev/null)" = inner=unset ] \
	&& ok "slot.sh runs the watched import inside the slot, then the command (which does not watch again)" \
	|| bad "slot.sh runs the watched import inside the slot" "$(cat "$tmp/out"; cat "$P/ran" 2>/dev/null)"
fresh
(cd "$P" && TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=1 IMPORT_WATCH_CMD="$HANG" timeout 30 bash "$tools/slot.sh" touch ran) > "$tmp/out" 2>&1
[ -e "$P/ran" ] && [ ! -e "$P/build/import-watch.log" ] && ok "without TANK_SQUAD_IMPORT_WATCH slot.sh runs no import" \
	|| bad "without TANK_SQUAD_IMPORT_WATCH slot.sh runs no import" "$(cat "$tmp/out")"
fresh
(cd "$P" && TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOT=1 TANK_SQUAD_IMPORT_WATCH=1 IMPORT_WATCH_CMD="$HANG" timeout 30 bash "$tools/slot.sh" touch ran) > "$tmp/out" 2>&1
[ -e "$P/ran" ] && [ ! -e "$P/build/import-watch.log" ] && ok "a nested slot.sh (already in a slot) runs no import" \
	|| bad "a nested slot.sh runs no import" "$(cat "$tmp/out")"
fresh
(cd "$P" && TANK_SQUAD_SLOT_DIR="$G" TANK_SQUAD_SLOTS=1 TANK_SQUAD_IMPORT_WATCH=1 IMPORT_WATCH_CMD="$HANG" IMPORT_WATCH_STALL=1 \
	IMPORT_WATCH_POLL=0.2 timeout 30 bash "$tools/slot.sh" touch ran) > "$tmp/out" 2>&1
st=$?
[ "$st" = 75 ] && [ ! -e "$P/ran" ] && grep -q '^>> remote: import hung on Oswald-Latin.ttf' "$tmp/out" \
	&& ok "through slot.sh a double hang ends the run: exit 75, the verdict line, the command never ran" \
	|| bad "through slot.sh a double hang ends the run" "status $st; $(tail -3 "$tmp/out")"

# ---- 8. remote.sh asks for it (and REMOTE_IMPORT_WATCH=0 is the escape) ---------------------------
grep -q 'import-watch.verdict' "$tools/remote.sh" && ! sed -n "/^read -r -d '' script <<EOF/,/^EOF/p" "$tools/remote.sh" | grep -q '`' \
	&& ok "remote.sh ends a hung run on the verdict file; its remote heredoc has no backticks (they run)" \
	|| bad "remote.sh ends a hung run on the verdict file; no backticks in its heredoc"
grep -q 'export TANK_SQUAD_IMPORT_WATCH=1' "$tools/remote.sh" && grep -q 'REMOTE_IMPORT_WATCH:-1' "$tools/remote.sh" \
	&& ok "remote.sh exports TANK_SQUAD_IMPORT_WATCH (REMOTE_IMPORT_WATCH=0 turns it off)" \
	|| bad "remote.sh exports TANK_SQUAD_IMPORT_WATCH"

echo "import-watchdog: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
