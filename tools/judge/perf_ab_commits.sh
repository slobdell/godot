#!/usr/bin/env bash
# Round 39 (native, the orchestrator's ask): perf-judge on builder0 for two or more COMMITS, alternating, so the box's
# drift (load, thermal, a kernel update) lands on every arm. Run on the laptop: tools/judge/perf_ab_commits.sh A B [C ...]
#
# Each commit gets a detached worktree of its own beside this one (../<this folder>-ab-<sha>, made once, reused), so it
# gets its own builder0 folder; each round runs `make remote T="native perf-judge"` from each in turn, the order rotating
# round to round (A B, B A, ... for two). PERF_AB_ROUNDS (3) rounds. perf-judge keeps its own pin, quiet wait and retries.
# OUT: build/perf-ab/summary.txt: one PERF_AB line per run (the judged PERF_JUDGE line), then each arm's mean and the
# paired difference of each arm from the first. The worktrees are left for reuse: `git worktree remove` them after.
set -uo pipefail
[ $# -ge 2 ] || { echo "usage: tools/judge/perf_ab_commits.sh <commit> <commit> [...]" >&2; exit 2; }
root=$(git rev-parse --show-toplevel)
rounds=${PERF_AB_ROUNDS:-3}
out=${PERF_AB_OUT:-$root/build/perf-ab}   # outside build/ if this worktree will run make remote meanwhile (its copy-back deletes)
mkdir -p "$out"
: > "$out/summary.txt"
say() { echo "$*" | tee -a "$out/summary.txt"; }
shas=()
for c in "$@"; do
	sha=$(git rev-parse --short=9 "$c^{commit}") || exit 2
	wt="$root-ab-$sha"
	[ -d "$wt" ] || git worktree add -q --detach "$wt" "$sha" || exit 2
	[ "$(git -C "$wt" rev-parse --short=9 HEAD)" = "$sha" ] || { echo "$wt is not at $sha" >&2; exit 2; }
	shas+=("$sha")
done
n=${#shas[@]}
say "PERF_AB arms ${shas[*]} rounds $rounds (builder0, make remote T=\"native perf-judge\")"
for r in $(seq 1 "$rounds"); do
	for k in $(seq 0 $((n - 1))); do
		sha=${shas[$(( (k + r - 1) % n ))]}
		wt="$root-ab-$sha"
		log="$out/$r-$sha.log"
		make -C "$wt" --no-print-directory remote T="native perf-judge" > "$log" 2>&1
		verdict=$(grep -E '^>> remote: make .* exited [0-9]+' "$log" | tail -1)
		line=$(grep -E '^PERF_JUDGE attempt=.* state=(PASS|FAIL) ' "$wt/build/perf-judge/perf-judge.txt" 2>/dev/null | tail -1)
		if [ -n "$line" ]; then say "PERF_AB round=$r arm=$sha $line"
		else say "PERF_AB round=$r arm=$sha NOT JUDGED (${verdict:-no verdict line}): $(tail -1 "$wt/build/perf-judge/perf-judge.txt" 2>/dev/null)"; fi
	done
done
python3 - "$out/summary.txt" "${shas[@]}" <<'EOF' | tee -a "$out/summary.txt"
import re, sys, statistics as st
arms = sys.argv[2:]
runs = {}
for l in open(sys.argv[1]):
    m = re.search(r'round=(\d+) arm=(\w+) PERF_JUDGE .*ai_usec_per_tick=(\d+) per_ref_ms=(\d+)', l)
    if m:
        runs.setdefault(m[2], {})[int(m[1])] = (int(m[3]), int(m[4]))
for a in arms:
    v = list(runs.get(a, {}).values())
    if v:
        print(f"PERF_AB mean arm={a} n={len(v)} ai_usec_per_tick={st.mean(x[0] for x in v):.0f} "
              f"(sd {st.pstdev([x[0] for x in v]):.0f}) per_ref_ms={st.mean(x[1] for x in v):.0f} (sd {st.pstdev([x[1] for x in v]):.0f})")
base = runs.get(arms[0], {})
for a in arms[1:]:
    rs = [r for r in runs.get(a, {}) if r in base]
    if rs:
        d = [runs[a][r][0] - base[r][0] for r in rs]; dr = [runs[a][r][1] - base[r][1] for r in rs]
        print(f"PERF_AB paired {a}-{arms[0]} n={len(rs)} ai_usec_per_tick {st.mean(d):+.0f} (per round {d}) "
              f"per_ref_ms {st.mean(dr):+.0f} (per round {dr})")
EOF
