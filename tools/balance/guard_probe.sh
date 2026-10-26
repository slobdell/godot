#!/usr/bin/env bash
# B5 (round 41, balance): tools/scoreboard/guard.sh, with the fights played by tests/tactics/face_probe.gd (GUARD_RESULT
# unchanged + a FACE line) through mk/balance.mk's `balance-guard-run` instead of scoreboard.mk's `guard-run`. Everything
# else is guard.sh's (its seeds, chunks, resume, copy-back, driver.txt); the one difference is the make target name in its
# remote call, so this adapter rewrites that word in a private copy and runs it. The commit it runs must carry
# mk/balance.mk's target and the probe (they are not in guard.sh's overlay). An adapter, not an edit: guard.sh is native's
# (workstreams.md round 41 ownership); a GUARD_TARGET knob in guard.sh would retire this file (requested in the brief).
#   tools/balance/guard_probe.sh COMMIT [HOST]        (search.py run --probe calls it with GUARD_* in the environment)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=$(git -C "$here" rev-parse --show-toplevel)
tmp=$(mktemp "${TMPDIR:-/tmp}/guard_probe.XXXXXX")
sed -e 's|remote\.sh native guard-run |remote.sh native balance-guard-run |' "$src/tools/scoreboard/guard.sh" > "$tmp"
grep -q 'remote.sh native balance-guard-run ' "$tmp" \
	|| { echo "guard_probe: guard.sh no longer calls 'remote.sh native guard-run': update this adapter" >&2; rm -f "$tmp"; exit 2; }
bash "$tmp" "$@"
status=$?
rm -f "$tmp"
exit $status
