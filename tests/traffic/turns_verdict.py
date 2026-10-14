"""Round 29 (traffic T3): the crossing rule's pre-registered bar, from a judged base arm (--traffic-off=turns) and a
judged arm (two traffic-series JSONL files, the same seeds and start ticks, TRAFFIC_WHICH=both).

  python3 tests/traffic/turns_verdict.py BASE.jsonl ARM.jsonl

(1) between-squad fast contacts pooled over the crossing cases down >= 25 %, and neither crossing case up;
(2) every case: crews >= base - 2, all-in median <= base + 20 %, no wedge (a run with > 1 crew never in whose paired base
    run had none);
(3) same-squad fast (all fast - between) <= base x 1.2 + 10 in each crossing case;
(4) head-on cases: all fast within 2 se of base (paired per run; a fall always passes).
The arm's own counters are printed (lesson 300). Prints VERDICT PASS / FAIL.
"""
import json
import math
import statistics
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from traffic_table import all_in_s  # noqa: E402


def load(path):
    runs = {}
    for line in open(path):
        r = json.loads(line)
        if r.get("which") != "both" or r.get("missing"):
            continue
        runs[(r["arena"] + "/" + r["kind"], r["seed"], r["start_tick"])] = r
    return runs


def main(base_path, arm_path):
    base, arm = load(base_path), load(arm_path)
    ok = True
    cross_b = cross_a = 0
    for case in sorted({k[0] for k in arm}):
        keys = sorted(k for k in arm if k[0] == case and k in base)
        b = [base[k] for k in keys]
        a = [arm[k] for k in keys]
        crews_b, crews_a = sum(r["arrived"] for r in b), sum(r["arrived"] for r in a)
        x_b, x_a = sum(r["contacts_cross_fast"] for r in b), sum(r["contacts_cross_fast"] for r in a)
        f_b, f_a = sum(r["contacts_fast"] for r in b), sum(r["contacts_fast"] for r in a)
        m_b = statistics.median(all_in_s(r) for r in b)
        m_a = statistics.median(all_in_s(r) for r in a)
        wedges = ["s%s/t%s" % (k[1], k[2]) for k in keys
                  if arm[k]["crews"] - arm[k]["arrived"] > 1 and base[k]["crews"] - base[k]["arrived"] == 0]
        counters = {c: sum(r.get("tr_" + c, 0) for r in a) for c in ("cross_verdicts", "cross_slowed", "verdicts", "holds")}
        lines = [("crews >= base - 2", crews_a >= crews_b - 2, "%d -> %d" % (crews_b, crews_a)),
                 ("all-in median <= +20 %", m_a <= 1.2 * m_b, "%.1f -> %.1f" % (m_b, m_a)),
                 ("no wedge", not wedges, " ".join(wedges) or "none")]
        if case.endswith("/cross"):
            cross_b += x_b
            cross_a += x_a
            lines.append(("between-squad fast not up", x_a <= x_b, "%d -> %d" % (x_b, x_a)))
            lines.append(("same-squad fast <= base x 1.2 + 10", f_a - x_a <= 1.2 * (f_b - x_b) + 10,
                          "%d -> %d" % (f_b - x_b, f_a - x_a)))
        else:
            d = [ra["contacts_fast"] - rb["contacts_fast"] for rb, ra in zip(b, a)]
            se = math.sqrt(len(d)) * statistics.stdev(d) if len(d) > 1 else 0.0
            lines.append(("fast within 2 se", f_a - f_b <= 2.0 * se, "%d -> %d (2 se %.1f)" % (f_b, f_a, 2.0 * se)))
        print("%s  n=%d  fast %d -> %d  between %d -> %d  counters %s" % (case, len(keys), f_b, f_a, x_b, x_a,
                                                                          json.dumps(counters)))
        for name, passed, detail in lines:
            ok = ok and passed
            print("   %-36s %s  %s" % (name, "pass" if passed else "FAIL", detail))
    if cross_b or cross_a:
        passed = cross_a <= 0.75 * cross_b
        ok = ok and passed
        print("crossings pooled: between-squad fast %d -> %d (%+.0f %%)  %s" % (
            cross_b, cross_a, 100.0 * (cross_a - cross_b) / max(cross_b, 1), "pass" if passed else "FAIL (needs <= -25 %)"))
    print("VERDICT " + ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
