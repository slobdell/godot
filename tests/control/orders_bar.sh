#!/usr/bin/env bash
# Round 39 (R39.8): one orders bar series, streets + his click, on builder0's light lane or on builder2, read to a verdict.
#   tests/control/orders_bar.sh <b0|b2> <mode g1v4|g3> <arm name:flag,flag> "<seeds>" <out dir outside build/> [jobs]
# Cells (as Bars G1 v4 / G3 v5): locks / crossing / terminus / yard_open x 3 / 5 squads x click / route, plus his click
# (terminus `--probe-click=-29.3/85.8`, 3 / 5, click; judged as terminus_his). Arms `main:` v <arm>.
# builder2 is Spot (remote_builds.md, round 36): a part counts only with its wrapper's `exited 0` line, a runs.jsonl
# holding every expected run and no MISSING line; otherwise it re-runs (up to 3 times; `make gcp-start` before each).
# Results are copied OUT of build/ after each part (a check's copy-back deletes non-.log files there).
set -u
host=$1 mode=$2 arm=$3 seeds=$4 out=$5 jobs=${6:-4}
cd "$(dirname "$0")/../.."
mkdir -p "$out"
n_seeds=$(echo $seeds | wc -w)
his_click="--probe-click=-29.3/85.8"
part() {  # part <name> <maps> <routes> <main arm> <new arm> <expected runs>
	local name=$1 maps=$2 routes=$3 a=$4 b=$5 want=$6 try src
	for try in 1 2 3; do
		if [ "$host" = b2 ]; then
			PATH=$HOME/projects/bin:$PATH make --no-print-directory gcp-start >/dev/null 2>&1
			REMOTE_HOST=slobdell@builder2 tools/remote.sh native orders-probe "ORDERS_PROBE_MAPS=$maps" "ORDERS_PROBE_SQUADS=3 5" \
				"ORDERS_PROBE_ROUTES=$routes" "ORDERS_PROBE_ARMS=$a $b" "ORDERS_PROBE_SEEDS=$seeds" \
				"ORDERS_PROBE_DIR=build/orders-bar-$name" "ORDERS_PROBE_JOBS=$jobs" "TANK_SQUAD_SLOT_TIMEOUT=14400" > "$out/$name.log" 2>&1
			src=build/orders-bar-$name
		else
			tools/remote.sh --light native orders-probe "ORDERS_PROBE_MAPS=$maps" "ORDERS_PROBE_SQUADS=3 5" \
				"ORDERS_PROBE_ROUTES=$routes" "ORDERS_PROBE_ARMS=$a $b" "ORDERS_PROBE_SEEDS=$seeds" \
				"ORDERS_PROBE_DIR=build/orders-bar-$name" "ORDERS_PROBE_JOBS=$jobs" "TANK_SQUAD_SLOT_TIMEOUT=14400" > "$out/$name.log" 2>&1
			src=build/light/build/orders-bar-$name
		fi
		local got=$(wc -l < "$src/runs.jsonl" 2>/dev/null || echo 0)
		if grep -aq ">> remote: make native orders-probe.*exited 0" "$out/$name.log" && [ "$got" -eq "$want" ] \
				&& ! grep -aq "^MISSING" "$out/$name.log"; then
			rm -rf "$out/$name" && cp -r "$src" "$out/$name" && rm -rf "$out/$name/logs" && cp -r "$src/logs" "$out/$name/logs"
			echo "PART $name OK: $got of $want runs (try $try)"
			return 0
		fi
		echo "PART $name NOT COMPLETE (try $try): runs $got of $want; $(grep -ao '>> remote: make native orders-probe.*exited [0-9]*' "$out/$name.log" | grep -o 'exited [0-9]*')"
	done
	return 1
}
base="main:"
part streets "locks crossing terminus yard_open" "click route" "$base" "$arm" $((4 * 2 * 2 * 2 * n_seeds)) || { echo "BAR NOT RUN: streets"; exit 1; }
part his terminus click "main:$his_click" "${arm%%:*}:${arm#*:},$his_click" $((2 * 2 * n_seeds)) || { echo "BAR NOT RUN: his"; exit 1; }
new=${arm%%:*}
python3 - "$out" <<'EOF'
import json, sys
out = sys.argv[1]
def load(p): return [json.loads(l) for l in open(p) if l.strip()]
rows, runs = load(out + "/streets/rows.jsonl"), load(out + "/streets/runs.jsonl")
his, his_runs = load(out + "/his/rows.jsonl"), load(out + "/his/runs.jsonl")
for r in his + his_runs:
    r["map"] = "terminus_his"
with open(out + "/judged_rows.jsonl", "w") as f:
    for r in [r for r in rows if r["map"] != "yard_open"] + his: f.write(json.dumps(r) + "\n")
with open(out + "/judged_runs.jsonl", "w") as f:
    for r in [r for r in runs if r.get("map") != "yard_open"] + his_runs: f.write(json.dumps(r) + "\n")
with open(out + "/yard_rows.jsonl", "w") as f:
    for r in [r for r in rows if r["map"] == "yard_open"]: f.write(json.dumps(r) + "\n")
EOF
if [ "$mode" = g3 ]; then
	# Bar G3 (v5, v6): the 18 cells judged together, yard_open included.
	cat "$out/judged_rows.jsonl" "$out/yard_rows.jsonl" > "$out/g3_rows.jsonl"
	cat "$out/judged_runs.jsonl" <(grep -h '"yard_open"' "$out/streets/runs.jsonl") > "$out/g3_runs.jsonl"
	python3 tests/control/orders_judge.py g3 "$out/g3_rows.jsonl" main "$new" "$out/g3_runs.jsonl" | tee "$out/verdict.txt"
else
	python3 tests/control/orders_judge.py "$mode" "$out/judged_rows.jsonl" main "$new" "$out/judged_runs.jsonl" "$out/yard_rows.jsonl" | tee "$out/verdict.txt"
fi
echo "BAR_DONE"
