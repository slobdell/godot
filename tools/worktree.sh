#!/usr/bin/env bash
# Parallel workstreams as git worktrees: one folder + one branch per agent, isolated so they
# don't interfere. See _agents/workstreams.md.
#
#   tools/worktree.sh add <stream> <offset>   create ../godot-<stream> on branch stream/<stream>
#   tools/worktree.sh list                    every worktree: branch, ports, dirty?, ahead/behind main
#   tools/worktree.sh remove <stream>         remove the folder (refuses if there are uncommitted changes)
#
# Isolation per worktree:
#   - its own branch and working files (git worktree)
#   - its own ports: local.mk sets WEB/NET/SMOKE/AGENT ports to base + 10*offset, so two agents
#     running `make check` at the same time don't fight over sockets
#   - its own Godot user data dir (override.cfg): saves and logs don't collide
#   - its own .godot import cache; the 300 MB Godot toolchain (.tools) is shared by symlink
set -euo pipefail

main_root="$(git rev-parse --show-toplevel)"
parent="$(dirname "$main_root")"
repo="$(basename "$main_root")"

cmd="${1:-list}"
case "$cmd" in
  add)
    stream="${2:?usage: worktree.sh add <stream> <offset 1-9>}"
    offset="${3:?usage: worktree.sh add <stream> <offset 1-9>}"
    [[ "$stream" =~ ^[a-z][a-z0-9_-]*$ ]] || { echo "stream must be lowercase letters/digits/-/_" >&2; exit 2; }
    [[ "$offset" =~ ^[1-9]$ ]] || { echo "offset must be 1-9 (0 is the main checkout)" >&2; exit 2; }
    dir="$parent/$repo-$stream"
    branch="stream/$stream"
    if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$main_root" worktree add "$dir" "$branch"
    else
      git -C "$main_root" worktree add "$dir" -b "$branch"
    fi
    ln -sfn "$main_root/.tools" "$dir/.tools"
    cat > "$dir/local.mk" <<MK
# Per-worktree settings (gitignored), written by tools/worktree.sh. Stream: $stream, offset $offset.
WEB_PORT       := $((8060 + 10 * offset))
NET_PORT       := $((9080 + 10 * offset))
SMOKE_PORT     := $((8061 + 10 * offset))
SMOKE_NET_PORT := $((9181 + 10 * offset))
AGENT_PORT     := $((8765 + 10 * offset))
export AGENT_PORT
# Leave CPU for the other agents' match series.
JOBS           := 2
MK
    cat > "$dir/override.cfg" <<CFG
; Per-worktree Godot overrides (gitignored), written by tools/worktree.sh.
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="tank_squad_$stream"
CFG
    echo ">> importing (first run builds $dir/.godot)"
    make -C "$dir" import >/dev/null 2>&1 || make -C "$dir" import
    echo
    echo "Worktree ready: $dir  (branch $branch, ports +$((10 * offset)))"
    echo "Start its agent:  cd $dir && claude"
    echo "Tell it: the /goal kickoff in HANDOFF.md (Overnight run), with <stream> = $stream"
    ;;
  list)
    printf "%-34s %-26s %-10s %-7s %s\n" "FOLDER" "BRANCH" "PORTS+" "DIRTY" "VS MAIN (behind/ahead)"
    git -C "$main_root" worktree list --porcelain | awk '/^worktree /{w=$2} /^branch /{sub("refs/heads/","",$2); print w" "$2}' |
    while read -r dir branch; do
      ports="0"
      [[ -f "$dir/local.mk" ]] && ports="$(awk -F':= ' '/^WEB_PORT/{print $2-8060}' "$dir/local.mk")"
      dirty="no"; [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]] && dirty="yes"
      counts="$(git -C "$main_root" rev-list --left-right --count "main...$branch" 2>/dev/null | tr '\t' '/')"
      printf "%-34s %-26s %-10s %-7s %s\n" "$(basename "$dir")" "$branch" "$ports" "$dirty" "$counts"
    done
    ;;
  remove)
    stream="${2:?usage: worktree.sh remove <stream>}"
    dir="$parent/$repo-$stream"
    if [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]]; then
      echo "$dir has uncommitted changes; commit or discard them first" >&2; exit 1
    fi
    rm -f "$dir/.tools"
    git -C "$main_root" worktree remove --force "$dir"   # --force only for the gitignored local files
    echo "removed $dir (branch stream/$stream is kept; delete it with: git branch -d stream/$stream)"
    ;;
  *)
    sed -n '2,16p' "$0"; exit 2 ;;
esac
