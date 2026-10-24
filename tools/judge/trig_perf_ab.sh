#!/usr/bin/env bash
# Round 39 (native, the orchestrator's ask after main 76f42a9c3): what N4's native trig costs the brains, by removal.
# Usage: tools/judge/trig_perf_ab.sh <godot> <sim_hz> <out_dir>   (driven by `make trig-perf-ab`, on a quiet builder0)
#
# On glibc >= 2.41 (the builders) the preload never applies, so the only thing N4 changed there is that libtank_native
# calls its own CORE-MATH atan2f/acosf/asinf/atanf/tanf instead of libm's (the same results). The two arms are that
# library built both ways: cr (as shipped) and libm (NATIVE_TRIG=libm, the five left out). Each round runs perf-judge
# (tools/perf_judge.sh, pinned, quiet-waiting, its own retries) once per arm, the order alternating round to round
# (cr libm, libm cr, ...) so a drift in the box's load lands on both. TRIG_AB_ROUNDS (3) rounds; the library is left cr.
# OUT: <out_dir>/<round>-<arm>/perf-judge.txt and <out_dir>/summary.txt (one TRIG_AB line per judged run, then the means).
set -uo pipefail
godot=$1 hz=$2 out=$3
rounds=${TRIG_AB_ROUNDS:-3}
so=native/bin/libtank_native.linux.x86_64.so
mkdir -p "$out"
: > "$out/summary.txt"
say() { echo "$*" | tee -a "$out/summary.txt"; }
build() {
	make --no-print-directory native NATIVE_TRIG="$1" > "$out/build-$1.log" 2>&1 || { tail -20 "$out/build-$1.log"; return 1; }
	local imported
	imported=$(nm -D --undefined-only "$so" | grep -oE ' (atan2f|acosf|asinf|atanf|tanf)(@|$)' | tr -d ' @' | sort | tr '\n' ' ')
	case $1 in
		cr) [ -z "$imported" ] || { say "TRIG_AB arm cr imports libm's ($imported): not the cr arm"; return 1; } ;;
		libm) [ -n "$imported" ] || { say "TRIG_AB arm libm imports none of the five: not the libm arm"; return 1; } ;;
	esac
	say "TRIG_AB built $1 (libm imports: ${imported:-none})"
}
say "TRIG_AB commit ${TANK_SQUAD_COMMIT:-$(git rev-parse --short=9 HEAD 2>/dev/null)} host $(hostname) rounds $rounds"
status=0
for r in $(seq 1 "$rounds"); do
	if [ $((r % 2)) -eq 1 ]; then order="cr libm"; else order="libm cr"; fi
	for arm in $order; do
		build "$arm" || { status=1; break 2; }
		d="$out/$r-$arm"
		PERF_JUDGE_TRIES=${PERF_JUDGE_TRIES:-3} tools/perf_judge.sh "$godot" "$hz" "$d" > /dev/null 2>&1
		line=$(grep -E '^PERF_JUDGE attempt=.* state=(PASS|FAIL) ' "$d/perf-judge.txt" | tail -1)
		if [ -n "$line" ]; then say "TRIG_AB round=$r arm=$arm $line"
		else say "TRIG_AB round=$r arm=$arm NOT JUDGED: $(tail -1 "$d/perf-judge.txt")"; fi
	done
done
build cr >/dev/null || status=1
python3 - "$out/summary.txt" <<'EOF' | tee -a "$out/summary.txt"
import re, sys, statistics as st
runs = {}
for l in open(sys.argv[1]):
    m = re.search(r'round=(\d+) arm=(\w+) PERF_JUDGE .*ai_usec_per_tick=(\d+) per_ref_ms=(\d+)', l)
    if m:
        runs.setdefault(m[2], {})[int(m[1])] = (int(m[3]), int(m[4]))
for arm in ('cr', 'libm'):
    v = list(runs.get(arm, {}).values())
    if v:
        print(f"TRIG_AB mean arm={arm} n={len(v)} ai_usec_per_tick={st.mean(x[0] for x in v):.0f} "
              f"(sd {st.pstdev([x[0] for x in v]):.0f}) per_ref_ms={st.mean(x[1] for x in v):.0f} (sd {st.pstdev([x[1] for x in v]):.0f})")
pairs = [(runs['cr'][r], runs['libm'][r]) for r in runs.get('cr', {}) if r in runs.get('libm', {})]
if pairs:
    d = [c[0] - l[0] for c, l in pairs]; dr = [c[1] - l[1] for c, l in pairs]
    print(f"TRIG_AB paired cr-libm n={len(pairs)} ai_usec_per_tick {st.mean(d):+.0f} (per round {d}) "
          f"per_ref_ms {st.mean(dr):+.0f} (per round {dr})")
EOF
exit $status
