#!/usr/bin/env bash
# Known-answer tests for the per-map sim baseline (tools/sim_baseline.py; `make sim-baseline`, `make
# sim-baseline-adopt`). Ship, round 18, S1/S2.
#
# Every branch the check and the adopter have is driven here ONCE by a stub, before it merges (lesson 250: the
# check's refusal branch ran for the first time at nine in the evening, and it ran nothing). The Godot runs are
# replaced by two tiny scripts: one prints the game's DEALT_LAYOUTS line, one prints a MATCH_RESULT per map from a
# table. What can be WRONG -- the comparison, the refusals, what gets written, what the messages name -- is real.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
sb="$here/sim_baseline.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -20; }

# ---- the stubs ----------------------------------------------------------------------------------------------
# layouts: $tmp/rotation (space-separated) and $tmp/candidates; default foundry.
cat > "$tmp/layouts.sh" <<EOF
rot=\$(cat "$tmp/rotation"); cand=\$(cat "$tmp/candidates" 2>/dev/null)
j() { printf '['; first=1; for n in \$1; do [ \$first = 1 ] || printf ','; printf '"%s"' "\$n"; first=0; done; printf ']'; }
echo "Godot Engine v4.7.2 (stub)"
echo "DEALT_LAYOUTS {\"default\":\"foundry\",\"rotation\":\$(j "\$rot"),\"candidates\":\$(j "\$cand")}"
EOF
# match: the hash for \$1 from $tmp/hashes ("<map> <hash>"); "<map> FALLBACK" prints the arena's fallback error;
# "<map> NONE" prints no result; "<map> FLIP" prints a different hash on every read (a non-deterministic map).
cat > "$tmp/match.sh" <<EOF
h=\$(awk -v m="\$1" '\$1 == m {print \$2}' "$tmp/hashes")
case "\$h" in
FALLBACK) echo "ERROR: arena: no arena layout '\$1' (have foundry); using foundry" >&2; h=05df1d55ba49cde1;;
NONE) exit 0;;
FLIP) h=\$(printf '%016x' "\$\$");;   # a different hash per process: reads run concurrently
esac
echo "MATCH_RESULT {\"state_hash\":\"\$h\",\"winner\":\"green\"}"
EOF
export SIM_BASELINE_LAYOUTS_CMD="bash $tmp/layouts.sh"
export SIM_BASELINE_MATCH_CMD="bash $tmp/match.sh {layout}"
export SIM_BASELINE_KEY=glibc-2.43
export TANK_SQUAD_SLOT=1          # do not queue for a heavy-run slot to run `echo`

H_F=05df1d55ba49cde1; H_Y=1111111111111111; H_P=2222222222222222; H_T=3333333333333333
set_world() {   # the game deals yard pit terminus; the matches print these hashes
	echo "yard pit terminus" > "$tmp/rotation"; : > "$tmp/candidates"
	printf 'foundry %s\nyard %s\npit %s\nterminus %s\n' $H_F $H_Y $H_P $H_T > "$tmp/hashes"
}
baseline() {    # the recorded file: every map as the world prints it
	printf '# glibc-2.43 foundry: recorded on builder0 at ea61d450, twice, agreeing (2026-10-02)\nglibc-2.43 foundry %s\nglibc-2.43 yard %s\nglibc-2.43 pit %s\nglibc-2.43 terminus %s\n# glibc-2.99 foundry: another machine\nglibc-2.99 foundry aaaaaaaaaaaaaaaa\n' \
		$H_F $H_Y $H_P $H_T > "$tmp/base.txt"
}
check() { python3 "$sb" check "$tmp/base.txt" "$tmp/out" 2>&1; }

echo "-- check"
set_world; baseline
out=$(check); rc=$?
[ $rc = 0 ] && grep -q 'sim-baseline passed: 4 maps unmoved' <<<"$out" && ok "nothing moved: passes, counts the maps" || bad "nothing moved: passes" "$out"
grep -q 'dealt maps on glibc-2.43' <<<"$out" && grep -q 'foundry yard pit terminus' <<<"$out" \
	&& ok "names every dealt map, default first" || bad "names every dealt map" "$out"
