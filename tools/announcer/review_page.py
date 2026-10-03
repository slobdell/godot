"""The lead's veto page for new announcer lines (round 16, booth B3; lead gate 1: no ElevenLabs before his taps).

One card per draft line, grouped by the pool it joins: the moment in plain words, today's pool (its lines, how often
it is said a match, how often a line comes back within five matches) beside what the drafts make of it, and the
credits each line costs to voice. APPROVE / REJECT write to the page's `db` (collection `verdicts`, doc id = the line
id with `.` → `_`, fields line_id, verdict, text, at), which the booth reads back (`ArtifactData list verdicts`).

    python3 tools/announcer/review_page.py --drafts assets/announcer/drafts/r16_lines.json \
        --before build/announcer/thin_before.json --after build/announcer/thin_after.json \
        --out build/announcer/review/index.html
"""

from __future__ import annotations

import argparse
import html
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import recording_plan  # noqa: E402
import thin_pools  # noqa: E402

LINES = os.path.join(ROOT, "assets", "announcer", "lines.json")
SPEAKER_NAMES = {"caller": "Caller", "color": "Veteran", "pa": "PA"}
## What each pool is, in the words a player would use. Keyed by thin_pools.pool_key.
MOMENTS = {
    "caller call [kill,streak]": "A kill in an unanswered run: three or more for one side, nothing coming back",
    "caller call [flurry,kill]": "Several vehicles down within four seconds, one call for the pile-up",
    "caller call [another,kill]": "The same side kills again while the last kill is still being called",
    "caller interrupt [any]": "The caller cuts off the Veteran or the PA because something bigger just happened",
    "caller stat [kill,streak]": "The caller's calmer follow-up to a run: the number behind it",
    "caller call [final_kill,kill]": "The kill that ends the match",
    "caller call [kill,upset]": "A smaller vehicle takes out a bigger one",
    "pa result [outro]": "Celeste reads the result after the match",
}


def pool_rows(path: str | None) -> dict:
    if not path:
        return {}
    with open(path) as handle:
        return {row["pool"]: row for row in json.load(handle)["pools"]}


def build(drafts: list, library: dict, before: dict, after: dict, title: str) -> str:
    vocabulary = library.get("vocabulary", {})
    existing = thin_pools.library_pools(library["lines"])
    groups: dict = {}
    for line in drafts:
        key = thin_pools.pool_key(line["speaker"], line["act"], line.get("tags", []))
        recordings = recording_plan.realizations(line, vocabulary)
        groups.setdefault(key, []).append({
            "id": line["id"], "speaker": line["speaker"], "text": line["text"],
            "recordings": len(recordings), "credits": sum(len(r.get("text", "")) for r in recordings),
            "oddity": (line.get("oddity") or {}).get("span", ""),
        })
    pools = []
    for key, cards in groups.items():
        was, now = before.get(key, {}), after.get(key, {})
        pools.append({
            "key": key, "moment": MOMENTS.get(key, key), "speaker": cards[0]["speaker"],
            "today": {"lines": len(existing.get(key, [])), "per_match": was.get("calls_per_match"),
                      "again5": was.get("again5")},
            "with": {"lines": len(existing.get(key, [])) + len(cards), "per_match": now.get("calls_per_match"),
                     "again5": now.get("again5")},
            "existing": [line["text"] for line in existing.get(key, [])],
            "cards": cards,
        })
    pools.sort(key=lambda p: -(p["today"]["again5"] or 0) * (p["today"]["per_match"] or 0))
    data = json.dumps({"pools": pools}).replace("</", "<\\/")
    with open(os.path.join(HERE, "review_template.html")) as handle:
        template = handle.read()
    return template.replace("{{TITLE}}", html.escape(title)).replace("{{DATA}}", data)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--drafts", required=True)
    parser.add_argument("--lines", default=LINES)
    parser.add_argument("--before", help="thin_pools --json over today's library")
    parser.add_argument("--after", help="thin_pools --json with the drafts")
    parser.add_argument("--title", default="Booth Veto, Round 16")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    with open(args.drafts) as handle:
        drafts = json.load(handle)["lines"]
    with open(args.lines) as handle:
        library = json.load(handle)
    page = build(drafts, library, pool_rows(args.before), pool_rows(args.after), args.title)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as handle:
        handle.write(page)
    print("wrote %s: %d lines in %d pools" % (args.out, len(drafts), page.count('"key":')))
    return 0


if __name__ == "__main__":
    sys.exit(main())
