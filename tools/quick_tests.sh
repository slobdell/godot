#!/usr/bin/env bash
# Round 29 (traffic I2, builder0 throughput): the test files a diff touches, as a `make test` FILTER ("stem::|stem::").
# `make quick` runs them (plus lint and one smoke) for a worker's in-between commits; `make check` stays the gate for
# any hash named for merge.
#
# The diff: QUICK_BASE (default: the merge-base with main) ... HEAD, plus uncommitted changes. A test file is picked when
#   - it changed itself (tests/**/test_*.gd), or
#   - it names a changed game script: the script's class_name as a word, or its res:// path, or
#   - tests/quick_neighbours.txt declares it for a changed path (a line "glob<TAB>stem stem ...": a neighbour the
#     search cannot see, e.g. a test that drives the changed code only through a scene).
# QUICK_FILES="a.gd b.gd" asks what a change to those files would run (no diff read).
# Prints nothing when the diff touches no test (then `make quick` runs lint and the smoke only, and says so).
set -euo pipefail
cd "$(dirname "$0")/.."
base="${QUICK_BASE:-$(git merge-base HEAD main 2>/dev/null || git rev-parse HEAD)}"
# QUICK_FILES (space-separated paths) replaces the diff: what a change to those files would run.
if [ -n "${QUICK_FILES:-}" ]; then changed=$(tr ' ' '\n' <<< "$QUICK_FILES" | sort -u)
else changed=$( { git diff --name-only "$base" HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u); fi
declare -A stems=()
add() { stems["$1"]=1; }
tests_list=$(find tests -name 'test_*.gd' | sort)
while IFS= read -r path; do
	[ -n "$path" ] || continue
	case "$path" in
	tests/*test_*.gd)
		[ -f "$path" ] && add "$(basename "$path" .gd)" ;;
	game/*.gd|assets/*.gd)
		[ -f "$path" ] || continue
		cls=$(grep -m1 -oP '^class_name\s+\K\w+' "$path" || true)
		hits=()
		while IFS= read -r t; do
			[ -n "$t" ] || continue
			if { [ -n "$cls" ] && grep -qw "$cls" "$t"; } || grep -qF "res://$path" "$t"; then hits+=("$(basename "$t" .gd)"); fi
		done <<< "$tests_list"
		# A core class (Match, Movement, Tank...) is named by a large share of the suite: then only the tests NAMED for
		# the script (its file stem in the test's name) run here; the rest are check's.
		if [ "${#hits[@]}" -gt "${QUICK_MAX_PER_SCRIPT:-30}" ]; then
			stem=$(basename "$path" .gd)
			echo "quick: $path is named by ${#hits[@]} test files; running only those named *$stem* (and its neighbours)" >&2
			for h in "${hits[@]}"; do [[ "$h" == *"$stem"* ]] && add "$h"; done
		else
			for h in "${hits[@]}"; do add "$h"; done
		fi ;;
	esac
	if [ -f tests/quick_neighbours.txt ]; then
		while IFS=$'\t' read -r glob names; do
			case "$glob" in ''|'#'*) continue ;; esac
			# shellcheck disable=SC2053
			if [[ "$path" == $glob ]]; then for n in $names; do add "$n"; done; fi
		done < tests/quick_neighbours.txt
	fi
done <<< "$changed"
[ "${#stems[@]}" -gt 0 ] || exit 0
printf '%s\n' "${!stems[@]}" | sort | sed 's/$/::/' | paste -sd'|'
