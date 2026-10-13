"""Round 29 (traffic T1, CP-T): the street hold's pre-registered bar, read from a judged base arm and a judged hold arm
(two traffic-series JSONL files, the same seeds and start ticks, TRAFFIC_WHICH=both).

  python3 tests/traffic/hold_verdict.py BASE.jsonl HOLD.jsonl [--only=terminus/head]

His case (terminus/head): crews in >= base - 2; contacts_cross_fast down >= 25 %; all-in median <= base + 20 %; no
wedge (no run with > 1 crew never in whose paired base run had none). Every other case: fast contacts and the all-in
median within 2 se of base (paired per run; a fall always passes), crews >= base - 2. The arm's own counters are
printed (lesson 300). Prints one line per case and VERDICT PASS / FAIL.
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


def se_total(diffs):
    return math.sqrt(len(diffs)) * statistics.stdev(diffs) if len(diffs) > 1 else 0.0


def main(base_path, hold_path, only=None):
    base, hold = load(base_path), load(hold_path)
    cases = sorted({k[0] for k in hold})
    ok = True
    for case in cases:
        if only and case != only:
            continue
        keys = sorted(k for k in hold if k[0] == case and k in base)
        b = [base[k] for k in keys]
        h = [hold[k] for k in keys]
        crews_b, crews_h = sum(r["arrived"] for r in b), sum(r["arrived"] for r in h)
        x_b, x_h = sum(r["contacts_cross_fast"] for r in b), sum(r["contacts_cross_fast"] for r in h)
        f_b, f_h = sum(r["contacts_fast"] for r in b), sum(r["contacts_fast"] for r in h)
        a_b = statistics.median(all_in_s(r) for r in b)
        a_h = statistics.median(all_in_s(r) for r in h)
        counters = {c: sum(r.get("tr_" + c, 0) for r in h) for c in ("verdicts", "holds", "hold_ticks", "released_passed",
                                                                      "released_cap", "no_spot")}
        wedges = ["s%s/t%s" % (k[1], k[2]) for k in keys
                  if hold[k]["crews"] - hold[k]["arrived"] > 1 and base[k]["crews"] - base[k]["arrived"] == 0]
        lines = []
        if case == "terminus/head":
            lines.append(("crews >= base - 2", crews_h >= crews_b - 2, "%d -> %d" % (crews_b, crews_h)))
            lines.append(("between-squad fast down >= 25 %", x_h <= 0.75 * x_b,
                          "%d -> %d (%+.0f %%)" % (x_b, x_h, 100.0 * (x_h - x_b) / max(x_b, 1))))
            lines.append(("all-in median <= +20 %", a_h <= 1.2 * a_b, "%.1f -> %.1f (%+.1f %%)" % (a_b, a_h, 100.0 * (a_h - a_b) / a_b)))
            lines.append(("no wedge", not wedges, " ".join(wedges) or "none"))
            lines.append(("the rule fired", counters["verdicts"] > 0 and counters["hold_ticks"] > 0, ""))
        else:
            fd = [hr["contacts_fast"] - br["contacts_fast"] for br, hr in zip(b, h)]
            ad = [all_in_s(hr) - all_in_s(br) for br, hr in zip(b, h)]
            fse, ase = se_total(fd), (statistics.stdev(ad) / math.sqrt(len(ad)) * 1.2533 if len(ad) > 1 else 0.0)
            lines.append(("crews >= base - 2", crews_h >= crews_b - 2, "%d -> %d" % (crews_b, crews_h)))
            lines.append(("fast within 2 se", f_h - f_b <= 2.0 * fse, "%d -> %d (2 se %.1f)" % (f_b, f_h, 2.0 * fse)))
            lines.append(("all-in median within 2 se", a_h - a_b <= 2.0 * ase, "%.1f -> %.1f (2 se %.1f)" % (a_b, a_h, 2.0 * ase)))
        print("%s  n=%d  fast %d -> %d  xfast %d -> %d  counters %s" % (case, len(keys), f_b, f_h, x_b, x_h, json.dumps(counters)))
        for name, passed, detail in lines:
            ok = ok and passed
            print("   %-34s %s  %s" % (name, "pass" if passed else "FAIL", detail))
    print("VERDICT " + ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--only=")]
    only = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")), None)
    main(args[0], args[1], only)
