#!/usr/bin/env bash
# tools/web_smoke/first_sound_gate.sh TXT MARKER: web-match-smoke's verdict once assert_match.py has FAILed (its output in
# TXT). "First sound <= 30 s after READY" is a wall-clock bound: when it is the ONLY FAIL and the box is loaded
# (tools/loaded.sh, per physical core), the run is NOT JUDGED (exit 0, the reason in MARKER for check's verdict row), as
# perf-judge refuses. Any other FAIL, or the same miss on a quiet box: exit 1. WEB_LOADED_PER_CORE (1.5).
set -u
txt=${1:?TXT}; marker=${2:?MARKER}
fails=$(grep -c '^  FAIL ' "$txt" || true)
bound=$(grep -c '^  FAIL sound: first sound .* after READY (bound ' "$txt" || true)
if [ "$fails" = 1 ] && [ "$bound" = 1 ] && box=$(bash "$(dirname "$0")/../loaded.sh" "${WEB_LOADED_PER_CORE:-1.5}"); then
	why="first-sound bound missed at $box ($(grep -o 'first sound [0-9.]* s after READY (bound [0-9]* s)' "$txt"))"
	echo ">> web-smoke: NOT JUDGED -- $why: the box was too loaded to judge a wall-clock bound"
	mkdir -p "$(dirname "$marker")"; echo "$why" > "$marker"
	exit 0
fi
exit 1
