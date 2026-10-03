#!/usr/bin/env bash
# scenario_perf, judged: first, alone, on the fast cores, in a quiet moment, and refused only when there is none.
# (ship W4, round 17.) Usage: tools/perf_judge.sh <godot> <sim_hz> <out_dir>
#
# WHY. scenario_perf refuses its CPU budget when its reference workload runs over 1.5x the machine's nominal
# (round 14). In rounds 15-16 it refused in most checks, and the last check of 7 of 17 builder0 folders was a
# refusal at 1.68-2.14x. `make perf-cores` (43390f5c, builder0, load 6.7-10.5) found why: builder0 is a hybrid
# i5-1345U, and on its E-cores (CPUs 4-11) the reference runs 1.76-1.93x the nominal EVERY time -- the nominal
# was recorded idle, where the scheduler gives a lone process a P-core. So a check refused whenever the scheduler
# parked the scenario on an E-core, which under five streams' load is most of the time; and on an E-core the
# brains read 17.7-21.7k usec a tick against a 20,000 fail line, so judging there would fail a healthy tree.
#
# WHAT. Pinned to the P-cores (taskset, from /sys/devices/cpu_core/cpus; every CPU on a machine without them),
# before the check fans out (so its own targets are not the load), and before each attempt it waits -- up to
# PERF_JUDGE_WAIT seconds -- for those cores to be mostly idle. Up to PERF_JUDGE_TRIES attempts; the scenario's own
# 1.5x refusal is untouched, so a busy box still REFUSES rather than lying, and the summary says so.
#
# OUT. <out_dir>/perf-judge.log (every attempt's full output), <out_dir>/perf-judge.txt (one PERF_JUDGE line per
# attempt + the verdict). Exit 0 = judged and passed; 1 = judged and FAILED the budget; 3 = refused every time.
set -uo pipefail
godot=$1 hz=$2 out=$3
tries=${PERF_JUDGE_TRIES:-3}
wait_s=${PERF_JUDGE_WAIT:-240}
idle_pct=${PERF_JUDGE_IDLE:-60}   # the P-cores count as quiet when at least this % idle over a 2 s sample
mkdir -p "$out"
: > "$out/perf-judge.log"
cpus=$(cat /sys/devices/cpu_core/cpus 2>/dev/null || echo "0-$(( $(nproc) - 1 ))")

# % idle of a cpulist over 2 s, from /proc/stat (idle + iowait over total).
idle_of() {
	local list=$1 a b
	expand() { local IFS=,; for r in $1; do case $r in *-*) seq "${r%-*}" "${r#*-}";; *) echo "$r";; esac; done; }
	snap() { for c in $(expand "$list"); do grep "^cpu$c " /proc/stat; done | awk '{t=0; for(i=2;i<=NF;i++) t+=$i; idle+=$5+$6; tot+=t} END {print idle, tot}'; }
	a=$(snap); sleep 2; b=$(snap)
	set -- $a $b
	awk -v i1="$1" -v t1="$2" -v i2="$3" -v t2="$4" 'BEGIN { d=t2-t1; printf "%d", (d > 0 ? 100*(i2-i1)/d : 0) }'
}

# One judgement at a time on the box: two checks arriving together would both pin the same four P-threads and slow each
# other into refusing. Machine-wide lock (flock, released when this script exits); the wait for it counts in the log.
lock=${PERF_JUDGE_LOCK:-/tmp/tank_squad_perf_judge.lock}
lock_t0=$(date +%s)
exec 9>"$lock"
if ! flock -w "${PERF_JUDGE_LOCK_WAIT:-600}" 9; then
	echo ">> perf-judge: NOT JUDGED -- another check held the perf lock for ${PERF_JUDGE_LOCK_WAIT:-600}s" | tee -a "$out/perf-judge.txt"
	exit 3
fi
lock_wait=$(( $(date +%s) - lock_t0 ))
[ "$lock_wait" -gt 0 ] && echo "PERF_JUDGE waited ${lock_wait}s for another check's judgement" | tee -a "$out/perf-judge.txt"

started=$(date +%s)
verdict=3
for attempt in $(seq 1 "$tries"); do
	waited=0
	idle=$(idle_of "$cpus")
	while [ "$idle" -lt "$idle_pct" ] && [ "$waited" -lt "$wait_s" ]; do
		sleep 10; waited=$(( waited + 12 )); idle=$(idle_of "$cpus")
	done
	load=$(cut -d' ' -f1 /proc/loadavg)
	t0=$(date +%s)
	run=$(taskset -c "$cpus" "$godot" --headless --fixed-fps "$hz" --path . --script res://tests/ai_scenarios/run_scenarios.gd -- \
		--filter=scenario_perf 2>&1)
	{ echo "==== attempt $attempt (cpus $cpus, ${idle}% idle after ${waited}s wait, load $load)"; echo "$run"; } >> "$out/perf-judge.log"
	ratio=$(echo "$run" | grep -oE 'perf_reference .*: [0-9.]+x' | grep -oE '[0-9.]+x$' | head -1)
	usec=$(echo "$run" | grep -oE 'MEASURE ai_usec_per_tick [0-9]+' | grep -oE '[0-9]+$' | head -1)
	per_ref=$(echo "$run" | grep -oE 'MEASURE ai_usec_per_ref_ms [0-9]+' | grep -oE '[0-9]+$' | head -1)
	if echo "$run" | grep -q 'SCENARIO_NOT_JUDGED'; then state=REFUSED
	elif echo "$run" | grep -qE '^\s*PASS\s+scenario_perf|PASS .*scenario_perf'; then state=PASS
	elif echo "$run" | grep -qE 'FAIL .*scenario_perf'; then state=FAIL
	else state=NO_RESULT; fi
	echo "PERF_JUDGE attempt=$attempt state=$state ratio=${ratio:-?} ai_usec_per_tick=${usec:-?} per_ref_ms=${per_ref:-?} cpus=$cpus idle=${idle}% waited=${waited}s load=$load run=$(( $(date +%s) - t0 ))s" | tee -a "$out/perf-judge.txt"
	case $state in
		PASS) verdict=0; break ;;
		FAIL) verdict=1; break ;;
	esac
done
total=$(( $(date +%s) - started ))
case $verdict in
	0) echo ">> perf-judge: JUDGED, PASS on attempt $attempt of $tries (${total}s)" ;;
	1) echo ">> perf-judge: JUDGED, FAILED the CPU budget on attempt $attempt (${total}s) -- see $out/perf-judge.log" ;;
	3) echo ">> perf-judge: NOT JUDGED -- refused $tries times (ratios: $(grep -oE 'ratio=[0-9.?x]+' "$out/perf-judge.txt" | tr '\n' ' ')) in ${total}s: the box was truly busy" ;;
esac | tee -a "$out/perf-judge.txt"
exit "$verdict"
