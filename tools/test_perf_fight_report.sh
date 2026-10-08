#!/usr/bin/env bash
# Known-answer tests for tools/perf_fight_report.py and tools/perf_armies.py (perf, round 22): run names parsed, the
# C22.3 bar read from the main arm's pooled p95 per arena, his recording turned back into squads of at most five.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -12; }
run() {  # $1 = file name, $2 = p95
	printf '{"summary":{"gpu":"Stub GPU","window":"(1854, 1011)","run":{"avg_ms":20,"p95_ms":%s,"p99_ms":40,"over_cap_share":0.1,"tick_script_ms":3,"ticks_per_frame":1,"frames":100},"vehicles_curve":[[6,50],[16,40]],"flags":{}},"phases":[{"phase":"all","t":6,"frames":50,"avg_ms":20,"vehicles":50,"process_game_ui_ms":2,"process_fx_ms":1,"gpu_ms":5,"game_speed":1}]}' "$2" > "$tmp/$1"
}
run pf-25-foundry-main-1.json 30; run pf-25-foundry-main-2.json 30; run pf-50-foundry-main-1.json 36
run pf-25-parade-main-1.json 30; run pf-50-parade-main-1.json 40; run pf-50-parade-noleaders-1.json 10
run pf-25-parade-main.json 99   # perf-play's seedless copy: not a run
out=$(TANK_SQUAD_COMMIT=abc12345 python3 "$here/perf_fight_report.py" "$tmp" pf 2>&1)
grep -q 'commit abc12345 | machine Stub GPU' <<<"$out" && ok "commit and machine named" || bad "header" "$out"
grep -Eq 'foundry +p95 25: 30.00 +p95 50: 36.00 +ratio 1.200 +HOLDS' <<<"$out" && ok "36 / 30 = 1.20: holds" || bad "foundry" "$out"
grep -Eq 'parade +p95 25: 30.00 +p95 50: 40.00 +ratio 1.333 +OVER' <<<"$out" && ok "40 / 30 = 1.33: over (the noleaders arm and the seedless copy ignored)" || bad "parade" "$out"
grep -q '"runs":{"25-foundry-main-1"' <<<"$out" && ok "PERF_FIGHT line keyed by run" || bad "json" "$out"

printf '{"arena":"sumps","seed":5988,"units":[%s]}\n' "$(for i in 1 2 3 4 5 6 7; do printf '{"name":"Green_Guns_%d","team":0,"id":"law_tank"},' $i; done)"'{"name":"Rust_Eyes2_1","team":1,"id":"syn_scout"}' > "$tmp/rec.jsonl"
out=$(python3 "$here/perf_armies.py" recording "$tmp/rec.jsonl" "$tmp/armies" 2>&1)
squads=$(python3 -c "import json;print([(s['name'],len(s['units'])) for s in json.load(open('$tmp/armies/green.json'))['squads']])")
[ "$squads" = "[('Guns', 5), ('Guns2', 2)]" ] && ok "Guns of 7 -> Guns 5 + Guns2 2 (folded back by the skirmish)" || bad "split" "$squads"
grep -q 'PERF_ARMY_MATCH arena=sumps seed=5988' <<<"$out" && ok "arena and seed printed" || bad "match" "$out"
python3 "$here/perf_armies.py" size 50 "$tmp/armies" >/dev/null
n=$(python3 -c "import json;d=json.load(open('$tmp/armies/rust_50.json'));print(sum(len(s['units']) for s in d['squads']), max(len(s['units']) for s in d['squads']))")
[ "$n" = "50 5" ] && ok "size 50: 50 vehicles, squads of at most five" || bad "size" "$n"

printf '\nperf-fight-report: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