[ "$(wc -l < "$tmp/out/lines.txt")" = 4 ] && grep -q "^glibc-2.43 yard $H_Y $H_Y$" "$tmp/out/lines.txt" \
	&& ok "writes one '<key> <map> <actual> <expected>' row per map" || bad "writes the rows" "$(cat "$tmp/out/lines.txt")"

sed -i "s/^yard .*/yard 9999999999999999/" "$tmp/hashes"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q "yard MOVED: expected $H_Y, got 9999999999999999" <<<"$out" && ok "one map moved: FAILS and names the map" || bad "one map moved" "$out"
grep -q 'make sim-baseline-adopt' <<<"$out" && ok "a move names the adopt command" || bad "a move names the adopt command" "$out"
grep -q 'pit .*unmoved' <<<"$out" && ok "the other maps still read unmoved" || bad "the others read unmoved" "$out"

set_world; echo "yard pit terminus locks" > "$tmp/rotation"; echo "locks 4444444444444444" >> "$tmp/hashes"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q 'locks: a DEALT map with no line for glibc-2.43' <<<"$out" \
	&& ok "a rotation map with no line FAILS (it does not skip)" || bad "a rotation map with no line FAILS" "$out"
grep -q 'make sim-baseline-adopt' <<<"$out" && ok "the missing line names the adopt command" || bad "missing line names adopt" "$out"

set_world; echo "open_centre" > "$tmp/candidates"
out=$(check); rc=$?
[ $rc = 0 ] && grep -q 'open_centre .*candidate: never dealt, no baseline line' <<<"$out" \
	&& ok "a candidate is shown, carries no line, and passes" || bad "a candidate is shown" "$out"
! grep -q 'open_centre' "$tmp/out/lines.txt" && ok "a candidate is never run" || bad "a candidate is never run"

set_world; echo "yard pit" > "$tmp/rotation"
out=$(check); rc=$?
[ $rc = 0 ] && grep -q 'terminus .*has a line but is not dealt: not checked' <<<"$out" \
	&& ok "a line for a map no longer dealt: noted, not checked" || bad "a stale line is noted" "$out"

set_world; out=$(SIM_BASELINE_KEY=glibc-9.9 check); rc=$?
[ $rc = 0 ] && grep -q 'sim-baseline SKIPPED: no baseline lines for glibc-9.9' <<<"$out" \
	&& ok "an unknown glibc: SKIPPED, as before (the laptop)" || bad "an unknown glibc skips" "$out"

set_world; sed -i 's/^pit .*/pit FALLBACK/' "$tmp/hashes"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q 'pit: the game did not load it' <<<"$out" \
	&& ok "ARM: a map that fell back to foundry FAILS by name" || bad "ARM: a fallback fails" "$out"

set_world; sed -i "s/^pit .*/pit $H_Y/" "$tmp/hashes"; sed -i "s/^glibc-2.43 pit .*/glibc-2.43 pit $H_Y/" "$tmp/base.txt"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q 'two maps fought the same fight (yard, pit share' <<<"$out" \
	&& ok "ARM: two maps with one hash FAIL" || bad "ARM: shared hash fails" "$out"

set_world; baseline; sed -i 's/^terminus .*/terminus NONE/' "$tmp/hashes"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q 'terminus: no MATCH_RESULT' <<<"$out" && ok "a match with no result FAILS by name" || bad "no result fails" "$out"

set_world; printf 'glibc-2.43 %s\n' $H_F > "$tmp/base.txt"
out=$(check); rc=$?
[ $rc != 0 ] && grep -q "unreadable line" <<<"$out" && ok "a two-column (pre-round-18) line is refused, not read as foundry" || bad "legacy line refused" "$out"

set_world; baseline; out=$(SIM_BASELINE_LAYOUTS_CMD="echo nothing" check); rc=$?
[ $rc != 0 ] && grep -q 'could not read the dealt maps from the game' <<<"$out" && ok "no DEALT_LAYOUTS from the game: FAILS" || bad "no layouts fails" "$out"

