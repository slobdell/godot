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
# DEGRADE, do not die. builder0's copy of a worktree has no `.git` at all (the launch rsync excludes it),
# and `check` runs this suite there -- so exiting 2 made fifteen assertions fail for a reason that has
# nothing to do with the tool. The box and the baselines are still readable without git, and a tool that
# refuses to say the things it CAN say is less useful than one that says them and names what is missing.
main_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
have_git=1; [ -n "$main_root" ] || { have_git=""; main_root=$(pwd); }

mode=${1:-}
remote_file=""
case "$mode" in
	--no-remote) ;;
	--remote-from) remote_file=${2:?usage: --remote-from FILE} ;;
	"") ;;
	*) echo "usage: round_status.sh [--no-remote | --remote-from FILE]" >&2; exit 2 ;;
esac

# ---- worktrees ---------------------------------------------------------------------------------
if [ -z "$have_git" ]; then
	printf '== worktrees == NOT AVAILABLE: %s is not a git repository\n' "$main_root"
	printf '   (a worktree copied to the build box has no .git -- the launch rsync excludes it)\n'
else
main_tip=$(git -C "$main_root" rev-parse --short main 2>/dev/null || echo "?")
# `main-checked` (lesson 190) marks the last commit on main that a full check actually passed. Knowing how
# far main has moved PAST it is the difference between "main is green" and "main was green 49 commits ago",
# and the two get said the same way in conversation.
# `^{commit}`, and it is not decoration: on an ANNOTATED tag `rev-parse main-checked` returns the TAG
# OBJECT's id, not the commit's. This printed `f4d327b8` where the orchestrator had just said `0ad28f49`
# -- two ids for one thing, in the line a reader uses to look it up. Annotating the tag was the fix I asked
# for, and it silently changed what this expression means: the same shape as make expanding `$` before my
# shell quoting, one layer up from where I was looking.
checked=$(git -C "$main_root" rev-parse --short main-checked^{commit} 2>/dev/null || true)
# THE TAG SAYS A CHECK RAN. It does not say the check PASSED -- the one on `0ad28f49` read 1516 passed,
# 2 failed. So the verdict is printed beside it, or its absence is, and the word "green" appears nowhere.
#
# The verdict can only come from an ANNOTATED tag. On a lightweight tag `%(contents:subject)` silently
# returns the COMMIT's subject, which reads exactly like a recorded verdict and is not one -- so the object
# type decides, not the presence of text.
checked_verdict=""
if [ -n "$checked" ] && [ "$(git -C "$main_root" cat-file -t main-checked 2>/dev/null)" = tag ]; then
	checked_verdict=$(git -C "$main_root" for-each-ref refs/tags/main-checked --format='%(contents:subject)' 2>/dev/null)
fi
if [ -z "$checked" ]; then
	printf '== worktrees (main at %s; NO main-checked tag -- nothing says main was ever checked) ==\n' "$main_tip"
elif ! git -C "$main_root" merge-base --is-ancestor main-checked main 2>/dev/null; then
	printf '== worktrees (main at %s; main-checked %s is NOT an ancestor of main -- it was rewound or rewritten) ==\n' \
		"$main_tip" "$checked"
	checked=""
else
	behind=$(git -C "$main_root" rev-list --count main-checked..main 2>/dev/null || echo "?")
	if [ "$behind" = 0 ]; then
		printf '== worktrees (main at %s, CHECKED) ==\n' "$main_tip"
	else
		printf '== worktrees (main at %s; last CHECKED at %s, %s commits back) ==\n' "$main_tip" "$checked" "$behind"
	fi
fi
if [ -n "$checked" ]; then
	if [ -n "$checked_verdict" ]; then
		printf '   main-checked %s: %s\n' "$checked" "$checked_verdict"
	else
		printf '   main-checked %s: VERDICT NOT RECORDED -- a lightweight tag says a check RAN, not that it passed.\n' "$checked"
		printf '                 Annotate it so the tool cannot be read as saying green:\n'
		printf '                 git tag -af main-checked %s -m "<the runner'"'"'s line and the reds>"\n' "$checked"
	fi
fi
printf '%-16s %-16s %-9s %-12s %-6s %-7s %s\n' FOLDER BRANCH TIP BEHIND/AHEAD DIRTY BASE SUBJECT
git -C "$main_root" worktree list --porcelain 2>/dev/null \
	| awk '/^worktree /{w=$2} /^branch /{sub("refs/heads/","",$2); print w" "$2}' \
	| while read -r dir branch; do
		tip=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "?")
		subject=$(git -C "$dir" log -1 --format=%s 2>/dev/null | cut -c1-58)
		dirty=no; [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ] && dirty=YES
		if [ "$branch" = main ]; then ba="-"
		else ba=$(git -C "$main_root" rev-list --left-right --count "main...$branch" 2>/dev/null | tr '\t' '/'); fi
		# Is what this branch has taken FROM main covered by a check? Its merge-base being an ancestor of
		# main-checked is the precise question, and it is the one that decides whether a red test here can
		# be blamed on main or has to be explained.
		base="-"
		if [ -n "$checked" ] && [ "$branch" != main ]; then
			mb=$(git -C "$main_root" merge-base main "$branch" 2>/dev/null || true)
			if [ -z "$mb" ]; then base="?"
			elif git -C "$main_root" merge-base --is-ancestor "$mb" main-checked^{commit} 2>/dev/null; then base="yes"
			else base="NO"; fi
		fi
		printf '%-16s %-16s %-9s %-12s %-6s %-7s %s\n' "$(basename "$dir")" "$branch" "$tip" "${ba:-?}" "$dirty" "$base" "$subject"
	done
fi

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
