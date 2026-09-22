#!/usr/bin/env python3
"""Builds the Arena Booth Monitor: one self-contained HTML page to watch fixture matches as the booth calls them.

    python3 tools/announcer/demo_page.py --data build/announcer/demo/data --out build/announcer/demo/index.html

--data holds the director's output (announcer_cli.gd --all ... writes <fixture>_seed<N>.json). When an audio mixdown
exists beside a match (<fixture>_seed<N>.ogg, from make announcer-mixdown), the page links it and plays it in sync.

Round 10: the "New this round" tab lists every line whose `added` is --round, with its id, speaker, moment and, when
--clips points at a clip pack whose manifest has it, a play button. The lead's veto is a line id: the page collects
the ids he ticks into a list he can copy back.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "demo_template.html"
LINES = HERE.parents[1] / "assets" / "announcer" / "lines.json"
BEATS = HERE.parents[1] / "assets" / "announcer" / "beats.json"
ROUND = "r10"
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


def fresh_lines(lines_data: dict, kinds: set, this_round: str, manifest: dict | None = None,
                clip_prefix: str = "") -> list[dict]:
    """Every line added this round, as the review page shows it. `clip` is one recording of it (the first variant,
    for a line with slots) when the manifest has one."""
    found = []
    for line in lines_data.get("lines", []):
        if line.get("added") != this_round:
            continue
        entry = {"id": line["id"], "speaker": line["speaker"], "act": line["act"], "text": line["text"],
                 "moments": [t for t in line["tags"] if t in kinds] or ["any"],
                 "tags": [t for t in line["tags"] if t not in kinds]}
        if isinstance(line.get("oddity"), dict):
            entry["span"] = line["oddity"].get("span", "")
        recorded = (manifest or {}).get("lines", {}).get(line["id"], {}).get("variants", {})
        clip = recorded[sorted(recorded)[0]] if recorded else None
        info = (manifest or {}).get("clips", {}).get(clip or "", {})
        if info.get("file"):
            entry["clip"] = "%s/%s" % (clip_prefix, info["file"]) if clip_prefix else info["file"]
            entry["stt_ok"] = bool(info.get("stt_ok", True))
            if len(recorded) > 1:
                entry["variants"] = len(recorded)
        found.append(entry)
    return found


def build(matches: list[dict], fresh: dict | None = None) -> str:
    if not matches:
        raise ValueError("no matches to show: run the director first (make announcer-demo)")
    payload = json.dumps({"matches": matches, "fresh": fresh or {"round": "", "lines": []}},
                         separators=(",", ":")).replace("</", "<\\/")
    template = TEMPLATE.read_text()
    if "/*__DATA__*/" not in template:
        raise ValueError("template lost its data marker")
    return template.replace("/*__DATA__*/", payload)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--fixture", default="", help="only this fixture")
    parser.add_argument("--lines", type=Path, default=LINES)
    parser.add_argument("--round", default=ROUND, help="the `added` value the New tab lists")
    parser.add_argument("--clips", type=Path, help="a clip pack (manifest.json and the .ogg files) for the New tab's play buttons")
    args = parser.parse_args(argv)
    matches = load_matches(args.data, args.fixture)
    prefix = os.path.relpath(args.data.resolve(), args.out.parent.resolve())
    for match in matches:
        if "audio" in match:
            match["audio"] = "%s/%s" % (prefix, match["audio"])
    kinds = set(json.loads(BEATS.read_text())["moments"])
    manifest, clip_prefix = None, ""
    if args.clips and (args.clips / "manifest.json").exists():
        manifest = json.loads((args.clips / "manifest.json").read_text())
        clip_prefix = os.path.relpath(args.clips.resolve(), args.out.parent.resolve())
    fresh = {"round": args.round,
             "lines": fresh_lines(json.loads(args.lines.read_text()), kinds, args.round, manifest, clip_prefix)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(build(matches, fresh))
    print("wrote %s: %d matches, %d lines, %d new this round (%d with a clip), %.0f KB" % (
        args.out, len(matches), sum(len(m["cues"]) for m in matches), len(fresh["lines"]),
        sum(1 for line in fresh["lines"] if "clip" in line), args.out.stat().st_size / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