echo "-- read (on the build box)"
set_world
rm -rf "$tmp/out"; out=$(python3 "$sb" read "$tmp/out" 2>&1); rc=$?
[ $rc = 0 ] && grep -q '4 maps read twice, agreeing' <<<"$out" && ok "two agreeing reads per map pass" || bad "agreeing reads" "$out"
python3 -c "import json,sys; d=json.load(open('$tmp/out/sim_baseline_adopt.json')); assert d['hashes']['yard']=='$H_Y' and d['order'][0]=='foundry' and d['key']=='glibc-2.43' and d['commit'] and d['machine'] and d['date']" 2>/dev/null \
	&& ok "writes the reads with key, order, commit, machine, date" || bad "writes the reads" "$(cat "$tmp/out/sim_baseline_adopt.json" 2>/dev/null)"
sed -i 's/^pit .*/pit FLIP/' "$tmp/hashes"
out=$(python3 "$sb" read "$tmp/out" 2>&1); rc=$?
[ $rc != 0 ] && grep -q 'REFUSED' <<<"$out" && grep -q 'pit: the two reads DISAGREE' <<<"$out" \
	&& ok "two reads that disagree on ONE map refuse, naming it" || bad "disagreement refuses" "$out"
grep -q 'is not a baseline' <<<"$out" && ok "says why it matters" || bad "says why" "$out"
[ ! -e "$tmp/out/sim_baseline_adopt.json" ] && ok "a refusal leaves NO reads file (adopts nothing)" || bad "refusal leaves no reads"
set_world; sed -i 's/^yard .*/yard NONE/' "$tmp/hashes"
out=$(python3 "$sb" read "$tmp/out" 2>&1); rc=$?
[ $rc != 0 ] && [ ! -e "$tmp/out/sim_baseline_adopt.json" ] && ok "an empty read refuses and writes nothing" || bad "empty read refuses" "$out"

echo "-- adopt (here)"
reads() {  # $1 = key; then "map hash" pairs in dealt order
	key=$1; shift; python3 - "$key" "$@" > "$tmp/reads.json" <<'PY'
import json, sys
key, pairs = sys.argv[1], sys.argv[2:]
order = pairs[0::2]; hashes = dict(zip(pairs[0::2], pairs[1::2]))
print(json.dumps({"key": key, "hashes": hashes, "order": order, "commit": "abc1234", "machine": "builder0", "date": "2026-10-04"}))
PY
}
adopt() { python3 "$sb" adopt "$tmp/base.txt" "$tmp/reads.json" 2>&1; }

baseline; cp "$tmp/base.txt" "$tmp/base.before"
reads glibc-2.43 foundry $H_F yard $H_Y pit $H_P terminus $H_T
out=$(adopt); rc=$?
[ $rc = 0 ] && grep -q 'nothing moved' <<<"$out" && cmp -s "$tmp/base.txt" "$tmp/base.before" \
	&& ok "nothing moved: says so, writes nothing" || bad "nothing moved" "$out"

reads glibc-2.43 foundry $H_F yard 5555555555555555 pit $H_P terminus $H_T
out=$(adopt); rc=$?
[ $rc = 0 ] && grep -q "yard $H_Y -> 5555555555555555" <<<"$out" && ok "one map moved: lists it before -> after" || bad "one moved" "$out"
grep -q '^glibc-2.43 yard 5555555555555555$' "$tmp/base.txt" && grep -q "^glibc-2.43 pit $H_P$" "$tmp/base.txt" \
	&& ok "one map moved: merges that line, keeps the rest" || bad "one moved: merge" "$(cat "$tmp/base.txt")"
grep -q '^# glibc-2.43 yard: recorded on builder0 at abc1234, twice, agreeing (2026-10-04)$' "$tmp/base.txt" \
	&& ok "the moved line carries its provenance" || bad "provenance" "$(cat "$tmp/base.txt")"
