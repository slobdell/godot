#!/usr/bin/env bash
# Refuse to rsync a worktree onto the build box while that worktree's own previous run is still live there.
#
# WHY (2026-09-20). `remote.sh`'s launch rsync runs `--delete`, so a second `make remote` from the same worktree
# replaces the tree the FIRST run is reading, mid-run. Two runs died that way in one morning: nav's `check` on
# `96bbf38e` was voided, and scale lost a 62-minute fairness run overnight. It is trip-up 66 in
# `_agents/remote_builds.md`, and until now the only defence was remembering it.
#
# ---- The marker file is PRINTED, never BELIEVED ------------------------------------------------
#
# The obvious implementation is a lock file, and the obvious implementation is the bug we already have:
# `slot.sh`'s `slot<N>.owner` outlived its process and made dead holders look alive to every waiter for as long
# as anyone cared to read it (remote_builds.md, "stale .owner"). A second file with the same failure mode would
# block a worktree out of its own build box until a human deleted it by hand.
#
# So the marker decides nothing. **/proc decides.** A run is live iff:
#
#   * some process has its cwd inside the run directory -- which covers the whole dangerous span, including the
#     forty minutes a run can spend QUEUED in slot.sh (it has already `cd`-ed in by then), or
#   * a claim is younger than the TTL -- the launch window between "the rsync started" and "a process exists".
#
# The first test is the ownership test remote_builds.md settles on after three misfires in one night: `ps`
# ancestry lies (nine sessions share one PPID), `pgrep -f` lies (it matches the searching shell), `readlink
# /proc/<pid>/cwd` does not. The second is the only place a file is trusted, it is bounded by the TTL, and it
# errs towards refusing rather than towards destroying a run.
#
# A marker whose process is gone is stale, is reported as stale, and blocks nobody.
#
#   remote_guard.sh check   <guard_dir> <run_dir> <label>   # exit 0 claimed, 9 busy (REMOTE_FORCE=1 claims anyway)
#   remote_guard.sh adopt   <guard_dir> <run_dir> <pid>     # the run itself, once it exists: claimed -> running
#   remote_guard.sh release <guard_dir> <run_dir>
#   remote_guard.sh report  <guard_dir> <run_dir>           # say what is live there; never writes
#
# <run_dir> may be relative, and is then taken as relative to $HOME -- so the caller can pass the same
# `tank_squad/godot-<stream>` it passes to rsync, without having to expand a remote $HOME through ssh quoting.
set -uo pipefail

mode=${1:-}
guard_dir=${2:-}
run_dir=${3:-}
arg=${4:-}
[ -n "$mode" ] && [ -n "$guard_dir" ] && [ -n "$run_dir" ] || {
	echo "usage: remote_guard.sh <check|adopt|release|report> <guard_dir> <run_dir> [label|pid]" >&2; exit 2; }

