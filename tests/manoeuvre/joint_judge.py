#!/usr/bin/env python3
"""Round 35 (manoeuvre W1c + traffic T9, the joint M6/T9 bar): the series reader.

usage: joint_judge.py SERIES_DIR   (the driver's folder: wedge-{base,on}, fights-{base,on}, jam-{base,on}, hull-rest/{base,new}_drawn)

Lines read here (the jam guards are traffic's tests/traffic/jam_ab.py over jam-base / jam-on, run beside this):
  (0) counters first in the ON arm: stall_intent_ticks, H1 hull escapes, asks (wedge probe totals), yields_unfinished (jam
      census route_arms) -- each > 0
  (d) attack-move crews moving at the judge by real_mps (hull-rest, paired by faction x seed): new <= base - 1.645 x 1.17 x sqrt(pairs);
      every other task: new <= base + 1.645 x sd_run x sqrt(pairs) (Bar M3's A/A sd_run per task)
  (e) attack-move never settled: new <= base; every task <= base + 1.645 x 3.0
  (f) arrivals (crews within ARRIVED_M) not down beyond 1.645 se -- REPORTED from hull_rest_ab here
  (i) kills and hit rate per team within 1.645 se (fight census)
  (q) open / stuck / jam deaths within 1.645 se (wedge probe causes)
  (r) far loops <= base + 1.645 se   (s) friendly contact ticks <= base + 1.645 se   (yields) give-ways started <= base + 1.645 se
  (t) asks REPORTED
"""
import json
import math
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from w1b_judge import fight_rows, paired, tagged  # noqa: E402

SD_RUN = {"faced_attack_move": 1.17, "faced_right": 0.64, "faced_move": 0.51, "faced_screen": 0.41, "faced_ambush": 0.24,
          "faced_support_by_fire": 0.23}


def wedge_rows(directory):
    rows = {}
    for _, r in tagged(directory, "WEDGE_TRACE"):
        t = r["totals"]
        c = t.get("by_cause", {})
        rows[(r["arena"], r["seed"])] = {
            "open": sum(v for k, v in c.items() if k.startswith("open:")),
            "stuck": sum(v for k, v in c.items() if k.startswith("stuck:")),
            "jam": sum(v for k, v in c.items() if k.startswith("jam:")),
            "deaths": t.get("deaths", 0), "contacts": t.get("friendly_contact_ticks", 0),
            "yields": r.get("yields_started", 0), "asks": r.get("esc_asks", 0),
            "stall_intent": r.get("stall_intent_ticks", 0), "esc_hull": r.get("esc_fires_hull", 0)}
    return rows


def unfinished(directory, key="yields_unfinished"):
    n = 0
    for _, r in tagged(directory, "JAM_CENSUS"):
        n += int((r.get("route_arms") or {}).get(key, 0))
    return n


def hull_cells(root, arm):
    """(task, faction, seed) -> [moving crews by real_mps (wedged apart), never settled 0/1, arrived crews]."""
    out = {}
    for path in Path(root, arm).glob("*/*/screen.json"):
        faction, case = path.parts[-3], path.parts[-2]
        seed = case.rsplit("-", 1)[-1]
        for row in json.loads(path.read_text()):
            if "squads" not in row:
                continue
            moving = 0
            for squad in row["squads"]:
                for crew in squad.get("each", []):
                    if float(crew.get("real_mps", 0.0)) >= 0.3:
                        moving += 1
            settled = row.get("settled_after_s")
            out[(row["scenario"], faction, seed)] = [moving, 1 if settled is None or float(settled) < 0 else 0]
    return out


def far_off(root, arm):
    """(task, faction, seed) -> crews whose last MANOEUVRE_STATE before the judge (`SCREEN {`) holds a live move_to and stands
    more than FAR_M from its goal (the joint bar's second deciding line). Needs the arm run with --turn-states."""
    out = {}
    for log in Path(root, arm).glob("*/*/run.log"):
        faction, case = log.parts[-3], log.parts[-2]
        task, seed = case.rsplit("-", 1)
        last = {}
        for text in log.read_text(errors="replace").splitlines():
            if text.startswith("SCREEN {"):
                break
            if text.startswith("MANOEUVRE_STATE "):
                w = text.split()
                last[w[3]] = w
        n = 0
        for w in last.values():
            try:
                order = w[w.index("order") + 1]
                at = w.index("at")
                to = w.index("to")
                ax, az, tx, tz = float(w[at + 1]), float(w[at + 2]), float(w[to + 1]), float(w[to + 2])
            except (ValueError, IndexError):
                continue
            if order == "move_to" and math.isfinite(tx) and math.hypot(ax - tx, az - tz) > FAR_M:
                n += 1
        out[(task, faction, seed)] = {"far": n}
    return out


FAR_M = 25.0


def line(name, base, new, field, rule):
    b, n, d, se, pairs = paired(base, new, field)
    lim = 1.645 * se
    ok = {"not_up": d <= lim, "within": abs(d) <= lim}.get(rule)
    print(f"JOINT {name:<24} base {b:>8} new {n:>8} diff {d:+8} 1.645se {lim:7.1f} pairs {pairs}  "
          f"{'REPORTED' if ok is None else ('PASS' if ok else 'FAIL')}")
    return ok is not False


