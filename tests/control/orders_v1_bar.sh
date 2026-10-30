#!/usr/bin/env bash
# Round 46 (orders, Bar V1 THE VETO-ONLY GROUP GUARD): the parts on builder3 (the default REMOTE_HOST), read to a verdict
# (tests/control/orders_v1_judge.py). From round 45's orders_g2_bar.sh.
#   tests/control/orders_v1_bar.sh <frozen tree> <main tree> "<A seeds>" "<B seeds>" <out dir outside build/> [jobs]
# Arms: `base` (--group-veto=off) and `veto` (the frozen tree's default) on the frozen tree; `main` on main's tree (I1: the OFF
# path is main's). A geometry: gorge / locks / crossing / terminus x his / along / across x reach 20 / 80, fixed clicks (his
# Gorge click and either side of each west / east neck; his Locks clicks of rounds 43-44, beside the lock, on the swing bridge's
# deck) and his exact Gorge click with his three squads at their recorded starts. B streets: the orders probe's street cells
# (locks / crossing / terminus / yard_open x 3 / 5 squads x click / route). A part counts only with its wrapper's `exited 0`,
# every expected run and no MISSING line; else it re-runs (3 tries). Results copied OUT of build/ after each part.
set -u
frozen=${1:?} maintree=${2:?} aseeds=${3:?} bseeds=${4:?} out=${5:?} jobs=${6:-8}
mkdir -p "$out"
out=$(cd "$out" && pwd)
na=$(echo $aseeds | wc -w); nb=$(echo $bseeds | wc -w)
runs_in() { cat $(find "$1" -name runs.jsonl 2>/dev/null) 2>/dev/null | wc -l; }
errors_in() { cat $(find "$1" -name runs.jsonl 2>/dev/null) 2>/dev/null | grep -ac '^{"error"'; }
part() {  # part <tree> <name> <target> <dir var> <want> <make args...>
	local tree=${1:?} name=${2:?} target=$3 dirvar=$4 want=$5 try src got err; shift 5
	for try in 1 2 3; do
		(cd "$tree" && tools/remote.sh native "$target" "$dirvar=build/v1-$name" "$@" "TANK_SQUAD_SLOT_TIMEOUT=28800") > "$out/$name.log" 2>&1
		src="$tree/build/v1-$name"
		got=$(runs_in "$src"); err=$(errors_in "$src")
		if [ "$err" -gt 0 ]; then
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
fixed="gorge:spawn:-43.2/53.2 gorge:across:-40/58 gorge:across:-40/30 gorge:across:40/58 gorge:across:40/30 \
locks:his:-62/50 locks:his:-35/97 locks:his:-61/59 locks:his:-22/13 locks:his:-92/0"
n_fixed=10
cells=$((4 * 3 * 2 + n_fixed))
geometry() {  # geometry <tree> <prefix> <arms...>
	local tree=$1 prefix=$2; shift 2
	local narms=$#
	part "$tree" "${prefix}geometry" orders-geometry ORDERS_GEOMETRY_DIR $((cells * narms * na)) \
		"ORDERS_GEOMETRY_MAPS=gorge locks crossing terminus" "ORDERS_GEOMETRY_STARTS=his along across" "ORDERS_GEOMETRY_REACH=20 80" \
		"ORDERS_GEOMETRY_FIXED=$fixed" "ORDERS_GEOMETRY_ARMS=$*" "ORDERS_GEOMETRY_SEEDS=$aseeds" "ORDERS_GEOMETRY_JOBS=$jobs" || return 1
	part "$tree" "${prefix}his3" orders-geometry ORDERS_GEOMETRY_DIR $((narms * na)) "ORDERS_GEOMETRY_MAPS=" "ORDERS_GEOMETRY_STARTS=" \
		"ORDERS_GEOMETRY_FIXED=gorge:recorded:-43.2/53.2" "ORDERS_GEOMETRY_SQUADS=3" "ORDERS_GEOMETRY_ARMY=res://tests/control/orders_probe_gorge_his3.json" \
		"ORDERS_GEOMETRY_FLAGS=--probe-stand=res://tests/control/orders_probe_gorge_his3_starts.json" "ORDERS_GEOMETRY_ARMS=$*" \
		"ORDERS_GEOMETRY_SEEDS=$aseeds" "ORDERS_GEOMETRY_JOBS=$jobs" || return 1
	cp -r "$out/${prefix}his3/"*-r* "$out/${prefix}geometry/" 2>/dev/null
}
streets() {  # streets <tree> <prefix> <arms...>
	local tree=$1 prefix=$2; shift 2
	part "$tree" "${prefix}streets" orders-probe ORDERS_PROBE_DIR $((4 * 2 * 2 * $# * nb)) "ORDERS_PROBE_MAPS=locks crossing terminus yard_open" \
		"ORDERS_PROBE_SQUADS=3 5" "ORDERS_PROBE_ROUTES=click route" "ORDERS_PROBE_ARMS=$*" "ORDERS_PROBE_SEEDS=$bseeds" \
		"ORDERS_PROBE_JOBS=$jobs"
}
geometry "$frozen" "" "base:--group-veto=off" "veto:" || { echo "BAR NOT RUN: geometry"; exit 1; }
streets "$frozen" "" "base:--group-veto=off" "veto:" || { echo "BAR NOT RUN: streets"; exit 1; }
# I1: main's tree, one arm. Its probe has no veto fields (the judge reads only its places).
geometry "$maintree" "main-" "main:" || { echo "BAR NOT RUN: main geometry"; exit 1; }
streets "$maintree" "main-" "main:" || { echo "BAR NOT RUN: main streets"; exit 1; }
python3 "$(dirname "$0")/orders_v1_judge.py" "$out" | tee "$out/verdict.txt"
echo "BAR_DONE"
