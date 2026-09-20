#!/usr/bin/env bash
# Run make targets on the remote build machine (builder0) instead of this slow laptop.
#
#     tools/remote.sh check                 # = make check, on builder0, logs and screenshots copied back
#     tools/remote.sh test FILTER=combat
#     tools/remote.sh bootstrap             # first time only (also runs automatically when needed)
#     tools/remote.sh --status              # what is running in YOUR folder on builder0, and is its marker stale
#     tools/remote.sh --quiet perf-trailer-ab  # a TIMING run: hold the whole box, and say whether the window held
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
# REMOTE_SLOTS, REMOTE_FORCE (launch on top of a live run of your own), REMOTE_CLAIM_TTL, QUIET_MAX_LOAD,
# REMOTE_VERIFY=0 (skip the sha256 check on the files copied back).
# Rendering targets use builder0's logged-in desktop session (DISPLAY :0).
#
# ---- REMOTE_SLOTS is 3, and that is DELIBERATELY FEWER than the 6 it was raised to (T1, 2026-09-20) ----
#
# **A slot now holds six to eight processes, not one.** That one sentence is the whole reason, and without it this
# reads as a step backwards. Before T1 a `check` was a single Godot process grinding ticks, which is why builder0
# sat at load 0.4 on 12 threads with three whole checks running and why raising 3 -> 6 was right at the time. After
# T1 a `check` is a sharded test suite plus a fanned-out lint plus concurrent targets.
#
# Measured on builder0 (12 threads, ~11.6 GB available, metrics, 2026-09-20). Peak RSS per target: audio-check
# 919 MB, test 427, the smokes 250-273, broker-test 84. `test` alone was 2388 s of a 2584 s serial check -- 92% --
# so the only thing that shortens a check is splitting the suite, and how far it can split is set by the memory a
# single check is entitled to:
#
#   slots  memory per check   shards it affords   `test`      whole check
#       2         ~5.8 GB              6           ~400 s        ~9 min
#       3         ~3.9 GB              5           ~480 s       ~10 min
#       6         ~1.9 GB              2          ~1200 s       ~22 min
#
# Throughput is the same at any slot count -- the box is the box -- but **latency per check scales with the slot
# count**, and latency is what eight streams sit waiting on. Six slots would also land the check right on T1's
# >= 50% bar instead of clearing it.
#
# This cannot OOM the box at any setting: `tools/slot.sh --jobs` divides the MEMORY budget by the live slot count,
# so the inner fan-out shrinks automatically as slots rise. Cores are deliberately not divided -- this work is
# latency-bound, not compute-bound, which is the finding T1 rests on
# (`_agents/streams/references/round9/metrics/t1-builder0-idle.txt`).
set -uo pipefail

# ---- Pin this script against a mid-run rewrite -------------------------------------------------
# `git merge` / `git checkout` rewrite a working-tree file IN PLACE -- same inode, verified -- and bash reads a
# script LAZILY, from a file offset. So a merge landing while this is running makes it jump into the middle of
# the NEW text. Demonstrated rather than assumed: a running script printed its line 1, then "command not found"
# from the replacement's line 2, then executed the replacement's lines 3-5; its own lines 3 and 4 never ran.
#
# That is not hypothetical here. Every stream is being told to merge `main` between runs, and `main` carries this
# file -- so a merge lands on a wrapper that may be holding a slot for forty minutes. Re-exec from a private copy
# and unlink it immediately: the kernel keeps the text alive for this process through its open fd, and nobody --
# not even git -- can reach it by name to change it.
if [ -z "${TANK_SQUAD_PINNED_SELF:-}" ]; then
	pinned=$(mktemp -t "$(basename "$0").XXXXXX") || exit 1
	cat "$0" > "$pinned" && chmod +x "$pinned" || { rm -f "$pinned"; exit 1; }
	TANK_SQUAD_PINNED_SELF="$pinned" exec bash "$pinned" "$@"
