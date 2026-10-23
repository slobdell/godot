#!/usr/bin/env python3
"""R38.10: judge S2's re-read. python3 tests/settle/settle_rr.py FIRST_DIR RR_DIR

FIRST_DIR = the first read's settle-series folder (probe/, fight/), RR_DIR = settle-s2-reread's folder (probe/, fight3/,
fight5/, census-*.jsonl). Writes RR_DIR/fight (the 3-squad fight read: the first read's 3873-3878 + the top-up, main and
latch only) and prints settle_judge.py s2 on the fresh probe, the 5-squad fight guards, and the never-in guard as ruled.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "control"))
import orders_judge as oj  # noqa: E402

ARMS = ("main", "latch")


def lines_of(path):
    with open(path) as f:
        return [json.loads(l) for l in f if l.strip()]


def merge(first, rr):
    out = os.path.join(rr, "fight")
    os.makedirs(out, exist_ok=True)
    for name in ("rows.jsonl", "runs.jsonl"):
        rows = [r for d in (os.path.join(first, "fight"), os.path.join(rr, "fight3")) for r in lines_of(os.path.join(d, name))
                if r.get("arm") in ARMS and r.get("squads") == 3]
        with open(os.path.join(out, name), "w") as f:
            f.writelines(json.dumps(r) + "\n" for r in rows)
    return out


def never_in(probe_dir):
    runs = oj.by_run(lines_of(os.path.join(probe_dir, "rows.jsonl")), "main"), oj.by_run(lines_of(os.path.join(probe_dir, "rows.jsonl")), "latch")
    return [sum(1 for sq in r.values() if oj.run_all_in(sq) < 0) for r in runs]


def main(first, rr):
    merge(first, rr)
    here = os.path.dirname(os.path.abspath(__file__))
    res = subprocess.run([sys.executable, os.path.join(here, "settle_judge.py"), "s2", os.path.join(rr, "probe"),
                          os.path.join(rr, "fight"), os.path.join(rr, "census-main.jsonl"), os.path.join(rr, "census-latch.jsonl"),
                          "main", "latch"], capture_output=True, text=True)
    print(res.stdout.strip())
    lines = []
    f5 = [r for r in lines_of(os.path.join(rr, "fight5", "runs.jsonl")) if "arm" in r]
    ok5 = oj.fight_guards(f5, "main", "latch", lines)
    print("5-squad fight read (--probe-budget=3000):\n" + "\n".join(lines))
    fresh = never_in(os.path.join(rr, "probe"))
    first_n = never_in(os.path.join(first, "probe"))
    pooled = [fresh[0] + first_n[0], fresh[1] + first_n[1]]
    g1 = fresh[1] <= fresh[0]
    g2 = pooled[1] <= pooled[0] + 1
    print("%s never-in (R38.10) fresh: main %d, latch %d (latch <= main)" % ("PASS" if g1 else "FAIL", fresh[0], fresh[1]))
    print("%s never-in (R38.10) pooled over both reads: main %d, latch %d (latch <= main + 1)" % ("PASS" if g2 else "FAIL",
                                                                                                 pooled[0], pooled[1]))
    # The judge's own never-in line is per cell (probe_guards); R38.10 replaces it with the two lines above, so every OTHER
    # FAIL line of the s2 judge still fails the re-read.
    other = [l.strip() for l in res.stdout.splitlines() if "FAIL" in l and "never-in" not in l
             and not l.startswith("FAIL probe guards") and not l.startswith("VERDICT")]
    print("other FAIL lines: %s" % (other or "none"))
    ok = g1 and g2 and ok5 and not other
    print("VERDICT %s latch v main (R38.10 re-read)" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
