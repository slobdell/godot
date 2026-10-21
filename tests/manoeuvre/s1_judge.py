#!/usr/bin/env python3
"""Round 36 (manoeuvre S1, stallnet): Bar S1's series reader (the bar: _agents/streams/manoeuvre.md, *Bar S1*).

usage: s1_judge.py SERIES_DIR [--bar s2a]   (s1_series.sh's folder: wedge-{base,on}, fights-{base,on}, jam-{base,on},
                                             hull-rest/{base,new}_drawn)

--bar s2a: Bar S2a's series (h1bside + yieldgap ON v both OFF): the same guards; (0) is REPORTED (the bar files no counter-first
line, and stall_net_holds is not S2a's); far bank 0 holds on hull-rest by construction (foundry has no river deck); plus the
player line REPORTED: left_behind.py on each hull-rest arm (crews > 25 m behind, by net motion).

Lines (the deciding line is the lab stage, test_manoeuvre_stall_net, read from the gate check; this reads the series):
  (0) counter first: stall_net_holds > 0 in ON (WEDGE_TRACE / FIGHT_CENSUS; the base's printed beside)
  guards, each within 1.645 se of base (paired by arena x seed, or task x faction x seed):
    (d) movers at the judge BY NET MOTION (mover_kind: closing + wander; never real_mps alone), every task, not up
    (e) never settled, every task, not up by more than 1.645 x 3.0 (the joint bar's line)
    (f) squads arrived (screen.json), not down
    (i) kills and hit rate per team, within; deaths per team, not up
    (q) open / stuck / jam deaths, within
    (r) far loops, not up    (s) friendly contact ticks, not up    give-ways started, not up
    unstick fires (live crews at the wedge trace's end), not up
  REPORTED: rocking_census crews ON v base (the X1(d) count), all deaths, asks.
"""
import json
import math
import os
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import joint_judge as jj  # noqa: E402
BAR = sys.argv[sys.argv.index("--bar") + 1].upper() if "--bar" in sys.argv else "S1"
import mover_kind as mk  # noqa: E402
from w1b_judge import fight_rows, tagged  # noqa: E402


def counters(directory, tag, key):
    return sum(int(r.get(key, 0) or 0) for _, r in tagged(directory, tag))


def wedge_extra(directory):
    return {(r["arena"], r["seed"]): {"unstick": int(r.get("unstick_fires", 0))} for _, r in tagged(directory, "WEDGE_TRACE")}


def hull_rows(root, arm):
    """(task, faction, seed) -> {movers by net motion, never settled, squads arrived}."""
    out = {}
    for path in Path(root, arm).glob("*/*/screen.json"):
        faction, case = path.parts[-3], path.parts[-2]
        task, seed = case.rsplit("-", 1)
        rows = [r for r in json.loads(path.read_text()) if "squads" in r]
        if not rows:
            continue
        row = rows[0]
        tr = mk.tracks(str(path.parent / "run.log"))
        moving = 0
        for squad in row["squads"]:
            for crew in squad.get("each", []):
                if float(crew.get("real_mps", 0.0)) < mk.e1_bar.MOVER_MPS:
                    continue
                k, _net, _goal = mk.kind(tr.get(crew["unit"], [(0, "", 0, 0, 0, 0)]))
                moving += k in ("closing", "wander")
        settled = row.get("settled_after_s")
        out[(task, faction, seed)] = {"movers": moving, "unsettled": 1 if settled is None or float(settled) < 0 else 0,
                                      "arrived": sum(1 for s in row["squads"] if s.get("arrived"))}
    return out


def paired_line(name, base, new, field, rule, keys=None):
    keys = sorted(set(base) & set(new)) if keys is None else keys
    d = [new[k][field] - base[k][field] for k in keys]
    if len(d) < 2:
        print(f"{BAR} {name:<30} MISSING (pairs {len(d)})")
        return False
    total = sum(d)
    se = statistics.stdev(d) * math.sqrt(len(d))
    lim = 1.645 * se
    ok = {"not_up": total <= lim, "not_down": total >= -lim, "within": abs(total) <= lim}.get(rule)
    print(f"{BAR} {name:<30} base {sum(base[k][field] for k in keys):>8} new {sum(new[k][field] for k in keys):>8} diff {total:+8} "
          f"1.645se {lim:7.1f} pairs {len(d)}  {'REPORTED' if ok is None else ('PASS' if ok else 'FAIL')}")
    return ok is not False


