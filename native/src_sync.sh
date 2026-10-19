#!/usr/bin/env bash
# Round 35 (native N3, R35.15): make a source change rebuild, whatever its mtime says.
#
#   src_sync.sh check  NATIVE_DIR SUMS   touch every input whose CONTENT differs from SUMS (new files too; a removed
#                                        file, or no SUMS at all, touches every input), so cmake's mtime test sees it as
#                                        newer than its objects
#   src_sync.sh record NATIVE_DIR SUMS   write SUMS (after a successful build only: a failed build re-touches next time)
#
# Inputs: NATIVE_DIR/src/** and NATIVE_DIR/CMakeLists.txt, by path relative to NATIVE_DIR. Why: a remote run built the
# library from the pre-merge tree, then the merge arrived by `rsync -a`, which keeps the SOURCE's older mtimes, so the
# objects looked newer, cmake rebuilt nothing and a full check ran on a stale library (brains, 2026-10-19).
set -euo pipefail
mode=${1:?check|record}; dir=${2:?NATIVE_DIR}; sums=${3:?SUMS}

current() { (cd "$dir" && { find src -type f; [ -e CMakeLists.txt ] && echo CMakeLists.txt; } | LC_ALL=C sort | xargs -r -d '\n' sha256sum); }

case "$mode" in
record)
	mkdir -p "$(dirname "$sums")"
	current > "$sums.tmp" && mv "$sums.tmp" "$sums"
	;;
check)
	if [ ! -s "$sums" ]; then
		# no record: a fresh tree, or one built before this check existed, whose objects may be stale: touch everything
		(cd "$dir" && current | sed 's/^[0-9a-f]*  //' | xargs -r -d '\n' touch)
		echo "src-sync: no record of the last build's sources: every input touched (a full rebuild, once)"
		exit 0
	fi
	now=$(current)
	changed=$(LC_ALL=C comm -13 <(LC_ALL=C sort "$sums") <(LC_ALL=C sort <<<"$now") | sed 's/^[0-9a-f]*  //')
	removed=$(LC_ALL=C comm -23 <(sed 's/^[0-9a-f]*  //' "$sums" | LC_ALL=C sort) <(sed 's/^[0-9a-f]*  //' <<<"$now" | LC_ALL=C sort))
	n=$(( $(grep -c . <<<"$changed" || true) + $(grep -c . <<<"$removed" || true) ))
	if [ -n "$removed" ]; then
		# an object can still hold the removed file's code: rebuild everything that remains
		(cd "$dir" && sed 's/^[0-9a-f]*  //' <<<"$now" | xargs -r -d '\n' touch)
		echo "src-sync: $n changed (removed: $(tr '\n' ' ' <<<"$removed")); every input touched"
	elif [ -n "$changed" ]; then
		(cd "$dir" && xargs -r -d '\n' touch <<<"$changed")
		echo "src-sync: $n changed since the last build, touched: $(tr '\n' ' ' <<<"$changed")"
	else
		echo "src-sync: 0 changed"
	fi
	;;
*) echo "src_sync.sh: check|record" >&2; exit 2 ;;
esac