grep -q '^# glibc-2.43 foundry: recorded on builder0 at ea61d450' "$tmp/base.txt" \
	&& ok "an unmoved line keeps its OLD provenance" || bad "unmoved provenance kept" "$(cat "$tmp/base.txt")"
grep -q '^glibc-2.99 foundry aaaaaaaaaaaaaaaa$' "$tmp/base.txt" && ok "another machine's line is kept" || bad "other machine kept"
grep -q 'git commit -m "baselines: sim hashes on glibc-2.43 moved on yard' <<<"$out" && grep -q 'unmoved: foundry, pit, terminus' <<<"$out" \
	&& ok "prints ONE commit message naming moved and unmoved maps" || bad "commit message" "$out"
out2=$(check); [ $? != 0 ] && ok "(the world still prints the old yard: check is red until it moves)" || bad "check red after adopt" "$out2"

baseline
reads glibc-2.43 foundry 6666666666666661 yard 6666666666666662 pit 6666666666666663 terminus 6666666666666664
out=$(adopt); rc=$?
[ $rc = 0 ] && [ "$(grep -c -- '->' <<<"$out")" -ge 4 ] && grep -q 'unmoved: none' <<<"$out" \
	&& ok "all moved: every map listed, none unmoved" || bad "all moved" "$out"

baseline
reads glibc-2.43 foundry $H_F yard $H_Y pit $H_P terminus $H_T locks 4444444444444444
out=$(adopt); rc=$?
[ $rc = 0 ] && grep -q 'locks (no line) -> 4444444444444444' <<<"$out" && grep -q '^glibc-2.43 locks 4444444444444444$' "$tmp/base.txt" \
	&& ok "a rotation map with no line: ADDED" || bad "missing line added" "$out"

baseline
reads glibc-2.43 foundry $H_F yard $H_Y pit $H_P
out=$(adopt); rc=$?
[ $rc = 0 ] && grep -q "terminus $H_T -> (dropped: no longer dealt)" <<<"$out" && ! grep -q 'glibc-2.43 terminus' "$tmp/base.txt" \
	&& ok "a map no longer dealt: its line dropped, and said" || bad "dropped line" "$out"

baseline
reads glibc-3.01 foundry $H_F yard $H_Y pit $H_P terminus $H_T
out=$(adopt); rc=$?
[ $rc = 0 ] && grep -q 'glibc-3.01 is a machine with no lines yet' <<<"$out" && [ "$(grep -c '^glibc-3.01 ' "$tmp/base.txt")" = 4 ] \
	&& grep -q "^glibc-2.43 yard $H_Y$" "$tmp/base.txt" && ok "an unknown glibc: adds its lines, keeps every other machine's" || bad "unknown glibc" "$out"

baseline; rm -f "$tmp/reads.json"
out=$(adopt); rc=$?
[ $rc != 0 ] && grep -q 'Nothing was adopted' <<<"$out" && cmp -s "$tmp/base.txt" "$tmp/base.before" \
	&& ok "no reads came back: FAILS, adopts nothing" || bad "no reads file" "$out"
echo '{"key":"glibc-2.43","hashes":{"yard":"short"},"order":["yard"],"commit":"x","machine":"m","date":"d"}' > "$tmp/reads.json"
out=$(adopt); rc=$?
[ $rc != 0 ] && cmp -s "$tmp/base.txt" "$tmp/base.before" && ok "a reads file holding a non-hash: refused" || bad "non-hash refused" "$out"

