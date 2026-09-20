#!/usr/bin/env bash
# Known-answer tests for `baseline_merge.py`, which adopts ONE machine's sim baseline.
#
# It exists because the hand procedure it replaces -- `cp build/sim_state_hash.txt tests/baselines/` -- does
# not go stale, it DELETES: `build/sim_state_hash.txt` holds one line, the recording machine's. With only
# builder0 baselined that is invisible, which is exactly when it should be pinned.
set -uo pipefail
bm="$(cd "$(dirname "$0")" && pwd)/baseline_merge.py"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
f="$tmp/sim_state_hash.txt"

printf 'glibc-2.43 1e90f69e5d6fcc46\n' > "$f"
out=$(python3 "$bm" "$f" glibc-2.43 aaaaaaaaaaaaaaaa abc1234 builder0 2026-09-20 2>&1); rc=$?
[ "$rc" = 0 ] && ok "adopt: exit 0" || bad "adopt: exit 0" "exit $rc: $out"
grep -q '^glibc-2.43 aaaaaaaaaaaaaaaa$' "$f" && ok "adopt: the line is replaced" || bad "adopt: the line is replaced" "$(cat "$f")"
grep -q '1e90f69e5d6fcc46 -> aaaaaaaaaaaaaaaa' <<<"$out" && ok "adopt: says what moved" || bad "adopt: says what moved" "$out"
grep -q '^# glibc-2.43: recorded on builder0 at abc1234, twice, agreeing (2026-09-20)$' "$f" \
	&& ok "adopt: carries provenance" || bad "adopt: carries provenance" "$(cat "$f")"

# THE ONE THAT MATTERS: another machine's line must survive.
printf 'glibc-2.39 1111111111111111\nglibc-2.43 2222222222222222\n' > "$f"
python3 "$bm" "$f" glibc-2.43 3333333333333333 abc1234 builder0 >/dev/null 2>&1
grep -q '^glibc-2.39 1111111111111111$' "$f" && ok "another machine's baseline SURVIVES" || bad "another machine's baseline SURVIVES" "$(cat "$f")"
grep -q '^glibc-2.43 3333333333333333$' "$f" && ok "this machine's is updated beside it" || bad "this machine's is updated beside it"
out=$(python3 "$bm" "$f" glibc-2.43 4444444444444444 abc1234 builder0 2>&1)
grep -q "kept 1 other machine's line(s): glibc-2.39" <<<"$out" && ok "it says what it kept" || bad "it says what it kept" "$out"

# A new machine is added, not substituted.
python3 "$bm" "$f" glibc-2.99 5555555555555555 abc1234 laptop >/dev/null 2>&1
[ "$(grep -c '^glibc-' "$f")" = 3 ] && ok "a new machine is ADDED" || bad "a new machine is ADDED" "$(cat "$f")"
out=$(python3 "$bm" "$f" glibc-3.00 6666666666666666 abc1234 laptop 2>&1)
grep -q 'ADDED glibc-3.00' <<<"$out" && ok "an added key says ADDED, not moved" || bad "an added key says ADDED" "$out"

# Re-running with the same hash is not a change.
printf 'glibc-2.43 2222222222222222\n' > "$f"
out=$(python3 "$bm" "$f" glibc-2.43 2222222222222222 abc1234 builder0 2>&1)
grep -q 'unchanged at 2222222222222222' <<<"$out" && ok "an unchanged adopt says so" || bad "an unchanged adopt says so" "$out"

# A hash that is not a hash must never become a baseline: every later check would compare against nonsense
# and the failure would read as a gameplay change.
printf 'glibc-2.43 2222222222222222\n' > "$f"
for junk in "" "short" "ZZZZZZZZZZZZZZZZ" "2222222222222222aa"; do
	python3 "$bm" "$f" glibc-2.43 "$junk" abc1234 builder0 >/dev/null 2>&1
	[ $? = 2 ] || bad "refuses a bad hash: '$junk'"
done
grep -q '^glibc-2.43 2222222222222222$' "$f" && ok "a refused adopt leaves the file untouched" || bad "a refused adopt leaves the file untouched" "$(cat "$f")"
ok "refuses an empty, short, non-hex or over-long hash"
python3 "$bm" "$f" "../../etc/passwd" 2222222222222222 abc1234 builder0 >/dev/null 2>&1
[ $? = 2 ] && ok "refuses a key that is not a libc key" || bad "refuses a key that is not a libc key"

