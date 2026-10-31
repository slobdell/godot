#!/usr/bin/env bash
# Known-answer tests for tools/remote.sh's first-sync SEED (round 47, native N6): a builder folder that never finished a sync
# is seeded from the box's own main checkout (~/<root>/godot) before the laptop's rsync, so only the delta crosses the uplink.
# The property: the seed fills missing files only (--ignore-existing), skips build/ .git/ .godot/ native/bin/, runs once
# (`.remote-synced` after the first complete sync), never seeds main's own folder, and REMOTE_SEED=0 turns it off.
# Fake ssh runs the box's commands locally under a scratch HOME; the laptop->box rsync is a no-op. No network, a second.
set -uo pipefail
tools="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

repo="$tmp/godot-seedme"; mkdir -p "$repo/tools" "$tmp/bin" "$tmp/home/tank_squad"
cp "$tools/remote.sh" "$repo/tools/"; echo 'all:' > "$repo/Makefile"
git -C "$repo" init -q && git -C "$repo" add -A && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm t
real_rsync=$(command -v rsync)
cat > "$tmp/bin/ssh" <<EOF
#!/usr/bin/env bash
# the last argument is the box's command (remote.sh passes ssh options and the host first)
for a in "\$@"; do cmd=\$a; done
case "\$cmd" in *"bash -s -- "*) cat >/dev/null; echo ">> builder: make fake exited 0" >&2; exit 0 ;; esac
HOME="$tmp/home" PATH="$tmp/realbin:\$PATH" bash -c "\$cmd"
EOF
mkdir -p "$tmp/realbin"; ln -s "$real_rsync" "$tmp/realbin/rsync"
cat > "$tmp/bin/rsync" <<'EOF'
#!/usr/bin/env bash
exit 0   # the laptop<->box syncs: nothing crosses in this test
EOF
chmod +x "$tmp/bin/"*

main="$tmp/home/tank_squad/godot"
mkdir -p "$main/game" "$main/build" "$main/.git" "$main/.godot" "$main/native/bin"
echo p > "$main/project.godot"; echo main > "$main/game/a.gd"; echo x > "$main/build/big"; echo x > "$main/.git/x"
echo x > "$main/.godot/x"; echo x > "$main/native/bin/lib.so"
box="$tmp/home/tank_squad/godot-seedme"

run() { out=$(cd "$repo" && env PATH="$tmp/bin:$PATH" REMOTE_HOST=fake@box REMOTE_VERIFY=0 "$@" timeout 60 bash tools/remote.sh fake 2>&1); st=$?; }

mkdir -p "$box/game"; echo mine > "$box/game/a.gd"
run
grep -q "seeding tank_squad/godot-seedme" <<<"$out" && ok "a folder that never synced is seeded" || bad "no seed line" "$out"
[ -e "$box/project.godot" ] && ok "missing files come from main's checkout" || bad "project.godot not seeded"
[ "$(cat "$box/game/a.gd")" = mine ] && ok "a file already there is never overwritten" || bad "a.gd overwritten"
for d in build/big .git/x .godot/x native/bin/lib.so; do
	[ ! -e "$box/$d" ] && ok "$d is not seeded" || bad "$d was seeded"
done
[ -e "$box/.remote-synced" ] && ok "a complete sync writes .remote-synced" || bad "no .remote-synced" "$out"
rm "$box/project.godot"
run
! grep -q "seeding" <<<"$out" && [ ! -e "$box/project.godot" ] && ok "a synced folder is not seeded again" || bad "re-seeded" "$out"
rm -rf "$box"; mkdir -p "$box"
run REMOTE_SEED=0
! grep -q "seeding" <<<"$out" && [ ! -e "$box/project.godot" ] && ok "REMOTE_SEED=0 skips it" || bad "seeded with REMOTE_SEED=0" "$out"
grep -q "'P /.remote-synced'" "$tools/remote.sh" && ok "the --delete sync protects .remote-synced (else every sync re-seeds)" || bad "the main rsync does not protect .remote-synced"
printf '\nremote-seed: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
