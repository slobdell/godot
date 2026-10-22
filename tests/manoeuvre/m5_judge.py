#!/usr/bin/env python3
"""Round 37 (manoeuvre M5, seatstep): Bar M5's series reader (the bar: _agents/streams/manoeuvre.md, *Bar M5*).

usage: m5_judge.py SERIES_DIR      (m5_series.sh's folder: jam-{base,on}, hull-rest/{base,new}_drawn)

Paired by (arena, seed) over the jam census's JAM_CENSUS rows:
  (0) counter first: route_arms.yields_seated > 0 in ON (the rule chose); yields_leadout_avoided REPORTED
  DECIDING: seat metres (seat_episodes.seat_m: the farthest from the seat + the path back, per seated give-way) ON < base by
            more than 1.645 se of the paired sum
  guards, not worse than base + 1.645 se: the asker's wait (seat_episodes.yield_ticks; timeouts), friendly contacts, deaths per
            team, jam deaths; kills per team within
  REPORTED: seated give-ways, lead-out picks, back within 15 s
  hull-rest (all-in): (e) never settled, (f) squads arrived, as s1_judge."""
import json
import math
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from w1b_judge import tagged  # noqa: E402
import s1_judge  # noqa: E402


def jam_rows(directory):
    out = {}
    for _, r in tagged(directory, "JAM_CENSUS"):
        se = r.get("seat_episodes", {})
        arms = r.get("route_arms", {})
        row = {"seat_m": float(se.get("seat_m", 0.0)), "episodes": int(se.get("episodes", 0)), "leadout": int(se.get("leadout", 0)),
               "back": int(se.get("back", 0)), "wait": int(se.get("yield_ticks", 0)), "timeouts": int(se.get("timeouts", 0)),
               "contacts": int(r.get("friendly_contacts", 0)), "seated": int(arms.get("yields_seated", 0)),
               "avoided": int(arms.get("yields_leadout_avoided", 0)),
               "jam_deaths": sum(int(v) for k, v in r.get("by_cause", {}).items() if k.startswith("jam:"))}
        for team, t in r.get("teams", {}).items():
            for k in ("kills", "deaths"):
                row[f"{k}_{team}"] = int(t.get(k, 0))
        out[(r["arena"], r["seed"])] = row
    return out


def line(name, base, new, field, rule):
    keys = sorted(set(base) & set(new))
    d = [new[k].get(field, 0) - base[k].get(field, 0) for k in keys]
    if len(d) < 2:
        print(f"M5 {name:<28} MISSING (pairs {len(d)})")
        return False
    total, se = sum(d), statistics.stdev(d) * math.sqrt(len(d))
    lim = 1.645 * se
    ok = {"not_up": total <= lim, "within": abs(total) <= lim, "down": total < -lim}.get(rule)
    b, n = sum(base[k].get(field, 0) for k in keys), sum(new[k].get(field, 0) for k in keys)
    print(f"M5 {name:<28} base {b:>9.1f} new {n:>9.1f} diff {total:+9.1f} 1.645se {lim:8.1f} pairs {len(d)}  "
          f"{'REPORTED' if ok is None else ('PASS' if ok else 'FAIL')}")
    return ok is not False


def main():
    root = Path(sys.argv[1])
    base, new = jam_rows(root / "jam-base"), jam_rows(root / "jam-on")
    seated = sum(r["seated"] for r in new.values())
    print(f"M5 (0) counter first: yields_seated ON {seated} (lead-outs avoided {sum(r['avoided'] for r in new.values())})  "
          f"{'PASS' if seated > 0 else 'FAIL'}")
    ok = seated > 0
    ok &= line("DECIDING seat metres", base, new, "seat_m", "down")
    for f in ("episodes", "leadout", "back"):
        line(f"seated give-ways: {f}", base, new, f, "report")
    ok &= line("asker's wait (ticks)", base, new, "wait", "not_up")
    ok &= line("give-way timeouts", base, new, "timeouts", "not_up")
    ok &= line("friendly contacts", base, new, "contacts", "not_up")
    ok &= line("jam deaths", base, new, "jam_deaths", "not_up")
    for team in ("0", "1"):
        ok &= line(f"deaths team {team}", base, new, f"deaths_{team}", "not_up")
        ok &= line(f"kills team {team}", base, new, f"kills_{team}", "within")
    hr = root / "hull-rest"
    if hr.exists():
        b, n = s1_judge.hull_rows(hr, "base_drawn"), s1_judge.hull_rows(hr, "new_drawn")
        for task in sorted({k[0] for k in b}):
            keys = sorted(k for k in b if k[0] == task and k in n)
            bu, nu = sum(b[k]["unsettled"] for k in keys), sum(n[k]["unsettled"] for k in keys)
            e_ok = nu - bu <= 1.645 * 3.0
            print(f"M5 (e) never settled {task:<20} base {bu} new {nu} ({nu - bu:+d}) <= +{1.645 * 3.0:.1f}  {'PASS' if e_ok else 'FAIL'}")
            ok &= e_ok
            ok &= s1_judge.paired_line(f"(f) arrived {task}", b, n, "arrived", "not_down", keys)
    print("M5 VERDICT " + ("PASS" if ok else "FAIL (see lines)"))


if __name__ == "__main__":
    main()
