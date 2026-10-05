#!/usr/bin/env bash
# The lent exit-code fixes (ship, round 18; the orchestrator's audit, items 1-8): each recipe, run with a Godot stub
# that prints every marker the recipe greps for and THEN exits 134, must go red naming the code. Targets that need an
# export or a display (desktop-smoke, windowed-elimination-pair) and music-smoke (its garage run comes after two real
# matches) are checked statically: their runs are captured as `|| s=$$?` and judged by tools/exit_gate.sh.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | tail -8; }
export TANK_SQUAD_SLOT=1
cat > "$tmp/godot" <<'STUB'
#!/usr/bin/env bash
echo "TANK_SQUAD_READY role=GARAGE"
echo "GARAGE_FIGHT player=user://garage_scratch/my_army.json enemy=cpu:siege enemy_path=cpu:siege seed=4 budget=1000 green=3 rust=3"
echo "HUD_MESSAGE [info] Your squads hold"
echo "TACTICS_DONE failures=0"
echo "scenarios: 43 passed, 1 failed, 3 pending, 0 unexpected"
echo "corrupted size vs. prev_size in fastbins"
exit 134
STUB
chmod +x "$tmp/godot"
mk() { ( cd "$repo" && make --no-print-directory -o import "$@" GODOT="$tmp/godot" BUILD_DIR="$tmp/build" 2>&1 ); }
for t in garage-smoke army-loop-smoke tactics-drills ai-scenarios-check; do
	out=$(mk $t); rc=$?
	[ $rc != 0 ] && grep -q "FAILED: the game exited 134 -- aborted" <<<"$out" && ok "$t: markers printed, then 134 -> red, named" || bad "$t" "$out"
done
grep -q 'tools/exit_gate.sh music-smoke/garage' "$repo/mk/audio.mk" && ok "music-smoke's garage run is judged by exit_gate" || bad "music-smoke static"
[ "$(grep -c 'tools/exit_gate.sh desktop-smoke' "$repo/mk/web.mk")" = 3 ] && ok "desktop-smoke: all three runs judged" || bad "desktop static"
grep -q 'tools/exit_gate.sh windowed-elimination-pair/run' "$repo/mk/match.mk" && ok "windowed-elimination-pair: both runs judged" || bad "windowed static"
[ "$(grep -c 'reap .*/server\|reap \$(1)/host' "$repo/mk/net.mk")" = 3 ] && ok "net-, combat-smoke and relay_verdict reap their Godot" || bad "reap static"
printf '\nlent-exit-codes: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
