#!/usr/bin/env bash
# Known-answer tests for tests/replay/playtest_report.py (round 43, native N5; round 44, N1 the one-screen summary): it PRINTS at
# most 40 lines (the match, one line per click, the off-screen count, the replay's verdict, the full report's path) and WRITES the
# full report (arrivals per order, the camera at each hit and death, the replay) to --out and a page beside it.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(dirname "$here")"
report="$root/tests/replay/playtest_report.py"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
fits() { [ "$(wc -l <<<"$1")" -le 40 ]; }

# His round-42 recording: no cam rows, no replay.
his="$root/_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz"
out=$(python3 "$report" "$his" --out "$tmp/r42/full.txt" 2>&1); rc=$?; full=$(cat "$tmp/r42/full.txt" 2>/dev/null)
[ "$rc" = 0 ] && ok "his round-42 recording: exit 0" || bad "his round-42 recording: exit 0" "exit $rc: $(tail -3 <<<"$out")"
fits "$out" && ok "his round-42 summary fits one screen" || bad "his round-42 summary fits one screen" "$(wc -l <<<"$out") lines"
grep -q "^match: locks, seed 56416" <<<"$out" && ok "the match line" || bad "the match line" "$(head -3 <<<"$out")"
grep -qE "attack_move .*AWAY Guns_1 82 m" <<<"$out" && ok "the summary's click line (his War Rig's AWAY 82 m)" \
	|| bad "the summary's click line (his War Rig's AWAY 82 m)" "$(grep attack_move <<<"$out")"
grep -q "attack_move to (-100.3, -14.6).*Guns_1:best61m/no-arr/AWAY82m" <<<"$full" && ok "the full report's arrivals" \
	|| bad "the full report's arrivals"
grep -q "^camera: no cam rows" <<<"$out" && grep -q "no cam rows: a recording from before round 43" <<<"$full" \
	&& ok "no cam rows reads cleanly" || bad "no cam rows reads cleanly"
grep -q "^replay: not run" <<<"$out" && grep -q "not run (pass --replay" <<<"$full" && ok "no replay: says so" || bad "no replay: says so"
grep -q "^full report: $tmp/r42/full.txt (page $tmp/r42/full.html)" <<<"$out" && [ -s "$tmp/r42/full.html" ] \
	&& ok "the full report's path is the last line; the page beside it" || bad "the full report's path is the last line" "$(tail -1 <<<"$out")"

# A small recording: a group click of two squads (one row each, the second with C44.2's click key), cam rows, a hit on screen
# and a death far off screen.
cat > "$tmp/r.jsonl" <<'J'
{"t":"match","arena":"locks","seed":-1,"tick_rate":30,"units":[{"name":"Green_A_1","team":0,"id":"gang_tank"},{"name":"Green_B_1","team":0,"id":"gang_tank"},{"name":"Rust_C_1","team":1,"id":"syn_tank"}],"squad_cap":4,"factions":{"green":"gangs","rust":"syndicate"},"preset":"laptop","native":true,"flags":{"attack-shot":"off","seed":"56416."},"spawn":{},"frame":0}
{"t":"census","tick":0,"units":[{"n":"Green_A_1","team":0,"pos":[10,-5],"hp":1,"shield":0,"order":"","src":"","phase":"","blocked":""},{"n":"Green_B_1","team":0,"pos":[400,400],"hp":1,"shield":0,"order":"","src":"","phase":"","blocked":""}]}
{"t":"order","tick":15,"verb":"move","to":[0,0],"units":["Green_A_1"],"click":[5,5],"group":2}
{"t":"order","tick":15,"verb":"move","to":[30,40],"units":["Green_B_1"],"click":[5,5],"group":2}
{"t":"cam","tick":30,"yaw":-90.0,"want":-90.0,"pitch":50.0,"dist":40.0,"target":[10.0,-5.0],"mode":"follow"}
{"t":"census","tick":30,"units":[{"n":"Green_A_1","team":0,"pos":[1,0],"hp":1,"shield":0,"order":"move","src":"","phase":"arrived","blocked":""},{"n":"Green_B_1","team":0,"pos":[400,400],"hp":1,"shield":0,"order":"move","src":"","phase":"","blocked":""}]}
{"t":"hit","tick":45,"shooter":"Rust_C_1","target":"Green_A_1","face":"side","weak":false,"damage":10,"killed":false}
{"t":"cam","tick":60,"yaw":180.0,"want":180.0,"pitch":50.0,"dist":40.0,"target":[12.0,-6.0],"mode":"danger","turn":true}
{"t":"dead","tick":61,"unit":"Green_B_1","killer":"Rust_C_1","team":0,"cause":"enemy"}
J
printf 'REPLAY_SETUP {}\ncrew   0\nA_1    0.0   0.0\nDIVERGENCE crews=1 within=1 bar=3.0m seconds=30 ticks=31 first_over=- verdict=PASS\n' > "$tmp/replay.txt"
out=$(python3 "$report" "$tmp/r.jsonl" --replay "$tmp/replay.txt" --out "$tmp/s/full.txt" --html "$tmp/out/report.html" 2>&1); rc=$?
full=$(cat "$tmp/s/full.txt" 2>/dev/null)
[ "$rc" = 0 ] && ok "a recording with cam rows: exit 0" || bad "a recording with cam rows: exit 0" "$out"
grep -q "seed -1 (his --seed=56416.)" <<<"$out" && ok "a seed that did not parse shows what he typed" || bad "a seed that did not parse" "$(head -2 <<<"$out")"
grep -q "squad cap 4, laptop, native on" <<<"$out" && grep -q "squad cap 4, preset laptop, native True" <<<"$full" \
	&& ok "the C43.2 keys are read" || bad "the C43.2 keys are read" "$out"