echo "-- candidates (S4: they load and play; no line)"
cand() { SIM_BASELINE_SMOKE_CMD="bash $tmp/match.sh {layout}" python3 "$sb" candidates "$tmp/cout" 2>&1; }
set_world
out=$(cand); rc=$?
[ $rc = 0 ] && grep -q 'lists no candidate maps' <<<"$out" && ok "no candidates: says so, passes" || bad "no candidates" "$out"
echo "open_centre ridge" > "$tmp/candidates"; printf 'open_centre 7777777777777777\nridge 8888888888888888\n' >> "$tmp/hashes"
out=$(cand); rc=$?
[ $rc = 0 ] && grep -q '2 candidate map(s) loaded and played: open_centre ridge' <<<"$out" && ok "candidates play: passes, names them" || bad "candidates play" "$out"
! grep -q 'yard' <<<"$out" && ok "candidates-smoke runs no dealt map" || bad "no dealt map in candidates" "$out"
sed -i 's/^ridge .*/ridge FALLBACK/' "$tmp/hashes"
out=$(cand); rc=$?
[ $rc != 0 ] && grep -q 'ridge: the game did not load it' <<<"$out" && ok "a candidate that does not load FAILS by name" || bad "candidate fallback" "$out"
grep -q '^ERROR: arena: no arena layout' <<<"$out" && ok "its engine line is echoed for the gate to judge" || bad "engine line echoed" "$out"

echo "-- the make targets (the recipe around the tool)"
mk() { ( cd "$repo" && make --no-print-directory -o import "$@" BUILD_DIR="$tmp/build" SIM_BASELINE_FILE="$tmp/base.txt" SIM_BASELINE_ENV=env 2>&1 ); }
set_world; baseline; rm -rf "$tmp/build"
out=$(mk sim-baseline); rc=$?
[ $rc = 0 ] && grep -q 'sim-baseline passed: 4 maps' <<<"$out" && [ "$(wc -l < "$tmp/build/sim_baseline.txt")" = 4 ] \
	&& ok "make sim-baseline: passes, leaves build/sim_baseline.txt" || bad "make sim-baseline" "$out"
out=$(mk check-hashes); grep -q "yard=$H_Y(unmoved)" <<<"$out" && ok "make check-hashes: one line, every map" || bad "check-hashes" "$out"
sed -i "s/^yard .*/yard 9999999999999999/" "$tmp/hashes"
out=$(mk sim-baseline); rc=$?
[ $rc != 0 ] && grep -q 'yard MOVED' <<<"$out" && ok "make sim-baseline: a move exits non-zero" || bad "make sim-baseline red" "$out"
out=$(mk check-hashes); grep -q "moved: yard" <<<"$out" && grep -q 'make sim-baseline-adopt' <<<"$out" \
	&& ok "make check-hashes: names the moved map and the adopt command" || bad "check-hashes moved" "$out"
rm -f "$tmp/build/sim_baseline.txt"; out=$(mk check-hashes); grep -q 'sim-baseline NOT RUN' <<<"$out" \
	&& ok "make check-hashes: absent data reads NOT RUN, never unmoved" || bad "check-hashes not run" "$out"

remote="make --no-print-directory -o import BUILD_DIR=$tmp/build SIM_BASELINE_ENV=env"
out=$(mk sim-baseline-adopt SIM_BASELINE_REMOTE="$remote"); rc=$?
[ $rc = 0 ] && grep -q "yard $H_Y -> 9999999999999999" <<<"$out" && grep -q '^glibc-2.43 yard 9999999999999999$' "$tmp/base.txt" \
	&& ok "make sim-baseline-adopt: reads twice, merges the moved map" || bad "make adopt" "$out"
out=$(mk sim-baseline); rc=$?
[ $rc = 0 ] && ok "make sim-baseline: green after the adoption" || bad "green after adopt" "$out"
cp "$tmp/base.txt" "$tmp/base.before"; sed -i 's/^pit .*/pit FLIP/' "$tmp/hashes"
out=$(mk sim-baseline-adopt SIM_BASELINE_REMOTE="$remote"); rc=$?
[ $rc != 0 ] && grep -q 'REFUSED' <<<"$out" && cmp -s "$tmp/base.txt" "$tmp/base.before" \
	&& ok "make sim-baseline-adopt: a disagreement on the box adopts nothing" || bad "make adopt refuses" "$out"
out=$(mk sim-baseline-adopt SIM_BASELINE_REMOTE="true"); rc=$?
[ $rc != 0 ] && grep -q 'Nothing was adopted' <<<"$out" && ok "make sim-baseline-adopt: nothing came back, nothing adopted" || bad "make adopt: nothing back" "$out"

printf '\nsim-baseline: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
