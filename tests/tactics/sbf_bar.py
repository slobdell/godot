#!/usr/bin/env python3
"""Round 31 (brains B6): the filed bar's lines from two sbf-series files, candidate (on) v control
(--sbf-told-sectors=on), same seeds. Usage: sbf_bar.py on.jsonl control.jsonl
(1) drawn arm, hull error at arrival pooled over the four wheeled classes: median on <= control - 10 deg; no class's
    median worse than control by > 2 se (se of the per-seed paired difference of run medians);
(2) crews in, drawn: on >= control - 1 per class;
(3) the clicked (facing none) rows byte-identical between arms;
(4) counter sbf_told_replaced > 0 every drawn on-run, 0 every clicked run;
guard: the tracked `tank` drawn error within 2 se of control (stated)."""
import json
import math
import statistics
import sys

WHEELED = ("law_tank", "gang_ifv", "law_ifv", "gang_tank")


def load(path):
    rows = {}
    for line in open(path):
        if line.strip():
            r = json.loads(line)
            rows[(r["unit"], r["seed"], r["facing"])] = r
    return rows


def run_median(r):
    errs = list(r["err_in_deg"].values())
    return statistics.median(errs) if errs else None


def main(on_path, off_path):
    on, off = load(on_path), load(off_path)
    missing = [k for k in set(on) | set(off) if on.get(k, {}).get("missing") or off.get(k, {}).get("missing") or k not in on or k not in off]
    ok = True
    pooled_on = [e for (u, s, f), r in on.items() if u in WHEELED and f == "drawn" for e in r["err_in_deg"].values()]
    pooled_off = [e for (u, s, f), r in off.items() if u in WHEELED and f == "drawn" for e in r["err_in_deg"].values()]
    m_on, m_off = statistics.median(pooled_on), statistics.median(pooled_off)
    line1 = m_on <= m_off - 10.0
    ok &= line1
    print(f"(1) pooled drawn hull error at in, four wheeled: on {m_on:.1f} v control {m_off:.1f} deg "
          f"(n crews {len(pooled_on)} v {len(pooled_off)}): need <= {m_off - 10:.1f}: {'PASS' if line1 else 'FAIL'}")
    for unit in sorted({k[0] for k in on}):
        seeds = sorted({k[1] for k in on if k[0] == unit})
        diffs = []
        for s in seeds:
            a, b = on.get((unit, s, "drawn")), off.get((unit, s, "drawn"))
            if a and b and run_median(a) is not None and run_median(b) is not None:
                diffs.append(run_median(a) - run_median(b))
        errs_on = [e for s in seeds for e in on[(unit, s, "drawn")]["err_in_deg"].values()]
        errs_off = [e for s in seeds for e in off[(unit, s, "drawn")]["err_in_deg"].values()]
        se = statistics.stdev(diffs) / math.sqrt(len(diffs)) if len(diffs) > 1 else float("nan")
        med_on = statistics.median(errs_on) if errs_on else float("nan")
        med_off = statistics.median(errs_off) if errs_off else float("nan")
        worse = med_on - med_off > 2 * se
        crews_on = sum(on[(unit, s, "drawn")]["crews_in"] for s in seeds)
        crews_off = sum(off[(unit, s, "drawn")]["crews_in"] for s in seeds)
        crews_all = sum(on[(unit, s, "drawn")]["crews"] for s in seeds)
        line2 = crews_on >= crews_off - 1
        tag = "guard (tracked, stated)" if unit not in WHEELED else ""
        if unit in WHEELED:
            ok &= (not worse) and line2
        print(f"    {unit:10s} drawn median {med_on:5.1f} v {med_off:5.1f} deg, paired run-median diff mean "
              f"{statistics.mean(diffs) if diffs else float('nan'):+.1f} se {se:.1f} (n {len(diffs)}): "
              f"{'WORSE > 2 se' if worse else 'ok'} | (2) crews in {crews_on} v {crews_off} of {crews_all}: "
              f"{'PASS' if line2 else 'FAIL'} {tag}")
    clicked = [k for k in on if k[2] == "none"]
    def strip(r):
        return {k: v for k, v in r.items() if k != "sbf_told_replaced"}
    same = [k for k in clicked if k in off and strip(on[k]) == strip(off[k])]
    line3 = len(same) == len(clicked)
    ok &= line3
    print(f"(3) clicked rows identical between arms: {len(same)}/{len(clicked)}: {'PASS' if line3 else 'FAIL'} "
          f"{sorted(set(clicked) - set(same))[:6]}")
    drawn_on = [r for k, r in on.items() if k[2] == "drawn"]
    fired = sum(1 for r in drawn_on if int(r.get("sbf_told_replaced", 0)) > 0)
    clicked_fired = sum(1 for k in clicked if int(on[k].get("sbf_told_replaced", 0)) > 0)
    off_fired = sum(1 for r in off.values() if int(r.get("sbf_told_replaced", 0)) > 0)
    line4 = fired == len(drawn_on) and clicked_fired == 0 and off_fired == 0
    ok &= line4
    print(f"(4) counter: drawn on-runs fired {fired}/{len(drawn_on)}, clicked on-runs {clicked_fired}, control runs "
          f"{off_fired}: {'PASS' if line4 else 'FAIL'}")
    if missing:
        print(f"MISSING {missing}")
        ok = False
    print("SBF BAR (lines 1-4): " + ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
