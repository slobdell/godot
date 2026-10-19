#!/usr/bin/env bash
# Known-answer tests for native/src_sync.sh (round 35, N3, R35.15): a source whose CONTENT changed since the last successful
# build is touched before cmake, whatever its mtime. The case it guards: a remote run built the library from the pre-merge
# tree, then the merge arrived by `rsync -a` with OLDER mtimes than the objects, cmake rebuilt nothing, and a full check ran
# on a stale library.
set -u
sync="$(cd "$(dirname "$0")/.." && pwd)/native/src_sync.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
mtime() { stat -c %Y "$1"; }

src="$tmp/native"; sums="$tmp/build/.src-sums"
mkdir -p "$src/src" "$tmp/build"
printf 'int a = 1;\n' > "$src/src/a.cpp"
printf 'int b = 1;\n' > "$src/src/b.h"
printf 'project(x)\n' > "$src/CMakeLists.txt"
old=200001010000  # 2000-01-01: older than any object a build writes
touch -t $old "$src/src/a.cpp" "$src/src/b.h" "$src/CMakeLists.txt"

touch -t $old "$tmp/ref"
out=$(bash "$sync" check "$src" "$sums"); rc=$?
[ $rc = 0 ] && grep -q "no record" <<<"$out" && ok "no record (a tree built before this check): says so" || bad "no record" "$out"
[ "$(mtime "$src/src/a.cpp")" -gt "$(mtime "$tmp/ref")" ] && [ "$(mtime "$src/CMakeLists.txt")" -gt "$(mtime "$tmp/ref")" ] \
	&& ok "  and touches every input: its objects may be stale" || bad "no record left old mtimes"
touch -t $old "$src/src/a.cpp" "$src/src/b.h" "$src/CMakeLists.txt"

bash "$sync" record "$src" "$sums" >/dev/null; [ -s "$sums" ] && ok "record writes the sums" || bad "record"

out=$(bash "$sync" check "$src" "$sums"); [ $? = 0 ] && grep -q "0 changed" <<<"$out" && ok "unchanged: 0 changed" || bad "unchanged" "$out"

# The R35.15 case: a.cpp's content changes but its mtime stays OLD (rsync -a of an older file)
printf 'int a = 2;\n' > "$src/src/a.cpp"; touch -t $old "$src/src/a.cpp"
before=$(mtime "$src/src/a.cpp")
out=$(bash "$sync" check "$src" "$sums")
after=$(mtime "$src/src/a.cpp")
[ "$after" -gt "$before" ] && grep -q "1 changed" <<<"$out" && grep -q "src/a.cpp" <<<"$out" \
	&& ok "content changed, mtime old: touched (now newer than any object)" || bad "stale mtime" "$out"
[ "$(mtime "$src/src/b.h")" = "$before" ] && ok "  an unchanged header is left alone" || bad "touched b.h"

# Not recorded yet (the build may still fail): the next check touches a.cpp again
touch -t $old "$src/src/a.cpp"
out=$(bash "$sync" check "$src" "$sums"); grep -q "1 changed" <<<"$out" && ok "a failed build re-touches on the next check" || bad "retouch" "$out"
bash "$sync" record "$src" "$sums" >/dev/null
out=$(bash "$sync" check "$src" "$sums"); grep -q "0 changed" <<<"$out" && ok "after a successful build's record: 0 changed" || bad "after record" "$out"

# A new file and a removed one count as changes; CMakeLists.txt is an input too
touch -t $old "$src/src/a.cpp"
printf 'int c;\n' > "$src/src/c.cpp"; touch -t $old "$src/src/c.cpp"
rm "$src/src/b.h"
printf 'project(y)\n' > "$src/CMakeLists.txt"; touch -t $old "$src/CMakeLists.txt"
out=$(bash "$sync" check "$src" "$sums")
grep -q "3 changed" <<<"$out" && [ "$(mtime "$src/src/c.cpp")" -gt "$before" ] && [ "$(mtime "$src/CMakeLists.txt")" -gt "$before" ] \
	&& ok "a new file, a removed one and CMakeLists.txt: 3 changed, the existing two touched" || bad "new/removed/cmake" "$out"

# A removed file forces a rebuild of what remains (an object can still hold the deleted code): every source touched
grep -q "removed" <<<"$out" && [ "$(mtime "$src/src/a.cpp")" -gt "$before" ] && ok "  a removal touches every source" || bad "removal" "$out"

printf '\nnative-src-sync: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
