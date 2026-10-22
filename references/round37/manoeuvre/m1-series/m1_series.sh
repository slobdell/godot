#!/bin/bash
# Bar M1 (sidestand, round 37) guards on BUILDER0, native. ON = lab/manoeuvre-m1on (stream ff40ed578 + SIDE_STAND_DEFAULT true),
# BASE = lab/manoeuvre-m1base (= stream ff40ed578, OFF; its check is the stream's). Preemption-safe (remote_builds.md, T8's driver): a step is done only when its
# rows are all there; a check counts only with its own verdict line. Fresh seeds: wedge/fights/jam locks,terminus,sumps x
# 6640-6663; hull-rest 6601-6632 drawn x 4 factions x 6 tasks (--turn-states --element-trace=all: the player line too).
set -u
export PATH=/home/slobdell/projects/bin:$PATH
O=/home/slobdell/overnight-manoeuvre/r37/m1; mkdir -p $O; S=$O/series-summary.txt
export REMOTE_HOST=slobdell@builder0
ON=/home/slobdell/projects/godot-manoeuvre-m1on; BASE=/home/slobdell/projects/godot-manoeuvre-m1base
J=4
log() { echo ">> $(date +%H:%M) $*" >> $S; }
up() { ssh -o BatchMode=yes -o ConnectTimeout=10 $REMOTE_HOST true 2>/dev/null && return 0
  log "builder0 unreachable, retrying in 5 min"; sleep 300; }
load() { ssh -o BatchMode=yes -o ConnectTimeout=10 $REMOTE_HOST 'cat /proc/loadavg; pgrep -fc generate_balsa_matrix' 2>/dev/null | tr '\n' ' '; }
log "m1 series driver start: ON $(git -C $ON rev-parse --short HEAD) BASE $(git -C $BASE rev-parse --short HEAD) on $REMOTE_HOST"
# 1. ON's full check (sim-baseline may move: attribution = base = main)
tries=0
while ! grep -qE '^>> check: [0-9]+ passed' $O/check_on.log 2>/dev/null; do
  tries=$((tries+1)); [ $tries -gt 3 ] && { log "STOP: no check verdict after 3 tries"; exit 1; }
  [ -s $O/check_on.log ] && mv $O/check_on.log $O/check_on.log.lost$tries
  up; ( cd $ON && tools/builder_checks.sh --wait-below 1 >> $O/wait.log 2>&1 )
  log "check start (try $tries), load: $(load)"; ( cd $ON && make --no-print-directory remote T="native check" > $O/check_on.log 2>&1 )
  log "check end: $(grep -E '^>> remote: .*exited|^>> check: ' $O/check_on.log | tail -3 | tr '\n' ' ')"
