#!/usr/bin/env bash
# Run make targets on the remote build machine (builder0) instead of this slow laptop.
#
#     tools/remote.sh check                 # = make check, on builder0, logs and screenshots copied back
#     tools/remote.sh test FILTER=combat
#     tools/remote.sh bootstrap             # first time only (also runs automatically when needed)
#
# What it does (one builder over ssh; deliberately much simpler than plane_maker's distributed system):
#   1. rsync this checkout to builder0:~/tank_squad/<folder name> (each worktree gets its own folder, so
#      parallel agents never share files; local.mk ports and override.cfg travel with it)
#   2. on first use, install the pinned Godot + templates and a Node runtime into builder0:~/tank_squad/.tools,
#      shared by every folder there (no sudo, nothing system-wide)
#   3. run `make <args>` there, through builder0's own heavy-run slots (tools/slot.sh, REMOTE_SLOTS at once)
#   4. copy build/ back (logs, screenshots, reports; not the big exports) and exit with make's status
#
# Knobs (environment or local.mk): REMOTE_HOST (default slobdell@builder0), REMOTE_ROOT (default tank_squad),
# REMOTE_SLOTS (default 3). Rendering targets use builder0's logged-in desktop session (DISPLAY :0).
set -uo pipefail

host=${REMOTE_HOST:-slobdell@builder0}
root=${REMOTE_ROOT:-tank_squad}
slots=${REMOTE_SLOTS:-3}
node_version=v22.14.0
repo_root="$(git rev-parse --show-toplevel)"
name="$(basename "$repo_root")"
remote_dir="$root/$name"
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=30)

[ $# -gt 0 ] || { echo "usage: tools/remote.sh <make target> [VAR=value ...]" >&2; exit 2; }

echo ">> remote: syncing $name to $host:~/$remote_dir" >&2
ssh "${ssh_opts[@]}" "$host" "mkdir -p ~/$remote_dir ~/$root/.tools" || { echo ">> remote: cannot reach $host" >&2; exit 3; }
# Protect (P) what builder0 generates for itself from --delete; skip what it doesn't need.
rsync -az --delete -e "ssh ${ssh_opts[*]}" \
	--filter='P .tools' --filter='P .godot/' --filter='P build/' --filter='P node_modules/' \
	--exclude='.git/' --exclude='.tools' --exclude='.godot/' --exclude='build/' --exclude='node_modules/' \
	--exclude='assets/incoming/' --exclude='__pycache__/' \
	"$repo_root/" "$host:~/$remote_dir/" || { echo ">> remote: rsync failed" >&2; exit 3; }

# The remote script: shared toolchain, Node on PATH, the desktop display for rendering targets, then make.
read -r -d '' script <<EOF
set -uo pipefail
cd ~/$remote_dir
ln -sfn ~/$root/.tools .tools
if [ ! -x ~/$root/.tools/node/bin/node ]; then
	echo ">> remote: installing Node $node_version into ~/$root/.tools/node" >&2
	mkdir -p ~/$root/.tools/node
	curl -fsSL https://nodejs.org/dist/$node_version/node-$node_version-linux-x64.tar.xz | tar -xJ --strip-components=1 -C ~/$root/.tools/node
fi
export PATH=~/$root/.tools/node/bin:\$PATH
export TANK_SQUAD_SLOTS=$slots
# The auth file the running Xwayland uses (older sessions leave stale ones: with a stale cookie Godot falls back to Wayland,
# which stops redrawing a hidden window, so screenshots after the first silently repeat old frames).
auth=\$(ps -C Xwayland -o args= 2>/dev/null | sed -n 's/.* -auth \\([^ ]*\\).*/\\1/p' | head -1)
[ -n "\$auth" ] || auth=\$(ls -t /run/user/\$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
if [ -n "\$auth" ]; then export DISPLAY=:0 XAUTHORITY="\$auth"; fi
if ! compgen -G ".tools/godot-*/editor_data/export_templates/*/.installed" >/dev/null && [ "\$1" != bootstrap ]; then
	echo ">> remote: first run here, bootstrapping the toolchain" >&2
	make bootstrap >&2 || exit \$?
fi
make "\$@"
EOF

echo ">> remote: make $* on $host" >&2
ssh "${ssh_opts[@]}" "$host" "bash -s -- $(printf '%q ' "$@")" <<<"$script"
status=$?

mkdir -p "$repo_root/build"
copy_log=$(rsync -az -e "ssh ${ssh_opts[*]}" --exclude='web/' --exclude='server/' --exclude='*.pck' --exclude='*.wasm' \
	"$host:~/$remote_dir/build/" "$repo_root/build/" 2>&1)
copy_status=$?
if [ $copy_status -ne 0 ]; then
	# Silently swallowed, this leaves stale local results wearing a fresh timestamp's name: a full local disk once
	# left build/audio/pass.* three hours old while the run that wrote them had just passed (audio, 2026-09-17).
	echo ">> remote: WARNING build/ did NOT come back (rsync exit $copy_status); local build/ is stale" >&2
	echo "$copy_log" | tail -3 >&2
	df -h "$repo_root" | tail -1 >&2
fi
echo ">> remote: make $* exited $status (build/ copied back$([ $copy_status -ne 0 ] && echo ": FAILED"))" >&2
exit "$status"
