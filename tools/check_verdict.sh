#!/usr/bin/env bash
# Every target's verdict after a `make check`, from the markers its wrappers leave.
#
#     check_verdict.sh <check_dir> <target> [<target> ...]
#
# WHY (2026-09-20). `check` handed its list to one `make -j` WITHOUT `-k`, so the first failure stopped the
# rest from starting. Two combat checks in a row therefore produced **no `sim-baseline` reading at all** --
# the one number that gates every merge went missing behind an unrelated shard failure, and the log said
# nothing about it. A target that never ran and a target that passed looked identical from the outside:
# absence reading as a measurement, again.
#
# So `check` now keeps going, and this renders what actually happened. Three states, not two, because
# "failed" and "never got to run" call for different responses and the difference is knowable:
#
#   PASS     started and finished
#   FAIL     started and did not finish
#   NOT RUN  never started -- skipped because something it was ordered after failed (lint gates everything;
#            the three exclusion pairs gate each other)
#
# CHECK_VERDICT_CONTEXT is appended to the summary line. It exists because `test_match_spawns_and_results`
# was measured passing at 6 shards and failing at 5, with identical game and test code -- and `TEST_SHARDS`
# is derived per run from free memory, so the schedule, and that test's verdict, is partly a property of how
# busy the box was at launch (2026-09-20, lesson 178's sharper form). The number that decides the schedule
# therefore has to travel with the verdict: a reader comparing two runs must be able to see, from the line
# they quote, whether the two are comparable at all.
#
# Exit 0 only when every target passed.
set -uo pipefail

dir=${1:-}
shift || true
[ -n "$dir" ] && [ $# -gt 0 ] || { echo "usage: check_verdict.sh <check_dir> <target>..." >&2; exit 2; }

passed=0; failed=0; notrun=0
fail_list=""; notrun_list=""
lines=""
for t in "$@"; do
	if [ -e "$dir/done/$t" ]; then
		passed=$((passed + 1)); lines="$lines$(printf '   PASS     %s\n' "$t")"$'\n'
	elif [ -e "$dir/started/$t" ]; then
		failed=$((failed + 1)); fail_list="$fail_list $t"
		lines="$lines$(printf '   FAIL     %s\n' "$t")"$'\n'
	else
		notrun=$((notrun + 1)); notrun_list="$notrun_list $t"
		lines="$lines$(printf '   NOT RUN  %s\n' "$t")"$'\n'
	fi
done

# Only the interesting rows, unless everything passed -- a wall of PASS buries the one line that matters.
ctx=${CHECK_VERDICT_CONTEXT:-}
[ -n "$ctx" ] && ctx="  [$ctx]"
if [ "$failed" -eq 0 ] && [ "$notrun" -eq 0 ]; then
	printf '>> check: %d targets, all passed%s\n' "$passed" "$ctx"
	exit 0
fi
printf '>> check: %d passed, %d FAILED, %d NOT RUN%s\n' "$passed" "$failed" "$notrun" "$ctx"
printf '%s' "$lines" | grep -v '   PASS  '
[ -n "$fail_list" ]   && printf '>> check: failed: %s\n' "${fail_list# }"
if [ -n "$notrun_list" ]; then
	printf '>> check: never ran:%s\n' "$notrun_list"
	printf '>> check:   a NOT RUN target is not a passing one. It was skipped because a target it is\n'
	printf '>> check:   ordered after failed -- lint gates every other target, and the three port/path\n'
	printf '>> check:   exclusion pairs gate each other.\n'
fi
exit 1