done
fails=$(grep -E '^>> check: failed: ' $O/check_on.log | sed 's/^>> check: failed: //' | tr ' ,' '\n\n' | grep -v -e '^$' -e '^sim-baseline$')
[ -n "$fails" ] && { log "STOP: ON check red beyond sim-baseline: $fails"; exit 1; }
grep -qE '^>> check: [0-9]+ passed, [0-9]+ FAILED, 0 NOT RUN|^>> check: [0-9]+ passed' $O/check_on.log || { log "STOP: no verdict"; exit 1; }
grep -qE '^>> check: .*NOT RUN' $O/check_on.log && ! grep -qE '^>> check: .*, 0 NOT RUN' $O/check_on.log && { log "STOP: targets NOT RUN"; exit 1; }
# 2. the series, up to 3 passes
T1=faced_ambush,faced_attack_move,faced_move; T2=faced_right,faced_screen,faced_support_by_fire
for pass in 1 2 3; do
  missing=""
  for a in locks terminus sumps; do for arm in on base; do T=$ON; [ $arm = base ] && T=$BASE
    mkdir -p $O/wedge-$arm $O/fights-$arm $O/jam-$arm
    if [ "$(ls $O/wedge-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^WEDGE_TRACE' | wc -l)" -lt 24 ]; then
      up; log "wedge $arm $a start, load: $(load)"
      ( cd $T && tools/remote.sh native manoeuvre-wedge-trace WEDGE_RANGE=6640-6663 WEDGE_AT=$a WEDGE_JOBS=$J WEDGE_DIR=build/manoeuvre/wedge-$a > $O/wedge-$arm-$a.log 2>&1 )
      cp $T/build/manoeuvre/wedge-$a/*.log $O/wedge-$arm/ 2>/dev/null; log "$(grep -E '>> remote: make .* exited' $O/wedge-$arm-$a.log | tail -1 | cut -c1-60)"
    fi
    if [ "$(ls $O/fights-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^FIGHT_CENSUS' | wc -l)" -lt 24 ]; then
      up; log "fights $arm $a start, load: $(load)"
      ( cd $T && rm -rf build/manoeuvre/fights && tools/remote.sh native manoeuvre-fights FIGHT_RANGE=6640-6663 FIGHT_AT=$a FIGHT_JOBS=$J > $O/fights-$arm-$a.log 2>&1 )
      cp $T/build/manoeuvre/fights/$a-*.log $O/fights-$arm/ 2>/dev/null; log "$(grep -E '>> remote: make .* exited' $O/fights-$arm-$a.log | tail -1 | cut -c1-60)"
    fi
    if [ "$(ls $O/jam-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^JAM_CENSUS' | wc -l)" -lt 24 ]; then
      up; log "jam $arm $a start, load: $(load)"
      ( cd $T && tools/remote.sh native traffic-jam-census JAM_AT=$a JAM_RANGE=6640-6663 JAM_JOBS=$J JAM_DIR=build/traffic-jam-$a > $O/jam-$arm-$a.log 2>&1 )
      cp $T/build/traffic-jam-$a/$a-*.log $O/jam-$arm/ 2>/dev/null; log "$(grep -E '>> remote: make .* exited' $O/jam-$arm-$a.log | tail -1 | cut -c1-60)"
    fi
    for k in wedge:WEDGE_TRACE fights:FIGHT_CENSUS jam:JAM_CENSUS; do d=${k%%:*}; tag=${k#*:}
      [ "$(ls $O/$d-$arm/$a-*.log 2>/dev/null | xargs -r grep -l "^$tag" | wc -l)" -ge 24 ] || missing="$missing $d/$arm/$a"; done
  done; done
  for arm in on base; do T=$ON; [ $arm = base ] && T=$BASE; A=new_drawn; [ $arm = base ] && A=base_drawn
    for f in gangs law syndicate condemned; do for set in 1 2; do ts=$T1; [ $set = 2 ] && ts=$T2; d=hr-$A-$f-$set
      have=$(ls $O/hull-rest/$A/$f/*/screen.json 2>/dev/null | grep -cE "/($(echo $ts | tr , '|'))-")
      [ "$have" -ge 96 ] && continue
      up; log "$d start, load: $(load)"
      ( cd $T && tools/remote.sh native manoeuvre-hull-rest M1_ARMS=$A M1_NEW_OFF= M1_BASE_OFF= M1_SEEDS=6601-6632 HULL_JOBS=$J HULL_FACTIONS=$f FACING_ONLY=$ts 'M1_FLAGS=--turn-states --element-trace=all' M1_DIR=build/manoeuvre/$d > $O/$d.log 2>&1 )
      mkdir -p $O/hull-rest/$A; cp -r $T/build/manoeuvre/$d/$A/. $O/hull-rest/$A/ 2>/dev/null
      have=$(ls $O/hull-rest/$A/$f/*/screen.json 2>/dev/null | grep -cE "/($(echo $ts | tr , '|'))-")
      log "$d: $have/96 screen.json; $(grep -E '>> remote: make .* exited' $O/$d.log | tail -1 | cut -c1-40)"
      [ "$have" -ge 96 ] || missing="$missing $d"
    done; done
  done
  [ -z "$missing" ] && break
  log "pass $pass incomplete:$missing"
done
[ -n "$missing" ] && { log "STOP: incomplete after 3 passes:$missing"; exit 1; }
log "series done, load: $(load)"; touch $O/done