grep -q "switches: --attack-shot=off" <<<"$full" && ok "his switches are listed (full report)" || bad "his switches are listed"
[ "$(grep -c '^ *0\.5 s  move' <<<"$out")" = 1 ] && ok "one click = one line (two order rows on one tick)" \
	|| bad "one click = one line" "$(grep 'move' <<<"$out")"
grep -qE "0\.5 s  move +A:1 B:1  click \(5, 5\)  2 spots 50 m apart  arrived 1/2  worst B_1 [0-9]+ m never" <<<"$out" \
	&& ok "the click line: squads, his click, how far apart, who arrived, the worst" || bad "the click line" "$(grep move <<<"$out")"
grep -qE "1\.5 s  hit   Rust_C_1 -> Green_A_1 side .* look E  +-90\.0 .* on$" <<<"$full" \
	&& ok "the hit beside the camera before it (east), on screen" || bad "the hit beside the camera" "$(grep hit <<<"$full")"
grep -qE "2\.0 s  death Green_B_1 \(by Rust_C_1\) .* look S  +180\.0 .* danger .* OFF$" <<<"$full" \
	&& ok "the death 400 m away, off screen" || bad "the death off screen" "$(grep death <<<"$full")"
grep -q "^camera: 1 of 2 hits/deaths off screen (1 on his units, 1 deaths)" <<<"$out" && ok "the off-screen count" \
	|| bad "the off-screen count" "$(grep camera <<<"$out")"
grep -q "^replay: PASS, his match: 1 of 1 crews within 3.0m for 30 s" <<<"$out" && grep -q "the replay IS his match" <<<"$full" \
	&& ok "a passing replay: one line, the table in the full report" || bad "a passing replay" "$(grep replay <<<"$out")"
[ -s "$tmp/out/report.html" ] && grep -q "<title>Playtest report</title>" "$tmp/out/report.html" && ok "--html writes the page" \
	|| bad "--html writes the page"
printf 'replay: godot exited 1 (log x)\n' > "$tmp/bad.txt"
out=$(python3 "$report" "$tmp/r.jsonl" --replay "$tmp/bad.txt" --out "$tmp/b/full.txt" 2>&1)
grep -q "^replay: replay: godot exited 1" <<<"$out" && ok "a failed replay says why in one line" || bad "a failed replay" "$(grep replay <<<"$out")"

printf 'REPLAY_REEXEC --skirmish --seed=-1 --arena=locks\nREPLAY_ROSTER_MISMATCH Green_A_1 is x, his was y\nREPLAY_NATIVE_MISMATCH recorded=true replay=false\nDIVERGENCE crews=2 within=1 bar=3.0m seconds=30 ticks=31 first_over=Green_A_1@7 verdict=FAIL\n' > "$tmp/fail.txt"
out=$(python3 "$report" "$tmp/r.jsonl" --replay "$tmp/fail.txt" --out "$tmp/f/full.txt" 2>&1)
grep -q "^replay: FAIL, 1 of 2 crews within 3.0m for 30 s; first over Green_A_1@7 (native differs (make native), 1 roster mismatches, seed not recorded)" <<<"$out" \
	&& ok "a failed replay names why it parted" || bad "a failed replay names why" "$(grep replay <<<"$out")"

# A long match: 60 clicks still print one screen, the tail lines kept.
{ head -2 "$tmp/r.jsonl"; for i in $(seq 1 60); do printf '{"t":"order","tick":%d,"verb":"move","to":[%d,0],"units":["Green_A_1"]}\n' $((i * 30)) "$i"; done
  printf '{"t":"census","tick":1900,"units":[]}\n'; } > "$tmp/long.jsonl"
out=$(python3 "$report" "$tmp/long.jsonl" --out "$tmp/l/full.txt" 2>&1)
fits "$out" && ok "60 clicks: at most 40 lines" || bad "60 clicks: at most 40 lines" "$(wc -l <<<"$out") lines"
grep -qE "^  \.\.\. [0-9]+ more clicks in the full report" <<<"$out" && grep -q "^replay: " <<<"$out" && grep -q "^full report: " <<<"$out" \
	&& ok "60 clicks: the rest are counted, the tail kept" || bad "60 clicks: the rest counted" "$(tail -4 <<<"$out")"
[ "$(grep -c ' t *[0-9]* move' "$tmp/l/full.txt")" = 60 ] && ok "60 clicks: all in the full report" || bad "60 clicks: all in the full report"

# His two round-43 recordings (the lead's ask: one screen he can paste).
for f in 2026-10-28T08-15-42-locks 2026-10-28T08-21-31-locks; do
	out=$(python3 "$report" "$root/_agents/streams/references/round43/playtest/$f.jsonl" --out "$tmp/$f.txt" 2>&1); rc=$?
	[ "$rc" = 0 ] && fits "$out" && ok "his $f: one screen" || bad "his $f: one screen" "exit $rc, $(wc -l <<<"$out") lines"
done
grep -qE "50\.4 s  move +Guns:1 Hunters:5 Spears:5 Wrenches:5  4 spots 105 m apart" <<<"$out" \
	&& ok "his group click at 50.4 s: four spots 105 m apart" || bad "his group click at 50.4 s" "$(grep '50.4 s' <<<"$out")"

echo "playtest_report: $pass passed, $fail failed"
[ "$fail" = 0 ]
