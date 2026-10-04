#!/usr/bin/env bash
# Known-answer tests for check's perf-judge stage (mk/core.mk `check-perf-judge-stage`), driven through the REAL recipe
# with stub judges -- the test that should have existed before round 17's defect: under the Makefile's
# `.SHELLFLAGS := -eu -o pipefail`, `judge; s=$?` died on a refusal (exit 3) before `s=$?` ran, and the whole check
# stopped before any target. The stage must ALWAYS let check go on, and the verdict must say what the judge said:
#   exit 0 -> perf-judge PASS          (the check can still read ALL JUDGED)
#   exit 3 -> perf-judge NOT JUDGED    (with the judge's reason, or a default one if it recorded none)
#   exit 1 -> perf-judge FAIL          (a real budget failure is never a refusal)
# No Godot, a few seconds.
set -uo pipefail
unset TANK_SQUAD_SLOT_DIR
export TANK_SQUAD_SLOT=1   # already "inside a slot": the root Makefile runs the goal directly

repo="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# A stub judge: writes what perf_judge.sh would write, exits with the given status.
stub() {  # stub <exit> <with-reason: 1|0>
	local f="$tmp/judge-$1-$2.sh"
	cat > "$f" <<EOF
#!/usr/bin/env bash
mkdir -p "\$3"
: > "\$3/perf-judge.txt"
[ "$2" = 1 ] && echo ">> perf-judge: NOT JUDGED -- refused 3 times (ratios: 2.1x 2.2x 2.0x) in 300s: the box was truly busy" >> "\$3/perf-judge.txt"
exit $1
EOF
	chmod +x "$f"; echo "$f"
}

OTHERS="lint test web-smoke export-guard"   # stand-ins for the fan-out's targets, all marked done
B="$tmp/b"   # set here, not inside run_stage: that runs in $(...), a subshell
run_stage() {  # run_stage <judge> -> leaves $B/check with markers; prints the stage's exit status
	rm -rf "$B"; mkdir -p "$B/check/started" "$B/check/done" "$B/check/notjudged"
	( cd "$repo" && make -s --no-print-directory check-perf-judge-stage BUILD_DIR="$B" PERF_JUDGE_CMD="$1" >/dev/null 2>"$tmp/stage.err" ); echo $?
	for t in $OTHERS; do touch "$B/check/started/$t" "$B/check/done/$t"; done
}
verdict() { "$repo/tools/check_verdict.sh" "$B/check" perf-judge $OTHERS 2>&1; }

# ---- exit 3, reason recorded: the stage exits 0 and the verdict names the refusal ----------------------------------
rc=$(run_stage "$(stub 3 1)")
[ "$rc" = 0 ] && ok "a refusal (exit 3) does not stop check: the stage exits 0" || bad "refusal: stage exits 0" "exit $rc: $(cat "$tmp/stage.err")"
out=$(verdict); vrc=$?
grep -q '4 passed, 1 NOT JUDGED' <<<"$out" && ok "refusal: the other targets pass and perf-judge is NOT JUDGED" || bad "refusal: counts" "$out"
grep -qE 'NOT JUDGED perf-judge: NOT JUDGED -- refused 3 times' <<<"$out" && ok "refusal: the row carries the judge's reason" || bad "refusal: reason" "$out"
[ "$vrc" = 0 ] && ok "refusal: the check's verdict exits 0 (green with a named hole)" || bad "refusal: verdict exit 0" "exit $vrc"

# ---- exit 3, no reason recorded: still NOT JUDGED, with a default reason -------------------------------------------
rc=$(run_stage "$(stub 3 0)")
out=$(verdict)
[ "$rc" = 0 ] && grep -q '1 NOT JUDGED' <<<"$out" && grep -q 'recorded no reason' <<<"$out" \
	&& ok "refusal with no reason: NOT JUDGED with a default reason (pipefail cannot kill it)" || bad "refusal, no reason" "rc=$rc $out"

# ---- exit 1: a FAIL, never a refusal ---------------------------------------------------------------------------------
rc=$(run_stage "$(stub 1 0)")
out=$(verdict); vrc=$?
[ "$rc" = 0 ] && ok "a FAIL (exit 1) does not stop check either: the stage exits 0" || bad "fail: stage exits 0" "exit $rc"
grep -qE 'FAIL +perf-judge' <<<"$out" && ok "a judged FAIL reads FAIL, not NOT JUDGED" || bad "fail: row" "$out"
[ "$vrc" != 0 ] && ok "a judged FAIL makes the check's verdict non-zero" || bad "fail: verdict non-zero" "exit $vrc"
grep -q 'perf-judge exited 1' "$tmp/stage.err" && ok "the stage says the judge exited 1" || bad "fail: says so" "$(cat "$tmp/stage.err")"

# ---- exit 0: PASS, ALL JUDGED ----------------------------------------------------------------------------------------
rc=$(run_stage "$(stub 0 0)")
out=$(verdict)
[ "$rc" = 0 ] && grep -q 'all passed, ALL JUDGED' <<<"$out" && ok "a pass: ALL JUDGED" || bad "pass" "rc=$rc $out"

echo
echo "check-perf-judge: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
