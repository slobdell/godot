#!/usr/bin/env bash
# Back up the generated assets that are NOT in git to builder0.
#
#     tools/backup_assets.sh            # back up now (what the timer runs)
#     tools/backup_assets.sh --status   # what's on builder0, and when it last ran
#
# What it copies, and why these and nothing else:
#   assets/incoming/          raw Meshy downloads + CC0 texture sets: the inputs the asset pipeline turns into models.
#                             ~600 Meshy credits. Git-ignored on purpose (a GB of binaries).
#   assets/announcer/masters/ ElevenLabs MP3 masters every shipped clip is cut from. 171k credits. Git-ignored.
#   assets/music/             the lead's Suno tracks, when they arrive.
# Everything else that matters is committed and pushed to GitHub, which is its own backup.
#
# Safety: never deletes on the far side. A file that changed or disappeared here is moved into
# `_replaced/<date>/` there instead of being overwritten away, so a bad local edit can't erase the only other copy.
#
# Knobs: BACKUP_HOST (default slobdell@builder0), BACKUP_ROOT (default tank_squad_backup).
set -uo pipefail

host=${BACKUP_HOST:-slobdell@builder0}
root=${BACKUP_ROOT:-tank_squad_backup}
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
paths=(assets/incoming assets/announcer/masters assets/music)
log="$repo/build/backup.log"
lock=/tmp/tank_squad_backup.lock
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)

mkdir -p "$(dirname "$log")"
say() { printf '%s %s\n' "$(date +'%F %T')" "$*" | tee -a "$log" >&2; }

if [ "${1:-}" = "--status" ]; then
	echo "last runs:"; tail -5 "$log" 2>/dev/null || echo "  (never run)"
	echo "on $host:"
	ssh "${ssh_opts[@]}" "$host" "du -sh ~/$root/* 2>/dev/null; echo; df -h ~ | tail -1" || echo "  unreachable"
	exit 0
fi

# One at a time: a slow first copy must not overlap the next tick.
exec {fd}>"$lock"
if ! flock -n $fd; then
	say "skipped: another backup is running"
	exit 0
fi

if ! ssh "${ssh_opts[@]}" "$host" true 2>/dev/null; then
	say "skipped: $host unreachable"
	exit 0   # a laptop away from the network is not a failure
fi

stamp="$(date +%F_%H%M)"
total=0
for path in "${paths[@]}"; do
	[ -d "$repo/$path" ] || continue
	dest="$root/$path"
	ssh "${ssh_opts[@]}" "$host" "mkdir -p ~/$dest" || { say "FAILED to create ~/$dest"; exit 1; }
	bytes=$(rsync -a --partial --stats -e "ssh ${ssh_opts[*]}" \
		--backup --backup-dir="$HOME/$root/_replaced/$stamp/$path" \
		"$repo/$path/" "$host:~/$dest/" 2>>"$log" \
		| awk '/Total transferred file size/ {gsub(/[^0-9]/, "", $5); print $5}')
	total=$(( total + ${bytes:-0} ))
done
say "backed up $(numfmt --to=iec ${total:-0} 2>/dev/null || echo ${total}B) to $host:~/$root"
