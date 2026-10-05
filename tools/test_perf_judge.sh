#!/usr/bin/env bash
# Known-answer tests for tools/perf_judge.sh's verdicts with a stub Godot (ship, round 18): PASS, FAIL, REFUSED, and
# the branch this exists for -- a run that prints PASS and then aborts at exit is a FAILED judgement, never a PASS.
set -u
pj="$(cd "$(dirname "$0")" && pwd)/perf_judge.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -12; }
export PERF_JUDGE_TRIES=2 PERF_JUDGE_WAIT=0 PERF_JUDGE_IDLE=0 PERF_JUDGE_LOCK="$tmp/lock"
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

printf '\nperf-judge: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