# A file that does not exist yet is created, not crashed on.
rm -f "$f"
python3 "$bm" "$f" glibc-2.43 7777777777777777 abc1234 builder0 >/dev/null 2>&1
grep -q '^glibc-2.43 7777777777777777$' "$f" && ok "a missing baseline file is created" || bad "a missing baseline file is created"

# The reader `sim-baseline` uses must still find it past the comments.
[ "$(awk -v k=glibc-2.43 '$1 == k {print $2}' "$f")" = 7777777777777777 ] \
	&& ok "the awk reader in mk/core.mk still finds it" || bad "the awk reader in mk/core.mk still finds it" "$(cat "$f")"

python3 "$bm" >/dev/null 2>&1; [ $? = 2 ] && ok "no arguments: exit 2" || bad "no arguments: exit 2"

# ---- the double-read refusal in `sim-baseline-adopt-read` --------------------------------------------
# The Godot run cannot happen here, but the part that can be WRONG can: the comparison, the refusal, and
# what gets written. `SIM_HASH_READ` is a make variable precisely so it can be replaced -- a recipe whose
# only testable path needs a forty-second match on another machine is a recipe nobody tests.
repo="$(cd "$(dirname "$0")/.." && pwd)"
export TANK_SQUAD_SLOT=1          # do not queue for a heavy-run slot to run `echo`
adopt() {   # $1 = script emitting the hash(es)
	( cd "$repo" && make --no-print-directory -o import sim-baseline-adopt-read \
		BUILD_DIR="$tmp/build" SIM_HASH_READ="bash $1" 2>&1 )
}

printf 'printf 1234567890abcdef\n' > "$tmp/same.sh"
rm -rf "$tmp/build"; out=$(adopt "$tmp/same.sh"); rc=$?
[ "$rc" = 0 ] && ok "adopt-read: two agreeing reads pass" || bad "adopt-read: two agreeing reads pass" "exit $rc: $out"
grep -q 'read twice, agreeing' <<<"$out" && ok "adopt-read: says it read twice" || bad "adopt-read: says it read twice" "$out"
grep -q '^glibc-.* 1234567890abcdef$' "$tmp/build/sim_state_hash.txt" 2>/dev/null \
	&& ok "adopt-read: writes the hash line" || bad "adopt-read: writes the hash line" "$(cat "$tmp/build/sim_state_hash.txt" 2>/dev/null)"
grep -q '^hash=1234567890abcdef$' "$tmp/build/sim_baseline_adopt.env" 2>/dev/null \
	&& ok "adopt-read: writes the provenance env" || bad "adopt-read: writes the provenance env"
grep -qE '^(commit|machine|date)=' "$tmp/build/sim_baseline_adopt.env" \
	&& ok "adopt-read: the env carries commit, machine and date" || bad "adopt-read: env carries provenance"

# THE POINT: two reads that disagree must refuse, and must adopt NEITHER.
printf 'n=$(cat "%s/n" 2>/dev/null || echo 0); echo $((n+1)) > "%s/n"; printf "%%016x" "$n"\n' "$tmp" "$tmp" > "$tmp/differ.sh"
rm -rf "$tmp/build"; rm -f "$tmp/n"; out=$(adopt "$tmp/differ.sh"); rc=$?
[ "$rc" != 0 ] && ok "adopt-read: two disagreeing reads REFUSE" || bad "adopt-read: two disagreeing reads REFUSE" "exit 0: $out"
grep -q 'REFUSED' <<<"$out" && ok "adopt-read: says REFUSED" || bad "adopt-read: says REFUSED" "$out"
grep -q 'first:' <<<"$out" && grep -q 'second:' <<<"$out" && ok "adopt-read: prints both reads" || bad "adopt-read: prints both reads" "$out"
grep -q 'is not a baseline' <<<"$out" && ok "adopt-read: says why it matters" || bad "adopt-read: says why it matters"
[ ! -e "$tmp/build/sim_state_hash.txt" ] && ok "adopt-read: a disagreement adopts NEITHER hash" \
	|| bad "adopt-read: a disagreement adopts NEITHER hash" "$(cat "$tmp/build/sim_state_hash.txt")"

# A read that produces nothing is not a hash of "".
printf 'true\n' > "$tmp/empty.sh"
rm -rf "$tmp/build"; out=$(adopt "$tmp/empty.sh"); rc=$?
[ "$rc" != 0 ] && ok "adopt-read: an empty read refuses" || bad "adopt-read: an empty read refuses" "exit 0: $out"
[ ! -e "$tmp/build/sim_state_hash.txt" ] && ok "adopt-read: an empty read writes nothing" || bad "adopt-read: an empty read writes nothing"

printf '\nbaseline-merge: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
