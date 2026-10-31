#!/usr/bin/env bash
# Spotter S0: THE NIGHT SHIFT. Runs on builder3 by itself (cron, no Claude session, no quota) whenever the box is idle, and leaves
# results a person or a fresh agent can read in the morning: ~/spotter-night/<date>/SUMMARY.md.
#
#   night.sh tick      what cron runs every 5 min: if the box has been idle NIGHT_IDLE_MIN minutes, run batches until it is busy
#   night.sh status    what it is doing, what holds the box, the last batches, the disk
#   night.sh stop      stop the running batch now and keep it stopped (touch state/STOP); `night.sh start` clears it
#   night.sh start     clear the STOP
#
# IDLE means: nobody holds the full-check lock (~/tank_squad/.full-check.lock) and no process of anyone else's runs in a
# ~/tank_squad/<folder> (a check, a quick-remote, a judged series, a light run, a render, a queued check waiting on the lock:
# they all run there). The batch runs `nice -n 19 ionice -c3` in its own process group; a watcher asks the same question every
# NIGHT_POLL_S seconds while it runs and, the moment the answer is "busy", kills the whole group (it YIELDS: it never takes the
# full-check lock or a slot). A killed fight leaves only a .part file; the next idle window re-runs it (each finished fight is a
# checkpoint).
#
# WHAT RUNS: main's game at a NAMED commit (refs/heads/green in ~/spotter-night/repo.git, pushed by `make spotter-night-push
# SHA=<green hash>`; else origin/main as GitHub has it), checked out clean into ~/tank_squad/spotter-night, with the spotter kit
# (tools/spotter, tests/spotter, mk/spotter.mk, installed by `make spotter-night-install`) laid over it. The game code is the named
# commit's; the kit is dev tooling. Each batch: NIGHT_MAPS x the next NIGHT_SEEDS_PER_BATCH seeds of 13121-13216 (R47.40), then
# the rank over every fight of that commit -> ~/spotter-night/<date>/<commit>/, and SUMMARY.md rewritten (the checkpoint).
#
# DISK: ~/spotter-night is kept under NIGHT_CAP_GB (20 GB; builder3 had 154 GB free on 2026-10-30): the oldest date folders go
# first, never today's. The fights' jsonl are gzipped once ranked.
set -uo pipefail

NIGHT=${NIGHT_HOME:-$HOME/spotter-night}
TREE=${NIGHT_TREE:-$HOME/tank_squad/spotter-night}
SQUAD=${NIGHT_SQUAD:-$HOME/tank_squad}
REPO=$NIGHT/repo.git
KIT=$NIGHT/kit
STATE=$NIGHT/state
IDLE_MIN=${NIGHT_IDLE_MIN:-10}
POLL_S=${NIGHT_POLL_S:-10}
CAP_GB=${NIGHT_CAP_GB:-20}
JOBS=${NIGHT_JOBS:-10}
MAPS=${NIGHT_MAPS:-terminus crossing locks sumps gorge parade}
SECONDS_PER_FIGHT=${NIGHT_FIGHT_S:-240}
PER_BATCH=${NIGHT_SEEDS_PER_BATCH:-2}
SEED_FIRST=${NIGHT_SEED_FIRST:-13121}
SEED_LAST=${NIGHT_SEED_LAST:-13216}
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH

mkdir -p "$STATE"
log() { echo "$(date '+%F %T %Z') $*" >>"$STATE/night.log"; }

