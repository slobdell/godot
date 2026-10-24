#!/usr/bin/env bash
# Known answers for tools/full_check_lock.sh (round 39, native): one full check per builder, claimed atomically. Two claimers
# released at the same instant: exactly one wins (-n), and blocking claimers never overlap; a SIGKILLed wrapper leaves the
# claim held while its check runs and free when it exits; a hang-up kills the check; remote.sh takes it for a full check
# only; builder_checks.sh counts the holder.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
fcl="$here/full_check_lock.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
lock=$tmp/tank_squad/.full-check.lock

# 1. Two non-blocking claimers released together by one barrier, 20 times: exactly one runs, the other exits 75 (busy).
races_ok=0
for i in $(seq 1 20); do
	rm -f "$tmp/go" "$tmp"/won.* "$tmp"/rc.*
	for c in a b; do
		( while [ ! -e "$tmp/go" ]; do :; done
		  bash "$fcl" run -n "$lock" bash -c "touch '$tmp/won.$c'; sleep 0.3" 2>/dev/null; echo $? > "$tmp/rc.$c" ) &
	done
	sleep 0.2; touch "$tmp/go"; wait
	won=$(ls "$tmp"/won.* 2>/dev/null | wc -l); rcs=$(cat "$tmp/rc.a" "$tmp/rc.b" | sort | tr '\n' ' ')
	[ "$won" = 1 ] && [ "$rcs" = "0 75 " ] && races_ok=$((races_ok + 1))
done
[ "$races_ok" = 20 ] && ok "two claimers at once, 20 races: exactly one wins each time, the other is told busy (75)" \
	|| bad "atomic claim" "$races_ok of 20 races had exactly one winner"

# 2. Two blocking claimers: both run, one after the other, never overlapping.
: > "$tmp/log"
for c in a b; do
	bash "$fcl" run "$lock" bash -c "echo start $c >> '$tmp/log'; sleep 0.5; echo end $c >> '$tmp/log'" 2>"$tmp/err.$c" &
done
wait
pattern=$(awk '{print $1}' "$tmp/log" | tr '\n' ' ')
[ "$pattern" = "start end start end " ] && ok "two waiting claimers both run, serially (start end start end)" \
	|| bad "serial" "$(cat "$tmp/log")"
grep -q "waiting" "$tmp/err.a" "$tmp/err.b" && ok "  the one that waited said so" || bad "wait message" "$(cat "$tmp"/err.*)"

# 3. holder: while held it prints the holder's folder; when free, exit 1.
bash "$fcl" run "$lock" sleep 1 &
holder_pid=$!
sleep 0.3
h=$(bash "$fcl" holder "$lock"); rc=$?
[ "$rc" = 0 ] && [[ "$h" == "$PWD "* ]] && ok "holder: the holding folder, pid and time ($h)" || bad "holder" "rc $rc: $h"
wait "$holder_pid"
bash "$fcl" holder "$lock" >/dev/null; rc=$?
[ "$rc" = 1 ] && ok "holder: free after the run ends (exit 1)" || bad "holder free" "rc $rc"

# 4. The wrapper dies, the check lives on (feedback: a killed local wrapper left the remote check running): the claim must
# stay held while the check runs, because the check inherits it, and free the moment the check exits. setsid gives the
# holder a process group of its own, as remote.sh's ssh session does (its traps signal that group).
setsid bash "$fcl" run "$lock" bash -c "echo \$\$ > '$tmp/child'; exec sleep 30" &
holder_pid=$!
for _ in $(seq 1 50); do [ -s "$tmp/child" ] && break; sleep 0.1; done
child=$(cat "$tmp/child")
kill -9 "$holder_pid"; wait "$holder_pid" 2>/dev/null
sleep 0.2
kill -0 "$child" 2>/dev/null && ! bash "$fcl" run -n "$lock" true 2>/dev/null \
	&& ok "the wrapper SIGKILLed, the check alive: the claim is still held (no second check)" || bad "orphan check unlocked"
kill "$child" 2>/dev/null; for _ in $(seq 1 20); do kill -0 "$child" 2>/dev/null || break; sleep 0.1; done
bash "$fcl" run -n "$lock" true 2>/dev/null && ok "  the check exits: the next claim wins at once (no stale lock)" || bad "stale after check exit"

# 5. A hang-up (the ssh session dropping) or TERM to the wrapper takes the check down too: no orphan, the claim freed.
for sig in HUP TERM; do
	rm -f "$tmp/child"
	setsid bash "$fcl" run "$lock" bash -c "echo \$\$ > '$tmp/child'; exec sleep 30" &
	holder_pid=$!
	for _ in $(seq 1 50); do [ -s "$tmp/child" ] && break; sleep 0.1; done
	child=$(cat "$tmp/child")
	kill -"$sig" "$holder_pid"; wait "$holder_pid" 2>/dev/null
	for _ in $(seq 1 30); do kill -0 "$child" 2>/dev/null || break; sleep 0.1; done
	if kill -0 "$child" 2>/dev/null; then bad "$sig: the check outlived its wrapper"; kill "$child"
	else bash "$fcl" run -n "$lock" true 2>/dev/null && ok "$sig to the wrapper: the check is gone and the claim free" || bad "$sig: claim held"; fi
