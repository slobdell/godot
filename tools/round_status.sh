#!/usr/bin/env bash
# One screen for the orchestrator: every worktree, the build box, and the baselines in force.
#
#     make round-status              # or: tools/round_status.sh
#     tools/round_status.sh --no-remote          # skip the ssh (offline, or the box is busy)
#     tools/round_status.sh --remote-from FILE   # render a captured remote block (used by the tests)
#
# Read-only throughout: no Godot, no writes, no slot taken, one ssh round trip. It answers the questions the
# orchestrator was asking one command at a time -- who is ahead of main, who has uncommitted work, what is
# actually running on builder0 and in which folder, and which baselines the checks are comparing against.
#
# Live runs come from /proc/<pid>/cwd on the box, not from the slot owner files: an owner file can be stale,
# `ps` ancestry is not ownership (nine sessions share one PPID) and `pgrep -f` matches the searching shell.
# The two are printed SIDE BY SIDE on purpose -- a folder with processes and no slot, or a slot with no
# processes, is the disagreement worth seeing.
set -uo pipefail

host=${REMOTE_HOST:-slobdell@builder0}
root=${REMOTE_ROOT:-tank_squad}
guard_dir=${TANK_SQUAD_SLOT_DIR:-/tmp/tank_squad_slots}
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)
main_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 2; }

mode=${1:-}
remote_file=""
case "$mode" in
	--no-remote) ;;
	--remote-from) remote_file=${2:?usage: --remote-from FILE} ;;
	"") ;;
	*) echo "usage: round_status.sh [--no-remote | --remote-from FILE]" >&2; exit 2 ;;
esac

# ---- worktrees ---------------------------------------------------------------------------------
main_tip=$(git -C "$main_root" rev-parse --short main 2>/dev/null || echo "?")
printf '== worktrees (main at %s) ==\n' "$main_tip"
printf '%-16s %-16s %-9s %-7s %-6s %s\n' FOLDER BRANCH TIP BEHIND/AHEAD DIRTY SUBJECT
git -C "$main_root" worktree list --porcelain 2>/dev/null \
	| awk '/^worktree /{w=$2} /^branch /{sub("refs/heads/","",$2); print w" "$2}' \
	| while read -r dir branch; do
		tip=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "?")
		subject=$(git -C "$dir" log -1 --format=%s 2>/dev/null | cut -c1-58)
		dirty=no; [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ] && dirty=YES
		if [ "$branch" = main ]; then ba="-"
		else ba=$(git -C "$main_root" rev-list --left-right --count "main...$branch" 2>/dev/null | tr '\t' '/'); fi
		printf '%-16s %-16s %-9s %-12s %-6s %s\n' "$(basename "$dir")" "$branch" "$tip" "${ba:-?}" "$dirty" "$subject"
	done

# ---- the build box -----------------------------------------------------------------------------
remote_script() {
	cat <<'REMOTE'
printf 'LOAD %s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
printf 'CORES %s\n' "$(nproc 2>/dev/null || echo ?)"
printf 'MEMAVAIL_MB %s\n' "$(awk '/^MemAvailable:/ {print int($2/1024); exit}' /proc/meminfo)"
for f in GUARD_DIR/slot*.owner; do
	[ -e "$f" ] || continue
	printf 'OWNER %s %s\n' "$(basename "$f" .owner)" "$(head -1 "$f")"
done
for t in GUARD_DIR/wait.*; do
	[ -e "$t" ] || continue
	base=${t##*/}; pid=${base##*.}
	cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
	case "$cwd" in "$HOME/ROOT/"*) ;; *) continue ;; esac
	rel=${cwd#"$HOME/ROOT/"}
	printf 'TICKET %s\n' "${rel%%/*}"
done | sort -u
for p in /proc/[0-9]*; do
	cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
	case "$cwd" in "$HOME/ROOT/"*) ;; *) continue ;; esac
	rel=${cwd#"$HOME/ROOT/"}
	printf '%s %s\n' "${rel%%/*}" "$(cut -d' ' -f22 "$p/stat" 2>/dev/null || echo 0)"
done | sort | awk '{n[$1]++; if (s[$1] == "" || $2 < s[$1]) s[$1] = $2} END {for (k in n) printf "PROCS %s %d\n", k, n[k]}'
REMOTE
}

