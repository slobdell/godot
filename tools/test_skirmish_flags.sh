#!/usr/bin/env bash
# Known answers for `make skirmish SKIRMISH_FLAGS="..."` (round 39, C39.6): the flags reach the game's own argv, after the
# `--` that separates the engine's flags from the game's, word for word; with no SKIRMISH_FLAGS the command is unchanged.
# A fake Godot records its argv (one word a line); the recipe's prerequisites (native-fresh, import) are held old with -o.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; root="$(dirname "$here")"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -12; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fake="$tmp/godot"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s"\n' "$tmp/argv" > "$fake"; chmod +x "$fake"

run() {  # run [make args...]: the fake's argv, the words after the game's `--` only
	rm -f "$tmp/argv"
	make -C "$root" --no-print-directory -o native-fresh -o import skirmish GODOT="$fake" SEED=7 "$@" > "$tmp/make.out" 2>&1 || return 1
	sed -n '/^--$/,$p' "$tmp/argv" | tail -n +2
}

base=$(run) || bad "plain make skirmish ran" "$(cat "$tmp/make.out")"
want=$'--skirmish\n--enemy=cpu\n--seed=7\n--arena=random\n--announcer=voice\n--music=on\n--camera-readout=on'
[ "$base" = "$want" ] && ok "no SKIRMISH_FLAGS: the default command, unchanged" || bad "default" "$base"

got=$(run SKIRMISH_FLAGS="--rules-off=sight,spread --parked-hold=on") || bad "flags ran" "$(cat "$tmp/make.out")"
[ "$(head -7 <<<"$got")" = "$want" ] && [ "$(tail -n +8 <<<"$got")" = $'--rules-off=sight,spread\n--parked-hold=on' ] \
	&& ok "two flags reach the game's argv, last and word for word" || bad "two flags" "$got"

got=$(run SKIRMISH_FLAGS="--rules-off=pin_slow" ARENA=locks CONTROL=1) || bad "flags + vars ran" "$(cat "$tmp/make.out")"
grep -qx -- '--arena=locks' <<<"$got" && grep -qx -- '--control' <<<"$got" && [ "$(tail -1 <<<"$got")" = "--rules-off=pin_slow" ] \
	&& ok "SKIRMISH_FLAGS beside ARENA= and CONTROL=: both kept" || bad "with vars" "$got"

# LaunchFlags.parse keeps the LAST value of a repeated flag, so an appended flag overrides the recipe's own.
got=$(run SKIRMISH_FLAGS="--arena=pit") || bad "repeat ran" "$(cat "$tmp/make.out")"
[ "$(grep -c -- '^--arena=' <<<"$got")" = 2 ] && [ "$(tail -1 <<<"$got")" = "--arena=pit" ] \
	&& ok "a repeated flag is appended last (so it wins in LaunchFlags)" || bad "repeat" "$got"

printf '\nskirmish-flags: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
