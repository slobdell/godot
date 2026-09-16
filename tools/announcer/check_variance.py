#!/usr/bin/env python3
"""Fails when the booth repeats itself too much across matches (`make announcer-variance`).

Reads the VARIANCE_RESULT line the announcer CLI prints and compares it with the ceilings in mk/announcer.mk.
Kept out of the CLI so the thresholds live with the build, not with the measurement.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MARKER = "VARIANCE_RESULT "


def read_result(path: Path) -> dict:
    for line in path.read_text().splitlines():
        if line.startswith(MARKER):
            return json.loads(line[len(MARKER):])
    raise SystemExit(f"{path}: no {MARKER.strip()} line (did the announcer CLI run?)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="the output of the announcer CLI's --variance run")
    parser.add_argument("--max-opener", type=float, default=0.10)
    parser.add_argument("--max-welcome", type=float, default=0.10)
    parser.add_argument("--max-carryover", type=float, default=0.30)
    args = parser.parse_args(argv)

    result = read_result(args.report)
    checks = [
        ("a line said twice in one match", result["in_match_repeats"], 0, "count"),
        ("the same opening line within five matches", result["opener_repeat_rate"], args.max_opener, "rate"),
        ("the same PA welcome within five matches", result["welcome_repeat_rate"], args.max_welcome, "rate"),
        ("lines carried over from the match before", result["carryover_rate"], args.max_carryover, "rate"),
    ]
    failed = []
    for what, value, ceiling, kind in checks:
        shown = f"{value * 100:.1f}%" if kind == "rate" else str(value)
        limit = f"{ceiling * 100:.0f}%" if kind == "rate" else str(ceiling)
        ok = value <= ceiling
        print(f"  {'ok  ' if ok else 'FAIL'} {what}: {shown} (ceiling {limit})")
        if not ok:
            failed.append(what)
    if failed:
        print(f"announcer-variance FAILED: {len(failed)} over the ceiling", file=sys.stderr)
        return 1
    print("announcer-variance passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
