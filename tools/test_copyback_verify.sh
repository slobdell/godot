#!/usr/bin/env bash
# Known-answer tests for the copy-back integrity check.
set -uo pipefail
cb="$(cd "$(dirname "$0")" && pwd)/copyback_verify.sh"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

R="$tmp/root"; mkdir -p "$R/build/metrics"
printf 'hello\n' > "$R/build/metrics/a.jsonl"
printf 'world\n' > "$R/build/metrics/b.jsonl"
( cd "$R" && sha256sum build/metrics/a.jsonl build/metrics/b.jsonl > "$tmp/manifest" )

out=$(bash "$cb" "$R" "$tmp/manifest" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "intact copy: exit 0" || bad "intact copy: exit 0" "exit $rc: $out"
grep -q "verified, 2 files" <<<"$out" && ok "intact copy: counts the files" || bad "intact copy: counts the files" "$out"

# One flipped byte, the shape of the real event.
printf 'hellp\n' > "$R/build/metrics/a.jsonl"
out=$(bash "$cb" "$R" "$tmp/manifest" 2>&1); rc=$?
[ "$rc" = 5 ] && ok "a changed byte: exit 5" || bad "a changed byte: exit 5" "exit $rc"
grep -q "CORRUPT  build/metrics/a.jsonl" <<<"$out" && ok "a changed byte: names the file" || bad "a changed byte: names the file" "$out"
grep -q "the box wrote" <<<"$out" && ok "a changed byte: prints both hashes" || bad "a changed byte: prints both hashes"
grep -q "b.jsonl" <<<"$out" && bad "the intact file is not blamed" || ok "the intact file is not blamed"
printf 'hello\n' > "$R/build/metrics/a.jsonl"

rm -f "$R/build/metrics/b.jsonl"
out=$(bash "$cb" "$R" "$tmp/manifest" 2>&1); rc=$?
[ "$rc" = 5 ] && ok "a file that never arrived: exit 5" || bad "a file that never arrived: exit 5" "exit $rc"
grep -q "MISSING  build/metrics/b.jsonl" <<<"$out" && ok "a file that never arrived: named" || bad "a file that never arrived: named" "$out"
printf 'world\n' > "$R/build/metrics/b.jsonl"

# "nothing to check" must never print like "everything checked out".
out=$(bash "$cb" "$R" "$tmp/no-such-manifest" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "no manifest: NOT VERIFIED, not a pass" || bad "no manifest: NOT VERIFIED" "exit $rc: $out"
grep -q "NOT VERIFIED" <<<"$out" && ok "no manifest: says so in those words" || bad "no manifest: says so"
: > "$tmp/empty"
out=$(bash "$cb" "$R" "$tmp/empty" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "empty manifest: NOT VERIFIED, not a vacuous pass" || bad "empty manifest: NOT VERIFIED" "exit $rc"
printf '# a comment\n\n' > "$tmp/comments"
out=$(bash "$cb" "$R" "$tmp/comments" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "a manifest with no sha lines: NOT VERIFIED" || bad "a manifest with no sha lines: NOT VERIFIED" "exit $rc"

bash "$cb" >/dev/null 2>&1; [ $? = 2 ] && ok "no arguments: exit 2" || bad "no arguments: exit 2"

# ---- the copy-back's own rsync flags: mirror the run, but never unlink an open log -------------------
# Two assertions, because either alone is a lie: that remote.sh CARRIES these flags, and that the flags DO
# what the comment beside them claims. Without the first the test drifts away from the script; without the
# second it only checks a string.
remote_sh="$(cd "$(dirname "$0")" && pwd)/remote.sh"
grep -q -- "--delete --filter='P \*\.log'" "$remote_sh" \
	&& ok "remote.sh copies back with --delete and protects *.log" \
	|| bad "remote.sh copies back with --delete and protects *.log" "flags not found in remote.sh"

S="$tmp/src"; D="$tmp/dst"; mkdir -p "$S/metrics" "$D/metrics" "$D/web"
printf 'this run
'   > "$S/metrics/fresh.jsonl"
printf 'LAST run
'   > "$D/metrics/stale.jsonl"      # must go: it wears a plausible name
printf 'wrapper
'    > "$D/metrics/check.log"        # must stay: a redirect may still be open on it
printf 'big
'        > "$D/web/index.wasm"           # must stay: excluded, so not ours to delete
rsync -a --delete --filter='P *.log' --exclude='web/' --exclude='server/' 	--exclude='*.pck' --exclude='*.wasm' "$S/" "$D/" >/dev/null 2>&1
[ -f "$D/metrics/fresh.jsonl" ] && ok "copy-back: this run's artefact arrives" || bad "copy-back: this run's artefact arrives"
[ ! -e "$D/metrics/stale.jsonl" ] && ok "copy-back: LAST run's artefact is gone" || bad "copy-back: LAST run's artefact is gone"
[ -f "$D/metrics/check.log" ] && ok "copy-back: the wrapper log survives" || bad "copy-back: the wrapper log survives"
[ -f "$D/web/index.wasm" ] && ok "copy-back: excluded paths are not deleted either" || bad "copy-back: excluded paths are not deleted"

printf '\ncopyback-verify: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
