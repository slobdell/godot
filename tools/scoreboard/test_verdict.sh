#!/usr/bin/env bash
# Known answers for tools/scoreboard/verdict.sh (round 36: a preempted builder2 run must not become a row).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

good_log() {
	printf '%s\n' '>> remote: make native scoreboard-run on slobdell@builder2' '>> scoreboard-run done: 40 fights, 48 moves, 36 orders runs' \
		'>> remote: copy-back verified, 216 files, sha256' '>> remote: make native scoreboard-run exited 0 (build/ copied back)'
}
good_run() {
	printf '%s\n' ">> scoreboard-run on builder2 | commit ${1:-abc123def} | native on | parts 'fights moves orders' | load 1 1 1" \
		'>> scoreboard-run done: 40 fights, 48 moves, 36 orders runs'
}
case_() { # name, want (0 counted / 1 not), args...
	local name=$1 want=$2; shift 2
	local out; out=$(bash "$here/verdict.sh" "$@" 2>&1); local got=$?
	if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $name: exit $got, want $want: $out"; fi
}

good_log > "$tmp/ok.log"; good_run > "$tmp/ok.txt"
case_ "a whole run counts" 0 "$tmp/ok.log" "$tmp/ok.txt" abc123def

# The 2026-10-20 preemption, verbatim in shape: 255, copy-back FAILED, and the local run.txt an earlier main's.
printf '%s\n' '>> remote: make native scoreboard-run on slobdell@builder2' '>> remote: FAILED to copy build/ back (rsync exit 255); local build/ is STALE, not this run'"'"'s' \
	'>> remote: make native scoreboard-run exited 255 (build/ copied back: FAILED)' > "$tmp/preempt.log"
good_run 1c82d6d1e > "$tmp/stale.txt"
case_ "preempted: 255 and a stale run.txt" 1 "$tmp/preempt.log" "$tmp/stale.txt" e45bb6632
case_ "a stale run.txt under a clean log" 1 "$tmp/ok.log" "$tmp/stale.txt" e45bb6632

head -1 "$tmp/ok.log" > "$tmp/killed.log"
case_ "killed: no exited line" 1 "$tmp/killed.log" "$tmp/ok.txt" abc123def
sed 's/exited 0 (build\/ copied back)/exited 2 (build\/ copied back)/' "$tmp/ok.log" > "$tmp/red.log"
case_ "the make target failed" 1 "$tmp/red.log" "$tmp/ok.txt" abc123def
grep -v 'copy-back verified' "$tmp/ok.log" > "$tmp/unverified.log"
case_ "the copy-back unverified" 1 "$tmp/unverified.log" "$tmp/ok.txt" abc123def
{ cat "$tmp/ok.log"; echo '>> scoreboard-run: moves NOT RUN'; } > "$tmp/notrun.log"
case_ "a target NOT RUN" 1 "$tmp/notrun.log" "$tmp/ok.txt" abc123def
head -1 "$tmp/ok.txt" > "$tmp/partial.txt"
case_ "run.txt without its done line" 1 "$tmp/ok.log" "$tmp/partial.txt" abc123def
sed 's/40 fights/31 fights/' "$tmp/ok.txt" > "$tmp/short.txt"
case_ "fewer fights than the workload" 1 "$tmp/ok.log" "$tmp/short.txt" abc123def
case_ "a missing run.txt" 1 "$tmp/ok.log" "$tmp/none.txt" abc123def
sed 's/40 fights, 48 moves, 36 orders/1 fights, 1 moves, 1 orders/' "$tmp/ok.txt" > "$tmp/smoke.txt"
case_ "a smoke (EXPECT any) counts" 0 "$tmp/ok.log" "$tmp/smoke.txt" abc123def any
sed 's/40 fights, 48 moves, 36 orders/1 fights, 0 moves, 1 orders/' "$tmp/ok.txt" > "$tmp/smoke0.txt"
case_ "a smoke with an empty part" 1 "$tmp/ok.log" "$tmp/smoke0.txt" abc123def any

sed 's/scoreboard-run exited 0/scoreboard-run SCORE_SEED_BASE=2700 exited 0/' "$tmp/ok.log" > "$tmp/vars.log"
case_ "a second seed block (make variables before exited)" 0 "$tmp/vars.log" "$tmp/ok.txt" abc123def
sed 's/scoreboard-run exited 0 (build\/ copied back)/scoreboard-run SCORE_SEED_BASE=2700 exited 255 (build\/ copied back: FAILED)/' "$tmp/ok.log" > "$tmp/vars255.log"
case_ "a second seed block preempted" 1 "$tmp/vars255.log" "$tmp/ok.txt" abc123def

echo "scoreboard verdict: $pass passed, $fail failed"
[ "$fail" = 0 ]