case "$run_dir" in /*) ;; *) run_dir="$HOME/$run_dir" ;; esac
# Canonical, because /proc/<pid>/cwd is canonical: one symlink in the path would make every comparison below
# fail open -- the direction that destroys a run. `readlink -f` resolves a path whose last component does not
# exist yet, which is the first run into a fresh folder.
run_dir=$(readlink -f "$run_dir" 2>/dev/null || echo "$run_dir")
name=$(basename "$run_dir")
marker="$guard_dir/run.$name.owner"
lock="$guard_dir/run.$name.lock"
ttl=${REMOTE_CLAIM_TTL:-300}
PROC_LINES=${REMOTE_GUARD_PROC_LINES:-6}   # how much of a live process tree a refusal prints
# How a reader sees the rest. `$0` cannot answer that: this script arrives on builder0 over stdin, so it is
# literally called "bash" there -- a refusal that told you to run `bash report ...` would be useless advice.
STATUS_CMD=${REMOTE_GUARD_STATUS_CMD:-tools/remote.sh --status}

# Every process whose cwd is the run directory or below it, excluding this script and its own ancestors (a
# search that finds itself is the `pgrep -f` phantom that has now misled this project three times).
procs_in_run_dir() {
	local p pid cwd self
	self=" $$ $PPID "
	for p in /proc/[0-9]*; do
		pid=${p##*/}
		case "$self" in *" $pid "*) continue ;; esac
		cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
		# Exact directory or a path below it. The trailing slash matters: without it `godot-metrics-old`
		# would read as a live run of `godot-metrics`.
		case "$cwd" in "$run_dir" | "$run_dir"/*) echo "$pid" ;; esac
	done
}

# One line per live process: pid, when it started, what it is. Start time comes from ps because that is what a
# reader needs to decide "is this mine, and how long has it had?".
describe_procs() {
	local pids
	pids=$(procs_in_run_dir | tr '\n' ' ')
	[ -n "${pids// /}" ] || return 1
	# shellcheck disable=SC2086
	ps --sort=start_time -o pid=,lstart=,args= -p $pids 2>/dev/null | cut -c1-160
	return 0
}

marker_field() { [ -f "$marker" ] && sed -n "s/^$1=//p" "$marker" | head -1; }
marker_age()   { echo $(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || echo 0) )); }

write_marker() {   # $1 state  $2 pid  $3 label
	mkdir -p "$guard_dir" 2>/dev/null
	{
		echo "state=$1"
		echo "pid=$2"
		echo "launched=$(date '+%Y-%m-%d %H:%M:%S')"
		echo "host=$(hostname 2>/dev/null || echo unknown)"
		echo "label=$3"
	} > "$marker.tmp.$$" && mv -f "$marker.tmp.$$" "$marker"
}

case "$mode" in
report)
	if procs=$(describe_procs); then
		echo "LIVE $run_dir"
		echo "$procs"
	else
		echo "IDLE $run_dir"
	fi
	if [ -f "$marker" ]; then
		echo "marker $marker:"
		sed 's/^/  /' "$marker"
		# The verdict, never left to the reader. An `.owner` file naming a dead pid looks exactly like
		# one naming a live pid, which is the whole trap this guard is built around.
		mpid=$(marker_field pid); mstate=$(marker_field state)
		if [ "$mstate" = claimed ]; then
			age=$(marker_age)
			if [ "$age" -lt "$ttl" ]; then echo "  -> CLAIMED ${age}s ago, still inside the ${ttl}s launch window"
			else echo "  -> STALE: a claim ${age}s old, past the ${ttl}s launch window; it blocks nobody"; fi
		elif [ -n "$mpid" ] && kill -0 "$mpid" 2>/dev/null; then
			echo "  -> pid $mpid is alive"
		else
			echo "  -> STALE: pid ${mpid:-none} is gone; it blocks nobody"
		fi
	fi
	exit 0
	;;

check)
	mkdir -p "$guard_dir" 2>/dev/null || { echo ">> guard: cannot create $guard_dir" >&2; exit 2; }
	# Check-and-claim must be one step, or two launches seconds apart both see an idle directory and both
	# rsync into it. This lock is held for the length of THIS check only -- it is not the run's lock; the run
	# is held by its own processes, which is the only thing that survives a dropped ssh.
	exec 9>"$lock" || { echo ">> guard: cannot open $lock" >&2; exit 2; }
	flock -w 10 9 || { echo ">> guard: another launch holds $lock (waited 10s)" >&2; exit 9; }

	busy=""; why=""; procs=""
	if procs=$(describe_procs); then
		busy=1; why="processes are running in $run_dir"
	elif [ "$(marker_field state)" = claimed ]; then
		age=$(marker_age)
		if [ "$age" -lt "$ttl" ]; then
			busy=1; why="another launch claimed this directory ${age}s ago and is still rsyncing (TTL ${ttl}s)"
		fi
	fi

	if [ -n "$busy" ]; then
		{
			echo ">> remote: $name already has a live run on this build box -- $why"
			[ -f "$marker" ] && sed 's/^/     /' "$marker"
			if [ -n "$procs" ]; then
				# A sharded check holds twenty-five processes, so the top of the tree is what a reader
				# needs; the rest is shards and their Godots. The COUNT is printed either way, because a
				# truncated list that does not say it is truncated is its own small lie.
				n=$(echo "$procs" | wc -l)
				echo "     $n processes live in $run_dir, oldest first:"
				echo "$procs" | head -"$PROC_LINES" | sed 's/^/     /'
				[ "$n" -gt "$PROC_LINES" ] && echo "     ... and $((n - PROC_LINES)) more -- all of them, with start times: $STATUS_CMD"
			fi
		} >&2
		if [ -z "${REMOTE_FORCE:-}" ]; then
			{
				echo ">> remote: REFUSING to launch. The rsync would --delete and replace the files that run is"
				echo ">>   reading, and its result would be void (trip-up 66: nav lost a check and scale lost a"
				echo ">>   62-minute run this way on 2026-09-20)."
				echo ">> Wait for it ($STATUS_CMD), or stop it on the box by cwd-verified PID"
				echo ">> (never by pattern -- seven checkouts run the same commands), or destroy it deliberately:"
				echo ">>   REMOTE_FORCE=1 <re-run what you just ran>${arg:+   # }${arg:+$arg}"
			} >&2
			exit 9
		fi
		echo ">> remote: REMOTE_FORCE=1 -- overwriting that run's files; its results become void" >&2
	fi

	write_marker claimed "" "$arg"
	exit 0
	;;

adopt)
	# The run now exists and /proc can speak for it; the claim's TTL stops mattering from here.
	[ -n "$arg" ] || { echo ">> guard: adopt needs a pid" >&2; exit 2; }
	write_marker running "$arg" "$(marker_field label)"
	exit 0
	;;

release)
	rm -f "$marker"
	exit 0
	;;

*)
	echo "remote_guard.sh: unknown mode '$mode'" >&2; exit 2 ;;
esac
