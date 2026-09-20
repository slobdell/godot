#!/usr/bin/env bash
# Known-answer tests for `make lint` — the gate that reported "all scripts parse" on a tree whose runtime
# could not compile `movement.gd`, while the SAME tree failed lint in another worktree.
#
# `GODOT` is a make variable, so the checker can be substituted and every way lint can WRONGLY PASS can be
# driven here in seconds. That is the point: the failure was not a wrong finding, it was a missing one, and
# a missing finding is indistinguishable from a clean file unless something is known to be dirty.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export TANK_SQUAD_SLOT=1      # do not queue for a heavy-run slot to run a stub
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

stub() { printf '#!/usr/bin/env bash\n%s\n' "$1" > "$tmp/godot"; chmod +x "$tmp/godot"; }
lint() { ( cd "$repo" && make --no-print-directory -o import lint \
	GODOT="$tmp/godot" BUILD_DIR="$tmp/build" LINT_JOBS=8 2>&1 ); }

# The path under check is the argument after --script.
BANNER='echo "Godot Engine v4.7.2.stable - https://godotengine.org" >&2'
TARGET='for a in "$@"; do case "$a" in res://*) t=${a#res://};; esac; done'
# A healthy checker still produces the baselined artefacts -- they are real parse errors from real files,
# and they are what proves it is still looking.
SELFTEST='case "$t" in *type_inference_probe*) echo "SCRIPT ERROR: Parse Error: Cannot infer the type of \"my_map\" variable";; esac'
ARTEFACTS='case "$t" in
  game/tank/tank.gd) echo "ERROR: res://game/tank/tank.tscn:12 - Parse Error: [ext_resource] referenced non-existent resource at: res://game/tank/tank.gd.";;
  game/theme/visual_slot.gd) echo "ERROR: res://game/combat/shell.tscn:10 - Parse Error: [ext_resource] referenced non-existent resource at: res://game/theme/visual_slot.gd."; echo "ERROR: res://game/tank/tank.tscn:19 - Parse Error: [ext_resource] referenced non-existent resource at: res://game/theme/visual_slot.gd."; echo "ERROR: res://game/tank/tank.tscn:26 - Parse Error: [ext_resource] referenced non-existent resource at: res://game/theme/visual_slot.gd."; echo "ERROR: res://game/tank/tank.tscn:30 - Parse Error: [ext_resource] referenced non-existent resource at: res://game/theme/visual_slot.gd.";;
  game/theme/factions/faction_art.gd|tests/test_assets_factions.gd|tests/test_theme_factions.gd) echo "SCRIPT ERROR: Invalid call. Nonexistent function '"'"'roster'"'"' in base '"'"'GDScript'"'"'.";;
esac'

# ---- 1. a healthy checker: silent on real files, and it SEES the deliberately broken one ----------
stub "$TARGET
$BANNER
$ARTEFACTS
$SELFTEST
exit 0"
out=$(lint); rc=$?
[ "$rc" = 0 ] && ok "healthy checker: lint passes" || bad "healthy checker: lint passes" "exit $rc: $(tail -6 <<<"$out")"
grep -qE '8 findings seen' <<<"$out" && ok "healthy checker: counts the findings it saw" || bad "counts the findings seen" "$(tail -3 <<<"$out")"

# ---- 2. THE FAILURE THAT HAPPENED: a checker that never reports anything -------------------------
stub "$BANNER
exit 0"
out=$(lint); rc=$?
[ "$rc" != 0 ] && ok "a checker that reports nothing at all FAILS lint" || bad "a blind checker fails lint" "exit 0"
# The self-test is checked BEFORE the baselined-artefact count, so a wholly blind checker trips the
# stronger probe first. Either message is the same diagnosis; require one of them.
grep -qE 'did not report the deliberately broken file|reported NOTHING over' <<<"$out" \
	&& ok "and says the CHECKER is the problem" || bad "says the checker is the problem" "$(tail -6 <<<"$out")"
grep -qiE 'says nothing about the tree' <<<"$out" && ok "and says it is not a finding about the tree" \
	|| bad "not about the tree" "$(tail -6 <<<"$out")"
grep -q 'all .* scripts parse' <<<"$out" && bad "a blind checker never prints 'all scripts parse'" \
	|| ok "a blind checker never prints 'all scripts parse'"

# ---- 3. a Godot that produces NO OUTPUT for one file (OOM on a loaded box) ------------------------
stub "$TARGET
case \"\$t\" in *movement.gd) exit 0;; esac      # killed before it printed even its banner
$BANNER
$ARTEFACTS
$SELFTEST
exit 0"
out=$(lint); rc=$?
[ "$rc" != 0 ] && ok "a file whose checker printed nothing FAILS lint" || bad "silent file fails lint" "exit 0"
grep -q 'CHECKER PRODUCED NO OUTPUT AT ALL' <<<"$out" && ok "and names that file, not the tree" || bad "names the silent file" "$out"

# ---- 4. a Godot killed by a signal ---------------------------------------------------------------
stub "$TARGET
$BANNER
$ARTEFACTS
$SELFTEST
case \"\$t\" in *movement.gd) exit 137;; esac
exit 0"
out=$(lint); rc=$?
[ "$rc" != 0 ] && ok "a checker killed by a signal FAILS lint" || bad "signalled checker fails lint" "exit 0"
grep -q 'CHECKER KILLED BY SIGNAL 9' <<<"$out" && ok "and says which signal" || bad "says which signal" "$out"

# ---- 5. a real finding is still reported (the gate still does its day job) ------------------------
stub "$TARGET
$BANNER
$ARTEFACTS
$SELFTEST
case \"\$t\" in *movement.gd) echo 'SCRIPT ERROR: Parse Error: Cannot infer the type of \"my_map\" variable';; esac
exit 0"
out=$(lint); rc=$?
[ "$rc" != 0 ] && ok "a real parse error FAILS lint" || bad "a real parse error fails lint" "exit 0"
grep -q 'Cannot infer the type' <<<"$out" && ok "and quotes it" || bad "quotes the real error" "$out"
grep -q 'movement.gd' <<<"$out" && ok "and names the file" || bad "names the file"

# ---- 6. `Failed to compile depended scripts` stays filtered (it is the isolation artefact) --------
stub "$TARGET
$BANNER
$ARTEFACTS
$SELFTEST
echo 'SCRIPT ERROR: Compile Error: Failed to compile depended scripts'
exit 0"
out=$(lint); rc=$?
[ "$rc" = 0 ] && ok "the depended-scripts artefact is still filtered" || bad "depended-scripts stays filtered" "exit $rc: $(tail -4 <<<"$out")"

# ---- 7. the checker sees the known artefacts but NOT a fresh error -------------------------------
# The stronger probe: reproducing yesterday's eight findings does not prove the analyser still runs. This
# stub is "alive" by the baseline's measure and blind to anything new.
stub "$TARGET
$BANNER
$ARTEFACTS
exit 0"
out=$(lint); rc=$?
[ "$rc" != 0 ] && ok "artefacts seen but a FRESH error missed: lint fails" || bad "fresh error missed: lint fails" "exit 0"
grep -q 'did not report the deliberately broken file' <<<"$out" && ok "and says the checker is the problem" \
	|| bad "says the checker is the problem" "$(tail -6 <<<"$out")"
grep -q 'says NOTHING about the tree' <<<"$out" && ok "and refuses to describe the tree" || bad "refuses to describe the tree"
grep -q 'type_inference_probe' <<<"$out" && bad "the self-test never leaks into the findings" \
	|| ok "the self-test never leaks into the findings"

printf '\nlint-gate: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
