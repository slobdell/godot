#!/bin/bash
# Bar M5 v2 (round 38, _agents/streams/manoeuvre.md) on BUILDER0, native. ON = lab/manoeuvre-r38-m5on (seatstep ON),
# BASE = lab/manoeuvre-r38-m5 (the same tree, seatstep OFF). Fresh seeds: jam census locks/terminus/sumps x 6940-6979;
# hull-rest 6901-6932 x 4 factions x 6 tasks, ON + BASE native, and BASE on the GDScript path (M1_GD=1: the (e) floor arm).
# Preemption-safe: a step is done only when its rows are all there; a check counts only with its own verdict line.
set -u
export PATH=/home/slobdell/projects/bin:$PATH
O=/home/slobdell/overnight-manoeuvre/r38/m5; mkdir -p $O; S=$O/series-summary.txt
ON=/home/slobdell/projects/godot-manoeuvre-m5on; BASE=/home/slobdell/projects/godot-manoeuvre-m5
J=6; SEEDS=6940-6979; NJ=40; HR=6901-6932
log() { echo ">> $(date +%H:%M) $*" >> $S; }
load() { ssh -o BatchMode=yes -o ConnectTimeout=10 slobdell@builder0 'cat /proc/loadavg' 2>/dev/null; }
log "m5 v2 driver start: ON $(git -C $ON rev-parse --short HEAD) BASE $(git -C $BASE rev-parse --short HEAD) on builder0, J=$J"
# 1. ON's full check (C31.1: the full suite before a judged series; sim-baseline may move: seatstep ON is a behaviour switch)
tries=0
while ! grep -qE '^>> check: [0-9]+ passed' $O/check_on.log 2>/dev/null; do
  tries=$((tries+1)); [ $tries -gt 3 ] && { log "STOP: no check verdict after 3 tries"; exit 1; }
  [ -s $O/check_on.log ] && mv $O/check_on.log $O/check_on.log.lost$tries
  # R38.2 (the orchestrator): the ON check runs on builder2; the series stays on builder0
  ( cd $ON && REMOTE_HOST=slobdell@builder2 tools/builder_checks.sh --wait-below 1 >> $O/wait.log 2>&1 )
  log "check start (try $tries) on builder2"; ( cd $ON && REMOTE_HOST=slobdell@builder2 make --no-print-directory remote T="native check" > $O/check_on.log 2>&1 )
  log "check end: $(grep -E '^>> remote: .*exited|^>> check: ' $O/check_on.log | tail -3 | tr '\n' ' ')"
  # a check the slot killed (a loaded box) is a lost try, not a verdict
  grep -q '^>> slot.sh: killed after' $O/check_on.log && { log "check killed by the slot timeout: a lost try"; mv $O/check_on.log $O/check_on.log.killed$tries.b; }
done
fails=$(grep -E '^>> check: failed: ' $O/check_on.log | sed 's/^>> check: failed: //' | tr ' ,' '\n\n' | grep -v -e '^$' -e '^sim-baseline$')
# web-smoke missed its first-sound timing line at 2 fps on a loaded builder2 (34.3 s v 30 s); its solo re-run at the same commit
# passed (websmoke_on.log): accepted as load, not the change
grep -q '^>> remote: make web-smoke exited 0' $O/websmoke_on.log 2>/dev/null && fails=$(echo "$fails" | grep -v -e '^web-smoke$')
[ -n "$fails" ] && { log "STOP: ON check red beyond sim-baseline: $fails"; exit 1; }
grep -qE '^>> check: .*NOT RUN' $O/check_on.log && ! grep -qE '^>> check: .*, 0 NOT RUN' $O/check_on.log && { log "STOP: targets NOT RUN"; exit 1; }
# 2. the series, up to 3 passes
T1=faced_ambush,faced_attack_move,faced_move; T2=faced_right,faced_screen,faced_support_by_fire
for pass in 1 2 3; do
  missing=""
  for a in locks terminus sumps; do for arm in on base; do T=$ON; [ $arm = base ] && T=$BASE
    mkdir -p $O/jam-$arm
    if [ "$(ls $O/jam-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^JAM_CENSUS' | wc -l)" -lt $NJ ]; then
      log "jam $arm $a start, load: $(load)"
      ( cd $T && tools/remote.sh native traffic-jam-census JAM_AT=$a JAM_RANGE=$SEEDS JAM_JOBS=$J JAM_DIR=build/traffic-jam-$a > $O/jam-$arm-$a.log 2>&1 )
      cp $T/build/traffic-jam-$a/$a-*.log $O/jam-$arm/ 2>/dev/null; log "$(grep -E '>> remote: make .* exited' $O/jam-$arm-$a.log | tail -1 | cut -c1-70)"
    fi
    [ "$(ls $O/jam-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^JAM_CENSUS' | wc -l)" -ge $NJ ] || missing="$missing jam/$arm/$a"
  done; done
  for arm in on base gd; do T=$ON; A=new_drawn; GD=; [ $arm != on ] && { T=$BASE; A=base_drawn; }; [ $arm = gd ] && GD=1
    D=$A; [ $arm = gd ] && D=gd_drawn
    for f in gangs law syndicate condemned; do for set in 1 2; do ts=$T1; [ $set = 2 ] && ts=$T2; d=hr-$D-$f-$set
      have=$(ls $O/hull-rest/$D/$f/*/screen.json 2>/dev/null | grep -cE "/($(echo $ts | tr , '|'))-")
      [ "$have" -ge 96 ] && continue
      log "$d start, load: $(load)"
      ( cd $T && tools/remote.sh native manoeuvre-hull-rest M1_ARMS=$A M1_NEW_OFF= M1_BASE_OFF= M1_GD=$GD M1_SEEDS=$HR HULL_JOBS=$J HULL_FACTIONS=$f FACING_ONLY=$ts 'M1_FLAGS=--turn-states --element-trace=all' M1_DIR=build/manoeuvre/$d > $O/$d.log 2>&1 )
      mkdir -p $O/hull-rest/$D; cp -r $T/build/manoeuvre/$d/$A/. $O/hull-rest/$D/ 2>/dev/null
      have=$(ls $O/hull-rest/$D/$f/*/screen.json 2>/dev/null | grep -cE "/($(echo $ts | tr , '|'))-")
      log "$d: $have/96 screen.json; $(grep -E '>> remote: make .* exited' $O/$d.log | tail -1 | cut -c1-50)"
      [ "$have" -ge 96 ] || missing="$missing $d"
    done; done
  done
  [ -z "$missing" ] && break
  log "pass $pass incomplete:$missing"
done
[ -n "$missing" ] && { log "STOP: incomplete after 3 passes:$missing"; exit 1; }
log "series done, load: $(load)"
( cd /home/slobdell/projects/godot-manoeuvre && python3 tests/manoeuvre/m5_judge.py $O --v2 > $O/judge.txt 2>&1 )
log "judged: $(tail -1 $O/judge.txt)"; touch $O/done
