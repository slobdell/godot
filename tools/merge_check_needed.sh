#!/usr/bin/env bash
# Does a merge on main need its own `make check`, or does it inherit a branch's green check? (round 31, the lead's
# "we seem mostly blocked on builds": several main checks that day re-tested trees identical to a checked one.)
#
#   tools/merge_check_needed.sh <checked-commit> [<merged-commit>=HEAD]
#
# Exit 0 + "INHERIT": every file a check can read is byte-identical between the commit whose check went green and the
#   merged tree, so main inherits that check. Record "main <merged> inherits <checked>'s check" in HANDOFF.md.
# Exit 1 + "CHECK": something a check can read differs (usually main moved after the branch's check was cut), so
#   run `make remote T=check` on main as before. The differing paths are listed.
# Exit 2: usage or an unknown commit.
#
# What is ignored is ONLY what no check target reads, as found by grepping tests/ tools/ mk/ for runtime reads:
# HANDOFF.md, every *.md under _agents/ EXCEPT the two docs tests read (tactical_map.md by test_control_panel.gd,
# ui_kit.md by tests/garage/test_ui_kit.gd), and the reference folders (judged rows; the judge tools that read them
# run at the close, not in check). If a new test starts reading a doc, add it to READ_BY_TESTS below.
set -euo pipefail
checked=${1:-}; merged=${2:-HEAD}
[ -n "$checked" ] || { echo "usage: tools/merge_check_needed.sh <checked-commit> [<merged-commit>]" >&2; exit 2; }
git rev-parse --verify -q "$checked^{commit}" >/dev/null || { echo "unknown commit: $checked" >&2; exit 2; }
git rev-parse --verify -q "$merged^{commit}" >/dev/null || { echo "unknown commit: $merged" >&2; exit 2; }

READ_BY_TESTS=("_agents/tactical_map.md" "_agents/ui_kit.md")

diffs=()
while IFS= read -r path; do
	[ -n "$path" ] || continue
	case "$path" in
		HANDOFF.md|references/*|_agents/streams/references/*) continue ;;
	esac
	if [[ "$path" == _agents/*.md || "$path" == _agents/*/*.md || "$path" == _agents/*/*/*.md ]]; then
		keep=0
		for r in "${READ_BY_TESTS[@]}"; do [ "$path" = "$r" ] && keep=1; done
		[ "$keep" -eq 1 ] || continue
	fi
	diffs+=("$path")
done < <(git diff --name-only "$checked" "$merged")

if [ "${#diffs[@]}" -eq 0 ]; then
	echo "INHERIT: $(git rev-parse --short "$merged") differs from $(git rev-parse --short "$checked") only in docs no check reads"
	exit 0
fi
echo "CHECK: $(git rev-parse --short "$merged") differs from $(git rev-parse --short "$checked") in ${#diffs[@]} file(s) a check can read:"
printf '  %s\n' "${diffs[@]:0:20}"
[ "${#diffs[@]}" -le 20 ] || echo "  ... and $(( ${#diffs[@]} - 20 )) more"
exit 1
