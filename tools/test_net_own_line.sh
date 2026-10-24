#!/usr/bin/env bash
# Known answers for mk/net.mk's wait_own_line (round 39, native; feedback's red relay-smoke at a2b560896: the clients joined
# WU2K7 from a STALE host log while this run's host opened PSVVQ). A fake host that makes its redirect late, beside a stale
# log holding the old room: the wait must answer THIS host's room, never the stale one, and never block on make's stdout.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; root="$(dirname "$here")"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
log=$tmp/x-host.log
cat > "$tmp/t.mk" <<EOF
include $root/mk/net.mk
probe:
	@printf 'TANK_SQUAD_ROOM code=STALE1\n' > $log; \\
	bash -c 'sleep \$(DELAY); exec > $log 2>&1; echo "TANK_SQUAD_ROOM code=FRESH2"; sleep \$(LIVE)' & host=\$\$!; \\
	\$(call wait_own_line,host,$log,TANK_SQUAD_ROOM code=\\K\\w+,25); echo "found=\$\$found"; wait
EOF
run() { (cd "$root" && timeout 20 make --no-print-directory -s -f "$tmp/t.mk" probe "$@" 2>&1 | cat); }
out=$(run DELAY=0.5 LIVE=1)
[ "$out" = "found=FRESH2" ] && ok "a late redirect beside a stale log: this host's room (FRESH2), not the stale one" || bad "late redirect" "$out"
out=$(run DELAY=0.3 LIVE=0)
[ "$out" = "found=FRESH2" ] && ok "a host that prints and exits at once: read from the file after it exits" || bad "exited host" "$out"
exp=$(cd "$root" && make -n --no-print-directory relay-smoke -o import 2>/dev/null | tr ';' '\n')
rm_line=$(grep -n 'rm -f .*relay-smoke-host.log' <<<"$exp" | head -1 | cut -d: -f1)
host_line=$(grep -n -- '--host --relay' <<<"$exp" | head -1 | cut -d: -f1)
[ -n "$rm_line" ] && [ -n "$host_line" ] && [ "$rm_line" -lt "$host_line" ] \
	&& ok "relay-smoke removes the host log before the host starts" || bad "relay-smoke order" "rm at ${rm_line:-none}, host at ${host_line:-none}"
printf '\nnet-own-line: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
