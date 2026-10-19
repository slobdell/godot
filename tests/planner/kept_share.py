#!/usr/bin/env python3
"""Round 33 P3's lines (0) (second half) and (2d) over manoeuvre-hull-rest's layout (`make planner-judge-face`, both
arms called): base_* = --planner-face-keep=0, new_* = --planner-face-keep=1, per mode, the last PLANNER_SEAM_REPORT of
every run.

  P3_KEPT  (0) the candidate's served face plans (one face_far entry each) and how many the KEPT search served
           (face_kept_served); line >= 50 % (below it the candidate is main in disguise: PARK). Fallbacks reported.
  P3_HOLD  (2d) REPORTED: the hold per event (hold_ticks, every event pooled), median candidate v base.

Usage: kept_share.py <hull-rest dir> [--seeds "96 97 ..."] [--distinct]   (--distinct: hull_distinct.py's rule)
"""
import json
import pathlib
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import hull_distinct  # noqa: E402

FIELDS = ("face_far", "face_kept_served", "face_kept_fallbacks", "hold_ticks")


def last_report(log):
    last = None
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("PLANNER_SEAM_REPORT "):
            last = line
    return json.loads(last.split(" ", 1)[1]) if last else None


def runs(root, name, seeds):
    out = {}
    for log in sorted(pathlib.Path(root, name).glob("*/*/run.log")):
        task, seed = log.parent.name.rsplit("-", 1)
        if seeds and seed not in seeds:
            continue
        rep = last_report(log)
        if rep is not None:
            out[(log.parent.parent.name, task, seed)] = {f: rep.get(f, 0 if "kept" in f else []) for f in FIELDS}
    return out


def main(argv):
    root = argv[1]
    seeds = set(argv[argv.index("--seeds") + 1].split()) if "--seeds" in argv else set()
    ok = True
    for mode in ("drawn", "clicked"):
        rb, rc = runs(root, f"base_{mode}", seeds), runs(root, f"new_{mode}", seeds)
        keys = sorted(set(rb) & set(rc))
        if not keys:
            print(f"P3_KEPT {mode} | NOT JUDGED: no paired runs (base {len(rb)}, candidate {len(rc)})")
            ok = False
            continue
        if "--distinct" in argv:
            keys, cells = hull_distinct.distinct_runs(root, keys, lambda _k, m=mode: (f"base_{m}", f"new_{m}"))
            for line in hull_distinct.summary({(mode,) + c: v for c, v in cells.items()}, "P3_DISTINCT"):
                print(line)
        served = sum(len(rc[k]["face_far"]) for k in keys)
        kept = sum(int(rc[k]["face_kept_served"]) for k in keys)
        fallbacks = sum(int(rc[k]["face_kept_fallbacks"]) for k in keys)
        share = kept / served if served else 0.0
        passed = served > 0 and share >= 0.5
        ok = ok and passed
        print(f"P3_KEPT {mode} | runs {len(keys)} | candidate face plans served {served}, by the kept search {kept} "
              f"({100 * share:.0f} %), fallbacks {fallbacks} | line >= 50 % | {'PASS' if passed else 'FAIL'}")
        hb = [int(t) for k in keys for t in rb[k]["hold_ticks"]]
        hc = [int(t) for k in keys for t in rc[k]["hold_ticks"]]
        print(f"P3_HOLD {mode} | hold median (all events) candidate {statistics.median(hc) if hc else 0} (n {len(hc)}) "
              f"v base {statistics.median(hb) if hb else 0} (n {len(hb)}) | reported")
    print(f"P3_KEPT line (0), the kept share: {'PASS' if ok else 'NOT ALL PASS'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
