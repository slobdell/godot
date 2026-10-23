#!/usr/bin/env bash
# Known answers for tools/loaded.sh and tools/web_smoke/first_sound_gate.sh (round 38, R38.19): a wall-clock bound missed
# on a box loaded per PHYSICAL core is NOT JUDGED; the same miss on a quiet box FAILs.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ld="$here/loaded.sh"; gate="$here/web_smoke/first_sound_gate.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# loaded.sh: exit 0 = loaded, 1 = quiet; its line names load, cores, per core. LOADED_LOAD / LOADED_CORES stand in for
# /proc/loadavg and lscpu's physical cores.
out=$(LOADED_LOAD=32.9 LOADED_CORES=16 bash "$ld"); s=$?
[ "$s" = 0 ] && [ "$out" = "load 32.9 on 16 cores (2.06 per core)" ] && ok "builder2 at 32.9 (16 cores): loaded" || bad "b2 32.9" "exit $s: $out"
out=$(LOADED_LOAD=20 LOADED_CORES=16 bash "$ld"); s=$?
[ "$s" = 1 ] && ok "builder2 at 20 (1.25 per core): quiet" || bad "b2 20" "exit $s: $out"
out=$(LOADED_LOAD=15 LOADED_CORES=10 bash "$ld"); s=$?
[ "$s" = 0 ] && ok "builder0 at 15 (10 cores, 1.5 per core): loaded (the bound is >=)" || bad "b0 15" "exit $s: $out"
out=$(LOADED_LOAD=12.6 LOADED_CORES=10 bash "$ld"); s=$?
[ "$s" = 1 ] && ok "builder0 at 12.6 (the round-33 pass): quiet" || bad "b0 12.6" "exit $s: $out"
out=$(LOADED_LOAD=20 LOADED_CORES=16 bash "$ld" 1.2); s=$?
[ "$s" = 0 ] && ok "a per-core bound as the argument (1.2)" || bad "arg" "exit $s: $out"
out=$(bash "$ld"); s=$?
[[ "$out" =~ ^load\ [0-9.]+\ on\ [1-9][0-9]*\ cores ]] && { [ "$s" = 0 ] || [ "$s" = 1 ]; } && ok "this box: $out" || bad "live" "exit $s: $out"

# first_sound_gate.sh TXT MARKER: assert_match's output; the first-sound bound as the ONLY FAIL on a loaded box -> NOT
# JUDGED (exit 0, the marker says why); on a quiet box, or with any other FAIL -> exit 1, no marker.
sound='  FAIL sound: first sound 32.9 s after READY (bound 30 s)'
printf 'WEB MATCH SMOKE\n  ok   booth\n%s\n' "$sound" > "$tmp/one.txt"
printf 'WEB MATCH SMOKE\n%s\n  FAIL console: 1 error\n' "$sound" > "$tmp/two.txt"
m="$tmp/marker"
out=$(LOADED_LOAD=32.9 LOADED_CORES=16 bash "$gate" "$tmp/one.txt" "$m"); s=$?
[ "$s" = 0 ] && grep -q "NOT JUDGED" <<<"$out" && grep -q "first sound 32.9 s after READY (bound 30 s)" "$m" \
	&& grep -q "2.06 per core" "$m" && ok "the bound alone, loaded box: NOT JUDGED, marker written" || bad "loaded one" "exit $s: $out / $(cat "$m" 2>/dev/null)"
rm -f "$m"
out=$(LOADED_LOAD=8 LOADED_CORES=16 bash "$gate" "$tmp/one.txt" "$m"); s=$?
[ "$s" = 1 ] && [ ! -e "$m" ] && ok "the bound alone, quiet box: FAIL" || bad "quiet one" "exit $s: $out"
out=$(LOADED_LOAD=60 LOADED_CORES=16 bash "$gate" "$tmp/two.txt" "$m"); s=$?
[ "$s" = 1 ] && [ ! -e "$m" ] && ok "the bound and another FAIL, loaded box: FAIL" || bad "loaded two" "exit $s: $out"

printf '\nloaded: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
