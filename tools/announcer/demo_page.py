#!/usr/bin/env python3
"""Builds the Arena Booth Monitor: one self-contained HTML page to watch fixture matches as the booth calls them.

    python3 tools/announcer/demo_page.py --data build/announcer/demo/data --out build/announcer/demo/index.html

--data holds the director's output (announcer_cli.gd --all ... writes <fixture>_seed<N>.json). When an audio mixdown
exists beside a match (<fixture>_seed<N>.ogg, from make announcer-mixdown), the page links it and plays it in sync.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "demo_template.html"
KEEP_CUE = ("t", "end", "speaker", "line_id", "text", "act", "moment", "reason", "cut", "full_seconds")


def load_matches(folder: Path, fixture: str = "") -> list[dict]:
    matches = []
    for path in sorted(folder.glob("*.json")):
        data = json.loads(path.read_text())
        if fixture and data["fixture"] != fixture:
            continue
        match = {
            "fixture": data["fixture"],
            "seed": int(data["seed"]),
            "events": data["events"],
            "cues": [{k: cue[k] for k in KEEP_CUE if k in cue} for cue in data["cues"]],
            "decisions": [d for d in data.get("decisions", []) if d["text"].startswith("skip")],
        }
        audio = path.with_suffix(".ogg")
        if audio.exists():
            match["audio"] = audio.name
        matches.append(match)
    matches.sort(key=lambda m: (m["fixture"], m["seed"]))
    return matches


def build(matches: list[dict]) -> str:
    if not matches:
        raise ValueError("no matches to show: run the director first (make announcer-demo)")
    payload = json.dumps({"matches": matches}, separators=(",", ":")).replace("</", "<\\/")
    template = TEMPLATE.read_text()
    if "/*__DATA__*/" not in template:
        raise ValueError("template lost its data marker")
    return template.replace("/*__DATA__*/", payload)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--fixture", default="", help="only this fixture")
    args = parser.parse_args(argv)
    matches = load_matches(args.data, args.fixture)
    prefix = os.path.relpath(args.data.resolve(), args.out.parent.resolve())
    for match in matches:
        if "audio" in match:
            match["audio"] = "%s/%s" % (prefix, match["audio"])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(build(matches))
    print("wrote %s: %d matches, %d lines, %.0f KB" % (args.out, len(matches), sum(len(m["cues"]) for m in matches),
                                                   args.out.stat().st_size / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
