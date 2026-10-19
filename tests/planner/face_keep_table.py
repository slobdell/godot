#!/usr/bin/env python3
"""Round 33 P3's line (2b) over manoeuvre-hull-rest's layout (`make planner-judge-face`, both arms called):
base_* = --planner-face-keep=0 (today), new_* = --planner-face-keep=1, per mode (drawn, clicked), the last
PLANNER_SEAM_REPORT of every run.

  FACE_KEEP_ABANDONED  (2b) the FACE asks' abandoned share, candidate not up beyond 1.645 se (two-proportion, pooled se)
  (2c) FACE_KEEP_FAR was deleted in round 35 (R34.5, C35.9): unpaired, it pooled faces planned in one arm only, so it
  measured WHICH faces got planned and flipped with the distinct rule alone. The judged reading is face_pairs.py (faces
  matched by crew and home).

Usage: face_keep_table.py <hull-rest dir> [--seeds "84 85 ..."] [--distinct]
  --seeds: only those seeds' runs are read. --distinct (round 33 overnight, as for CP-F's R33.23): a (base, candidate)
  run pair whose face counters and plans repeat another seed's in the same (faction, task) is read once
  (hull_distinct.py), and FACE_KEEP_DISTINCT says how many pairs remain.
"""
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import hull_distinct  # noqa: E402

K = 1.645


def last_report(log):
    last = None
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("PLANNER_SEAM_REPORT "):
            last = line
    return json.loads(last.split(" ", 1)[1]) if last else None


def runs(root, name, seeds):
    """{(faction, task, seed): {"asks", "abandoned"}} from each run's last report (face asks only)."""
    out = {}
    for log in sorted(pathlib.Path(root, name).glob("*/*/run.log")):
        task, seed = log.parent.name.rsplit("-", 1)
        if seeds and seed not in seeds:
            continue
        rep = last_report(log)
        if rep is None:
            continue
        out[(log.parent.parent.name, task, seed)] = {
            "asks": int(rep.get("asks_by_kind", {}).get("face", 0)),
            "abandoned": int(rep.get("abandoned_by_kind", {}).get("face", 0))}
    return out


def total(recs, keys):
    keys = [k for k in keys if k in recs]
    return {"runs": len(keys), "asks": sum(recs[k]["asks"] for k in keys),
            "abandoned": sum(recs[k]["abandoned"] for k in keys)}


def main():
    root = sys.argv[1]
    seeds = set(sys.argv[sys.argv.index("--seeds") + 1].split()) if "--seeds" in sys.argv else set()
    ok = True
    for mode in ("drawn", "clicked"):
        rb, rc = runs(root, f"base_{mode}", seeds), runs(root, f"new_{mode}", seeds)
        if "--distinct" in sys.argv:
            keys, cells = hull_distinct.distinct_runs(root, sorted(set(rb) & set(rc)), lambda _k, m=mode: (f"base_{m}", f"new_{m}"))
            for line in hull_distinct.summary({(mode,) + c: v for c, v in cells.items()}, "FACE_KEEP_DISTINCT"):
                print(line)
            b, c = total(rb, keys), total(rc, keys)
        else:
            b, c = total(rb, rb), total(rc, rc)
        if not b["runs"] or not c["runs"]:
            print(f"FACE_KEEP_ABANDONED {mode} | missing arm (base runs {b['runs']}, candidate runs {c['runs']})")
            ok = False
            continue
        if not b["asks"] or not c["asks"]:
            print(f"FACE_KEEP_ABANDONED {mode} | NOT JUDGED: no face asks counted (candidate {c['asks']}, base {b['asks']}; "
                  "a tree without asks_by_kind?)")
            ok = False
            continue
        pb = b["abandoned"] / max(1, b["asks"])
        pc = c["abandoned"] / max(1, c["asks"])
        pool = (b["abandoned"] + c["abandoned"]) / max(1, b["asks"] + c["asks"])
        se = math.sqrt(pool * (1 - pool) * (1 / max(1, b["asks"]) + 1 / max(1, c["asks"])))
        line = pb + K * se
        verdict = "PASS" if pc <= line else "FAIL"
        ok = ok and verdict == "PASS"
        print(f"FACE_KEEP_ABANDONED {mode} | runs {c['runs']} v {b['runs']} | candidate {c['abandoned']}/{c['asks']} = "
              f"{100 * pc:.1f} % v base {b['abandoned']}/{b['asks']} = {100 * pb:.1f} % | se {100 * se:.1f} pts | "
              f"line <= {100 * line:.1f} % | {verdict}")
    print(f"FACE_KEEP line (2b): {'ALL PASS' if ok else 'NOT ALL PASS'}")


if __name__ == "__main__":
    main()
