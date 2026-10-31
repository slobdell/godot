#!/usr/bin/env bash
# Round 47 (orders O2, Bars O and O2, R47.4 / R47.15 / R47.21): his group click, OFF (`--group-merged=off`) v the merged arm
# (`--group-merged=on`) and the all arm (`--group-merged=all`), on builder3, read to a verdict.
#   tests/control/orders_o_bar.sh "<merged seeds>" "<his seeds>" "<identity seeds>" <out dir outside build/> [jobs]
# Parts (every one `--probe-merge=on` but identity):
#   merged    locks crossing terminus yard_open sumps x 2 / 3 squads x click            (deciding D1 D2, guards G1-G3, G5)
#   his_x     crossing, his click (80.9, 49.5), 2 squads                                   (reported with D1)
#   his_l     locks, his click (-81.6, 45.7), 2 squads                                     (reported with D1)
#   identity  locks crossing terminus x 2 / 3 squads x click / route, NOT merged         (G4: ON == OFF, place for place)
# A part counts only with its wrapper's `exited 0`, a runs.jsonl holding every expected run and no MISSING line (3 tries).
set -u
merged_seeds=$1 his_seeds=$2 id_seeds=$3 out=$4 jobs=${5:-8}
cd "$(dirname "$0")/../.."
mkdir -p "$out"
part() {  # part <name> <maps> <squads> <routes> <arms> <seeds> <expected runs>
	local name=$1 maps=$2 squads=$3 routes=$4 arms=$5 seeds=$6 want=$7 try src=build/orders-bar-$1
	for try in 1 2 3; do
		tools/remote.sh native orders-probe "ORDERS_PROBE_MAPS=$maps" "ORDERS_PROBE_SQUADS=$squads" "ORDERS_PROBE_ROUTES=$routes" \
			"ORDERS_PROBE_ARMS=$arms" "ORDERS_PROBE_SEEDS=$seeds" "ORDERS_PROBE_DIR=$src" "ORDERS_PROBE_JOBS=$jobs" \
			"TANK_SQUAD_SLOT_TIMEOUT=14400" > "$out/$name.log" 2>&1
		# Bar O's first series: an errored run ("no RtsControls") is a row too; only a run with its map counts (Bar O2).
		local got=$(grep -c '"map"' "$src/runs.jsonl" 2>/dev/null || echo 0)
		if grep -aq ">> remote: make native orders-probe.*exited 0" "$out/$name.log" && [ "$got" -eq "$want" ] \
				&& ! grep -aq "^MISSING" "$out/$name.log"; then
			rm -rf "$out/$name" && cp -r "$src" "$out/$name"
			echo "PART $name OK: $got of $want runs (try $try)"
			return 0
		fi
		echo "PART $name NOT COMPLETE (try $try): runs $got of $want"
	done
	return 1
}
n() { echo $1 | wc -w; }
# Bar O2 (R47.37): every arm runs manoeuvre's no-progress census (G6).
C="--noprogress-census"
OFF="off:--group-merged=off,--probe-merge=on,$C"
ON="on:--group-merged=on,--probe-merge=on,$C"
part merged "locks crossing terminus yard_open sumps" "2 3" click "$OFF $ON" "$merged_seeds" $((5 * 2 * 2 * $(n "$merged_seeds"))) \
	|| { echo "BAR NOT RUN: merged"; exit 1; }
part his_x crossing 2 click "$OFF,--probe-click=80.9/49.5 $ON,--probe-click=80.9/49.5" "$his_seeds" $((2 * $(n "$his_seeds"))) \
	|| { echo "BAR NOT RUN: his_x"; exit 1; }
part his_l locks 2 click "$OFF,--probe-click=-81.6/45.7 $ON,--probe-click=-81.6/45.7" "$his_seeds" $((2 * $(n "$his_seeds"))) \
	|| { echo "BAR NOT RUN: his_l"; exit 1; }
part identity "locks crossing terminus" "2 3" "click route" "off:--group-merged=off,$C on:--group-merged=on,$C" "$id_seeds" $((3 * 2 * 2 * 2 * $(n "$id_seeds"))) \
	|| { echo "BAR NOT RUN: identity"; exit 1; }
# Amendment 2 (R47.15, before any number): the `all` arm (the double file on every 2-3 squad click, `--group-merged=all`) is
# DECIDING on the same lines (G4 does not apply: it changes unmerged clicks by design), on the merged corpus NOT merged, and his
# Locks click as a box-select (his_l_all, READ beside D1).
part all "locks crossing terminus yard_open sumps" "2 3" click "off:--group-merged=off,$C all:--group-merged=all,$C" "$merged_seeds" \
	$((5 * 2 * 2 * $(n "$merged_seeds"))) || { echo "BAR NOT RUN: all"; exit 1; }
part his_l_all locks 2 click "off:--group-merged=off,$C,--probe-click=-81.6/45.7 all:--group-merged=all,$C,--probe-click=-81.6/45.7" \
	"$his_seeds" $((2 * $(n "$his_seeds"))) || { echo "BAR NOT RUN: his_l_all"; exit 1; }
# G7 (manoeuvre's guard): test_manoeuvre_noprogress on this tree (its sliver case is "same as main": M2b is on its branch).
tools/remote.sh test FILTER=test_manoeuvre_noprogress > "$out/g7_noprogress.log" 2>&1
grep -aE ">> remote: make test.*exited|[0-9]+ passed, [0-9]+ failed" "$out/g7_noprogress.log" | tail -2
python3 tests/control/orders_o_judge.py "$out" off on | tee "$out/verdict.txt"
python3 tests/control/orders_o_judge.py --all "$out" off all | tee "$out/verdict_all.txt"
echo "BAR_DONE"
