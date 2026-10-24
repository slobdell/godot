#!/usr/bin/env bash
# Known answers for tools/full_check_lock.sh (round 39, native): one full check per builder, claimed atomically. Two claimers
# released at the same instant: exactly one wins (-n), and blocking claimers never overlap; a SIGKILLed holder frees the
# claim at once (no stale lock); remote.sh takes it for a full check only; builder_checks.sh counts the holder.
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

# 4. A holder killed by SIGKILL (no trap runs) frees the claim at once: no stale lock.
bash "$fcl" run "$lock" bash -c "echo \$\$ > '$tmp/child'; exec sleep 30" &
holder_pid=$!
sleep 0.3
kill -9 "$holder_pid"; wait "$holder_pid" 2>/dev/null
bash "$fcl" run -n "$lock" true 2>/dev/null; rc=$?
[ "$rc" = 0 ] && ok "a SIGKILLed holder: the next claim wins at once" || bad "stale" "rc $rc"
kill "$(cat "$tmp/child")" 2>/dev/null   # the killed holder's own 'sleep 30', by its recorded pid

# 5. The command's status comes back; the make child does not inherit the descriptor.
bash "$fcl" run "$lock" bash -c 'exit 7' 2>/dev/null; rc=$?
[ "$rc" = 7 ] && ok "run exits with the command's status (7)" || bad "status" "rc $rc"
fds=$(bash "$fcl" run "$lock" bash -c 'ls /proc/$$/fd' 2>/dev/null | tr '\n' ' ')
[[ " $fds " != *" 9 "* ]] && ok "  the command does not inherit the lock's descriptor" || bad "fd 9 leaked" "$fds"

# 6. Which make arguments are a full check (remote.sh takes the lock for these only).
yes=0; for args in "check" "native check" "check NATIVE=off" "native check WEB_PORT=8600"; do
	# shellcheck disable=SC2086
	bash "$fcl" is-full-check $args && yes=$((yes + 1)); done
no=0; for args in "quick" "native test" "check-perf-judge-stage" "perf-judge" "trig-perf-ab"; do
	# shellcheck disable=SC2086
	bash "$fcl" is-full-check $args || no=$((no + 1)); done
[ "$yes" = 4 ] && [ "$no" = 5 ] && ok "is-full-check: check / native check (vars after) yes; quick, test, sub-stages no" \
	|| bad "is-full-check" "yes $yes of 4, no $no of 5"
grep -q 'full_check_lock.sh run ~/\$root/.full-check.lock make' "$here/remote.sh" \
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
