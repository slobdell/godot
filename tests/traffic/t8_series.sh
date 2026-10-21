#!/bin/bash
# T8 (X2, R35.7): the pair's gates and judged series on builder2, as filed (workstreams *Bars (round 35)*, T8). Run FROM the
# pair's worktree under systemd-run (it survives the session):
#   systemd-run --user --unit=t8-series tests/traffic/t8_series.sh
# Steps, each skipped when its output is already there (a Spot stop or a reaped run resumes where it left off):
#   1. wait until no full check runs on builder2 (orders' D5 first; one check + one series there at a time), then
#      `make native check` on this commit; stop unless every target but sim-baseline is green
#   2. the switch-OFF sim-baseline read (sim-variants --traffic-off=holdfire) beside it: T8 OFF must read main's lines
#   3. the series: {terminus, locks, crossing, gorge, parade} x 1800-1827 (locks 1801-1828: R35.69, locks-1800 was seen in a
#      smoke before the series, so it is swapped for locks-1828; n stays 140, every judged fight unseen), base --traffic-off=holdfire v arm (ON by default),
#      native, one remote call per arena per arm, then crossing arrivals (traffic-series 44-46 x six, both arms)
#   4. jam_ab --bar t8, v2_lines, jam_table per arm -> $OUT
# Every step logs its commit and machine to $OUT/driver.log. Nothing is kept in build/ (remote.sh's copy-back deletes).
set -u
OUT=${OUT:-$HOME/overnight-traffic/r36/t8series}
RANGE=${RANGE:-1800-1827}
LOCKS_RANGE=${LOCKS_RANGE:-1801-1828}  # R35.69: locks-1800 seen before the series (06144d171's smoke) -> locks-1828
ARENAS=${ARENAS:-terminus locks crossing gorge parade}
JOBS=${JOBS:-4}
export REMOTE_HOST=${REMOTE_HOST:-slobdell@builder2}
cd "$(git rev-parse --show-toplevel)" || exit 1
h=$(git rev-parse --short HEAD)
mkdir -p "$OUT/base" "$OUT/arm"
log() { echo "$(date -Is) [$h $REMOTE_HOST] $*" >> "$OUT/driver.log"; }
up() {  # builder2 stops itself after 20 idle minutes; start it again rather than lose the step
	ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" true 2>/dev/null && return 0
	log "host down: make gcp-start"; make --no-print-directory gcp-start >> "$OUT/driver.log" 2>&1
}
n_census() { grep -l '^JAM_CENSUS' "$OUT/$1/$2-"*.log 2>/dev/null | wc -l; }
want=$(( $(echo "$RANGE" | cut -d- -f2) - $(echo "$RANGE" | cut -d- -f1) + 1 ))
log "T8 series driver start: range $RANGE (locks $LOCKS_RANGE) arenas '$ARENAS' jobs $JOBS"

# 1. the full check. Done = the check's own verdict line (">> check: N passed, ..."); a run that lost its host (a Spot
# preemption: ssh/rsync exit 255, only progress lines) is no result and is run again (round 36: the first try was preempted 4 min in).
checked() { grep -qE '^>> check: [0-9]+ passed' "$OUT/check_$h.log" 2>/dev/null; }
tries=0
while ! checked; do
	tries=$((tries + 1)); [ $tries -gt 3 ] && { log "STOP: no check verdict after 3 tries (see check_$h.log*)"; exit 1; }
	[ -s "$OUT/check_$h.log" ] && mv "$OUT/check_$h.log" "$OUT/check_$h.log.lost$tries"
	up; log "check: waiting for builder2's checks to clear"
	tools/builder_checks.sh --wait-below 1 >> "$OUT/driver.log" 2>&1
	log "check start (try $tries)"; make --no-print-directory remote T="native check" > "$OUT/check_$h.log" 2>&1
	log "check end: $(grep -E '^>> remote: .*exited|^>> check: [0-9]+ passed|^>> check: failed' "$OUT/check_$h.log" | tail -3 | tr '\n' ' ')"
