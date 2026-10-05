#!/usr/bin/env bash
# Known-answer tests for mk/net.mk's REAP_GODOT (the smokes' background Godot server/host, reaped and its exit read;
# ship, round 18, lent). The function is taken from make's own database, so this tests the text the recipes run.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
fn=$(cd "$repo" && TANK_SQUAD_SLOT=1 make -s --no-print-directory -o import -p -n net-smoke 2>/dev/null \
	| grep '^REAP_GODOT = ' | head -1 | sed 's/^REAP_GODOT = //; s/\$\$/$/g')
[ -n "$fn" ] && ok "REAP_GODOT found in make's database" || { bad "REAP_GODOT found"; printf '\nreap: %d passed, %d failed\n' "$pass" "$fail"; exit 1; }
run() { ( cd "$repo" && bash -c "set -eu -o pipefail; $fn; $1" ) 2>&1; }
out=$(run "( sleep 30 ) & p=\$!; reap t/alive \$p $tmp/x.log"); [ $? = 0 ] && grep -q 'exited 143 (expected' <<<"$out" \
	&& ok "a server still running: stopped by our SIGTERM, 143 expected, passes" || bad "alive" "$out"
echo "server up" > "$tmp/d.log"
out=$(run "( exit 134 ) & p=\$!; sleep 0.3; reap t/died \$p $tmp/d.log"); [ $? != 0 ] && grep -q 'gone before the clients finished (exit 134)' <<<"$out" \
	&& ok "a server that died mid-run, no ERROR in its log: FAILED with its exit" || bad "died" "$out"
out=$(run "( exit 0 ) & p=\$!; sleep 0.3; reap t/gone \$p $tmp/d.log"); [ $? != 0 ] && grep -q 'gone before the clients finished (exit 0)' <<<"$out" \
	&& ok "a server that quit early (exit 0): FAILED, it was not there for the clients" || bad "gone" "$out"
out=$(run "bash -c 'trap \"exit 134\" TERM; sleep 30 & wait' & p=\$!; sleep 0.3; reap t/crash \$p $tmp/d.log"); [ $? != 0 ] && grep -q 'exited 134' <<<"$out" \
	&& ok "a server that crashes while being stopped: FAILED" || bad "crash at stop" "$out"
printf '\nreap: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