fi
rm -f "$TANK_SQUAD_PINNED_SELF"

host=${REMOTE_HOST:-slobdell@builder0}
root=${REMOTE_ROOT:-tank_squad}
slots=${REMOTE_SLOTS:-3}
node_version=v22.14.0
repo_root="$(git rev-parse --show-toplevel)"
name="$(basename "$repo_root")"
remote_dir="$root/$name"
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=30)

[ $# -gt 0 ] || { echo "usage: tools/remote.sh <make target> [VAR=value ...] | --status" >&2; exit 2; }

# ---- Do not rsync --delete over a run of our own that is still going (trip-up 66) --------------
# The sync below replaces this worktree's files ON BUILDER0. Doing that under a running check swaps the tree
# the suite is reading, mid-suite: nav's check on 96bbf38e was voided that way and scale lost a 62-minute
# fairness run overnight, both on 2026-09-20. The guard runs BEFORE the sync -- which is the only place it can
# run, because by the time the remote script starts, the damage is already on disk.
#
# It asks /proc on builder0, not a lock file: see the header of tools/remote_guard.sh for why a second .owner
# file would have been the stale-.owner bug again. The script is piped over stdin rather than run from the
# remote checkout, because the remote checkout is exactly what has not been synced yet (and on a first run
# does not exist).
guard_dir=${TANK_SQUAD_SLOT_DIR:-/tmp/tank_squad_slots}
guard_script="$repo_root/tools/remote_guard.sh"

run_guard() {   # $1 = mode, $2 = label/pid
	[ -r "$guard_script" ] || return 0
	ssh "${ssh_opts[@]}" "$host" \
		"REMOTE_FORCE=$(printf '%q' "${REMOTE_FORCE:-}") REMOTE_CLAIM_TTL=$(printf '%q' "${REMOTE_CLAIM_TTL:-300}") \
		 bash -s -- $(printf '%q ' "$1" "$guard_dir" "$remote_dir" "${2:-}")" < "$guard_script"
}

if [ "$1" = "--status" ]; then
	run_guard report; exit $?
fi

# ---- --quiet: a timing run owns the box, and says afterwards whether it did ---------------------
# A frame-time measurement needs a quiet machine (lesson 179). Waiting for the box to look idle and then
# launching does not give one -- another stream can start two seconds later, inside the run. So the run
# HOLDS the window by taking every slot (`slot.sh`'s TANK_SQUAD_EXCLUSIVE), and a sampler watches it while
# it is open, because holding a window and having held one are different claims and only the second is
# evidence. The run's own output ends in QUIET WINDOW: HELD or NOT USABLE, and the samples come home in
# build/quiet-window.tsv.
quiet=""
if [ "$1" = "--quiet" ]; then
	quiet=1; shift
	[ $# -gt 0 ] || { echo "usage: tools/remote.sh --quiet <make target> [VAR=value ...]" >&2; exit 2; }
fi

if [ -r "$guard_script" ]; then
	run_guard check "make $*${quiet:+ (quiet window)}"
	guard_status=$?
	if [ "$guard_status" -eq 9 ]; then
		echo ">> remote: nothing was synced and nothing was run." >&2
		exit 9
	elif [ "$guard_status" -ne 0 ]; then
		# Fail OPEN, loudly. A guard that cannot run must not lock a stream out of the build box -- but
		# silence here would put us back to the behaviour that voided two runs while looking fine, so it
		# says so in the same words a reader would use to report it.
		echo ">> remote: WARNING: the live-run guard did not run (exit $guard_status); launching UNGUARDED." >&2
		echo ">>   check by hand first: tools/remote.sh --status" >&2
	fi
else
	echo ">> remote: WARNING: tools/remote_guard.sh is missing; launching UNGUARDED (trip-up 66)." >&2
fi

echo ">> remote: syncing $name to $host:~/$remote_dir" >&2
# Identify the code before it leaves this machine (see the exports in the remote script below).
commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo unknown)
dirty=$([ -n "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ] && echo 1 || echo 0)

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
export TANK_SQUAD_QUIET=$quiet
export QUIET_MAX_LOAD=${QUIET_MAX_LOAD:-4.0}
# Hand the marker from "a launch claimed this directory" to "this pid is the run". From here the claim's TTL
# stops mattering, because /proc can speak for the run itself -- including the forty minutes it may spend
# QUEUED inside slot.sh, which has already cd-ed in. A signalled run releases it at once; a normal exit leaves
# it for the local wrapper to clear AFTER the copy-back, so a second launch cannot rsync over the files being
# copied. The handlers exit, because a handler that falls through does not stop the script (slot.sh's lesson).
_guard() { [ -f tools/remote_guard.sh ] || return 0; bash tools/remote_guard.sh "\$1" '$guard_dir' '$remote_dir' "\${2:-}" >/dev/null 2>&1 || true; }
_guard adopt \$\$
trap '_guard release; exit 130' INT
trap '_guard release; exit 143' TERM
# What ran, carried over by hand, because the rsync above excludes .git/ — so builder0 has no repository to ask, and
# builder0 is where nearly every measurement this project quotes is taken. Without this a measurement's own header
# would say "commit: unknown" on exactly the machine whose numbers we cite. tools/run_conditions.py prefers these and
# falls back to git locally. DIRTY=1 means the commit does NOT identify what ran: uncommitted changes were rsynced.
export TANK_SQUAD_COMMIT=$commit
export TANK_SQUAD_DIRTY=$dirty
# The auth file the running Xwayland uses (older sessions leave stale ones: with a stale cookie Godot falls back to Wayland,
# which stops redrawing a hidden window, so screenshots after the first silently repeat old frames).
auth=\$(ps -C Xwayland -o args= 2>/dev/null | sed -n 's/.* -auth \\([^ ]*\\).*/\\1/p' | head -1)
[ -n "\$auth" ] || auth=\$(ls -t /run/user/\$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
if [ -n "\$auth" ]; then export DISPLAY=:0 XAUTHORITY="\$auth"; fi
if ! compgen -G ".tools/godot-*/editor_data/export_templates/*/.installed" >/dev/null && [ "\$1" != bootstrap ]; then
	echo ">> remote: first run here, bootstrapping the toolchain" >&2
	make bootstrap >&2 || exit \$?
fi
# A manifest of what the copy-back is about to take, written by the machine that WROTE the files. The
# exclusions match the copy-back rsync's exactly, or the check would report files that were never sent.
write_manifest() {
	[ -d build ] || return 0
	find build -type f ! -path 'build/web/*' ! -path 'build/server/*' \
		! -name '*.pck' ! -name '*.wasm' ! -name '.copyback.sha256' -print0 2>/dev/null \
		| xargs -0 -r sha256sum > build/.copyback.sha256 2>/dev/null || true
}
if [ -n "\$TANK_SQUAD_QUIET" ] && [ -f tools/quiet_window.sh ]; then
	export TANK_SQUAD_EXCLUSIVE=1
	mkdir -p build
	bash tools/quiet_window.sh watch $guard_dir ~/$root "\$PWD" build/quiet-window.tsv 15 >/dev/null 2>&1 &
	watcher=\$!
fi
make "\$@"
make_status=\$?
if [ -n "\${watcher:-}" ]; then
	kill "\$watcher" 2>/dev/null
	# The verdict prints whatever the run's own status was: a green run in a window that did not hold is
	# exactly the case worth shouting about, because nothing else in the output would say so.
	bash tools/quiet_window.sh verdict build/quiet-window.tsv || true
fi
write_manifest
exit \$make_status
EOF

echo ">> remote: make $* on $host" >&2
ssh "${ssh_opts[@]}" "$host" "bash -s -- $(printf '%q ' "$@")" <<<"$script"
status=$?

mkdir -p "$repo_root/build"
# --delete, so the local build/ MIRRORS the run that just finished. Without it build/ accumulated artefacts
# across runs and a stale file announced nothing: plausible name, plausible size, nothing saying which run
# wrote it (nav, 2026-09-20 -- a 101 MB log from an earlier run sat there being read as this one's).
#
# `P *.log` PROTECTS the wrapper logs, and that is not a nicety. Every stream launches with
# `make remote T=check > build/metrics/x.log` (the pattern in remote_builds.md), so those files exist only
# here -- and --delete would unlink one while the redirect is still open, leaving the shell writing to an
# unlinked inode and the log vanishing silently, mid-run. Excluded paths (web/, server/, the big exports)
# are not deleted either: rsync protects what it was told to skip unless --delete-excluded says otherwise.
#
# The end state is wrapper logs in the session scratchpad (`> $SCRATCH/x.log`) and this protection dropped;
# it is a belt until that habit is everywhere.
copy_log=$(rsync -az --delete --filter='P *.log' -e "ssh ${ssh_opts[*]}" \
	--exclude='web/' --exclude='server/' --exclude='*.pck' --exclude='*.wasm' \
	"$host:~/$remote_dir/build/" "$repo_root/build/" 2>&1)
copy_status=$?
if [ $copy_status -ne 0 ]; then
	# Silently swallowed, this leaves stale local results wearing a fresh timestamp's name: a full local disk once
	# left build/audio/pass.* three hours old while the run that wrote them had just passed (audio, 2026-09-17).
	echo ">> remote: FAILED to copy build/ back (rsync exit $copy_status); local build/ is STALE, not this run's" >&2
	echo "$copy_log" | tail -3 >&2
	df -h "$repo_root" | tail -1 >&2
fi
# ---- Did the bytes survive the trip? -----------------------------------------------------------
# nav's p7-pit.jsonl came back from builder0 with ONE byte changed in 273,578 lines, and the file alone
# cannot say whether that happened in the box's memory, on its disk, in the transfer, or here. This narrows
# it to "the transfer, or not", which is the only part we can cheaply learn -- and the next flip gets
# located instead of argued about. The check is on the files, not on the format: a flip in a digit reads as
# a perfectly good number, so the reader can never be the place this is caught.
verify_status=0
if [ "${REMOTE_VERIFY:-1}" != 0 ] && [ "$copy_status" -eq 0 ] && [ -x "$repo_root/tools/copyback_verify.sh" ]; then
	"$repo_root/tools/copyback_verify.sh" "$repo_root" "$repo_root/build/.copyback.sha256" || verify_status=$?
	# A missing manifest (exit 3) is reported and does not fail the command: an older checkout on the box
	# writes none, and refusing every run over that would be worse than the problem. A MISMATCH (5) does.
	[ "$verify_status" -eq 3 ] && verify_status=0
fi

# The copy-back is done, so the directory is genuinely free now.
run_guard release >/dev/null 2>&1 || true
echo ">> remote: make $* exited $status (build/ copied back$([ "$copy_status" -ne 0 ] && echo ": FAILED"))" >&2
# A failed copy-back fails the command. The run may well have passed on builder0, but everything local that would
# prove it is from an earlier run, and a warning in a long log is exactly what nobody reads (the orchestrator called
# main green off the wrong line of a log the same afternoon). A real make failure still wins: it is the bigger news.
if [ "$status" -eq 0 ] && [ "$copy_status" -ne 0 ]; then
	echo ">> remote: treating that as a failure: nothing local proves what the run did" >&2
	exit 4
fi
# Corruption outranks a green run for the same reason: what is local is not what the run produced, and a
# green exit beside silently altered bytes is the worst shape this can take.
if [ "$verify_status" -ne 0 ]; then
	echo ">> remote: treating that as a failure: build/ here is not what the box wrote" >&2
	exit 5
fi
exit "$status"
