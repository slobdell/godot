#!/usr/bin/env bash
# Spotter S0: the night shift's frame, without Godot. A throwaway HOME with a one-commit bare repo whose `make spotter-batch`
# sleeps; then: (1) an idle box runs a batch, (2) a process appearing in another ~/tank_squad folder makes it YIELD within
# POLL_S + 6 s, killing the whole batch group, (3) a held full-check lock is busy, (4) a busy tick never starts, (5) STOP holds.
#   tests/spotter/test_night.sh        (make spotter-test runs it)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
night=$here/../../tools/spotter/night.sh
tmp=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$tmp"' EXIT
pass=0 fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

export NIGHT_HOME=$tmp/spotter-night NIGHT_SQUAD=$tmp/tank_squad NIGHT_TREE=$tmp/tank_squad/spotter-night
export NIGHT_IDLE_MIN=0 NIGHT_POLL_S=1 NIGHT_MAPS=terminus NIGHT_SEEDS_PER_BATCH=1 NIGHT_SEED_FIRST=1 NIGHT_SEED_LAST=2
mkdir -p "$NIGHT_SQUAD/other" "$NIGHT_HOME/kit/tools/spotter" "$NIGHT_HOME/kit/tests/spotter" "$NIGHT_HOME/kit/mk" "$NIGHT_SQUAD/.tools"
echo kit0 >"$NIGHT_HOME/kit/.kit-commit"
: >"$NIGHT_HOME/kit/mk/spotter.mk"
printf 'import sys; open(sys.argv[1] + "/SUMMARY.md", "w").write("ok")\n' >"$NIGHT_HOME/kit/tools/spotter/summary.py"
# The game commit: a Makefile whose batch writes one fight per seed, slowly (BATCH_SLEEP), and records its pid.
src=$tmp/src
git init -q "$src"
cat >"$src/Makefile" <<'EOF'
include mk/*.mk
spotter-batch:
	@echo $$$$ > $(SPOT_DIR)/../make.pid; mkdir -p $(SPOT_DIR); sleep $${BATCH_SLEEP:-1}; for s in $(SPOT_SEEDS); do echo '{}' > $(SPOT_DIR)/terminus-$$s.jsonl; done
EOF
git -C "$src" add Makefile && git -C "$src" -c user.email=t@t -c user.name=t commit -qm one
git clone -q --bare "$src" "$NIGHT_HOME/repo.git"
git --git-dir="$NIGHT_HOME/repo.git" update-ref refs/heads/green HEAD
day=$NIGHT_HOME/$(date +%F)

echo "night: an idle box runs batches until every seed is done"
BATCH_SLEEP=0 timeout 60 "$night" tick
c=$(ls "$day" 2>/dev/null | head -1)
[ -s "$day/$c/fights/terminus-1.jsonl.gz" ] && [ -s "$day/$c/fights/terminus-2.jsonl.gz" ] && ok "two batches, fights gzipped" || bad "fights missing: $(ls -R "$day" 2>&1 | head)"
[ -e "$day/$c/.complete" ] && ok "commit marked complete" || bad "no .complete"
[ -s "$day/SUMMARY.md" ] && ok "SUMMARY.md written" || bad "no SUMMARY.md"
[ "$(cut -d: -f1 "$NIGHT_TREE/.spotter-commit")" = "$(git -C "$src" rev-parse HEAD)" ] && ok "tree is the named commit" || bad "tree commit"

echo "night: a process in another folder makes it yield"
rm -rf "$day"
(BATCH_SLEEP=120 "$night" tick) &
runner=$!
for _ in $(seq 50); do [ -s "$day"/*/make.pid ] 2>/dev/null && break; sleep 0.2; done
mpid=$(cat "$day"/*/make.pid 2>/dev/null)
[ -n "$mpid" ] && kill -0 "$mpid" 2>/dev/null && ok "batch running (pid $mpid)" || bad "batch never started"
(cd "$NIGHT_SQUAD/other" && exec sleep 30) &
intruder=$!
t0=$(date +%s)
wait "$runner"
t1=$(date +%s)
[ $((t1 - t0)) -le 8 ] && ok "yielded in $((t1 - t0)) s" || bad "yield took $((t1 - t0)) s"
kill -0 "$mpid" 2>/dev/null && bad "batch survived the yield" || ok "batch group killed"
grep -q "sleep (pid $intruder) in other" "$day"/*/yields.txt && ok "yields.txt names who" || bad "yields.txt: $(cat "$day"/*/yields.txt 2>&1)"

echo "night: a busy box never starts a batch"
rm -rf "$day"
BATCH_SLEEP=0 "$night" tick
[ ! -d "$day" ] && ok "no batch while busy" || bad "ran while busy"
grep -q "in other" "$NIGHT_HOME/state/last_busy_reason" && ok "last_busy_reason recorded" || bad "no last_busy_reason"
kill "$intruder"
wait "$intruder" 2>/dev/null

echo "night: the idle wait after busy"
NIGHT_IDLE_MIN=5 BATCH_SLEEP=0 "$night" tick
[ ! -d "$day" ] && ok "waits NIGHT_IDLE_MIN after the last busy" || bad "ran right after busy"

echo "night: the full-check lock is busy"
touch "$NIGHT_SQUAD/.full-check.lock"
(exec 8>"$NIGHT_SQUAD/.full-check.lock"; flock 8; sleep 10) &
locker=$!
sleep 0.5
"$night" busy | grep -q "full-check lock" && ok "held lock reads busy" || bad "lock not seen"
kill "$locker"
wait "$locker" 2>/dev/null
[ -z "$("$night" busy)" ] && ok "free lock reads idle" || bad "idle box reads: $("$night" busy)"

echo "night: STOP holds"
"$night" stop >/dev/null
BATCH_SLEEP=0 "$night" tick
[ ! -d "$day" ] && ok "no batch while STOP" || bad "ran despite STOP"
"$night" start >/dev/null
BATCH_SLEEP=0 timeout 60 "$night" tick
[ -d "$day" ] && ok "start clears it" || bad "start did not clear STOP"

echo "test_night: $pass passed, $fail failed"
[ "$fail" = 0 ]
