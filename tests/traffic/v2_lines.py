#!/usr/bin/env python3
"""Round 33 overnight (traffic, parkedroom v2's bar, filed before numbers): lines L4 and L5.

    python3 tests/traffic/v2_lines.py series BASE.jsonl ARM.jsonl   (make traffic-series TRAFFIC_OUT=..., both arms)
    python3 tests/traffic/v2_lines.py census ARM.jsonl              (make traffic-census, the arm)

L4 (deciding) arrivals not down: per crossing case (arena, kind), the "both" runs paired by (seed, start tick), crews
arrived summed: arm >= base - k*se, se = the paired se of the SUM. L5 (deciding) T1c-b2 as shipped: the arm's census
runs with a repack while firing (repacks_while_firing > 0) = 0.
"""
import json
import statistics
import sys

K = 1.645


def rows(path):
    return [json.loads(line) for line in open(path) if line.strip()]


def series(base_path, arm_path):
    ok = True
    def table(path):
        out = {}
        for r in rows(path):
            if r.get("missing") or r.get("which") != "both":
                continue
            out.setdefault((r["arena"], r["kind"]), {})[(r["seed"], r.get("start_tick"))] = int(r["arrived"])
        return out
    tb, ta = table(base_path), table(arm_path)
    for case in sorted(set(tb) | set(ta)):
        b, a = tb.get(case, {}), ta.get(case, {})
        keys = sorted(set(b) & set(a))
        d = [a[k] - b[k] for k in keys]
        se = statistics.stdev(d) * len(d) ** 0.5 if len(d) > 1 else 0.0
        sb, sa = sum(b[k] for k in keys), sum(a[k] for k in keys)
        good = len(keys) > 0 and sa >= sb - K * se
        ok &= good
        print("L4 %s,%s crews arrived: base %d arm %d diff %+d se %.1f (n %d), line >= %.1f: %s" % (
            case[0], case[1], sb, sa, sa - sb, se, len(keys), sb - K * se, "PASS" if good else "FAIL"))
    print("v2 L4 %s" % ("PASS" if ok else "FAIL"))


def census(arm_path):
    rs = rows(arm_path)
    firing = [r for r in rs if int(r.get("repacks_while_firing", 0)) > 0]
    missing = [r for r in rs if r.get("missing")]
    print("v2 L5 runs with a repack while firing: %d of %d (missing %d): %s" % (
        len(firing), len(rs), len(missing), "PASS" if not firing and not missing else "FAIL"))
    for r in firing:
        print("  %s s%s repacks_while_firing %d" % (r.get("arena"), r.get("seed"), int(r["repacks_while_firing"])))


if __name__ == "__main__":
    if sys.argv[1] == "series":
        series(sys.argv[2], sys.argv[3])
    else:
        census(sys.argv[2])
