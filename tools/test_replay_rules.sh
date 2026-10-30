#!/usr/bin/env bash
# R46.11 (native): tests/replay's Python known answers (rules.py: which rule switches a replay of his recording turns off),
# run by shell-tools-test so make check holds them.
cd "$(dirname "$0")/.." || exit 1
out=$(python3 -m unittest discover -s tests/replay -p 'test_*.py' 2>&1)
echo "$out" | tail -3
echo "$out" | tail -1 | grep -qE '^OK' && echo "$out" | grep -qE '^Ran [1-9]'
