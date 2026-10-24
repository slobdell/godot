#!/usr/bin/env bash
# Known answers for tools/judge/physics_share.py (round 39 stretch): wall a tick from MATCH_RESULT, scripts from SIM_PROFILE,
# the engine as the difference, the fights weighted by ticks, and a log missing either line refused.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fight() {  # fight FILE TICKS TICK_MS DRIVE_MS REAL_SECONDS
	printf 'SIM_PROFILE {"ticks": %s, "tick_ms": %s, "sections": {"tank/drive": {"ms_per_tick": %s, "calls_per_tick": 1}}}\n' "$2" "$3" "$4" > "$1"
	printf 'MATCH_RESULT {"real_seconds": %s}\n' "$5" >> "$1"
}
fight "$tmp/a.log" 1000 8.0 1.0 10.0   # wall 10 ms: engine 2 (20 %), drive 1 (10 %)
fight "$tmp/b.log" 3000 18.0 3.0 60.0  # wall 20 ms: engine 2 (10 %), drive 3 (15 %)
out=$(python3 "$here/judge/physics_share.py" "$tmp/a.log" "$tmp/b.log"); s=$?
[ "$s" = 0 ] && grep -q "a.log: 1000 ticks, wall 10.000 ms/tick, scripts 8.000, engine (frame - scripts) 2.000 (20.0%), tank/drive 1.000 (10.0%)" <<<"$out" \
	&& ok "one fight: wall, scripts, engine, drive" || bad "one fight" "$out"
# weighted by ticks: wall (10x1000 + 20x3000)/4000 = 17.5; engine 2.0 (11.4 %); drive (1000 + 9000)/4000 = 2.5 (14.3 %)
grep -q "all 2 fights, 4000 ticks: wall 17.500 ms/tick; engine 2.000 (11.4%); tank/drive 2.500 (14.3%); physics at most 25.7% of a tick" <<<"$out" \
	&& ok "all fights, weighted by ticks" || bad "weighted" "$out"
printf 'MATCH_RESULT {"real_seconds": 1}\n' > "$tmp/c.log"
out=$(python3 "$here/judge/physics_share.py" "$tmp/c.log"); s=$?
[ "$s" = 1 ] && grep -q "not read" <<<"$out" && ok "a log without SIM_PROFILE is refused" || bad "refused" "exit $s: $out"
printf '\nphysics-share: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
