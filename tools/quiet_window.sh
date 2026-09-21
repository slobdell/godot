#!/usr/bin/env bash
# Watch a quiet window while a measurement runs in it, and say afterwards whether it actually held.
#
#     quiet_window.sh watch   <slot_dir> <root> <run_dir> <out.tsv> [interval_s]   # until killed
#     quiet_window.sh verdict <out.tsv>                                            # HELD | NOT USABLE
#     quiet_window.sh sample  <slot_dir> <root> <run_dir>                           # one line, for testing
#
# A frame-time measurement needs a quiet machine (lesson 179), and `slot.sh`'s TANK_SQUAD_EXCLUSIVE holds one
# by taking every slot. **Holding a window and having held one are different claims**, and only the second is
# evidence: a run launched outside the slots, a leftover Godot from a dropped wrapper, or somebody's hand-run
# command are all invisible to the lock and all fatal to a timing number. show's back-to-back pair once
# reported the instrumented arm 43% FASTER than its control on a loaded box -- noise swamping the effect, and
# nothing in the output said so.
#
# So the window is sampled while it is open, and the run's own summary carries the verdict:
#
# ---- NOT USABLE, exactly ------------------------------------------------------------------------
# The window did not hold, on any one of four stated bounds, each of which makes the number beside it
# unsafe to quote. The verdict names which one and by how much; it never says "probably".
#
#   1. another run was live on the box   -- any process whose cwd is in another worktree under <root>,
#                                           in any sample. Bound: 0.
#   2. a Godot outside this run was live -- any process whose executable is Godot and whose cwd is not
#                                           this run's, anywhere on the machine. Bound: 0.
#   3. load1 above a stated bound        -- QUIET_MAX_LOAD (default 4.0) in any sample. This INCLUDES
#                                           this run's own load: a timing number taken on a box at load 8
#                                           is not a quiet-box number even when every bit of the 8 is
#                                           ours, which is the case a foreign-process test cannot catch.
#   4. fewer than two samples            -- the window never opened, or NOBODY WATCHED IT. An unwatched
#                                           window is not a quiet one; absence of evidence must never
#                                           print as evidence, which is the failure this round kept
#                                           finding (`lint` over zero files, `arc_live=0.0s` for an
#                                           unpublished field, `check-hashes` "baseline unmoved" with no
#                                           data). Silence is the one that would go unnoticed.
#
#   HELD         every sample cleared all four. The load range is printed either way, because HELD says
#                nobody else RAN -- not that the machine was fast.
#
# Recording starts only once the window is OPEN -- every slot owner file names this folder and says
# EXCLUSIVE -- so the queueing beforehand, when other runs legitimately hold the box, is not counted
# against it.
set -uo pipefail

mode=${1:-}
[ -n "$mode" ] || { echo "usage: quiet_window.sh <watch|verdict|sample> ..." >&2; exit 2; }

