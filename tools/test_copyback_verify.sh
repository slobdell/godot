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

# ---- a same-size, same-mtime stale file (round 39, build/flank_s5.mp4): only a --checksum re-copy fixes it ------------
B="$tmp/box"; L="$tmp/local"; mkdir -p "$B/build" "$L/build"
printf 'fresh frames 0123\n' > "$B/build/clip.mp4"
printf 'ok\n'                > "$B/build/other.txt"
( cd "$B" && sha256sum build/clip.mp4 build/other.txt > "$tmp/box.manifest" )
rsync -a "$B/" "$L/" >/dev/null
printf 'STALE frames 9876\n' > "$L/build/clip.mp4"; touch -r "$B/build/clip.mp4" "$L/build/clip.mp4"
rsync -a "$B/" "$L/" >/dev/null
cmp -s "$B/build/clip.mp4" "$L/build/clip.mp4" \
	&& bad "the planted file reproduces the bug (a plain rsync -a skips it)" "plain rsync fixed it: the test plants nothing" \
	|| ok "the planted file reproduces the bug (a plain rsync -a skips it)"
out=$(bash "$cb" "$L" "$tmp/box.manifest" 2>&1); rc=$?
[ "$rc" = 5 ] && ok "no source: the stale file is still CORRUPT (exit 5)" || bad "no source: exit 5" "exit $rc: $out"
out=$(bash "$cb" "$L" "$tmp/box.manifest" "$B/" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "with the box as source: re-copied with --checksum, then verified (exit 0)" || bad "with source: exit 0" "exit $rc: $out"
cmp -s "$B/build/clip.mp4" "$L/build/clip.mp4" && ok "with source: the local bytes are the box's" || bad "with source: the local bytes are the box's"
grep -q "CORRUPT  build/clip.mp4" <<<"$out" && grep -q "fixed all 1" <<<"$out" && grep -q "verified, 2 files" <<<"$out" \
	&& ok "with source: the first-pass mismatch is still printed, then the fix" || bad "with source: says what happened" "$out"
grep -q "other.txt" <<<"$out" && bad "with source: only the failed file is re-copied" "$out" || ok "with source: only the failed file is re-copied"
printf 'BOX ITSELF CHANGED\n' > "$B/build/clip.mp4"
printf 'STALE frames 9876\n' > "$L/build/clip.mp4"
out=$(bash "$cb" "$L" "$tmp/box.manifest" "$B/" 2>&1); rc=$?
[ "$rc" = 5 ] && grep -q "FAILED -- 1 corrupt" <<<"$out" \
	&& ok "a source that no longer matches the manifest: still FAILED (exit 5), never a pass" || bad "unfixable: exit 5" "exit $rc: $out"
rm -f "$L/build/other.txt" "$B/build/other.txt"
out=$(bash "$cb" "$L" "$tmp/box.manifest" "$B/" 2>&1); rc=$?
[ "$rc" = 5 ] && grep -q "MISSING  build/other.txt" <<<"$out" && ok "missing on both sides: exit 5, the rsync error does not end the check" || bad "missing both: exit 5" "exit $rc: $out"
grep -q 'copyback_verify.sh" "$verify_root" "$verify_root/build/.copyback.sha256" \\' "$remote_sh" \
	&& grep -q '"$host:$remote_dir/" || verify_status' "$remote_sh" \
	&& ok "remote.sh passes the box's folder as the re-copy source, home-relative" || bad "remote.sh passes the box's folder as the re-copy source, home-relative"

# ---- round 41 N1: a `host:~/dir/` source runs the re-copy branch for real -------------------------------------------------
# rsync 3.4's sender takes the `~` of a --files-from source literally: change_dir "/home/<user>/~/tank_squad/..." and exit 12
# on the receiving side (manoeuvre, builder2, 2026-10-25; reproduced against builder0 2026-10-26). A stub rsync on PATH plays
# the box: `box:<path>` maps onto $tmp/home/<path>, and a literal `~` in a --files-from source fails exactly that way.
H="$tmp/home"; mkdir -p "$H/tank_squad/godot-x/build" "$tmp/bin"
real_rsync=$(command -v rsync)
cat > "$tmp/bin/rsync" <<STUB
#!/usr/bin/env bash
args=(); ff=0; tilde=0
for a in "\$@"; do
	case "\$a" in --files-from=*) ff=1 ;; esac
	case "\$a" in
		box:*) p=\${a#box:}; case "\$p" in '~/'*) tilde=1 ;; esac; args+=("$H/\$p") ;;
		*) args+=("\$a") ;;
	esac
done
if [ \$ff = 1 ] && [ \$tilde = 1 ]; then
	echo 'rsync: [sender] change_dir "/home/u/~/..." failed: No such file or directory (2)' >&2; exit 12
fi
exec "$real_rsync" "\${args[@]}"
STUB
chmod +x "$tmp/bin/rsync"
X="$tmp/xlocal"; mkdir -p "$X/build"
printf 'fresh frames 0123\n' > "$H/tank_squad/godot-x/build/clip.mp4"
( cd "$H/tank_squad/godot-x" && sha256sum build/clip.mp4 > "$tmp/x.manifest" )
cp -p "$H/tank_squad/godot-x/build/clip.mp4" "$X/build/clip.mp4"
printf 'STALE frames 9876\n' > "$X/build/clip.mp4"; touch -r "$H/tank_squad/godot-x/build/clip.mp4" "$X/build/clip.mp4"
out=$(PATH="$tmp/bin:$PATH" bash "$tmp/bin/rsync" -a --files-from=<(echo build/clip.mp4) "box:~/tank_squad/godot-x/" "$X/" 2>&1); rc=$?
[ "$rc" = 12 ] && ok "the stub reproduces the bug: a --files-from source with ~/ exits 12" || bad "stub reproduces exit 12" "exit $rc: $out"
out=$(PATH="$tmp/bin:$PATH" bash "$cb" "$X" "$tmp/x.manifest" "box:~/tank_squad/godot-x/" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "a box:~/dir/ source: the re-copy runs and the file verifies (exit 0)" || bad "box:~/ source: exit 0" "exit $rc: $out"
grep -q "re-copy exited" <<<"$out" && bad "a box:~/dir/ source: the re-copy's rsync succeeds" "$out" || ok "a box:~/dir/ source: the re-copy's rsync succeeds"
grep -q "fixed all 1" <<<"$out" && ok "a box:~/dir/ source: says the re-copy fixed it" || bad "box:~/ source: fixed all 1" "$out"
printf 'STALE frames 9876\n' > "$X/build/clip.mp4"; touch -r "$H/tank_squad/godot-x/build/clip.mp4" "$X/build/clip.mp4"
out=$(PATH="$tmp/bin:$PATH" bash "$cb" "$X" "$tmp/x.manifest" "box:tank_squad/godot-x/" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "a home-relative box:dir/ source (what remote.sh passes): exit 0" || bad "box:dir/ source: exit 0" "exit $rc: $out"

printf '\ncopyback-verify: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