def main():
    root = Path(sys.argv[1])
    ok = True
    bw, nw = wedge_rows(root / "wedge-base"), wedge_rows(root / "wedge-on")
    si, eh, ak = (sum(r[k] for r in nw.values()) for k in ("stall_intent", "esc_hull", "asks"))
    yu = unfinished(root / "jam-on")
    c0 = si > 0 and eh > 0 and ak > 0 and yu > 0
    print(f"JOINT (0) counters ON: stall_intent_ticks {si}, H1 hull escapes {eh}, asks {ak}, yields_unfinished {yu}  "
          f"{'PASS' if c0 else 'FAIL'}  (base: stall_intent {sum(r['stall_intent'] for r in bw.values())}, "
          f"yields_unfinished {unfinished(root / 'jam-base')})")
    ok &= c0
    for f in ("open", "stuck", "jam"):
        ok &= line(f"(q) {f} deaths", bw, nw, f, "within")
    line("all deaths", bw, nw, "deaths", "report")
    ok &= line("(s) friendly contacts", bw, nw, "contacts", "not_up")
    ok &= line("(yields) give-ways started", bw, nw, "yields", "not_up")
    line("(t) asks", bw, nw, "asks", "report")
    print(f"JOINT retries capped (yields_unfinished_capped) base {unfinished(root / 'jam-base', 'yields_unfinished_capped')} "
          f"new {unfinished(root / 'jam-on', 'yields_unfinished_capped')}  REPORTED")
    bf, nf = fight_rows(root / "fights-base"), fight_rows(root / "fights-on")
    ok &= line("(r) far loops", bf, nf, "far", "not_up")
    for team in ("0", "1"):
        ok &= line(f"deaths team {team}", bf, nf, f"deaths_{team}", "not_up")
        ok &= line(f"(i) kills team {team}", bf, nf, f"kills_{team}", "within")
        keys = sorted(set(bf) & set(nf))
        d = [nf[k][f"hits_{team}"] / nf[k][f"shots_{team}"] - bf[k][f"hits_{team}"] / bf[k][f"shots_{team}"]
             for k in keys if bf[k].get(f"shots_{team}") and nf[k].get(f"shots_{team}")]
        if len(d) < 2:
            print(f"JOINT (i) hit rate team {team}: MISSING")
            ok = False
            continue
        se = statistics.stdev(d) / math.sqrt(len(d))
        hit_ok = abs(statistics.mean(d)) <= 1.645 * se
        print(f"JOINT (i) hit rate team {team:<9} mean diff {statistics.mean(d):+.4f} 1.645se {1.645 * se:.4f} pairs {len(d)}  "
              f"{'PASS' if hit_ok else 'FAIL'}")
        ok &= hit_ok
    hr = root / "hull-rest"
    if hr.exists():
        base, new = hull_cells(hr, "base_drawn"), hull_cells(hr, "new_drawn")
        for task in sorted({k[0] for k in base}):
            keys = sorted(k for k in base if k[0] == task and k in new)
            dm = sum(new[k][0] - base[k][0] for k in keys)
            de = sum(new[k][1] - base[k][1] for k in keys)
            n = len(keys)
            g = 1.645 * SD_RUN.get(task, 1.0) * math.sqrt(n)
            if task == "faced_attack_move":
                d_ok = dm <= -g
                e_ok = de <= 0
                rule_d, rule_e = f"<= -{g:.1f} (deciding)", "<= 0 (deciding)"
            else:
                d_ok = dm <= g
                e_ok = de <= 1.645 * 3.0
                rule_d, rule_e = f"<= +{g:.1f}", f"<= +{1.645 * 3.0:.1f}"
            print(f"JOINT (d) {task:<22} movers {sum(base[k][0] for k in keys)} -> {sum(new[k][0] for k in keys)} ({dm:+d}) {rule_d}  "
                  f"{'PASS' if d_ok else 'FAIL'} | (e) never settled {sum(base[k][1] for k in keys)} -> {sum(new[k][1] for k in keys)} "
                  f"({de:+d}) {rule_e}  {'PASS' if e_ok else 'FAIL'}  pairs {n}")
            ok &= d_ok and e_ok
        fb, fn = far_off(hr, "base_drawn"), far_off(hr, "new_drawn")
        keys = sorted(set(fb) & set(fn))
        b_far, n_far = sum(fb[k]["far"] for k in keys), sum(fn[k]["far"] for k in keys)
        print(f"JOINT deciding: crews > {FAR_M:.0f} m off goal with a live move at the judge  base {b_far} new {n_far}  pairs {len(keys)}  "
              f"{'PASS' if n_far <= b_far else 'FAIL'} (new <= base)")
        ok &= n_far <= b_far
    print("JOINT VERDICT " + ("PASS (with traffic's jam_ab G and jam:yielding guards read beside)" if ok else "FAIL (see lines)"))


if __name__ == "__main__":
    main()
