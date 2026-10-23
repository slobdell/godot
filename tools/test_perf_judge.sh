#!/usr/bin/env bash
# Known-answer tests for tools/perf_judge.sh's verdicts with a stub Godot (ship, round 18): PASS, FAIL, REFUSED, and
# the branch this exists for -- a run that prints PASS and then aborts at exit is a FAILED judgement, never a PASS.
set -u
pj="$(cd "$(dirname "$0")" && pwd)/perf_judge.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -12; }
export PERF_JUDGE_TRIES=2 PERF_JUDGE_WAIT=0 PERF_JUDGE_IDLE=0 PERF_JUDGE_LOCK="$tmp/lock" PERF_JUDGE_HOSTNAME=testhost
stub() {  # $1 = the line it prints, $2 = its exit
	printf '#!/usr/bin/env bash\necho "MEASURE ai_usec_per_tick 1234"\necho "  %s"\nexit %s\n' "$1" "$2" > "$tmp/godot"
	chmod +x "$tmp/godot"
}
judge() { out=$(bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?; }

stub "PASS  scenario_perf" 0; judge
[ $rc = 0 ] && grep -q 'JUDGED, PASS on attempt 1' <<<"$out" && ok "PASS, exit 0: judged PASS" || bad "pass" "$out"
stub "FAIL  scenario_perf (over budget)" 1; judge
[ $rc = 1 ] && grep -q 'FAILED the CPU budget' <<<"$out" && ok "FAIL: judged FAIL" || bad "fail" "$out"
stub "SCENARIO_NOT_JUDGED reason=busy" 0; judge
[ $rc = 3 ] && grep -q 'NOT JUDGED -- refused 2 times' <<<"$out" && ok "refused every time: NOT JUDGED (3)" || bad "refused" "$out"
stub "PASS  scenario_perf" 134; judge
[ $rc = 1 ] && grep -q 'FAILED -- the scenario run exited 134' <<<"$out" && grep -q 'state=CRASHED exit=134' "$tmp/out/perf-judge.txt" \
	&& ok "PASS printed, then exit 134: FAILED as a crash, never PASS" || bad "crash after pass" "$out"
stub "PASS  scenario_perf" 124; judge
[ $rc = 1 ] && grep -q 'exited 124' <<<"$out" && ok "a timeout (124) after PASS: FAILED" || bad "timeout" "$out"
# Round 37 (R37.20): builder2 refuses at once, with its reason, and never runs the scenario.
printf '#!/usr/bin/env bash\ntouch "%s/ran"\necho "  PASS  scenario_perf"\n' "$tmp" > "$tmp/godot"; chmod +x "$tmp/godot"; rm -f "$tmp/ran"
out=$(PERF_JUDGE_HOSTNAME=builder2 bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?
[ $rc = 3 ] && grep -q 'NOT JUDGED: builder2 is not a judging machine' <<<"$out" && [ ! -e "$tmp/ran" ] \
	&& ok "builder2: NOT JUDGED at once (3), the scenario never runs" || bad "builder2 refusal" "$out"
out=$(PERF_JUDGE_HOSTNAME=builder0 bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?
[ $rc = 0 ] && [ -e "$tmp/ran" ] && ok "builder0 still judges" || bad "builder0 judges" "$out"

# Round 38 (N3): the relative line, recorded beside the absolute (FAIL_RATIO 25,840 usec per reference ms), never deciding.
rel_stub() {  # $1 = the scenario's line, $2 = its usec per reference ms
	printf '#!/usr/bin/env bash\necho "MEASURE ai_usec_per_tick 9000"\necho "MEASURE ai_usec_per_ref_ms %s (x)"\necho "  %s"\necho "args: $*" > "%s/args"\n' \
		"$2" "$1" "$tmp" > "$tmp/godot"; chmod +x "$tmp/godot"
}
rel_stub "PASS  scenario_perf" 12000; judge
[ $rc = 0 ] && grep -q 'PERF_JUDGE_RELATIVE attempt=1 host=testhost absolute=PASS relative=PASS per_ref_ms=12000 line=25840' "$tmp/out/perf-judge.txt" \
	&& grep -q 'relative line (recorded, not deciding): PASS, 12000 usec per reference ms v 25840; agrees' <<<"$out" \
	&& ok "relative: both PASS, agrees, exit 0" || bad "relative agrees" "$out"
rel_stub "PASS  scenario_perf" 30000; judge
[ $rc = 0 ] && grep -q 'relative=FAIL' "$tmp/out/perf-judge.txt" && grep -q 'DISAGREES with the absolute' <<<"$out" \
	&& ok "relative FAIL beside an absolute PASS: recorded DISAGREES, the absolute still decides (0)" || bad "relative disagrees" "$out"
rel_stub "FAIL  scenario_perf (over budget)" 30000; judge
[ $rc = 1 ] && grep -q 'FAIL, 30000 usec per reference ms v 25840; agrees' <<<"$out" && ok "both FAIL: agrees, exit 1" || bad "both fail" "$out"
rel_stub "PASS  scenario_perf" 20000; out=$(PERF_JUDGE_FAIL_RATIO=15000 bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?
[ $rc = 0 ] && grep -q 'relative=FAIL per_ref_ms=20000 line=15000' "$tmp/out/perf-judge.txt" && ok "PERF_JUDGE_FAIL_RATIO moves the line" || bad "fail ratio env" "$out"
rel_stub "PASS  scenario_perf" 12000; out=$(PERF_JUDGE_HOSTNAME=builder2 PERF_JUDGE_TRIAL=1 bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?
[ $rc = 3 ] && [ "$(grep -c '^PERF_JUDGE_RELATIVE .*host=builder2 absolute=PASS relative=PASS.* trial=1' "$tmp/out/perf-judge.txt")" = 2 ] \
	&& grep -q -- '--perf-refuse=off' "$tmp/args" && grep -q 'TRIAL on builder2' <<<"$out" \
	&& ok "trial on builder2: runs every attempt with the nominal refusal off, records both lines, NOT JUDGED (3)" || bad "trial" "$out"
rel_stub "PASS  scenario_perf" 12000; out=$(PERF_JUDGE_HOSTNAME=builder2 PERF_JUDGE_NOT_JUDGING= bash "$pj" "$tmp/godot" 30 "$tmp/out" 2>&1); rc=$?
[ $rc = 0 ] && ok "PERF_JUDGE_NOT_JUDGING= (empty): builder2 judges" || bad "not-judging empty" "$out"

printf '\nperf-judge: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