echo ""
if [ -n "$remote_file" ]; then
	block=$(cat "$remote_file"); rc=0
elif [ "$mode" = --no-remote ]; then
	echo "== $host == (skipped: --no-remote)"
	block=""; rc=0
else
	block=$(remote_script | sed -e "s|GUARD_DIR|$guard_dir|g" -e "s|ROOT|$root|g" \
		| ssh "${ssh_opts[@]}" "$host" "bash -s" 2>/dev/null); rc=$?
fi

if [ "$mode" != --no-remote ]; then
	if [ "$rc" -ne 0 ] || [ -z "$block" ]; then
		# Never print an empty box as a quiet one.
		echo "== $host == UNREACHABLE (ssh exit $rc). Nothing below is known about the box."
	else
		load=$(awk '/^LOAD /{print $2" "$3" "$4}' <<<"$block")
		cores=$(awk '/^CORES /{print $2}' <<<"$block")
		mem=$(awk '/^MEMAVAIL_MB /{print $2}' <<<"$block")
		printf '== %s ==  load %s on %s cores, %s MB available\n' "$host" "$load" "$cores" "$mem"
		owners=$(grep '^OWNER ' <<<"$block" | sed 's/^OWNER /  slot /')
		if [ -n "$owners" ]; then echo "$owners"; else echo "  no slot is held"; fi
		procs=$(grep '^PROCS ' <<<"$block")
		if [ -n "$procs" ]; then
			echo "  live processes by folder (from /proc, the authority):"
			awk '{printf "    %-18s %s\n", $2, $3" processes"}' <<<"$procs"
			# Work in a folder that holds no slot is NOT automatically an orphan: a run that is QUEUED has
			# already cd-ed in and is waiting for a slot, which is the normal, healthy case. The first
			# version of this said "has work but holds NO SLOT" for exactly that and read as an accusation.
			# A queued run holds a slot.sh TICKET, so the three states are distinguishable -- and the one
			# with neither is the one worth a look, named as the uncertainty it is.
			while read -r _ folder _; do
				if grep -q "^OWNER .*$folder:" <<<"$block"; then continue; fi
				if grep -qx "TICKET $folder" <<<"$block"; then
					echo "    ~ $folder is QUEUED (holds a ticket, waiting for a slot)"
				else
					echo "    ? $folder has work, no slot and no ticket: an orphan, or a command run outside the slots"
				fi
			done <<<"$procs"
		else
			echo "  no processes in any $root folder"
		fi
	fi
fi

# ---- baselines in force ------------------------------------------------------------------------
echo ""
echo "== baselines in this checkout =="
b=$main_root/tests/baselines
if [ -r "$b/sim_state_hash.txt" ]; then
	grep -v '^#' "$b/sim_state_hash.txt" | grep -v '^$' | sed 's/^/  sim-baseline    /'
else echo "  sim-baseline    MISSING"; fi
if [ -r "$b/ai_scenarios_count.txt" ]; then
	counts=$(grep -v '^#' "$b/ai_scenarios_count.txt" | grep -v '^$' | head -1)
	printf '  ai-scenarios    %s  (gated: %s)  %s %s\n' "$counts" "$(cut -d, -f1,2 <<<"$counts")" \
		"$(sed -n 's/^# machine: *//p' "$b/ai_scenarios_count.txt" | head -1)" \
		"$(sed -n 's/^# commit: *//p' "$b/ai_scenarios_count.txt" | head -1)"
else echo "  ai-scenarios    MISSING"; fi
if [ -r "$b/lint_expected.txt" ]; then
	printf '  lint            %s known artefacts\n' "$(grep -cvE '^\s*(#|$)' "$b/lint_expected.txt")"
else echo "  lint            MISSING"; fi