busy_reason() { # prints why the box is busy (nothing when idle)
	local lock=$SQUAD/.full-check.lock
	if [ -e "$lock" ] && ! flock -n "$lock" true 2>/dev/null; then echo "full-check lock: $(head -1 "$lock" 2>/dev/null)"; return; fi
	local p c
	for p in /proc/[0-9]*; do
		c=$(readlink "$p/cwd" 2>/dev/null) || continue
		case "$c" in
		"$TREE" | "$TREE"/*) ;;
		"$SQUAD"/*) echo "$(cat "$p/comm" 2>/dev/null) (pid ${p#/proc/}) in ${c#"$SQUAD"/}"; return ;;
		esac
	done
}

pick_commit() { # the named commit to run: refs/heads/green, else origin/main
	git --git-dir="$REPO" fetch -q origin main:refs/remotes/origin/main 2>/dev/null || true
	git --git-dir="$REPO" rev-parse -q --verify refs/heads/green 2>/dev/null ||
		git --git-dir="$REPO" rev-parse -q --verify refs/remotes/origin/main 2>/dev/null
}

prepare_tree() { # $1 = commit: a clean checkout of it + the kit, the import cache kept
	local sha=$1
	if [ "$(cat "$TREE/.spotter-commit" 2>/dev/null)" = "$sha:$(cat "$KIT/.kit-commit" 2>/dev/null)" ]; then return 0; fi
	if [ ! -d "$TREE" ]; then
		mkdir -p "$TREE"
		# Seed the import cache and the native build from main's folder: a cold import is long (remote_builds.md).
		[ -d "$SQUAD/godot/.godot" ] && cp -a "$SQUAD/godot/.godot" "$TREE/" 2>/dev/null
		[ -d "$SQUAD/godot/native/build" ] && mkdir -p "$TREE/native" && cp -a "$SQUAD/godot/native/build" "$TREE/native/" 2>/dev/null
	fi
	# The tree's own index (the bare repo has none): read-tree writes the commit's files, clean drops anything else.
	export GIT_INDEX_FILE=$NIGHT/tree.index
	git --git-dir="$REPO" --work-tree="$TREE" read-tree --reset -u "$sha" 2>>"$STATE/night.log" || return 1
	git --git-dir="$REPO" --work-tree="$TREE" clean -q -fdx -e .godot -e native/build -e native/bin -e .tools -e build \
		-e local.mk -e override.cfg -e .spotter-commit 2>>"$STATE/night.log"
	unset GIT_INDEX_FILE
	ln -sfn "$SQUAD/.tools" "$TREE/.tools"
	# The kit over the named tree (dev tooling only; the game files are the commit's).
	mkdir -p "$TREE/tools/spotter" "$TREE/tests/spotter" "$TREE/mk"
	cp -a "$KIT/tools/spotter/." "$TREE/tools/spotter/"
	cp -a "$KIT/tests/spotter/." "$TREE/tests/spotter/"
	cp -a "$KIT/mk/spotter.mk" "$TREE/mk/spotter.mk"
	# Its own ports, so a night fight never shares one with a stream's smoke (none of the batch opens one; belt and braces).
	printf 'WEB_PORT := 8980\nNET_PORT := 9980\nSMOKE_PORT := 8981\nSMOKE_NET_PORT := 9981\nAGENT_PORT := 9985\n' >"$TREE/local.mk"
	echo "$sha:$(cat "$KIT/.kit-commit" 2>/dev/null)" >"$TREE/.spotter-commit"
	log "tree: $sha (kit $(cat "$KIT/.kit-commit" 2>/dev/null)) checked out in $TREE"
}

next_seeds() { # $1 = fights dir: the next PER_BATCH seeds with any fight not finished
	local dir=$1 seed arena out=() missing
	for ((seed = SEED_FIRST; seed <= SEED_LAST; seed++)); do
		missing=0
		for arena in $MAPS; do [ -s "$dir/$arena-$seed.jsonl" ] || [ -s "$dir/$arena-$seed.jsonl.gz" ] || missing=1; done
		[ $missing = 1 ] && out+=("$seed")
		[ ${#out[@]} -ge "$PER_BATCH" ] && break
	done
	echo "${out[*]}"
}

prune_disk() {
	local today used
	today=$(date +%F)
	while used=$(du -s --block-size=1G "$NIGHT" 2>/dev/null | cut -f1) && [ "$used" -gt "$CAP_GB" ]; do
		local oldest
		oldest=$(find "$NIGHT" -maxdepth 1 -type d -name '20[0-9][0-9]-*' ! -name "$today" | sort | head -1)
		[ -n "$oldest" ] || { log "disk: ${used} GB > cap ${CAP_GB} GB and nothing old to remove"; break; }
		log "disk: ${used} GB > cap ${CAP_GB} GB: removing $oldest"
		rm -rf "$oldest"
	done
}

summary() { # $1 = date dir, $2 = commit dir
	python3 "$TREE/tools/spotter/summary.py" "$1" --state "$STATE" >>"$STATE/night.log" 2>&1 || log "summary failed"
}

run_batch() { # $1 = commit dir, $2.. = seeds; returns 0 done, 10 yielded, other = failed
	local cdir=$1
	shift
	local seeds="$*" pgid rc reason
	mkdir -p "$cdir/fights"
	log "batch: seeds '$seeds' maps '$MAPS' -> $cdir"
	(
		cd "$TREE" || exit 1
		# TANK_SQUAD_SLOT=night: past the Makefile's slot gate, so a night batch never takes (or queues for) a check's slot.
		exec setsid nice -n 19 ionice -c3 env TANK_SQUAD_SLOT=night TANK_SQUAD_COMMIT="$(cut -d: -f1 "$TREE/.spotter-commit" | cut -c1-9)" \
			make --no-print-directory spotter-batch SPOT_DIR="$cdir/fights" SPOT_SEEDS="$seeds" SPOT_MAPS="$MAPS" \
			SPOT_SECONDS="$SECONDS_PER_FIGHT" SPOT_JOBS="$JOBS" >>"$cdir/batch.log" 2>&1
	) &
	pgid=$!
	echo "$pgid" >"$STATE/batch.pid"
	while kill -0 "$pgid" 2>/dev/null; do
		sleep "$POLL_S"
		reason=$(busy_reason)
		if [ -n "$reason" ] || [ -e "$STATE/STOP" ]; then
			[ -e "$STATE/STOP" ] && reason="STOP"
			log "yield: $reason: stopping the batch (pgid $pgid)"
			echo "$(date '+%F %T %Z') $reason" >>"$cdir/yields.txt"
			kill -TERM -- -"$pgid" 2>/dev/null
			sleep 5
			kill -KILL -- -"$pgid" 2>/dev/null
			wait "$pgid" 2>/dev/null
			rm -f "$STATE/batch.pid"
			return 10
		fi
	done
	wait "$pgid"
	rc=$?
	rm -f "$STATE/batch.pid"
	return $rc
}

tick() {
	exec 9>"$STATE/runner.lock"
	flock -n 9 || exit 0 # a runner is already working
	[ -e "$STATE/STOP" ] && exit 0
	local reason
	reason=$(busy_reason)
	if [ -n "$reason" ]; then
		date +%s >"$STATE/last_busy"
		echo "$reason" >"$STATE/last_busy_reason"
		exit 0
	fi
	local last now
	last=$(cat "$STATE/last_busy" 2>/dev/null || echo 0)
	now=$(date +%s)
	[ $((now - last)) -ge $((IDLE_MIN * 60)) ] || exit 0
	[ -d "$KIT" ] || { log "no kit: run make spotter-night-install"; exit 0; }
	local sha
	sha=$(pick_commit) || { log "no commit to run"; exit 0; }
	prepare_tree "$sha" || { log "tree: checkout of $sha failed"; exit 0; }
	echo $$ >"$STATE/runner.pid"
	local day cdir seeds rc
	while true; do
		[ -e "$STATE/STOP" ] && break
		[ -n "$(busy_reason)" ] && break
		prune_disk
		day=$NIGHT/$(date +%F)
		cdir=$day/${sha:0:9}
		seeds=$(next_seeds "$cdir/fights")
		if [ -z "$seeds" ]; then
			[ -e "$cdir/.complete" ] || { log "commit ${sha:0:9}: every seed $SEED_FIRST-$SEED_LAST done today"; touch "$cdir/.complete"; }
			break
		fi
		run_batch "$cdir" $seeds
		rc=$?
		if [ $rc = 10 ]; then
			date +%s >"$STATE/last_busy"
			break
		fi
		[ $rc = 0 ] || log "batch exited $rc (see $cdir/batch.log)"
		# Checkpoint: the fights are ranked (spotter-batch); squeeze them and rewrite the morning page.
		find "$cdir/fights" -name '*.jsonl' -exec gzip -qf {} \; 2>/dev/null
		summary "$day" "$cdir"
		log "batch done: seeds '$seeds' rc $rc"
		[ $rc = 0 ] || break
	done
	rm -f "$STATE/runner.pid"
}

status() {
	echo "night shift on $(hostname), $(date '+%F %T %Z')"
	if [ -e "$STATE/STOP" ]; then echo "  STOPPED (night.sh start clears it)"; fi
	if [ -s "$STATE/runner.pid" ] && kill -0 "$(cat "$STATE/runner.pid")" 2>/dev/null; then
		echo "  RUNNING: runner pid $(cat "$STATE/runner.pid"), batch pgid $(cat "$STATE/batch.pid" 2>/dev/null || echo -)"
	else echo "  not running"; fi
	local reason
	reason=$(busy_reason)
	echo "  box: ${reason:-idle}"
	echo "  last busy: $(date -d @"$(cat "$STATE/last_busy" 2>/dev/null || echo 0)" '+%F %T') ($(cat "$STATE/last_busy_reason" 2>/dev/null))"
	echo "  tree: $(cat "$TREE/.spotter-commit" 2>/dev/null || echo none)   green ref: $(git --git-dir="$REPO" rev-parse -q --short refs/heads/green 2>/dev/null || echo none)"
	echo "  disk: $(du -sh "$NIGHT" 2>/dev/null | cut -f1) of cap ${CAP_GB}G; $(df -h ~ | tail -1 | awk '{print $4}') free on /"
	echo "  last log lines:"
	tail -8 "$STATE/night.log" 2>/dev/null | sed 's/^/    /' || true
}

stop() {
	touch "$STATE/STOP"
	if [ -s "$STATE/batch.pid" ]; then
		local pgid
		pgid=$(cat "$STATE/batch.pid")
		kill -TERM -- -"$pgid" 2>/dev/null
		sleep 3
		kill -KILL -- -"$pgid" 2>/dev/null
	fi
	log "stop: STOP set by hand"
	echo "night shift stopped (STOP set; 'night.sh start' clears it)"
}

case "${1:-}" in
tick) tick ;;
status) status ;;
stop) stop ;;
start) rm -f "$STATE/STOP"; log "start: STOP cleared"; echo "STOP cleared: the next idle tick runs" ;;
busy) busy_reason ;;
cron-install) # every 5 min, from this script's installed path (the line is marked so cron-remove finds only ours)
	line="*/5 * * * * $NIGHT/bin/night.sh tick >> $STATE/cron.log 2>&1 # spotter-night"
	{ crontab -l 2>/dev/null | grep -v '# spotter-night'; echo "$line"; } | crontab - && crontab -l | grep '# spotter-night' ;;
cron-remove) { crontab -l 2>/dev/null | grep -v '# spotter-night' || true; } | crontab - && echo "cron line removed" ;;
*) echo "night.sh tick | status | stop | start | busy | cron-install | cron-remove" >&2; exit 2 ;;
esac
