#!/bin/bash
# Bar M5 (seatstep, round 37) deciding + guards on BUILDER2 (R37.18: after rules' Bar R series), native. ON = lab/manoeuvre-m5on (pair/native-m5 + stream, seatstep out of DEFAULT_OFF),
# BASE = lab/manoeuvre-m5base (the same, seatstep OFF). The deciding line is the jam census's seat_episodes. Preemption-safe (remote_builds.md, T8's driver): a step is done only when its
# rows are all there; a check counts only with its own verdict line. Fresh seeds: wedge/fights/jam locks,terminus,sumps x
# 6840-6863; hull-rest 6801-6832 drawn x 4 factions x 6 tasks (--turn-states --element-trace=all: the player line too).
set -u
export PATH=/home/slobdell/projects/bin:$PATH
O=/home/slobdell/overnight-manoeuvre/r37/m5; mkdir -p $O; S=$O/series-summary.txt
export REMOTE_HOST=slobdell@builder2
ON=/home/slobdell/projects/godot-manoeuvre-m5on; BASE=/home/slobdell/projects/godot-manoeuvre-m5
J=14  # godot-b0 22:35: builder2 has 16 physical cores; results do not depend on J
log() { echo ">> $(date +%H:%M) $*" >> $S; }
up() { ssh -o BatchMode=yes -o ConnectTimeout=10 $REMOTE_HOST true 2>/dev/null && return 0
  log "builder2 down: make gcp-start"; ( cd $ON && make --no-print-directory gcp-start >> $O/gcp.log 2>&1 ); }
load() { ssh -o BatchMode=yes -o ConnectTimeout=10 $REMOTE_HOST 'cat /proc/loadavg; pgrep -fc generate_balsa_matrix' 2>/dev/null | tr '\n' ' '; }
log "m5 series driver start: ON $(git -C $ON rev-parse --short HEAD) BASE $(git -C $BASE rev-parse --short HEAD) on $REMOTE_HOST"
# 0. R37.18: queued after rules' series on builder2: wait until a godot-rules* process has been seen there, then none for 10 min
#    (touch $O/rules_seen by hand if rules finished before this driver started).
quiet=0; seen=0
[ -e $O/go ] && { seen=1; quiet=10; }  # the orchestrator released builder2 (R37 18:36)
[ -e $O/rules_seen ] && seen=1  # a restart after rules was already seen
while [ $quiet -lt 10 ] || [ $seen = 0 ]; do
  # never start the Spot box to look: a stopped builder2 is "not yet" (its queue starts it)
  n=$(ssh -o BatchMode=yes -o ConnectTimeout=10 $REMOTE_HOST 'c=0; for p in $(pgrep -f "make|godot|slot.sh"); do case "$(readlink /proc/$p/cwd 2>/dev/null)" in */godot-rules*) c=$((c+1));; esac; done; echo $c' 2>/dev/null || echo down)
  if [ "$n" = down ] && [ $seen = 1 ]; then quiet=10; break; fi  # rules seen, then the box idled itself off
  if [ "$n" = down ]; then quiet=0; sleep 240; continue; fi
  if [ "$n" = 0 ]; then quiet=$((quiet+1)); else quiet=0; seen=1; touch $O/rules_seen; fi
  sleep 60
done
log "builder2: no rules process for 10 min; M5 series starts (load: $(load))"
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
    if [ "$(ls $O/jam-$arm/$a-*.log 2>/dev/null | xargs -r grep -l '^JAM_CENSUS' | wc -l)" -lt 24 ]; then
      up; log "jam $arm $a start, load: $(load)"
      ( cd $T && tools/remote.sh native traffic-jam-census JAM_AT=$a JAM_RANGE=6840-6863 JAM_JOBS=$J JAM_DIR=build/traffic-jam-$a > $O/jam-$arm-$a.log 2>&1 )
      cp $T/build/traffic-jam-$a/$a-*.log $O/jam-$arm/ 2>/dev/null; log "$(grep -E '>> remote: make .* exited' $O/jam-$arm-$a.log | tail -1 | cut -c1-60)"
    fi
    for k in jam:JAM_CENSUS; do d=${k%%:*}; tag=${k#*:}
      [ "$(ls $O/$d-$arm/$a-*.log 2>/dev/null | xargs -r grep -l "^$tag" | wc -l)" -ge 24 ] || missing="$missing $d/$arm/$a"; done
  done; done
  for arm in on base; do T=$ON; [ $arm = base ] && T=$BASE; A=new_drawn; [ $arm = base ] && A=base_drawn
    for f in gangs law syndicate condemned; do for set in 1 2; do ts=$T1; [ $set = 2 ] && ts=$T2; d=hr-$A-$f-$set
      have=$(ls $O/hull-rest/$A/$f/*/screen.json 2>/dev/null | grep -cE "/($(echo $ts | tr , '|'))-")
      [ "$have" -ge 96 ] && continue
      up; log "$d start, load: $(load)"
      ( cd $T && tools/remote.sh native manoeuvre-hull-rest M1_ARMS=$A M1_NEW_OFF= M1_BASE_OFF= M1_SEEDS=6801-6832 HULL_JOBS=$J HULL_FACTIONS=$f FACING_ONLY=$ts 'M1_FLAGS=--turn-states --element-trace=all' M1_DIR=build/manoeuvre/$d > $O/$d.log 2>&1 )
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
