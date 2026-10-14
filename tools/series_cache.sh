#!/usr/bin/env bash
# Round 29 (traffic I3, builder0 throughput): a cache of judged-series ROWS. The sim is deterministic per (build, seed,
# start tick, flags) (trip-ups 28, 63), and every judged A/B re-ran main's unchanged base arm per stream. A row is reused
# only when its key matches EXACTLY:
#   tree   a content hash of everything a run reads: game/, native/src/, arenas/, doctrines/, project.godot,
#          export_presets.cfg, tests/support/, tests/tactics/, tests/traffic/ (the stage and probe: the "stage version"),
#          plus the Godot binary's name and the machine's glibc (builder0 and the laptop simulate differently, trip-up 63).
#          Content, not git: builder0's copy has no .git (tools/remote.sh excludes it).
#   row    the row's own arguments (arena, kind, which, seed, tick, seconds, flags), verbatim.
# Usage:
#   tools/series_cache.sh tree                      the tree hash for this checkout
#   tools/series_cache.sh key TREE ARGS...          the row key
#   tools/series_cache.sh get KEY OUT               copy a cached row to OUT; exit 1 on a miss
#   tools/series_cache.sh put KEY FILE              store a row (only a non-empty one that is not a "missing" row)
# SERIES_CACHE_DIR (default ~/.cache/tank_squad/series) holds them, OUTSIDE any worktree, so remote.sh's rsync --delete
# never touches them and every stream on the machine shares one cache.
set -euo pipefail
dir="${SERIES_CACHE_DIR:-$HOME/.cache/tank_squad/series}"
case "${1:-}" in
tree)
	cd "$(dirname "$0")/.."
	{
		find game native/src arenas doctrines tests/support tests/tactics tests/traffic -type f \
			\( -name '*.gd' -o -name '*.json' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o -name '*.tscn' \
			-o -name '*.tres' -o -name '*.txt' -o -name '*.cfg' \) 2>/dev/null | LC_ALL=C sort | xargs sha256sum
		sha256sum project.godot export_presets.cfg
		ls .tools/ 2>/dev/null | grep -i godot | LC_ALL=C sort
		ldd --version 2>&1 | head -1
	} | sha256sum | cut -c1-16 ;;
key)
	tree="$2"; shift 2
	printf '%s|%s' "$tree" "$*" | sha256sum | cut -c1-32 ;;
get)
	[ -s "$dir/$2.json" ] || exit 1
	cp "$dir/$2.json" "$3" ;;
put)
	[ -s "$3" ] && ! grep -q '"missing":true' "$3" || exit 0
	mkdir -p "$dir"
	cp "$3" "$dir/$2.json.tmp.$$" && mv "$dir/$2.json.tmp.$$" "$dir/$2.json" ;;
*)
	echo "usage: series_cache.sh tree | key TREE ARGS... | get KEY OUT | put KEY FILE" >&2; exit 2 ;;
esac
