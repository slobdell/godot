#!/usr/bin/env python3
"""Round 35 (manoeuvre W1b): the bar's reader. Two arms, each a wedge-probe dir (WEDGE_TRACE / WEDGE_DEATH rows,
tests/manoeuvre/wedge_trace.gd) and a fights dir (FIGHT_CENSUS + H1B_FAR rows, tests/manoeuvre/fight_census.gd), paired by
(arena, seed).

usage: w1b_judge.py BASE_WEDGE_DIR NEW_WEDGE_DIR BASE_FIGHTS_DIR NEW_FIGHTS_DIR

Lines (W1b's bar, workstreams.md Round 35): counter first (wheel_halts > 0 in NEW, halt_creep_ticks non-zero in BASE);
deciding: halt_creep_ticks -> ~0, wedged + held deaths not up beyond 1.645 se; guards: open, stuck, jam deaths, far loops,
kills and hit rate per team, each within 1.645 se paired; all deaths reported.
"""
import json
import math
import statistics
import sys
from pathlib import Path


def tagged(directory, tag):
    out = []
    for log in sorted(Path(directory).glob("*.log")):
        for line in log.read_text(errors="replace").splitlines():
            if line.startswith(tag + " "):
                out.append((log.stem, json.loads(line[len(tag) + 1:])))
    return out


def wedge_rows(directory):
    rows = {}
    held = {}
    for stem, r in tagged(directory, "WEDGE_DEATH"):
        key = (r["arena"], r["seed"])
        held[key] = held.get(key, 0) + (1 if r["timeline"] and r["timeline"][-1].get("held") else 0)
    for stem, r in tagged(directory, "WEDGE_TRACE"):
        key = (r["arena"], r["seed"])
        t = r["totals"]
        causes = t.get("by_cause", {})
        rows[key] = {
            "deaths": t.get("deaths", 0),
            "wedged": causes.get("stuck:wedged", 0),
            "held_wedged": held.get(key, 0),
            "open": sum(v for k, v in causes.items() if k.startswith("open:")),
            "stuck": sum(v for k, v in causes.items() if k.startswith("stuck:")),
            "jam": sum(v for k, v in causes.items() if k.startswith("jam:")),
            "halt_ticks": t.get("halt_ticks", 0),
            "halt_creep_ticks": t.get("halt_creep_ticks", 0),
            "wheel_halts": r.get("wheel_halts", 0),
            "wheel_halt_on": r.get("wheel_halt_on"),
        }
    return rows


def fight_rows(directory):
    rows = {}
    far = {}
    for stem, r in tagged(directory, "H1B_FAR"):
        far[stem] = far.get(stem, 0) + 1
    for stem, r in tagged(directory, "FIGHT_CENSUS"):
        key = (r["arena"], r["seed"])
        row = {"far": far.get(stem, 0)}
        for team, t in r["teams"].items():
            for k in ("kills", "deaths", "shots", "hits"):
                row[f"{k}_{team}"] = int(t.get(k, 0))
        rows[key] = row
    return rows


def paired(base, new, field):
    keys = sorted(set(base) & set(new))
    d = [new[k].get(field, 0) - base[k].get(field, 0) for k in keys]
    se = statistics.stdev(d) * math.sqrt(len(d)) if len(d) > 1 else float("nan")
    return sum(base[k].get(field, 0) for k in keys), sum(new[k].get(field, 0) for k in keys), sum(d), se, len(keys)


def line(name, base, new, field, rule):
    b, n, diff, se, pairs = paired(base, new, field)
    lim = 1.645 * se
    if rule == "not_up":
        ok = diff <= lim
    elif rule == "within":
        ok = abs(diff) <= lim
    else:
        ok = None
    verdict = "REPORTED" if ok is None else ("PASS" if ok else "FAIL")
    print(f"W1B {name:<22} base {b:>7} new {n:>7} diff {diff:+7} 1.645se {lim:6.1f} pairs {pairs}  {verdict}")
    return ok


def main():
    bw, nw, bf, nf = (wedge_rows(sys.argv[1]), wedge_rows(sys.argv[2]), fight_rows(sys.argv[3]), fight_rows(sys.argv[4]))
    ok = True
    halts = sum(r["wheel_halts"] for r in nw.values())
    base_creep = sum(r["halt_creep_ticks"] for r in bw.values())
    print(f"W1B counter first: wheel_halts NEW {halts} (> 0: {'PASS' if halts > 0 else 'FAIL'}); "
          f"halt_creep_ticks BASE {base_creep} (non-zero: {'PASS' if base_creep > 0 else 'FAIL'}); "
          f"switch base {sorted({str(r['wheel_halt_on']) for r in bw.values()})} new {sorted({str(r['wheel_halt_on']) for r in nw.values()})}")
    ok &= halts > 0 and base_creep > 0
    nc = sum(r["halt_creep_ticks"] for r in nw.values())
    nt = sum(r["halt_ticks"] for r in nw.values())
    bt = sum(r["halt_ticks"] for r in bw.values())
    print(f"W1B deciding creep: base {base_creep}/{bt} ({100 * base_creep / max(bt, 1):.0f} %) new {nc}/{nt} ({100 * nc / max(nt, 1):.0f} %)")
    for k in nw:
        nw[k]["wedged_held"] = nw[k]["wedged"]
    for k in bw:
        bw[k]["wedged_held"] = bw[k]["wedged"]
    ok &= line("wedged+held deaths", bw, nw, "wedged_held", "not_up") is not False
    line("held wedged deaths", bw, nw, "held_wedged", "report")
    for f in ("open", "stuck", "jam"):
        ok &= line(f + " deaths", bw, nw, f, "within") is not False
    line("all deaths", bw, nw, "deaths", "report")
    ok &= line("far loops", bf, nf, "far", "not_up") is not False
    for team in ("0", "1"):
        ok &= line(f"kills team {team}", bf, nf, f"kills_{team}", "within") is not False
        keys = sorted(set(bf) & set(nf))
        rb = [bf[k][f"hits_{team}"] / bf[k][f"shots_{team}"] for k in keys if bf[k].get(f"shots_{team}") and nf[k].get(f"shots_{team}")]
        rn = [nf[k][f"hits_{team}"] / nf[k][f"shots_{team}"] for k in keys if bf[k].get(f"shots_{team}") and nf[k].get(f"shots_{team}")]
        d = [a - b for a, b in zip(rn, rb)]
        if len(d) < 2:
            print(f"W1B hit rate team {team}: MISSING (pairs {len(d)})")
            ok = False
            continue
        se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("nan")
        mean = statistics.mean(d) if d else float("nan")
        hit_ok = abs(mean) <= 1.645 * se
        print(f"W1B hit rate team {team:<12} base {statistics.mean(rb):.4f} new {statistics.mean(rn):.4f} mean diff {mean:+.4f} "
              f"1.645se {1.645 * se:.4f} pairs {len(d)}  {'PASS' if hit_ok else 'FAIL'}")
        ok &= hit_ok
    print("W1B VERDICT " + ("PASS" if ok else "FAIL (see lines)"))


if __name__ == "__main__":
    main()
