#!/usr/bin/env python3
"""Spotter S5: read his labels from the judging page and say how good the ranker was.

    python3 tools/spotter/labels.py references/spotter/labels/<batch>.json
        the file is the page's db as exported by the session (ArtifactData list of `clips` and `labels`):
        {"clips": [{"id", "order", "crew", "arena", "seed", "reasons", "signals", "repro", "score", ...}],
         "labels": [{"clip", "verdict": "dumb"|"fine"|"unsure", "note"}]}

Round 48 (C48.4): a label with `by: "assumed"` / `assumed: true` is the orchestrator's assumption, not his tap; precision by
rank band and the controls' base rate read HIS taps only, and the assumed count is printed beside them. `--bands 31-50,51-75,76-100`.

Prints: precision of the ranker's order (share of judged clips he called dumb, overall and in the top 10 / 20 / 30), which
signals the dumb ones and the fine ones carried (so a signal that only finds fine moments can be down-weighted), and the
dumb ones as findings for the orchestrator to relay: crew, map, seconds, his note, and the reproduction line.
"""
import json
import sys
from collections import Counter


VERDICTS = ("dumb", "fine", "unsure")


def is_assumed(label):
    return bool(label.get("assumed")) or label.get("by") == "assumed"


def _tally(clips, labels):
    t = {v: 0 for v in VERDICTS}
    t["untapped"] = 0
    for c in clips:
        lab = labels.get(c["id"])
        t[lab["verdict"] if lab and lab.get("verdict") in VERDICTS else "untapped"] += 1
    return t


def summarize(clips, labels, bands=((31, 50), (51, 75), (76, 100))):
    """His taps v assumed labels; precision by rank band (flagged clips, his taps only); the controls' base rate."""
    lab_all = {l["clip"]: l for l in labels if l.get("verdict")}
    lab_his = {k: l for k, l in lab_all.items() if not is_assumed(l)}
    flagged = [c for c in clips if not c.get("control")]
    controls = [c for c in clips if c.get("control")]
    out = {"assumed": sum(1 for l in lab_all.values() if is_assumed(l)), "n_flagged": len(flagged), "n_controls": len(controls)}
    for key, lab in (("his", lab_his), ("all", lab_all)):
        rows = []
        for lo, hi in bands:
            band = [c for c in flagged if lo <= c.get("rank", c.get("order", 0)) <= hi]
            t = _tally(band, lab)
            rows.append({"band": f"{lo}-{hi}", "n": len(band), "dumb": t["dumb"], "decided": t["dumb"] + t["fine"],
                         "unsure": t["unsure"], "untapped": t["untapped"]})
        ctl = _tally(controls, lab)
        dec = ctl["dumb"] + ctl["fine"]
        out[key] = {"flagged": _tally(flagged, lab), "bands": rows, "controls": ctl,
                    "base_rate": (ctl["dumb"] / dec) if dec else None}
    return out


def print_summary(s):
    print(f"flagged {s['n_flagged']}, controls {s['n_controls']}; assumed labels (C48.4, not his taps): {s['assumed']}")
    for key, title in (("his", "HIS OWN TAPS"), ("all", "his taps + assumed")):
        d = s[key]
        f = d["flagged"]
        print(f"{title}: flagged dumb {f['dumb']}, fine {f['fine']}, can't tell {f['unsure']}, untapped {f['untapped']}")
        for b in d["bands"]:
            p = f"{b['dumb']}/{b['decided']} = {b['dumb'] / b['decided']:.2f}" if b["decided"] else "no taps"
            print(f"  rank {b['band']:>7s}: precision {p}  (n {b['n']}, can't tell {b['unsure']}, untapped {b['untapped']})")
        c = d["controls"]
        br = f"{d['base_rate']:.2f}" if d["base_rate"] is not None else "unknown (no control tapped)"
        print(f"  controls: dumb {c['dumb']}, fine {c['fine']}, can't tell {c['unsure']}, untapped {c['untapped']}; base rate {br}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    data = json.load(open(sys.argv[1]))
    bands = ((31, 50), (51, 75), (76, 100))
    if "--bands" in sys.argv:
        spec = sys.argv[sys.argv.index("--bands") + 1]
        bands = tuple(tuple(int(x) for x in b.split("-")) for b in spec.split(","))
    print_summary(summarize(data["clips"], data["labels"], bands))
    print()
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
