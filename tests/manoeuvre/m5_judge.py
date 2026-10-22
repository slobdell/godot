#!/usr/bin/env python3
"""Round 37 (manoeuvre M5, seatstep): Bar M5's series reader (the bar: _agents/streams/manoeuvre.md, *Bar M5*).

usage: m5_judge.py SERIES_DIR [--v2]   (m5_series.sh's folder: jam-{base,on}, hull-rest/{base,new}_drawn[, gd_drawn])

--v2 (round 38, Bar M5 v2 in _agents/streams/manoeuvre.md): kills per team are replaced by (a1) team 0's kill SHARE within
1.645 se (paired linearisation) and (a2) total deaths not up; (e) never settled is judged per task against
1.645 sqrt(max(b + c, D_floor, 1)), D_floor = runs discordant between the base arm (native) and hull-rest/gd_drawn (the same
base tree and seeds on the GDScript path).

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


def share_line(base, new):
    """(a1) team 0's kill share K0 / (K0 + K1), paired: each arm's per-pair linearised residual z = (k0 - R k) / K, se of the
    paired sum of z_on - z_base. Returns ok."""
    keys = sorted(set(base) & set(new))
    if len(keys) < 2:
        print(f"M5 (a1) kill share team 0        MISSING (pairs {len(keys)})")
        return False

    def arm(rows):
        k0 = [rows[k].get("kills_0", 0) for k in keys]
        k = [rows[x].get("kills_0", 0) + rows[x].get("kills_1", 0) for x in keys]
        total = sum(k)
        r = sum(k0) / total if total else 0.0
        return r, [(a - r * b) / total if total else 0.0 for a, b in zip(k0, k)], total
    rb, zb, kb = arm(base)
    rn, zn, kn = arm(new)
    d = [b - a for a, b in zip(zb, zn)]
    lim = 1.645 * statistics.stdev(d) * math.sqrt(len(d))
    ok = abs(rn - rb) <= lim
    print(f"M5 (a1) kill share team 0        base {rb:9.4f} new {rn:9.4f} diff {rn - rb:+9.4f} 1.645se {lim:8.4f} pairs {len(d)}  "
          f"{'PASS' if ok else 'FAIL'}  (total kills {kb} -> {kn}, REPORTED)")
    return ok


def settle_floor(b, n, g, task):
    """(e) v2 for one task: (ON - base never settled, limit, b + c, D_floor, gd - base net)."""
    keys = sorted(k for k in b if k[0] == task and k in n)
    bu, nu = sum(b[k]["unsettled"] for k in keys), sum(n[k]["unsettled"] for k in keys)
    disc = sum(1 for k in keys if b[k]["unsettled"] != n[k]["unsettled"])
    gkeys = [k for k in keys if k in g]
    floor = sum(1 for k in gkeys if b[k]["unsettled"] != g[k]["unsettled"])
    gnet = sum(g[k]["unsettled"] - b[k]["unsettled"] for k in gkeys)
    lim = 1.645 * math.sqrt(max(disc, floor, 1))
    return nu - bu, lim, disc, floor, gnet, bu, nu, len(gkeys), len(keys)


def main():
    root = Path(sys.argv[1])
    v2 = "--v2" in sys.argv[2:]
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
        if not v2:
            ok &= line(f"kills team {team}", base, new, f"kills_{team}", "within")
    if v2:
        ok &= share_line(base, new)
        for rows in (base, new):
            for r in rows.values():
                r["deaths_all"] = r.get("deaths_0", 0) + r.get("deaths_1", 0)
                r["kills_all"] = r.get("kills_0", 0) + r.get("kills_1", 0)
        ok &= line("(a2) deaths, both teams", base, new, "deaths_all", "not_up")
        line("kills, both teams", base, new, "kills_all", "report")
    hr = root / "hull-rest"
    if hr.exists():
        b, n = s1_judge.hull_rows(hr, "base_drawn"), s1_judge.hull_rows(hr, "new_drawn")
        g = s1_judge.hull_rows(hr, "gd_drawn") if v2 else {}
        if v2 and not g:
            print("M5 (e) v2: hull-rest/gd_drawn MISSING (the floor arm)  FAIL")
            ok = False
        for task in sorted({k[0] for k in b}):
            if v2:
                diff, lim, disc, floor, gnet, bu, nu, ng, nk = settle_floor(b, n, g, task)
                e_ok = diff <= lim and ng == nk
                print(f"M5 (e) never settled {task:<20} base {bu} new {nu} ({diff:+d}) <= +{lim:.1f}  "
                      f"[b+c {disc}, D_floor {floor} (gd-base net {gnet:+d}, {ng}/{nk} floor pairs)]  {'PASS' if e_ok else 'FAIL'}")
                ok &= e_ok
                keys = sorted(k for k in b if k[0] == task and k in n)
                ok &= s1_judge.paired_line(f"(f) arrived {task}", b, n, "arrived", "not_down", keys)
                continue
            keys = sorted(k for k in b if k[0] == task and k in n)
            bu, nu = sum(b[k]["unsettled"] for k in keys), sum(n[k]["unsettled"] for k in keys)
            e_ok = nu - bu <= 1.645 * 3.0
            print(f"M5 (e) never settled {task:<20} base {bu} new {nu} ({nu - bu:+d}) <= +{1.645 * 3.0:.1f}  {'PASS' if e_ok else 'FAIL'}")
            ok &= e_ok
            ok &= s1_judge.paired_line(f"(f) arrived {task}", b, n, "arrived", "not_down", keys)
    print("M5 VERDICT " + ("PASS" if ok else "FAIL (see lines)"))


if __name__ == "__main__":
    main()
