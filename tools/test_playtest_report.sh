#!/usr/bin/env bash
# Known-answer tests for tests/replay/playtest_report.py (round 43, native N5): his round-42 recording (no cam rows) reads
# cleanly, and a small recording WITH cam rows puts the camera's look beside each hit and death.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(dirname "$here")"
report="$root/tests/replay/playtest_report.py"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

his="$root/_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz"
out=$(python3 "$report" "$his" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "his round-42 recording: exit 0" || bad "his round-42 recording: exit 0" "exit $rc: $(tail -3 <<<"$out")"
grep -q "arena locks, seed 56416" <<<"$out" && ok "the match line" || bad "the match line" "$(head -4 <<<"$out")"
grep -q "attack_move to (-100.3, -14.6).*Guns_1:best61m/no-arr/AWAY82m" <<<"$out" && ok "the arrivals (his War Rig's AWAY 82 m)" \
	|| bad "the arrivals (his War Rig's AWAY 82 m)"
grep -q "no cam rows: a recording from before round 43" <<<"$out" && ok "no cam rows reads cleanly" || bad "no cam rows reads cleanly"
grep -q "not run (pass --replay" <<<"$out" && ok "no replay: says so" || bad "no replay: says so"

cat > "$tmp/r.jsonl" <<'J'
{"t":"match","arena":"locks","seed":7,"tick_rate":30,"units":[{"name":"Green_A_1","team":0,"id":"gang_tank"},{"name":"Rust_B_1","team":1,"id":"syn_tank"}],"squad_cap":4,"factions":{"green":"gangs","rust":"syndicate"},"preset":"laptop","native":true,"flags":{"attack-shot":"off"},"spawn":{},"frame":0}
{"t":"census","tick":0,"units":[{"n":"Green_A_1","team":0,"pos":[0,0],"hp":1,"shield":0,"order":"","src":"","phase":"","blocked":""}]}
{"t":"cam","tick":30,"yaw":-90.0,"want":-90.0,"pitch":50.0,"dist":40.0,"target":[10.0,-5.0],"mode":"follow"}
{"t":"hit","tick":45,"shooter":"Rust_B_1","target":"Green_A_1","face":"side","weak":false,"damage":10,"killed":false}
{"t":"cam","tick":60,"yaw":180.0,"want":180.0,"pitch":50.0,"dist":40.0,"target":[12.0,-6.0],"mode":"danger","turn":true}
{"t":"dead","tick":61,"unit":"Green_A_1","killer":"Rust_B_1","team":0,"cause":"enemy"}
J
printf 'REPLAY_SETUP {}\ncrew   0\nA_1    0.0   0.0\nDIVERGENCE crews=1 within=1 bar=3.0m seconds=30 ticks=31 first_over=- verdict=PASS\n' > "$tmp/replay.txt"
out=$(python3 "$report" "$tmp/r.jsonl" --replay "$tmp/replay.txt" --html "$tmp/out/report.html" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "a recording with cam rows: exit 0" || bad "a recording with cam rows: exit 0" "$out"
grep -q "squad cap 4, preset laptop, native True" <<<"$out" && ok "the C43.2 keys are read" || bad "the C43.2 keys are read" "$out"
grep -q "switches: --attack-shot=off" <<<"$out" && ok "his switches are listed" || bad "his switches are listed"
grep -qE "1\.5 s  hit   Rust_B_1 -> Green_A_1 side .* look E  +-90\.0" <<<"$out" && ok "the hit beside the camera before it (east)" \
	|| bad "the hit beside the camera before it (east)" "$(grep hit <<<"$out")"
grep -qE "2\.0 s  death Green_A_1 \(by Rust_B_1\) .* look S  +180\.0 .* danger" <<<"$out" && ok "the death beside the turn to it" \
	|| bad "the death beside the turn to it" "$(grep death <<<"$out")"
grep -q "the replay IS his match for these 30 s" <<<"$out" && ok "a passing replay reads as his match" || bad "a passing replay reads as his match"
[ -s "$tmp/out/report.html" ] && grep -q "<title>Playtest report</title>" "$tmp/out/report.html" && ok "--html writes the page" \
	|| bad "--html writes the page"

echo "playtest_report: $pass passed, $fail failed"
[ "$fail" = 0 ]
