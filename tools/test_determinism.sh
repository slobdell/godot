#!/usr/bin/env bash
# Known-answer tests for `make determinism` (mk/match.mk), which runs the same seeded match twice on foundry AND on a
# dealt map (crossing) at once (ship, round 18; the orchestrator's carve-out). Godot is replaced by a stub that prints
# a MATCH_RESULT per map from a table, so every branch is driven once (lesson 250): both agree, foundry differs,
# crossing differs, a run prints no MATCH_RESULT.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -20; }
export TANK_SQUAD_SLOT=1          # do not queue for a heavy-run slot to run a stub
export DET_STUB_DIR="$tmp"

# The stub: $DET_STUB_DIR/mode.<map> is SAME (default), DIFFER (a different hash per process) or NONE (no result).
printf '%s\n' '#!/usr/bin/env bash' \
	'map=foundry; for a in "$@"; do case "$a" in --arena=*) map=${a#--arena=};; esac; done' \
	'mode=$(cat "$DET_STUB_DIR/mode.$map" 2>/dev/null || echo SAME)' \
	'case "$mode" in' \
	'NONE) echo "no result"; exit 0;;' \
	'DIFFER) h=$(printf "%016x" "$$");;' \
	'*) h=$(printf "%s" "$map" | md5sum | cut -c1-16);;' \
	'esac' \
	'echo "MATCH_RESULT {\"state_hash\":\"$h\",\"real_seconds\":$RANDOM,\"speedup\":2.0,\"winner\":\"green\"}"' \
	> "$tmp/godot"
chmod +x "$tmp/godot"

det() {
	rm -f "$tmp"/mode.*
	for m in "$@"; do echo "${m#*=}" > "$tmp/mode.${m%%=*}"; done
	( cd "$repo" && make --no-print-directory -o import determinism GODOT="$tmp/godot" BUILD_DIR="$tmp/build" 2>&1 )
}

out=$(det); rc=$?
[ $rc = 0 ] && grep -q 'determinism passed on foundry' <<<"$out" && grep -q 'determinism passed on crossing' <<<"$out" \
	&& ok "both maps agree: passes, names both" || bad "both agree" "$out"
[ -s "$tmp/build/determinism_1.json" ] && [ -s "$tmp/build/determinism_crossing_2.json" ] \
	&& ok "foundry keeps determinism_1/2.json; crossing writes its own" || bad "file names" "$(ls "$tmp/build")"
grep -q '"real_seconds"' "$tmp/build/determinism_1.json" && bad "wall-clock fields are stripped" || ok "wall-clock fields are stripped"
out=$(det foundry=DIFFER); rc=$?
[ $rc != 0 ] && grep -q 'determinism FAILED on foundry: the two runs DIFFER' <<<"$out" && grep -q 'passed on crossing' <<<"$out" \
	&& ok "foundry differs: FAILS naming foundry; crossing still judged" || bad "foundry differs" "$out"
out=$(det crossing=DIFFER); rc=$?
[ $rc != 0 ] && grep -q 'determinism FAILED on crossing: the two runs DIFFER' <<<"$out" && grep -q 'passed on foundry' <<<"$out" \
	&& ok "crossing differs: FAILS naming crossing; foundry cannot mask it" || bad "crossing differs" "$out"
out=$(det crossing=NONE); rc=$?
[ $rc != 0 ] && grep -q 'determinism FAILED on crossing: a run printed no MATCH_RESULT' <<<"$out" \
	&& ok "no MATCH_RESULT: FAILS naming the map, never compares two empty files" || bad "no result" "$out"
out=$(det foundry=NONE crossing=DIFFER); rc=$?
[ $rc != 0 ] && grep -q 'FAILED on foundry' <<<"$out" && grep -q 'FAILED on crossing' <<<"$out" \
	&& ok "both fail: both named" || bad "both fail" "$out"

printf '\ndeterminism: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
