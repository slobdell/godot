#!/usr/bin/env bash
# Known answers for tools/scoreboard/guard.sh's GUARD_TARGET (round 41, balance's ask): guard.sh runs end to end in a
# throwaway git repo whose tools/remote.sh is a stub that records the make target and writes one GUARD_RESULT per fight.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
pass=0; fail=0
tmp=$(mktemp -d); trap 'git -C "$tmp/repo" worktree remove --force "$tmp/wt" >/dev/null 2>&1; rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

R="$tmp/repo"; mkdir -p "$R/tools/scoreboard"
cp "$here/scoreboard/guard.sh" "$R/tools/scoreboard/guard.sh"
cat > "$R/tools/remote.sh" <<'STUB'
#!/usr/bin/env bash
# stub: remote.sh native <target> KEY=VAL...; plays every fight locally as one GUARD_RESULT line
target=$2; shift 2
for a in "$@"; do case "$a" in GUARD_KINDS=*|GUARD_AT=*|GUARD_SEEDS=*|GUARD_SIDES=*) export "${a%%=*}=${a#*=}" ;; esac; done
echo "$target" >> "$STUB_LOG"
for k in $GUARD_KINDS; do mkdir -p build/guards/$k; for a in $GUARD_AT; do for s in $GUARD_SEEDS; do for d in $GUARD_SIDES; do
	echo 'GUARD_RESULT {}' > build/guards/$k/$a-$s-$d.log; done; done; done; done
echo '>> guard-run on stub | load 0.00' > build/guards/run.txt
echo ">> remote: copy-back verified, 1 files, sha256"
echo ">> remote: make $target GUARD_RESUME=1 exited 0 (build/ copied back)"
STUB
( cd "$R" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm stub ) || { echo "setup failed"; exit 1; }
run() {  # run TARGET-or-empty: guard.sh on the stub repo, one seed, one kind, one arena, one side
	( cd "$R" && { [ -z "$1" ] || export GUARD_TARGET="$1"; } && STUB_LOG="$tmp/targets.log" GUARD_WORKTREE="$tmp/wt" GUARD_OUT="$tmp/out" GUARD_SEEDS=1 GUARD_KINDS=blob \
		GUARD_AT=terminus GUARD_SIDES=green GUARD_TAG="${2:-t}" bash tools/scoreboard/guard.sh HEAD slobdell@stubhost )
}

: > "$tmp/targets.log"
out=$(run "" default 2>&1); rc=$?
[ "$rc" = 0 ] && ok "default: guard.sh reads the seed (exit 0)" || bad "default: exit 0" "exit $rc: $out"
[ "$(cat "$tmp/targets.log")" = guard-run ] && ok "default: the remote call runs guard-run" || bad "default target" "$(cat "$tmp/targets.log")"
grep -q "target guard-run" <<<"$out" && ok "default: driver line names the target" || bad "default: driver line" "$out"

: > "$tmp/targets.log"
out=$(run balance-guard-run probe 2>&1); rc=$?
[ "$rc" = 0 ] && ok "GUARD_TARGET=balance-guard-run: the seed is read (exit 0)" || bad "knob: exit 0" "exit $rc: $out"
[ "$(cat "$tmp/targets.log")" = balance-guard-run ] && ok "GUARD_TARGET=balance-guard-run: the remote call runs it" \
	|| bad "knob target" "$(cat "$tmp/targets.log")"
grep -q "seed 1 read" <<<"$out" && ok "GUARD_TARGET: its exit line is recognised (seed read, not LOST)" || bad "knob: exit line" "$out"

: > "$tmp/targets.log"
out=$(run 'guard-run; rm -rf x' bad 2>&1); rc=$?
[ "$rc" = 2 ] && grep -q "not a make target name" <<<"$out" && ok "a GUARD_TARGET that is not a target name: exit 2, nothing run" \
	|| bad "bad name: exit 2" "exit $rc: $out"
[ ! -s "$tmp/targets.log" ] && ok "a bad GUARD_TARGET reaches no remote call" || bad "bad name ran" "$(cat "$tmp/targets.log")"

printf '\nguard-target: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