done
fails=$(grep -E '^>> check: failed: ' "$OUT/check_$h.log" | sed 's/^>> check: failed: //' | tr ' ,' '\n\n' | grep -v -e '^$' -e '^sim-baseline$')
if [ -n "$fails" ]; then log "STOP: the check is red beyond sim-baseline: $(echo $fails)"; exit 1; fi
# a green check prints "N passed, M NOT JUDGED" with no FAILED/NOT RUN field; reds are read from the failed list above
if grep -E '^>> check: [0-9]+ passed' "$OUT/check_$h.log" | grep -qE '[1-9][0-9]* NOT RUN'; then log "STOP: targets NOT RUN: $(grep -E '^>> check: [0-9]+ passed' "$OUT/check_$h.log")"; exit 1; fi

# 2. switch-OFF inertness
if ! grep -qE 'exited [0-9]+' "$OUT/inert_$h.log" 2>/dev/null || grep -q 'exited 255' "$OUT/inert_$h.log"; then  # 255: host lost
	up; tools/remote.sh sim-variants VARIANTS_EXTRA=--traffic-off=holdfire VARIANTS_TAG=hfoff > "$OUT/inert_$h.log" 2>&1
	log "inertness end: $(grep 'exited' "$OUT/inert_$h.log" | tail -1)"
fi

# 3. the series (up to 3 passes: an arena or arm the host was lost in is run again whole; same pinned fights)
for pass in 1 2 3; do
	for arena in $ARENAS; do
		for arm in base arm; do
			flags="--traffic-off=holdfire"; [ "$arm" = arm ] && flags=""
			if [ "$(n_census $arm $arena)" -ge "$want" ]; then continue; fi
			range=$RANGE; [ "$arena" = locks ] && range=$LOCKS_RANGE
			up; tools/remote.sh native traffic-jam-census JAM_AT=$arena JAM_RANGE=$range JAM_JOBS=$JOBS "JAM_FLAGS=$flags" \
				JAM_DIR=build/t8/$arm > "$OUT/remote-$arena-$arm.log" 2>&1
			cp build/t8/$arm/$arena-*.log "$OUT/$arm/" 2>/dev/null
			log "$arena $arm: $(n_census $arm $arena)/$want with JAM_CENSUS; NATIVE $(grep -l NATIVE_EXEC "$OUT/$arm/$arena-"*.log 2>/dev/null | wc -l); $(grep 'exited' "$OUT/remote-$arena-$arm.log" | tail -1 | cut -c1-80)"
		done
	done
	for arm in base arm; do  # line 7: crossing arrivals, the T1/T3 stage
		flags="--traffic-off=holdfire"; [ "$arm" = arm ] && flags=""
		[ -s "$OUT/series-$arm.jsonl" ] && continue
		up; tools/remote.sh native traffic-series "TRAFFIC_SEEDS=44 45 46" TRAFFIC_WHICH=both TRAFFIC_JOBS=$JOBS CACHE=off \
			"TRAFFIC_FLAGS=$flags" TRAFFIC_OUT=build/t8-series-$arm.jsonl > "$OUT/remote-series-$arm.log" 2>&1
		cp build/t8-series-$arm.jsonl "$OUT/series-$arm.jsonl" 2>/dev/null
		log "series $arm: $(grep 'exited' "$OUT/remote-series-$arm.log" | tail -1 | cut -c1-80)"
	done
	missing=""
	for arena in $ARENAS; do for arm in base arm; do [ "$(n_census $arm $arena)" -ge "$want" ] || missing="$missing $arena/$arm"; done; done
	for arm in base arm; do [ -s "$OUT/series-$arm.jsonl" ] || missing="$missing crossings/$arm"; done
	[ -z "$missing" ] && break
	log "pass $pass incomplete:$missing"
done
[ -n "$missing" ] && { log "STOP: still incomplete after 3 passes:$missing"; exit 1; }

# 4. the reads
python3 tests/traffic/v2_lines.py series "$OUT/series-base.jsonl" "$OUT/series-arm.jsonl" > "$OUT/v2_lines.txt" 2>&1
python3 tests/traffic/jam_ab.py "$OUT/base" "$OUT/arm" --bar t8 > "$OUT/jam_ab.txt" 2>&1
for arm in base arm; do python3 tests/traffic/jam_table.py "$OUT/$arm" > "$OUT/jam_table_$arm.txt" 2>&1; done
log "T8 series done: $(tail -1 "$OUT/jam_ab.txt")"
