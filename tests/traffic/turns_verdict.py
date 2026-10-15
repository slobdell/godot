"""Round 30 (traffic T3b): the crossing's pre-registered bar (sent to the orchestrator before any judged number; sized by
sizing's CP-N table, `_agents/judging.md`), from a judged base arm (no flag: the crossing is DEFAULT_OFF) and a judged
arm (--traffic-on=turns): two traffic-series JSONL files, the same seeds and start ticks, TRAFFIC_WHICH=both.

  python3 tests/traffic/turns_verdict.py BASE.jsonl ARM.jsonl

(1) between-squad fast pooled over the crossing cases down >= 25 % (row 56), and neither crossing case up beyond
    base + 1.645 se (rows 38 / 44);
(2) THE CROSSING CLOCK per crossing case: mean paired cross_clear_s difference <= 0.10 x base median + 1.645 se (se from
    this run's own paired sd); each squad's own crossing reported;
(3) crews >= base - 1.645 se (rows 35 / 41 / 47 / 53); no wedge (> 1 crew never in where the paired base run had none);
(4) same-squad fast <= base + 1.645 se per crossing case (rows 40 / 46);
(5) head-on cases: fast, between-squad fast and all-in median within 1.645 se of base (rows 32 / 36 / 50 / 54; a fall passes);
(6) all-in median per crossing case REPORTED with its se (rows 42 / 48), not judged.
The arm's own counters are printed (lesson 300). Prints VERDICT PASS / FAIL.

Round 31 (T3b-c, his call): `--allow yard_open/cross=3.0` replaces line (2)'s 10 % allowance for that case with his
absolute one: mean paired cross_clear_s <= +3.0 s + 1.645 se. The Terminus crossing keeps 0.10 x base median.
"""
import json
import math
import statistics
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from traffic_table import all_in_s  # noqa: E402

# CP-N's noise-sized guards at n = 18 (judging.md, stream/sizing 44a8b95a): 1.645 se of the case total.
CREWS_GUARD = {"terminus/cross": 4.07, "yard_open/cross": 4.77, "terminus/head": 6.81, "yard_open/head": 1.64}
XFAST_GUARD = {"terminus/cross": 19.1, "yard_open/cross": 12.6}
OWN_GUARD = {"terminus/cross": 43.7, "yard_open/cross": 52.6}
HEAD_FAST_GUARD = {"terminus/head": 194.4, "yard_open/head": 8.38}
HEAD_XFAST_GUARD = {"terminus/head": 116.5, "yard_open/head": 5.81}
HEAD_ALLIN_GUARD = {"terminus/head": 9.62, "yard_open/head": 3.82}
ALLIN_SE = {"terminus/cross": 7.01, "yard_open/cross": 10.2}


def load(path):
    runs = {}
    for line in open(path):
        r = json.loads(line)
        if r.get("which") != "both" or r.get("missing"):
            continue
        runs[(r["arena"] + "/" + r["kind"], r["seed"], r["start_tick"])] = r
    return runs


def clock(r, field):
    v = r.get(field, -1.0)
    return v if v >= 0 else r["end_s"]


def paired(b, a, field):
    d = [clock(ra, field) - clock(rb, field) for rb, ra in zip(b, a)]
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else 0.0
    return statistics.mean(d), se


def main(base_path, arm_path, allow=None):
    allow = allow or {}
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
        counters = {c: sum(r.get("tr_" + c, 0) for r in a) for c in ("cross_verdicts", "cross_slowed", "cross_reach_free", "verdicts", "holds")}
        g = CREWS_GUARD.get(case, 2.0)
        lines = [("crews >= base - %.2f (1.645 se)" % g, crews_a >= crews_b - g, "%d -> %d" % (crews_b, crews_a)),
                 ("no wedge", not wedges, " ".join(wedges) or "none")]
        if case.endswith("/cross"):
            cross_b += x_b
            cross_a += x_a
            lines.append(("between-squad fast <= base + %.1f" % XFAST_GUARD[case], x_a <= x_b + XFAST_GUARD[case],
                          "%d -> %d" % (x_b, x_a)))
            lines.append(("same-squad fast <= base + %.1f" % OWN_GUARD[case], f_a - x_a <= f_b - x_b + OWN_GUARD[case],
                          "%d -> %d (round 29's x1.2+10: %.0f)" % (f_b - x_b, f_a - x_a, 1.2 * (f_b - x_b) + 10)))
            clear_b = statistics.median(clock(r, "cross_clear_s") for r in b)
            diff, se = paired(b, a, "cross_clear_s")
            if case in allow:
                limit, name = allow[case] + 1.645 * se, "crossing clock <= +%.1f s + 1.645 se (his)" % allow[case]
            else:
                limit, name = 0.10 * clear_b + 1.645 * se, "crossing clock <= +10 % + 1.645 se"
            lines.append((name, diff <= limit,
                          "median %.1f -> %.1f; mean paired %+.2f s (se %.2f, limit %+.2f)" % (
                              clear_b, statistics.median(clock(r, "cross_clear_s") for r in a), diff, se, limit)))
            for squad in ("a", "b"):
                d_s, se_s = paired(b, a, "cross_%s_s" % squad)
                print("   (reported) squad %s's own crossing: median %.1f -> %.1f, mean paired %+.2f s (se %.2f)" % (
                    squad.upper(), statistics.median(clock(r, "cross_%s_s" % squad) for r in b),
                    statistics.median(clock(r, "cross_%s_s" % squad) for r in a), d_s, se_s))
            print("   (reported) all-in median %.1f -> %.1f (CP-N se %.1f s)" % (m_b, m_a, ALLIN_SE[case]))
        else:
            lines.append(("fast within 1.645 se", f_a - f_b <= HEAD_FAST_GUARD[case],
                          "%d -> %d (+%.1f)" % (f_b, f_a, HEAD_FAST_GUARD[case])))
            lines.append(("between-squad fast within 1.645 se", x_a - x_b <= HEAD_XFAST_GUARD[case],
                          "%d -> %d (+%.1f)" % (x_b, x_a, HEAD_XFAST_GUARD[case])))
            lines.append(("all-in median within 1.645 se", m_a - m_b <= HEAD_ALLIN_GUARD[case],
                          "%.1f -> %.1f (+%.2f)" % (m_b, m_a, HEAD_ALLIN_GUARD[case])))
        print("%s  n=%d  fast %d -> %d  between %d -> %d  counters %s" % (case, len(keys), f_b, f_a, x_b, x_a,
                                                                          json.dumps(counters)))
        for name, passed, detail in lines:
            ok = ok and passed
            print("   %-40s %s  %s" % (name, "pass" if passed else "FAIL", detail))
    if cross_b or cross_a:
        passed = cross_a <= 0.75 * cross_b
        ok = ok and passed
        print("crossings pooled: between-squad fast %d -> %d (%+.0f %%)  %s" % (
            cross_b, cross_a, 100.0 * (cross_a - cross_b) / max(cross_b, 1), "pass" if passed else "FAIL (needs <= -25 %)"))
    print("VERDICT " + ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--allow")]
    allows = {}
    for i, a in enumerate(sys.argv[1:]):
        if a.startswith("--allow"):
            spec = a.split("=", 1)[1] if a.startswith("--allow=") else sys.argv[i + 2]
            case, _, sec = spec.partition("=")
            allows[case] = float(sec)
            if not a.startswith("--allow="):
                args.remove(spec)
    main(args[0], args[1], allows)