done

# 5b. The session dies without a hang-up (an ssh with no terminal): the watchdog stops the check and frees the claim.
sleep 300 & session=$!
rm -f "$tmp/child"
FULL_CHECK_LOCK_SESSION=$session FULL_CHECK_LOCK_POLL=0.2 setsid bash "$fcl" run "$lock" bash -c "echo \$\$ > '$tmp/child'; exec sleep 30" 2>"$tmp/err.w" &
holder_pid=$!
for _ in $(seq 1 50); do [ -s "$tmp/child" ] && break; sleep 0.1; done
child=$(cat "$tmp/child")
sleep 0.5
kill -0 "$child" 2>/dev/null && ! bash "$fcl" run -n "$lock" true 2>/dev/null && ok "the session alive: the check runs, holding the claim" \
	|| bad "watchdog fired early"
kill "$session"; wait "$session" 2>/dev/null
wait "$holder_pid" 2>/dev/null
for _ in $(seq 1 30); do kill -0 "$child" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$child" 2>/dev/null; then bad "the session gone, the check lived on"; kill "$child"
else bash "$fcl" run -n "$lock" true 2>/dev/null && grep -q "session .* is gone" "$tmp/err.w" \
	&& ok "  the session gone: the check stopped, said why, claim free" || bad "session: claim or message" "$(cat "$tmp/err.w")"; fi

# 5c. A check QUEUED for the claim whose session dies never runs (it would wake later as an orphan).
bash "$fcl" run "$lock" sleep 2 &
first=$!
sleep 0.3
sleep 300 & session=$!
rm -f "$tmp/ran"
FULL_CHECK_LOCK_SESSION=$session FULL_CHECK_LOCK_POLL=0.2 setsid bash "$fcl" run "$lock" touch "$tmp/ran" 2>/dev/null &
queued=$!
sleep 0.5
kill "$session"; wait "$session" 2>/dev/null
wait "$queued" 2>/dev/null; wait "$first"
[ ! -e "$tmp/ran" ] && ok "a queued check whose session died never runs" || bad "queued orphan ran"

# 6a. The command's status comes back, and the command holds the claim's descriptor (it is what keeps the claim).
bash "$fcl" run "$lock" bash -c 'exit 7' 2>/dev/null; rc=$?
[ "$rc" = 7 ] && ok "run exits with the command's status (7)" || bad "status" "rc $rc"
fds=$(bash "$fcl" run "$lock" bash -c 'ls /proc/$$/fd' 2>/dev/null | tr '\n' ' ')
[[ " $fds " == *" 9 "* ]] && ok "  the command inherits the claim's descriptor" || bad "fd 9 not inherited" "$fds"

# 6. Which make arguments are a full check (remote.sh takes the lock for these only).
yes=0; for args in "check" "native check" "check NATIVE=off" "native check WEB_PORT=8600"; do
	# shellcheck disable=SC2086
	bash "$fcl" is-full-check $args && yes=$((yes + 1)); done
no=0; for args in "quick" "native test" "check-perf-judge-stage" "perf-judge" "trig-perf-ab"; do
	# shellcheck disable=SC2086
	bash "$fcl" is-full-check $args || no=$((no + 1)); done
[ "$yes" = 4 ] && [ "$no" = 5 ] && ok "is-full-check: check / native check (vars after) yes; quick, test, sub-stages no" \
	|| bad "is-full-check" "yes $yes of 4, no $no of 5"
grep -q 'FULL_CHECK_LOCK_SESSION=\\$PPID bash tools/full_check_lock.sh run ~/\$root/.full-check.lock make' "$here/remote.sh" \
	&& ok "remote.sh wraps a full check's make in the claim" || bad "remote.sh wiring"

# 7. builder_checks.sh counts the lock's holder as a full check (a fake ssh runs the probe here, with pgrep stubbed out).
cat > "$tmp/ssh" <<'FAKE'
#!/usr/bin/env bash
cmd=${*: -1}; cmd=${cmd//pgrep -f/true}
HOME=$FAKE_HOME bash -c "$cmd"
FAKE
chmod +x "$tmp/ssh"
( cd "$tmp" && bash "$fcl" run "$lock" sleep 1 ) &
holder_pid=$!
sleep 0.3
out=$(FAKE_HOME=$tmp BUILDER_CHECKS_SSH=$tmp/ssh bash "$here/builder_checks.sh" 2>&1)
[ "$(head -1 <<<"$out")" = 1 ] && grep -qx "$tmp" <<<"$out" && ok "builder_checks: the lock's holder counts (1, its folder)" \
	|| bad "builder_checks holder" "$out"
wait "$holder_pid"
out=$(FAKE_HOME=$tmp BUILDER_CHECKS_SSH=$tmp/ssh bash "$here/builder_checks.sh" 2>&1)
[ "$(head -1 <<<"$out")" = 0 ] && ok "builder_checks: a free lock adds nothing (0)" || bad "builder_checks free" "$out"

printf '\nfull-check-lock: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
