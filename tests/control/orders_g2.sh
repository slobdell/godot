#!/usr/bin/env bash
# Round 40 (O4): one G2 read (his shift-click routes), main v G2 v2c, on builder0's light lane or builder2, judged.
#   tests/control/orders_g2.sh <b0|b2> "<seeds>" <out dir outside build/> [jobs] [extra flags for the g2 arm, comma-joined]
# Cells (as round 39's dev read 3, 584d23588): the route cells (locks / crossing / terminus x 3 / 5 squads x route) and his
# three Terminus routes (`--probe-points`, 3 / 5 squads) as arms "<arm>_<route>", which `orders_judge.py g2` folds back.
set -u
host=$1 seeds=$2 out=$3 jobs=${4:-4} extra=${5:-}
cd "$(dirname "$0")/../.."
mkdir -p "$out"
g2="--group-lay=column,--group-legs=on,--group-route-line=on,--group-leg-width=along,--group-gate=main,--group-route-corner=line${extra:+,$extra}"
east="--probe-points=70/50+70/-30+25/-30"
west="--probe-points=-70/50+-70/-30+-25/-30"
avenue="--probe-points=0/30+0/-30+-50/-30"
run() {  # run <name> <maps> <arms>
	local name=$1 maps=$2 arms=$3 src
	local args=(native orders-probe "ORDERS_PROBE_MAPS=$maps" "ORDERS_PROBE_SQUADS=3 5" "ORDERS_PROBE_ROUTES=route"
		"ORDERS_PROBE_ARMS=$arms" "ORDERS_PROBE_SEEDS=$seeds" "ORDERS_PROBE_DIR=build/orders-g2-$name" "ORDERS_PROBE_JOBS=$jobs"
		"TANK_SQUAD_SLOT_TIMEOUT=14400")
	if [ "$host" = b2 ]; then
		PATH=$HOME/projects/bin:$PATH make --no-print-directory gcp-start >/dev/null 2>&1
		REMOTE_HOST=slobdell@builder2 tools/remote.sh "${args[@]}" > "$out/$name.log" 2>&1
		src=build/orders-g2-$name
	else
		tools/remote.sh --light "${args[@]}" > "$out/$name.log" 2>&1
		src=build/light/build/orders-g2-$name
	fi
	grep -aq ">> remote: make native orders-probe.*exited 0" "$out/$name.log" || { echo "PART $name FAILED"; return 1; }
	rm -rf "$out/$name" && cp -r "$src" "$out/$name"
	echo "PART $name OK: $(wc -l < "$out/$name/runs.jsonl") runs"
}
run cells "locks crossing terminus" "main: g2:$g2" || exit 1
run his terminus "main_east:$east main_west:$west main_avenue:$avenue g2_east:$g2,$east g2_west:$g2,$west g2_avenue:$g2,$avenue" || exit 1
python3 tests/control/orders_judge.py g2 "$out/cells/rows.jsonl" main g2 "$out/cells/runs.jsonl" "$out/his/rows.jsonl" "$out/his/runs.jsonl" \
	| tee "$out/verdict.txt"
echo "G2_DONE"
