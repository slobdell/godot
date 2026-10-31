#!/usr/bin/env python3
"""Spotter S5: read his labels from the judging page and say how good the ranker was.

    python3 tools/spotter/labels.py references/spotter/labels/<batch>.json
        the file is the page's db as exported by the session (ArtifactData list of `clips` and `labels`):
        {"clips": [{"id", "order", "crew", "arena", "seed", "reasons", "signals", "repro", "score", ...}],
         "labels": [{"clip", "verdict": "dumb"|"fine"|"unsure", "note"}]}

Prints: precision of the ranker's order (share of judged clips he called dumb, overall and in the top 10 / 20 / 30), which
signals the dumb ones and the fine ones carried (so a signal that only finds fine moments can be down-weighted), and the
dumb ones as findings for the orchestrator to relay: crew, map, seconds, his note, and the reproduction line.
"""
import json
import sys
from collections import Counter


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    data = json.load(open(sys.argv[1]))
    clips = {c["id"]: c for c in data["clips"]}
    labels = {l["clip"]: l for l in data["labels"] if l.get("verdict")}
    judged = [c for c in sorted(clips.values(), key=lambda c: c["order"]) if c["id"] in labels]
    decided = [c for c in judged if labels[c["id"]]["verdict"] in ("dumb", "fine")]
    dumb = [c for c in judged if labels[c["id"]]["verdict"] == "dumb"]
    print(f"labels: {len(judged)} of {len(clips)} clips judged ({len(dumb)} dumb, "
          f"{sum(1 for c in judged if labels[c['id']]['verdict'] == 'fine')} fine, "
          f"{sum(1 for c in judged if labels[c['id']]['verdict'] == 'unsure')} can't tell)")
    if decided:
        print(f"precision (dumb / dumb+fine): {len(dumb)}/{len(decided)} = {len(dumb) / len(decided):.2f}")
    for k in (10, 20, 30):
        top = [c for c in decided if c["order"] <= k]
        if top:
            hit = sum(1 for c in top if labels[c["id"]]["verdict"] == "dumb")
            print(f"  top {k:2d}: {hit}/{len(top)} = {hit / len(top):.2f}")
    by = {"dumb": Counter(), "fine": Counter()}
    for c in decided:
        for s in c.get("signals", []):
            by[labels[c["id"]]["verdict"]][s] += 1
    print("signals (dumb / fine):")
    for s in sorted(set(by["dumb"]) | set(by["fine"]), key=lambda s: -by["dumb"][s]):
        print(f"  {s:12s} {by['dumb'][s]:3d} / {by['fine'][s]:3d}")
    print("\nfindings (his 'looks dumb', for the orchestrator to relay):")
    for c in dumb:
        note = labels[c["id"]].get("note", "").strip()
        print(f"- {c['crew']} ({c.get('unit', '')}) on {c['arena']} seed {c['seed']}, {c.get('seconds', '')}: "
              f"{'; '.join(c.get('reasons', []))}" + (f'. His note: "{note}"' if note else "") + f"\n  `{c['repro']}`")


if __name__ == "__main__":
    main()
