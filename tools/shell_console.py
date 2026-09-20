#!/usr/bin/env python3
"""The console state of a real player session, as a committed baseline.

`make shell-playtest` walks title -> skirmish -> a minute of battle through real clicks and reads the whole console.
Until round 9 it failed on ANY `ERROR`/`WARNING` outside two hard-coded allow-list patterns, which is why it was never
put in `check`: lesson 42 says do not add a red suite to the gate. This turns it into the honest first step instead --
**record the expected state and fail only on CHANGE** -- so the next texture leak is visible to the gate rather than to
whoever happens to run a windowed playtest.

The unit is a CLASS, not a line. `Texture with GL ID 4127 leaked 5460 bytes` and the same message with another id are
one class with a count of two; otherwise the baseline would churn on every run and teach everyone to ignore it. Numbers,
hex ids, paths, node paths and times are replaced by placeholders before counting.

    tools/shell_console.py write   build/shell-playtest/run.log tests/baselines/shell_console.txt
    tools/shell_console.py compare build/shell-playtest/run.log tests/baselines/shell_console.txt

`compare` exits 0 when the classes and counts match the baseline, 1 otherwise, and prints what moved in both
directions -- a line that DISAPPEARED is news too (something was fixed and the baseline should shrink, or a step of the
playtest silently stopped running).
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

# A console line worth recording: Godot's own error and warning channels, plus script errors.
INTERESTING = re.compile(r"(^ERROR:|^WARNING:|^\s*ERROR:|^\s*WARNING:|SCRIPT ERROR)")

# What varies run to run and must not make two identical faults look different.
PLACEHOLDERS = [
    (re.compile(r"\b0x[0-9a-fA-F]+\b"), "<hex>"),
    (re.compile(r"res://[^\s:,)\"']+"), "<res>"),
    (re.compile(r"(?:/[\w.\-+]+){2,}"), "<path>"),
    (re.compile(r"\b\d+\.\d+\b"), "<f>"),
    (re.compile(r"\b\d+\b"), "<n>"),
    (re.compile(r"\s+"), " "),
]


def classify(line: str) -> str:
    """One console line reduced to the class of fault it is."""
    text = line.strip()
    for pattern, placeholder in PLACEHOLDERS:
        text = pattern.sub(placeholder, text)
    return text.strip()


def classes(log: str) -> Counter[str]:
    found: Counter[str] = Counter()
    for line in log.splitlines():
        if INTERESTING.search(line):
            found[classify(line)] += 1
    return found


def render(found: Counter[str]) -> str:
    """The baseline file: count and class, one per line, sorted so a diff is readable."""
    lines = ["# The console state `make shell-playtest` is expected to produce (tools/shell_console.py).",
             "# Failing on CHANGE, not on redness: every line here is a fault we have already seen and decided about.",
             "# Regenerate deliberately: make shell-console-baseline -- and say in the commit why each line moved.",
             ""]
    for text, count in sorted(found.items()):
        lines.append(f"{count}\t{text}")
    return "\n".join(lines) + "\n"


def parse(text: str) -> Counter[str]:
    found: Counter[str] = Counter()
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        count, _, body = line.partition("\t")
        found[body] = int(count)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["write", "compare"])
    parser.add_argument("log", type=Path)
    parser.add_argument("baseline", type=Path)
    args = parser.parse_args()

    if not args.log.exists():
        print(f"shell_console: no log at {args.log} -- did the playtest run?", file=sys.stderr)
        return 2
    found = classes(args.log.read_text(errors="replace"))

    if args.action == "write":
        args.baseline.parent.mkdir(parents=True, exist_ok=True)
        args.baseline.write_text(render(found))
        print(f"shell_console: wrote {len(found)} classes ({sum(found.values())} lines) to {args.baseline}")
        return 0

    if not args.baseline.exists():
        print(f"shell_console: no baseline at {args.baseline}; run `make shell-console-baseline` once and commit it",
              file=sys.stderr)
        return 2
    expected = parse(args.baseline.read_text())
    if found == expected:
        print(f"shell_console: unchanged ({len(found)} classes, {sum(found.values())} lines)")
        return 0

    print("shell_console: THE CONSOLE CHANGED. Every line below is news: a new fault, or one that stopped happening.")
    for text in sorted(set(expected) | set(found)):
        was, now = expected.get(text, 0), found.get(text, 0)
        if was != now:
            print(f"  {was} -> {now}\t{text}")
    print("\nIf the change is wanted (a fix, or a fault decided about), `make shell-console-baseline` and say why in")
    print("the commit. If it is not, it is a regression a player would have seen in their console.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
