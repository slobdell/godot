#!/usr/bin/env bash
# A Godot run's exit code, judged (ship, round 18; the exit-code audit after picker's crash at exit).
#
#     tools/exit_gate.sh <target> <status> <log> [<expected non-zero code> ...]
#
# Exits 0 when <status> is 0 or one of the named expected codes; otherwise prints the target, the code and what it
# means, and the log's last lines, and exits 1. Recipes capture the status as `s=0; cmd > log 2>&1 || s=$$?`
# (lesson 250) and call this after their marker greps, so a run that printed every marker and then aborted at exit
# (134) or timed out (124) is red, with the reason, instead of green.
set -u
target=$1 status=$2 log=$3
shift 3
[ "$status" = 0 ] && exit 0
for expected in "$@"; do
	[ "$status" = "$expected" ] && { echo "$target: exited $status (expected: named in its recipe)"; exit 0; }
done
case $status in
	124) why="timed out" ;;
	134) why="aborted (SIGABRT: a crash, e.g. heap corruption at exit)" ;;
	139) why="segfault" ;;
	137) why="killed (SIGKILL)" ;;
	*) why="a non-zero exit" ;;
esac
echo "$target FAILED: the game exited $status -- $why. Its last lines ($log):"
tail -6 "$log" 2>/dev/null | sed 's/^/    /'
exit 1
