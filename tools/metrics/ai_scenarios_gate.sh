#!/usr/bin/env bash
# The ai-scenarios gate: compare a run's summary line against the committed baseline.
#
#     ai_scenarios_gate.sh check  <log> <baseline>      # exit 0 pass, 1 fail; prints the verdict
#     AI_SCENARIOS_REASON="..." ai_scenarios_gate.sh record <log> <out> [commit]   # write a new baseline
#
# It lives in a script rather than in the make recipe it came from because **this gate has already been wrong
# once** (2026-09-20): it inherited a 2% coin landing heads as its expectation and would have failed `main` at
# random. Buried in a recipe it could not be exercised without Godot and a full scenario run; here its
# comparison is driven by fixture logs in milliseconds, which is how the mistake would have been caught.
#
# ---- Only the NON-PENDING counts are gated ------------------------------------------------------
#
# The runner prints `scenarios: P passed, F failed, N pending, U unexpectedly passing`. A PENDING scenario is
# one the file itself declares is EXPECTED to fail (`const PENDING := [...]`), so:
#
#   * `passed,failed` are the gate -- a new script error moves them and is caught (lesson 159);
#   * `pending,unexpectedly_passing` are REPORTED and never fail it -- a known-failing scenario that passes by
#     luck must not redden eight streams' checks (lesson 42). Reported, because a pending behaviour that starts
#     working is news worth promoting; just not news worth failing a gate over.
set -uo pipefail

mode=${1:-}; log=${2:-}; other=${3:-}
[ -n "$mode" ] && [ -n "$log" ] && [ -n "$other" ] || {
	echo "usage: ai_scenarios_gate.sh <check|record> <log> <baseline|out> [commit]" >&2; exit 2; }

# The summary line, or a refusal. An absent line is a crashed or refused run, NOT a clean one, and must never
# read as "nothing changed" -- absence is not a measurement.
line=$(grep -E '^scenarios: ' "$log" 2>/dev/null | tail -1)
if [ -z "$line" ]; then
	echo "ai-scenarios FAILED: the runner printed no summary line at all."
	echo "  That is a crashed or refused run, not a clean one -- the last 20 lines of $log:"
	tail -20 "$log" 2>/dev/null | sed 's/^/    /'
	exit 1
fi
counts=$(echo "$line" | grep -oE '[0-9]+' | paste -sd,)

if [ "$mode" = record ]; then
	# WHY the counts moved, IN THE FILE rather than only in a commit message. Checked before the redirect
	# below, because `{ ... } > "$other"` truncates first and a refused record must damage nothing.
	#
	# A baseline that records a number without its cause is the shape this gate already failed once: `45,0,2,0`
	# was a 2% coin, and nothing in the file said what had been true when it was taken. Re-recording is exactly
	# the moment the reason is known, and the only moment it is cheap.
	if [ -z "${AI_SCENARIOS_REASON:-}" ]; then
		echo "REFUSED to record a baseline with no reason." >&2
		echo "  Set AI_SCENARIOS_REASON to what moved the counts and why that is correct." >&2
		echo "  Counts that would have been written: $counts" >&2
		exit 2
	fi
	{
		echo "# ai-scenarios counts: passed,failed,pending,unexpectedly_passing"
		echo "# ONLY THE FIRST TWO ARE GATED. ai-scenarios-check fails when passed,failed CHANGE, not when a"
		echo "# scenario fails: one perf case is laptop-speed-sensitive and would redden the gate for a reason"
		echo "# that is not a defect (lesson 42), while a new script error moves \`failed\` and is caught (159)."
		echo "# pending,unexpectedly_passing are reported and never fail the gate: a PENDING scenario is one we"
		echo "# EXPECT to fail, and one that passes by luck must not redden eight streams' checks. That is not"
		echo "# hypothetical -- this baseline's first version recorded a 2% coin landing heads on dodge_rate."
		echo "# machine: $(hostname 2>/dev/null || echo unknown)"
		echo "# commit:  ${4:-${TANK_SQUAD_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}}"
		echo "# line:    $line"
		echo "# reason:  $AI_SCENARIOS_REASON"
		echo "$counts"
	} > "$other"
	cat "$other"
	echo "recorded $counts on $(hostname 2>/dev/null || echo unknown) in $other"
	exit 0
fi

expected=$(grep -v '^#' "$other" 2>/dev/null | grep -v '^$' | head -1 | cut -d' ' -f1)
if [ -z "$expected" ]; then
	echo "ai-scenarios-check FAILED: no baseline in $other."
	echo "  Record one with: make ai-scenarios-record   (counts now: $counts)"
	exit 1
fi

gated=$(echo "$counts"   | cut -d, -f1,2); want=$(echo "$expected"       | cut -d, -f1,2)
loose=$(echo "$counts"   | cut -d, -f3,4); want_loose=$(echo "$expected" | cut -d, -f3,4)

if [ "$gated" != "$want" ]; then
	echo "ai-scenarios-check FAILED: the non-pending counts CHANGED."
	echo "  expected (passed,failed): $want        [pending,unexpectedly_passing: $want_loose, not gated]"
	echo "  got:                      $gated        [pending,unexpectedly_passing: $loose]"
	echo "  baseline was recorded on: $(sed -n 's/^# machine: *//p' "$other" | head -1)"
	echo "  baseline commit:          $(sed -n 's/^# commit: *//p' "$other" | head -1)"
	echo "  this machine: $(hostname 2>/dev/null || echo unknown)"
	echo "  $line"
	grep -E '^  (FAIL|UNEXPECTED PASS)' "$log" | sed 's/^/    /' | head -20
	echo "  If the change is intended, re-record with 'make ai-scenarios-record' and say why in the commit."
	exit 1
fi

if [ "$loose" != "$want_loose" ]; then
	echo "ai-scenarios-check: $line"
	echo "  gate PASSED ($gated unchanged), but pending,unexpectedly_passing moved $want_loose -> $loose."
	echo "  A PENDING scenario that starts passing should be PROMOTED (delete it from that file's const"
	echo "  PENDING); the runner then fails the run on UNEXPECTED PASS, which is the point."
	grep -E '^  UNEXPECTED PASS' "$log" | sed 's/^/    /' | head -10
	exit 0
fi

echo "ai-scenarios-check: $line (non-pending counts $gated unchanged against $other)"
exit 0
