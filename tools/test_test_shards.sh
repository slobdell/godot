#!/usr/bin/env bash
# Known-answer tests for `make test`'s sharded recipe (mk/core.mk), with Godot replaced by a stub (ship, round 18).
# The branch this exists for: a shard that prints its summary line and then dies at exit must FAIL the target.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -20; }
export TANK_SQUAD_SLOT=1
export SHARD_STUB_DIR="$tmp"
# $SHARD_STUB_DIR/mode.<i>: OK (default), CRASH (summary, then abort 134), FAILS (2 failed, exit 1), SILENT (dies first)
printf '%s\n' '#!/usr/bin/env bash' \
	'sh=""; for a in "$@"; do case "$a" in --shard=*) sh=${a#--shard=};; esac; done; i=${sh%/*}' \
	'mode=$(cat "$SHARD_STUB_DIR/mode.$i" 2>/dev/null || echo OK)' \
	'[ "$mode" = SILENT ] && exit 139' \
	'echo "SHARD-ENGINE $sh: 0 errors, 0 warnings"' \
	'if [ "$mode" = FAILS ]; then echo "SHARD $sh: 2 files, 3 passed, 2 failed"; exit 1; fi' \
	'echo "SHARD $sh: 2 files, 5 passed, 0 failed"' \
	'if [ "$mode" = CRASH ]; then echo "corrupted size vs. prev_size in fastbins"; exit 134; fi' \
	'exit 0' > "$tmp/godot"
chmod +x "$tmp/godot"
run() { rm -f "$tmp"/mode.*; for m in "$@"; do echo "${m#*=}" > "$tmp/mode.${m%%=*}"; done
	( cd "$repo" && make --no-print-directory -o import test TEST_SHARDS=3 GODOT="$tmp/godot" BUILD_DIR="$tmp/build" 2>&1 ); }

out=$(run); rc=$?
[ $rc = 0 ] && grep -q '^15 passed, 0 failed' <<<"$out" && ok "three clean shards: pass, totals summed" || bad "clean" "$out"
out=$(run 1=CRASH); rc=$?
[ $rc != 0 ] && grep -q 'test FAILED: shard 1 exited 134 with no failed test' <<<"$out" \
	&& ok "a shard that aborts AFTER its summary line FAILS, named" || bad "crash after summary" "$out"
grep -q 'corrupted size' <<<"$out" && ok "and its last lines are shown" || bad "last lines" "$out"
out=$(run 2=FAILS); rc=$?
[ $rc != 0 ] && grep -q '13 passed, 2 failed' <<<"$out" && ! grep -q 'died AFTER' <<<"$out" \
	&& ok "a shard with failed tests fails as before, not called a crash" || bad "fails" "$out"
out=$(run 0=SILENT); rc=$?
[ $rc != 0 ] && grep -q '2 of 3 shards reported a summary line' <<<"$out" && ok "a shard that dies first: the old refusal" || bad "silent" "$out"

printf '\ntest-shards: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
