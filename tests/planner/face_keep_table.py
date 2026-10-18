#!/usr/bin/env python3
"""Round 33 P3's lines (2b) and (2c) over manoeuvre-hull-rest's layout (`make planner-judge-face`, both arms called):
base_* = --planner-face-keep=0 (today), new_* = --planner-face-keep=1, per mode (drawn, clicked), the last
PLANNER_SEAM_REPORT of every run.

  FACE_KEEP_ABANDONED  (2b) the FACE asks' abandoned share, candidate not up beyond 1.645 se (two-proportion, pooled se)
  FACE_KEEP_FAR        (2c) served face plans' furthest-from-home (face_far, m): candidate median <= base median +
                       1.645 se (bootstrap over plans, 4000 rounds, seed 33) AND candidate p90 <= base p90; max reported

Usage: face_keep_table.py <hull-rest dir> [--seeds "84 85 ..."] [--distinct]
  --seeds: only those seeds' runs are read. --distinct (round 33 overnight, as for CP-F's R33.23): a (base, candidate)
  run pair whose face counters and plans repeat another seed's in the same (faction, task) is read once
  (hull_distinct.py), and FACE_KEEP_DISTINCT says how many pairs remain.
"""
import json
import math
import pathlib
import random
import statistics
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
    """{(faction, task, seed): {"asks", "abandoned", "far"}} from each run's last report (face asks only)."""
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
            "abandoned": int(rep.get("abandoned_by_kind", {}).get("face", 0)),
            "far": [float(x) for x in rep.get("face_far", [])]}
    return out


def total(recs, keys):
    keys = [k for k in keys if k in recs]
    return {"runs": len(keys), "asks": sum(recs[k]["asks"] for k in keys),
            "abandoned": sum(recs[k]["abandoned"] for k in keys), "far": [x for k in keys for x in recs[k]["far"]]}


def p90(xs):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(math.ceil(0.9 * len(xs))) - 1)] if xs else float("nan")


def boot_se_median_diff(a, b, rounds=4000):
    rng = random.Random(33)
    diffs = [statistics.median(rng.choices(a, k=len(a))) - statistics.median(rng.choices(b, k=len(b)))
             for _ in range(rounds)]
    return statistics.pstdev(diffs)


def main():
    root = sys.argv[1]
    seeds = set(sys.argv[sys.argv.index("--seeds") + 1].split()) if "--seeds" in sys.argv else set()
    ok = True
    for mode in ("drawn", "clicked"):
        rb, rc = runs(root, f"base_{mode}", seeds), runs(root, f"new_{mode}", seeds)
        if "--distinct" in sys.argv:
            keys, cells = hull_distinct.distinct_keys(rb, rc, sorted(set(rb) & set(rc)))
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
        if not b["far"] or not c["far"]:
            print(f"FACE_KEEP_FAR {mode} | plans candidate {len(c['far'])} v base {len(b['far'])}: NOT JUDGED, nothing to compare")
            ok = False
            continue
        mb, mc = statistics.median(b["far"]), statistics.median(c["far"])
        se_m = boot_se_median_diff(c["far"], b["far"])
        med_ok = mc <= mb + K * se_m
        p90_ok = p90(c["far"]) <= p90(b["far"])
        verdict = "PASS" if med_ok and p90_ok else "FAIL"
        ok = ok and verdict == "PASS"
        print(f"FACE_KEEP_FAR {mode} | plans candidate {len(c['far'])} v base {len(b['far'])} | median {mc:.1f} v "
              f"{mb:.1f} m (se {se_m:.2f}, line <= {mb + K * se_m:.1f}) {'ok' if med_ok else 'over'} | p90 "
              f"{p90(c['far']):.1f} v {p90(b['far']):.1f} {'ok' if p90_ok else 'over'} | max {max(c['far']):.1f} v "
              f"{max(b['far']):.1f} | {verdict}")
    print(f"FACE_KEEP lines (2b) and (2c): {'ALL PASS' if ok else 'NOT ALL PASS'}")


if __name__ == "__main__":
    main()