# Processes whose cwd is under $root but NOT under $run_dir: another worktree's run, whether or not it went
# through the slots. cwd, not `ps` ancestry and not `pgrep -f` -- both of those have misled this project
# (remote_builds.md).
foreign_folders() {
	local root=$1 run_dir=$2 p cwd rel
	for p in /proc/[0-9]*; do
		cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
		case "$cwd" in "$root"/*) ;; *) continue ;; esac
		case "$cwd" in "$run_dir" | "$run_dir"/*) continue ;; esac
		rel=${cwd#"$root"/}
		echo "${rel%%/*}"
	done | sort -u
}

# Godot processes that are not ours, anywhere on the machine -- an editor someone left open, a hand-run
# match outside ~/tank_squad. Matched on the EXECUTABLE, never on a command line (`pgrep -f "Godot_v4.7.2"`
# matched the shell doing the searching and reported a phantom; squad, three times in one night).
foreign_godot() {
	local run_dir=$1 p exe cwd n=0
	for p in /proc/[0-9]*; do
		exe=$(readlink "$p/exe" 2>/dev/null) || continue
		case "${exe##*/}" in *[Gg]odot*) ;; *) continue ;; esac
		cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
		case "$cwd" in "$run_dir" | "$run_dir"/*) continue ;; esac
		n=$((n + 1))
	done
	echo "$n"
}

# Is the window open? Every live slot owner file names this folder and says EXCLUSIVE. Read from the owner
# files rather than from slot.sh's internals, because that is the artefact the rest of the system already
# publishes -- and if one of them names somebody else, the window is not ours by definition.
window_open() {
	local slot_dir=$1 name=$2 f any=0
	for f in "$slot_dir"/slot*.owner; do
		[ -e "$f" ] || continue
		grep -q "$name: EXCLUSIVE (quiet window)" "$f" 2>/dev/null || return 1
		any=1
	done
	[ "$any" = 1 ]
}

sample_line() {
	local slot_dir=$1 root=$2 run_dir=$3
	local load folders count
	load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
	folders=$(foreign_folders "$root" "$run_dir" | paste -sd, -)
	count=$(foreign_folders "$root" "$run_dir" | wc -l)
	printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$load" "$count" "$(foreign_godot "$run_dir")" "${folders:--}"
}

case "$mode" in
sample)
	sample_line "${2:?slot_dir}" "$(readlink -f "${3:?root}")" "$(readlink -f "${4:?run_dir}")"
	;;

watch)
	slot_dir=${2:?slot_dir}; root=$(readlink -f "${3:?root}"); run_dir=$(readlink -f "${4:?run_dir}")
	out=${5:?out}; interval=${6:-15}
	name=$(basename "$run_dir")
	: > "$out"
	printf '# quiet window for %s, sampled every %ss: epoch load1 foreign_runs foreign_godot folders\n' \
		"$name" "$interval" >> "$out"
	# Wait for the window to open, then record until killed. No timeout: the watcher's life is the run's,
	# and a window that never opens leaves a file with no samples, which the verdict reads as NOT USABLE.
	while ! window_open "$slot_dir" "$name"; do sleep 2; done
	while true; do
		sample_line "$slot_dir" "$root" "$run_dir" >> "$out"
		sleep "$interval"
	done
	;;

verdict)
	out=${2:?out}
	max_load=${QUIET_MAX_LOAD:-4.0}
	# NOT `grep -cv ... || echo 0`: grep exits 1 when the count is zero, so the fallback FIRES on the very
	# case it is there for and the variable becomes "0\n0" -- `[ "0 0" -lt 2 ]` then errors, the guard is
	# skipped, and a file with no samples at all printed HELD. Found by this file's own test. It is the
	# round's recurring defect inside the code written to prevent it: the failure path defaulted to the
	# reassuring answer.
	rows=$(grep -vc '^#' "$out" 2>/dev/null)
	case "$rows" in ''|*[!0-9]*) rows=0 ;; esac
	if [ "$rows" -lt 2 ]; then
		echo "QUIET WINDOW: NOT USABLE -- $rows sample(s). The window never opened, or nobody watched it;"
		echo "  either way nothing here says the box was quiet, and an unwatched window is not a quiet one."
		exit 1
	fi
	awk -F'\t' -v max_load="$max_load" '!/^#/ {
		n++
		if (min == "" || $2 + 0 < min) min = $2 + 0
		if (max == "" || $2 + 0 > max) max = $2 + 0
		if (first == "") first = $1
		last = $1
		if ($3 + 0 > 0) { bad++; if (who == "") who = $5; else if (index(who, $5) == 0) who = who "," $5 }
		if ($4 + 0 > 0) godot += $4
		if ($2 + 0 > max_load + 0) over++
	} END {
		# Belt and braces, deliberately. The guard above is the one that failed, and a verdict that can
		# print HELD when it counted nothing is the only outcome here that is worse than no verdict.
		if (n < 2) {
			printf "QUIET WINDOW: NOT USABLE -- %d sample(s) reached the verdict; nothing says the box was quiet.\n", n
			exit 1
		}
		span = last - first
		if (bad > 0) {
			printf "QUIET WINDOW: NOT USABLE -- another run was live on the box in %d of %d samples (%s).\n", bad, n, who
			printf "  The measurement ran beside it. Re-run it in a window that holds.\n"
			exit 1
		}
		if (godot > 0) {
			printf "QUIET WINDOW: NOT USABLE -- %d Godot process-samples outside this run during the window.\n", godot
			printf "  Something was rendering or simulating beside the measurement. Bound for this is 0.\n"
			exit 1
		}
		if (over > 0) {
			printf "QUIET WINDOW: NOT USABLE -- load1 was above %.2f in %d of %d samples (peak %.2f).\n", max_load + 0, over, n, max
			printf "  That bound counts this run OWN load too: a number taken on a busy box is not a quiet-box\n"
			printf "  number even when the box is busy with us. Raise it deliberately with QUIET_MAX_LOAD=.\n"
			exit 1
		}
		printf "QUIET WINDOW: HELD -- %d samples over %ds, this run alone on the box, load1 %.2f-%.2f (bound %.2f).\n", n, span, min, max, max_load + 0
		printf "  HELD says nobody else RAN. It does not say the machine was fast: read the load range too.\n"
	}' "$out"
	;;

*)
	echo "quiet_window.sh: unknown mode '$mode'" >&2; exit 2 ;;
esac
