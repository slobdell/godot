#!/usr/bin/env bash
# Round 43 (native, the orchestrator's ask after camera lost a 26-of-27 builder2 check): the BUILDER keeps its own copy of a
# remote run's output and its verdict line, so a laptop wrapper that dies (killed, its session's memory guard, a dropped
# ssh) never takes the verdict with it. Logs live OUTSIDE the synced folder (the next launch's rsync --delete would wipe
# build/): ~/<root>/remote-logs/<folder>-<target>-<stamp>.log, the newest REMOTE_LOG_KEEP (300) kept.
# Sourced by remote.sh's remote side:
#   remote_log_begin <dir> <folder> <make args...>   tee this shell's stdout and stderr into the log (tee -p: a reader
#                                                    that went away stops the copy to it, never the copy to the file)
#   remote_log_end <status> <make args...>           the verdict line, `>> builder: make <args> exited <status>`
# What it does not change: a lost session still stops its full check (tools/full_check_lock.sh, round 39); the log then
# ends with the lock's own "the session ... is gone: stopping this check".
remote_log_path() {
	local dir=$1 folder=$2; shift 2
	local what
	what=$(printf '%s' "$*" | tr -c 'A-Za-z0-9._=-' '_' | cut -c1-60)
	printf '%s/%s-%s-%s-%s.log\n' "$dir" "$folder" "${what:-none}" "$(date +%Y%m%d-%H%M%S)" "$$"
}

remote_log_prune() {
	local dir=$1 keep=${2:-300}
	ls -1t "$dir"/*.log 2>/dev/null | tail -n +$((keep + 1)) | while read -r old; do rm -f -- "$old"; done
}

remote_log_begin() {
	local dir=$1 folder=$2; shift 2
	mkdir -p "$dir" || return 0
	REMOTE_LOG=$(remote_log_path "$dir" "$folder" "$@")
	remote_log_prune "$dir" "${REMOTE_LOG_KEEP:-300}"
	exec > >(tee -p -a "$REMOTE_LOG") 2> >(tee -p -a "$REMOTE_LOG" >&2)
	echo ">> builder: this run's output is also in $(hostname -s):$REMOTE_LOG" >&2
}

remote_log_end() {
	local status=$1; shift
	echo ">> builder: make $* exited $status (log $REMOTE_LOG)"
}
