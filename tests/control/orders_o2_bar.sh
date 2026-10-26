#!/usr/bin/env bash
# Round 41 (orders O2, Bar O2): the departure-queue bar series, three parts, read to a verdict.
#   tests/control/orders_o2_bar.sh <b0|b2> <arm name:flag,flag> "<group seeds>" "<guard seeds>" <out dir outside build/> [jobs]
# A group: his group order (make orders-group): crossing / locks / sumps / terminus, crew headings, `main:` v <arm>.
# B streets: the orders probe's 12 street cells (locks / crossing / terminus x 3 / 5 x click / route) + his click.
# C fight: the probe's fight (`--probe-fight=on`), terminus / locks, 5 squads, click.
# Spot (builder2): a part counts only with its wrapper's `exited 0`, every expected run and no MISSING line; else it
# re-runs (3 tries, `make gcp-start` first). Results copied OUT of build/ after each part.
set -u
host=$1 arm=$2 gseeds=$3 seeds=$4 out=$5 jobs=${6:-4}
cd "$(dirname "$0")/../.."
mkdir -p "$out"
ng=$(echo $gseeds | wc -w); n=$(echo $seeds | wc -w)
remote() {  # remote <log> <args...>
	local log=$1; shift
	if [ "$host" = b2 ]; then
		PATH=$HOME/projects/bin:$PATH make --no-print-directory gcp-start >/dev/null 2>&1
		REMOTE_HOST=slobdell@builder2 tools/remote.sh native "$@" "TANK_SQUAD_SLOT_TIMEOUT=14400" > "$log" 2>&1
	else
		tools/remote.sh --light native "$@" "TANK_SQUAD_SLOT_TIMEOUT=14400" > "$log" 2>&1
	fi
}
src_of() { [ "$host" = b2 ] && echo "build/$1" || echo "build/light/build/$1"; }
part() {  # part <name> <target> <dir var> <want> <make args...>
	local name=$1 target=$2 dirvar=$3 want=$4 try src got; shift 4
	for try in 1 2 3; do
		remote "$out/$name.log" "$target" "$dirvar=build/o2bar-$name" "$@"
		src=$(src_of "o2bar-$name")
		got=$(wc -l < "$src/runs.jsonl" 2>/dev/null || echo 0)
		if grep -aq ">> remote: make native $target.*exited 0" "$out/$name.log" && [ "$got" -eq "$want" ] \
				&& ! grep -aq "^MISSING" "$out/$name.log"; then
			rm -rf "$out/$name" && cp -r "$src" "$out/$name"
			echo "PART $name OK: $got of $want runs (try $try)"
			return 0
		fi
		echo "PART $name NOT COMPLETE (try $try): runs $got of $want"
	done
	return 1
}
part group orders-group ORDERS_GROUP_DIR $((4 * 2 * ng)) "ORDERS_GROUP_MAPS=crossing locks sumps terminus" \
	"ORDERS_GROUP_SEEDS=$gseeds" "ORDERS_GROUP_HEADINGS=crew" "ORDERS_GROUP_ARMS=main: $arm" "ORDERS_GROUP_JOBS=$jobs" \
	|| { echo "BAR NOT RUN: group"; exit 1; }
part streets orders-probe ORDERS_PROBE_DIR $((3 * 2 * 2 * 2 * n)) "ORDERS_PROBE_MAPS=locks crossing terminus" \
	"ORDERS_PROBE_SQUADS=3 5" "ORDERS_PROBE_ROUTES=click route" "ORDERS_PROBE_ARMS=main: $arm" "ORDERS_PROBE_SEEDS=$seeds" \
	"ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: streets"; exit 1; }
part his orders-probe ORDERS_PROBE_DIR $((2 * 2 * n)) "ORDERS_PROBE_MAPS=terminus" "ORDERS_PROBE_SQUADS=3 5" \
	"ORDERS_PROBE_ROUTES=click" "ORDERS_PROBE_ARMS=main:--probe-click=-29.3/85.8 ${arm},--probe-click=-29.3/85.8" \
	"ORDERS_PROBE_SEEDS=$seeds" "ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: his"; exit 1; }
part fight orders-probe ORDERS_PROBE_DIR $((2 * 2 * n)) "ORDERS_PROBE_MAPS=terminus locks" "ORDERS_PROBE_SQUADS=5" \
	"ORDERS_PROBE_ROUTES=click" "ORDERS_PROBE_ARMS=main:--probe-fight=on ${arm},--probe-fight=on" \
	"ORDERS_PROBE_SEEDS=$seeds" "ORDERS_PROBE_JOBS=$jobs" || { echo "BAR NOT RUN: fight"; exit 1; }
python3 tests/control/orders_group_judge.py "$out" main "${arm%%:*}" | tee "$out/verdict.txt"
echo "BAR_DONE"
