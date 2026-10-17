#!/usr/bin/env python3
"""Round 33 (planner P3): the face searches as the seam made them, re-planned whole at each weight (--planner-face-shadow).

Reads every PLANNER_FACE_SHADOW {json} line under DIR (recursively, *.log), one per face search begun. Prints, per
weight: how many land inside the hold (code OK and expansions <= cap), how many OK past it, refused by code; and over
the searches OK at BOTH 1.5 and the weight: the cost ratio (median, p90, max) and the legs' change. FACE_SHADOW lines.
Usage: face_shadow_table.py DIR
"""
import json
import pathlib
import statistics
import sys


def main(root):
    rows = []
    for path in sorted(pathlib.Path(root).rglob("*.log")):
        for line in path.read_text(errors="replace").splitlines():
            if line.startswith("PLANNER_FACE_SHADOW "):
                try:
                    rows.append(json.loads(line[len("PLANNER_FACE_SHADOW "):]))
                except json.JSONDecodeError:
                    pass
    if not rows:
        print(f"FACE_SHADOW no lines under {root}")
        return 1
    weights = [k for k in rows[0] if k.startswith(("e", "k"))]
    cap = rows[0]["cap"]
    print(f"FACE_SHADOW searches {len(rows)} (keep circle on {sum(1 for r in rows if r.get('keep'))}), hold cap {cap} expansions")
    for w in weights:
        inside = sum(1 for r in rows if r[w]["code"] == "OK" and r[w]["exp"] <= cap)
        past = sum(1 for r in rows if r[w]["code"] == "OK" and r[w]["exp"] > cap)
        codes = {}
        for r in rows:
            if r[w]["code"] != "OK":
                codes[r[w]["code"]] = codes.get(r[w]["code"], 0) + 1
        exps = [r[w]["exp"] for r in rows if r[w]["code"] == "OK"]
        line = f"FACE_SHADOW {w} | inside the hold {inside} | OK past it {past} | refused {codes}"
        if exps:
            line += f" | expansions median {statistics.median(exps)} max {max(exps)}"
        fars = [r[w].get("far", 0.0) for r in rows if r[w]["code"] == "OK"]
        if fars:
            line += f" | furthest from home median {statistics.median(fars):.1f} max {max(fars):.1f} m"
        if w != "e1.5":
            both = [r for r in rows if r[w]["code"] == "OK" and r["e1.5"]["code"] == "OK" and r["e1.5"]["cost"] > 0]
            if both:
                ratio = sorted(r[w]["cost"] / r["e1.5"]["cost"] for r in both)
                legs = [r[w]["legs"] - r["e1.5"]["legs"] for r in both]
                line += (f" | cost v 1.5 over {len(both)}: median {statistics.median(ratio):.3f} p90 "
                         f"{ratio[int(0.9 * (len(ratio) - 1))]:.3f} max {ratio[-1]:.3f}; same plan {sum(1 for r in both if r[w]['plan'] == r['e1.5']['plan'])}; "
                         f"legs +{sum(1 for d in legs if d > 0)} / -{sum(1 for d in legs if d < 0)}")
            gained = sum(1 for r in rows if r[w]["code"] == "OK" and r[w]["exp"] <= cap and not (r["e1.5"]["code"] == "OK" and r["e1.5"]["exp"] <= cap))
            line += f" | newly inside the hold {gained}"
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/manoeuvre/hull-rest"))
