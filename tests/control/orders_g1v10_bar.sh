#!/usr/bin/env bash
# Round 44 (orders, Bar G1 v10): the three parts on builder2, read to a verdict (tests/control/orders_geometry_judge.py).
#   tests/control/orders_g1v10_bar.sh <b0|b2> <arm name:flag,flag> "<A seeds>" "<B seeds>" "<C seeds>" <out dir outside build/> [jobs]
# A geometry: make orders-geometry (locks / crossing / terminus / yard_open x his / along / across x reach 20 / 80, + the fixed
#   cell locks:his:-62/50, his far click into the west quay; R44.9), `main:` v <arm>.
# B streets: the orders probe's street cells (locks / crossing / terminus / yard_open x 3 / 5 x click / route) + his terminus click.
# C fight: the probe's fight (`--probe-fight=on`), terminus / locks, 5 squads, click. `--probe-budget=3000`: the 5-squad army
#   costs 2970 and the probe's fight default is 2500 (Bar G1 v10c's part C ran 48 error rows and no fight, R44.23).
# Spot (builder2): a part counts only with its wrapper's `exited 0`, every expected run and no MISSING line; else it re-runs
# (3 tries, `make gcp-start` first). Results copied OUT of build/ after each part.
set -u
host=${1:?} arm=${2:?} aseeds=${3:?} bseeds=${4:?} cseeds=${5:?} out=${6:?} jobs=${7:-8}
cd "$(dirname "$0")/../.."
mkdir -p "$out"
na=$(echo $aseeds | wc -w); nb=$(echo $bseeds | wc -w); nc=$(echo $cseeds | wc -w)
his_click="--probe-click=-29.3/85.8"
remote() {  # remote <log> <args...>
	local log=$1; shift
	if [ "$host" = b2 ]; then
		PATH=$HOME/projects/bin:$PATH make --no-print-directory gcp-start >/dev/null 2>&1
		REMOTE_HOST=slobdell@builder2 tools/remote.sh native "$@" "TANK_SQUAD_SLOT_TIMEOUT=28800" > "$log" 2>&1
	else
		tools/remote.sh --light native "$@" "TANK_SQUAD_SLOT_TIMEOUT=28800" > "$log" 2>&1
	fi
}
src_of() { [ "$host" = b2 ] && echo "build/$1" || echo "build/light/build/$1"; }
runs_in() {  # every runs.jsonl under a folder (orders-geometry keeps one per cell)
	cat $(find "$1" -name runs.jsonl 2>/dev/null) 2>/dev/null | wc -l
}
errors_in() {  # Bar G1 v10c's part C (R44.23): a probe that could not start writes {"error": ...} as its run line; it is not a run
	cat $(find "$1" -name runs.jsonl 2>/dev/null) 2>/dev/null | grep -ac '^{"error"'
}
part() {  # part <name> <target> <dir var> <want> <make args...>
	local name=${1:?} target=$2 dirvar=$3 want=$4 try src got; shift 4
	for try in 1 2 3; do
		remote "$out/$name.log" "$target" "$dirvar=build/g1v10-$name" "$@"
		src=$(src_of "g1v10-$name")
		got=$(runs_in "$src"); err=$(errors_in "$src")
		if [ "$err" -gt 0 ]; then  # a setup error repeats on every try: stop, show the first, the part did not run
			echo "PART $name ERROR: $err of $got run lines are errors (try $try): $(cat $(find "$src" -name runs.jsonl) | grep -a '^{"error"' | head -1 | cut -c1-200)"
			return 1
		fi
		if grep -aq ">> remote: make native $target.*exited 0" "$out/$name.log" && [ "$got" -eq "$want" ] \
				&& ! grep -aq "^MISSING" "$out/$name.log"; then
			rm -rf "${out:?}/${name:?}" && cp -r "$src" "$out/$name" && rm -rf "${out:?}/${name:?}/logs"
			echo "PART $name OK: $got of $want runs (try $try)"
			return 0
		fi
		echo "PART $name NOT COMPLETE (try $try): runs $got of $want"
	done
	return 1
}
part geometry orders-geometry ORDERS_GEOMETRY_DIR $(((4 * 3 * 2 + 1) * 2 * na)) "ORDERS_GEOMETRY_MAPS=locks crossing terminus yard_open" \
	"ORDERS_GEOMETRY_STARTS=his along across" "ORDERS_GEOMETRY_REACH=20 80" "ORDERS_GEOMETRY_FIXED=locks:his:-62/50" "ORDERS_GEOMETRY_ARMS=main: $arm" \
	"ORDERS_GEOMETRY_SEEDS=$aseeds" "ORDERS_GEOMETRY_JOBS=$jobs" || { echo "BAR NOT RUN: geometry"; exit 1; }
part streets orders-probe ORDERS_PROBE_DIR $((4 * 2 * 2 * 2 * nb)) "ORDERS_PROBE_MAPS=locks crossing terminus yard_open" \
	"ORDERS_PROBE_SQUADS=3 5" "ORDERS_PROBE_ROUTES=click route" "ORDERS_PROBE_ARMS=main: $arm" "ORDERS_PROBE_SEEDS=$bseeds" \
	"ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: streets"; exit 1; }
part his orders-probe ORDERS_PROBE_DIR $((2 * 2 * nb)) "ORDERS_PROBE_MAPS=terminus" "ORDERS_PROBE_SQUADS=3 5" \
	"ORDERS_PROBE_ROUTES=click" "ORDERS_PROBE_ARMS=main:$his_click ${arm%%:*}:${arm#*:},$his_click" \
	"ORDERS_PROBE_SEEDS=$bseeds" "ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: his"; exit 1; }
part fight orders-probe ORDERS_PROBE_DIR $((2 * 2 * nc)) "ORDERS_PROBE_MAPS=terminus locks" "ORDERS_PROBE_SQUADS=5" \
	"ORDERS_PROBE_ROUTES=click" "ORDERS_PROBE_ARMS=main:--probe-fight=on,--probe-budget=3000 ${arm},--probe-fight=on,--probe-budget=3000" \
	"ORDERS_PROBE_SEEDS=$cseeds" "ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: fight"; exit 1; }
python3 tests/control/orders_geometry_judge.py "$out" main "${arm%%:*}" | tee "$out/verdict.txt"
echo "BAR_DONE"
