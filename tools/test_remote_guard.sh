#!/usr/bin/env bash
# Known-answer tests for tools/remote_guard.sh -- the thing that stops `make remote` rsyncing --delete over a
# run that is still going (trip-up 66).
#
# These run in a temp directory with `sleep` processes standing in for a check, so they exercise the real
# script, on this machine, in under a second -- which is the point. The guard it replaces (a human remembering
# trip-up 66) failed twice in one morning, and EVERY defect this project found in round 9 was a guard that had
# never been exercised. This one is exercised on every `make check`.
set -uo pipefail

guard="$(cd "$(dirname "$0")" && pwd)/remote_guard.sh"
pass=0; fail=0; kids=()

cleanup() { local p; for p in "${kids[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; rm -rf "$tmp"; }
tmp=$(mktemp -d); trap cleanup EXIT

ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
check(){ "$guard" check "$G" "$R" "${1:-make check}" >"$tmp/out" 2>"$tmp/err"; echo $?; }

# A process whose cwd is $1, standing in for a check still running on the box. Sets $SPAWNED.
# NOT `p=$(spawn_in ...)`: a backgrounded child inherits the command substitution's pipe, so the
# substitution waits for the child to EXIT -- `sleep 120` hangs the test for two minutes. Its stdout
# is closed here for the same reason, so nothing downstream can ever wait on it.
spawn_in() {
	SPAWNED=""
	( cd "$1" && exec sleep 120 ) >/dev/null 2>&1 </dev/null &
	SPAWNED=$!
	kids+=("$SPAWNED")
	sleep 0.2
}

fresh() {   # a clean guard dir + run dir for one case
	G="$tmp/slots"; R="$tmp/run/godot-metrics"
	rm -rf "$G" "$tmp/run"; mkdir -p "$G" "$R"
}

# ---- 1. an idle directory is claimed ------------------------------------------------------------
fresh
rc=$(check)
[ "$rc" = 0 ] && ok "idle directory: claims" || bad "idle directory: claims" "exit $rc"
[ "$(sed -n 's/^state=//p' "$G/run.godot-metrics.owner")" = claimed ] \
	&& ok "idle directory: marker says claimed" || bad "idle directory: marker says claimed"

# ---- 2. a live process in the run directory refuses, and says which ------------------------------
fresh
spawn_in "$R"; p=$SPAWNED
rc=$(check)
[ "$rc" = 9 ] && ok "live process: refuses" || bad "live process: refuses" "exit $rc"
grep -q "REFUSING" "$tmp/err" && ok "live process: says REFUSING" || bad "live process: says REFUSING"
grep -q "\b$p\b" "$tmp/err" && ok "live process: names the pid" || bad "live process: names the pid"
grep -qE '[A-Z][a-z][a-z] [A-Z][a-z][a-z] +[0-9]+ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' "$tmp/err" \
	&& ok "live process: prints its start time" || bad "live process: prints its start time" "$(cat "$tmp/err")"
grep -q "REMOTE_FORCE=1" "$tmp/err" && ok "live process: names the override" || bad "live process: names the override"
kill "$p" 2>/dev/null

# ---- 3. the run directory is MINE, not the box's ------------------------------------------------
# A sibling worktree's run must not block this one -- eight streams share the box, and a guard that stops
# seven of them is worse than no guard.
fresh
mkdir -p "$tmp/run/godot-nav"
spawn_in "$tmp/run/godot-nav"; p=$SPAWNED
rc=$(check)
[ "$rc" = 0 ] && ok "sibling worktree running: claims" || bad "sibling worktree running: claims" "exit $rc"
kill "$p" 2>/dev/null

# ---- 4. prefix is not containment ---------------------------------------------------------------
# `godot-metrics-old` starts with `godot-metrics`; a naive prefix test would call it a live run.
fresh
mkdir -p "$tmp/run/godot-metrics-old"
spawn_in "$tmp/run/godot-metrics-old"; p=$SPAWNED
rc=$(check)
[ "$rc" = 0 ] && ok "same-prefix directory: claims" || bad "same-prefix directory: claims" "exit $rc"
kill "$p" 2>/dev/null

# ---- 5. a process in a SUBdirectory is the same run ----------------------------------------------
fresh
mkdir -p "$R/tests"
spawn_in "$R/tests"; p=$SPAWNED
rc=$(check)
[ "$rc" = 9 ] && ok "process below the run dir: refuses" || bad "process below the run dir: refuses" "exit $rc"
kill "$p" 2>/dev/null

# ---- 6. THE STALE-MARKER TRAP: a marker alone blocks nobody ---------------------------------------
# slot.sh's slot<N>.owner outlived its process and lied to every waiter for as long as anyone read it. A
# marker naming a dead pid, with nothing running, must be ignored -- otherwise this locks a stream out of the
# build box until a human deletes a file.
fresh
printf 'state=running\npid=999999\nlaunched=2026-09-20 01:00:00\nlabel=make check\n' > "$G/run.godot-metrics.owner"
rc=$(check)
[ "$rc" = 0 ] && ok "stale running marker, dead pid: claims" || bad "stale running marker, dead pid: claims" "exit $rc"

# ---- 7. a marker naming a LIVE pid that is not in the run dir is still not a run --------------------
# pids are recycled. The marker is printed, never believed: only /proc decides.
fresh
spawn_in "$tmp"; p=$SPAWNED
printf 'state=running\npid=%s\nlaunched=2026-09-20 01:00:00\nlabel=make check\n' "$p" > "$G/run.godot-metrics.owner"
rc=$(check)
[ "$rc" = 0 ] && ok "marker pid alive but elsewhere: claims" || bad "marker pid alive but elsewhere: claims" "exit $rc"
kill "$p" 2>/dev/null

# ---- 8. the launch window: a fresh claim refuses, an expired one does not ---------------------------
fresh
"$guard" check "$G" "$R" "make check" >/dev/null 2>&1          # launch A claims, then rsyncs
rc=$(check)                                                     # launch B, seconds later
[ "$rc" = 9 ] && ok "fresh claim (mid-rsync): refuses" || bad "fresh claim (mid-rsync): refuses" "exit $rc"
grep -q "still rsyncing" "$tmp/err" && ok "fresh claim: says why" || bad "fresh claim: says why"
touch -d '2 hours ago' "$G/run.godot-metrics.owner"
rc=$(check)
[ "$rc" = 0 ] && ok "expired claim: claims" || bad "expired claim: claims" "exit $rc"
fresh
"$guard" check "$G" "$R" "make check" >/dev/null 2>&1
rc=$(REMOTE_CLAIM_TTL=0 check)
[ "$rc" = 0 ] && ok "REMOTE_CLAIM_TTL honoured" || bad "REMOTE_CLAIM_TTL honoured" "exit $rc"

# ---- 9. REMOTE_FORCE=1 proceeds, but still prints what it destroys ---------------------------------
fresh
spawn_in "$R"; p=$SPAWNED
rc=$(REMOTE_FORCE=1 check)
[ "$rc" = 0 ] && ok "REMOTE_FORCE=1: claims anyway" || bad "REMOTE_FORCE=1: claims anyway" "exit $rc"
grep -q "\b$p\b" "$tmp/err" && ok "REMOTE_FORCE=1: still names the run it destroys" \
	|| bad "REMOTE_FORCE=1: still names the run it destroys" "$(cat "$tmp/err")"
grep -q "become void" "$tmp/err" && ok "REMOTE_FORCE=1: says the result is void" || bad "REMOTE_FORCE=1: says the result is void"
kill "$p" 2>/dev/null

# ---- 10. adopt / release -----------------------------------------------------------------------
fresh
check >/dev/null
"$guard" adopt "$G" "$R" 4242 >/dev/null 2>&1
m="$G/run.godot-metrics.owner"
[ "$(sed -n 's/^state=//p' "$m")" = running ] && ok "adopt: state becomes running" || bad "adopt: state becomes running"
[ "$(sed -n 's/^pid=//p' "$m")" = 4242 ] && ok "adopt: records the pid" || bad "adopt: records the pid"
grep -q '^label=make check' "$m" && ok "adopt: keeps the label" || bad "adopt: keeps the label" "$(cat "$m")"
"$guard" release "$G" "$R" >/dev/null 2>&1
[ ! -e "$m" ] && ok "release: removes the marker" || bad "release: removes the marker"
"$guard" release "$G" "$R" >/dev/null 2>&1 && ok "release: is idempotent" || bad "release: is idempotent"

# ---- 11. check-and-claim is atomic --------------------------------------------------------------
# Two launches at the same instant must not both see an idle directory. Without the flock both rsync.
fresh
racers=()
for i in 1 2 3 4 5 6; do
	( "$guard" check "$G" "$R" "launch $i" >/dev/null 2>&1; echo $? > "$tmp/rc.$i" ) &
	racers+=($!)
done
wait "${racers[@]}"   # not a bare `wait`: that would also wait on the spawned stand-ins
won=$(cat "$tmp"/rc.* 2>/dev/null | grep -c '^0$')
[ "$won" = 1 ] && ok "six simultaneous launches: exactly one claims" \
	|| bad "six simultaneous launches: exactly one claims" "$won claimed"

# ---- 11b. a big process tree is truncated, and SAYS it is truncated ------------------------------
# A sharded check holds ~25 processes on builder0 (measured). A refusal that dumps all of them buries the
# one line that matters; one that silently shows six is a small lie about how much is running.
fresh
for i in 1 2 3; do spawn_in "$R"; done
REMOTE_GUARD_PROC_LINES=2 "$guard" check "$G" "$R" "make check" >/dev/null 2>"$tmp/err"
grep -qE '^ +3 processes live in' "$tmp/err" && ok "many processes: prints the full count" \
	|| bad "many processes: prints the full count" "$(cat "$tmp/err")"
grep -q 'and 1 more' "$tmp/err" && ok "many processes: says it truncated" || bad "many processes: says it truncated"
# It must name a command that WORKS. Over ssh this script is called "bash", so $0 would send the
# reader to `bash report ...`; the refusal has to name remote.sh instead.
grep -q 'tools/remote.sh --status' "$tmp/err" && ok "many processes: names a runnable way to see the rest" \
	|| bad "many processes: names a runnable way to see the rest" "$(cat "$tmp/err")"
grep -q '^ *bash report' "$tmp/err" && bad "truncation advice is not \$0" || ok "truncation advice is not \$0"
[ "$(grep -cE '^ +[0-9]+ [A-Z][a-z][a-z] ' "$tmp/err")" = 2 ] && ok "many processes: prints exactly the cap" \
	|| bad "many processes: prints exactly the cap" "$(grep -cE '^ +[0-9]+ [A-Z][a-z][a-z] ' "$tmp/err") lines"
for k in "${kids[@]}"; do kill "$k" 2>/dev/null; done

# ---- 12. report never writes --------------------------------------------------------------------
fresh
"$guard" report "$G" "$R" >"$tmp/out" 2>&1
grep -q "^IDLE" "$tmp/out" && ok "report: idle directory reads IDLE" || bad "report: idle directory reads IDLE" "$(cat "$tmp/out")"
[ ! -e "$G/run.godot-metrics.owner" ] && ok "report: writes no marker" || bad "report: writes no marker"
spawn_in "$R"; p=$SPAWNED
"$guard" report "$G" "$R" >"$tmp/out" 2>&1
grep -q "^LIVE" "$tmp/out" && ok "report: live directory reads LIVE" || bad "report: live directory reads LIVE"
kill "$p" 2>/dev/null

# ---- 13. a run directory that does not exist yet is not a run --------------------------------------
fresh
R="$tmp/run/godot-brand-new"
rc=$(check)
[ "$rc" = 0 ] && ok "first run into a fresh folder: claims" || bad "first run into a fresh folder: claims" "exit $rc"

# ---- 14. bad usage is refused, not guessed --------------------------------------------------------
"$guard" >/dev/null 2>&1; [ $? = 2 ] && ok "no arguments: exit 2" || bad "no arguments: exit 2"
"$guard" wibble "$G" "$R" >/dev/null 2>&1; [ $? = 2 ] && ok "unknown mode: exit 2" || bad "unknown mode: exit 2"

printf '\nremote-guard: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