def main():
    root = Path(sys.argv[1])
    ok = True
    holds_on = counters(root / "wedge-on", "WEDGE_TRACE", "stall_net_holds") + counters(root / "fights-on", "FIGHT_CENSUS", "stall_net_holds")
    holds_base = counters(root / "wedge-base", "WEDGE_TRACE", "stall_net_holds") + counters(root / "fights-base", "FIGHT_CENSUS", "stall_net_holds")
    first = "REPORTED" if BAR != "S1" else ("PASS" if holds_on > 0 else "FAIL")
    print(f"{BAR} (0) counter first: stall_net_holds ON {holds_on} (base, counted the same way: {holds_base})  {first}")
    ok &= holds_on > 0 or BAR != "S1"
    bw, nw = jj.wedge_rows(root / "wedge-base"), jj.wedge_rows(root / "wedge-on")
    for f in ("open", "stuck", "jam"):
        ok &= paired_line(f"(q) {f} deaths", bw, nw, f, "within")
    paired_line("all deaths", bw, nw, "deaths", "report")
    ok &= paired_line("(s) friendly contacts", bw, nw, "contacts", "not_up")
    ok &= paired_line("give-ways started", bw, nw, "yields", "not_up")
    paired_line("asks", bw, nw, "asks", "report")
    ok &= paired_line("unstick fires", wedge_extra(root / "wedge-base"), wedge_extra(root / "wedge-on"), "unstick", "not_up")
    bf, nf = fight_rows(root / "fights-base"), fight_rows(root / "fights-on")
    ok &= paired_line("(r) far loops", bf, nf, "far", "not_up")
    for team in ("0", "1"):
        ok &= paired_line(f"deaths team {team}", bf, nf, f"deaths_{team}", "not_up")
        ok &= paired_line(f"(i) kills team {team}", bf, nf, f"kills_{team}", "within")
        keys = sorted(set(bf) & set(nf))
        d = [nf[k][f"hits_{team}"] / nf[k][f"shots_{team}"] - bf[k][f"hits_{team}"] / bf[k][f"shots_{team}"]
             for k in keys if bf[k].get(f"shots_{team}") and nf[k].get(f"shots_{team}")]
        if len(d) < 2:
            print(f"{BAR} (i) hit rate team {team}: MISSING")
            ok = False
            continue
        se = statistics.stdev(d) / math.sqrt(len(d))
        hit_ok = abs(statistics.mean(d)) <= 1.645 * se
        print(f"{BAR} (i) hit rate team {team:<15} mean diff {statistics.mean(d):+.4f} 1.645se {1.645 * se:.4f} pairs {len(d)}  "
              f"{'PASS' if hit_ok else 'FAIL'}")
        ok &= hit_ok
    hr = root / "hull-rest"
    if hr.exists():
        base, new = hull_rows(hr, "base_drawn"), hull_rows(hr, "new_drawn")
        for task in sorted({k[0] for k in base}):
            keys = sorted(k for k in base if k[0] == task and k in new)
            ok &= paired_line(f"(d) movers net {task}", base, new, "movers", "not_up", keys)
            bu, nu = sum(base[k]["unsettled"] for k in keys), sum(new[k]["unsettled"] for k in keys)
            e_ok = nu - bu <= 1.645 * 3.0
            print(f"{BAR} (e) never settled {task:<20} base {bu} new {nu} ({nu - bu:+d}) <= +{1.645 * 3.0:.1f}  {'PASS' if e_ok else 'FAIL'}")
            ok &= e_ok
            ok &= paired_line(f"(f) arrived {task}", base, new, "arrived", "not_down", keys)
        for arm in ("base_drawn", "new_drawn"):
            out = subprocess.run([sys.executable, str(HERE / "rocking_census.py"), str(hr / arm)], capture_output=True, text=True)
            first = (out.stdout.splitlines() or ["(no output)"])[0]
            print(f"{BAR} rocking_census {arm}: {first}  REPORTED")
            if BAR == "S2A":
                out = subprocess.run([sys.executable, str(HERE / "left_behind.py"), str(hr / arm), "--list", "0"],
                                     capture_output=True, text=True)
                print(f"{BAR} player line {arm}: " + " / ".join(out.stdout.splitlines()[:2]) + "  REPORTED")
    print(BAR + " VERDICT (series guards) " + ("PASS" if ok else "FAIL (see lines)"))


if __name__ == "__main__":
    main()
