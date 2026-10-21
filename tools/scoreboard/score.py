#!/usr/bin/env python3
"""Round 35 extension (X5 (a), native): one scoreboard row from one run of mk/scoreboard.mk's workload, read with TODAY's
readers so every main is read the same way. Prints the row as JSON (tools/scoreboard/run.sh files it under
references/scoreboard/rows/; tools/scoreboard/table.py renders the rows).

usage: score.py RAW_DIR --commit C --machine M [--overlay O] [--remote-status N]

The readers, unchanged:
  fights  tests/traffic/jam_ab.py: read + per_fight (T5's causes: open / stuck / jam; jammed under fire = the last hit
          during the jam, or >= 2 hits in the 10 s before), kills; hit rate pooled over every shot; held (round 36, T8's
          G: JAM_CENSUS held_deaths, the deaths whose JAM_DEATH says held_3s: killed in, or within 3 s of, a take-turns
          hold at a street mouth; null when a fight's census lacks the field)
  moves   tests/tactics/e1_bar.py: judge (settled in 75 s, squads arrived) and left_behind (> 25 m off the slot in the
          element's last ELEMENT_TRACE row; wedged = holding a move, not moving, goal far); tools/scoreboard/mover_kind.py
          (brains' still-moving rule)
  orders  tests/control/orders_probe_table.py: _cell (all-in = the last squad's arrival; never = not in the 90 s window),
          far bank (squads with a crew past a deck), twitch (the most a crew moved after its place; -1 or absent = not
          measured on that main)
A number a main's logs cannot give is null, never 0: an absent probe line, a field an older main never printed."""
import argparse
import json
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
for sub in ("tests/traffic", "tests/tactics", "tests/control", "tools/scoreboard"):
    sys.path.insert(0, os.path.join(REPO, sub))
import jam_ab  # noqa: E402
import e1_bar  # noqa: E402
import orders_probe_table  # noqa: E402
import mover_kind  # noqa: E402


def fight_seed(name):
    return name[:-len(".log")].rsplit("-", 1)[-1]


def fights(root, seed=None):
    d = os.path.join(root, "fights")
    names = sorted(n for n in os.listdir(d) if n.endswith(".log")) if os.path.isdir(d) else []
    if seed is not None:
        names = [n for n in names if fight_seed(n) == seed]
    tot = {"ran": len(names), "read": 0, "deaths": 0, "open": 0, "stuck": 0, "jam": 0, "jam_under_fire": 0, "kills": 0,
           "shots": 0, "hits": 0, "held": 0}
    for name in names:
        deaths, census, standoffs, aborts = jam_ab.read(os.path.join(d, name))
        if census is None:
            continue
        f = jam_ab.per_fight(deaths, census, standoffs, aborts)
        tot["read"] += 1
        tot["deaths"] += f["all"]
        tot["open"] += f["open"]
        tot["stuck"] += f["stuck"]
        tot["jam"] += f["jam"]
        tot["jam_under_fire"] += f["jam_uf"]
        tot["kills"] += f["kills"]
        if tot["held"] is not None:
            tot["held"] = None if "held_deaths" not in census else tot["held"] + int(census["held_deaths"])
        for t in (census.get("teams") or {}).values():
            tot["shots"] += int(t.get("shots", 0))
            tot["hits"] += int(t.get("hits", 0))
    if not tot["read"]:
        return {"ran": tot["ran"], "read": 0}
    tot["hit_rate"] = tot["hits"] / tot["shots"] if tot["shots"] else None
    return tot


def moves(root, seed=None):
    d = os.path.join(root, "moves")
    tot = {"ran": 0, "read": 0, "crews_left_behind": 0, "left_behind_wedged": 0, "never_settled": 0, "squads": 0,
           "squads_arrived": 0, "movers": {"closing": 0, "wander": 0, "jitter": 0, "unknown": 0}}
    per_task = {}
    if not os.path.isdir(d):
        return tot
    for faction in sorted(os.listdir(d)):
        for run in sorted(os.listdir(os.path.join(d, faction))):
            run_dir = os.path.join(d, faction, run)
            log = os.path.join(run_dir, "run.log")
            if not os.path.exists(log) or (seed is not None and run.rsplit("-", 1)[-1] != seed):
                continue
            tot["ran"] += 1
            judged = e1_bar.judge(run_dir)
            if judged is None:
                continue
            task = run.rsplit("-", 1)[0]
            _movers, arrived, settled = judged
            left, wedged = e1_bar.left_behind(log)
            squads = len([r for r in json.load(open(os.path.join(run_dir, "screen.json"))) if "squads" in r][0]["squads"])
            tot["read"] += 1
            tot["crews_left_behind"] += left
            tot["left_behind_wedged"] += wedged
            tot["never_settled"] += 1 - settled
            tot["squads"] += squads
            tot["squads_arrived"] += arrived
            t = per_task.setdefault(task, {"runs": 0, "never_settled": 0, "crews_left_behind": 0, "still_moving": 0, "jitter": 0})
            t["runs"] += 1
            t["never_settled"] += 1 - settled
            t["crews_left_behind"] += left
            for _unit, k in mover_kind.movers(run_dir):
                tot["movers"][k] += 1
                if k in ("closing", "wander"):
                    t["still_moving"] += 1
                elif k == "jitter":
                    t["jitter"] += 1
    tot["still_moving"] = tot["movers"]["closing"] + tot["movers"]["wander"]
    tot["per_task"] = per_task
    return tot


SEED = re.compile(r"-s(\d+)\.log$")


def orders(root, seed=None):
    d = os.path.join(root, "orders")
    names = sorted(n for n in os.listdir(d) if n.endswith(".log")) if os.path.isdir(d) else []
    if seed is not None:
        names = [n for n in names if SEED.search(n) and SEED.search(n).group(1) == seed]
    runs = {}
    for name in names:
        seed = int(SEED.search(name).group(1)) if SEED.search(name) else None
        for line in open(os.path.join(d, name), errors="replace"):
            if line.startswith("ORDERS_PROBE_SQUAD "):
                r = json.loads(line[len("ORDERS_PROBE_SQUAD "):])
                runs.setdefault((r["map"], r["squads"], r["route"], r.get("seed", seed)), []).append(r)
    out = {"ran": len(names), "read": len(runs)}
    if not runs:
        return out
    cells = {k: orders_probe_table._cell(v) for k, v in runs.items()}
    cases = {}
    for (m, n, route, _seed), c in cells.items():
        cases.setdefault("%s %d %s" % (m, n, route), []).append(c)
    twitch_measured = all("twitch_m" in r for v in runs.values() for r in v)
    out["never_all_in"] = sum(c["all_in"] == float("inf") for c in cells.values())
    out["far_bank_squads"] = sum(c["far"] for c in cells.values())
    finite = [c["all_in"] for c in cells.values() if c["all_in"] != float("inf")]
    out["all_in_median_s"] = round(statistics.median(finite), 1) if finite else None
    out["twitch_median_m"] = round(statistics.median(c["twitch"] for c in cells.values()), 1) if twitch_measured else None
    out["twitch_worst_m"] = round(max(c["twitch"] for c in cells.values()), 1) if twitch_measured else None
    out["cases"] = {}
    for case, cs in sorted(cases.items()):
        fin = [c["all_in"] for c in cs if c["all_in"] != float("inf")]
        out["cases"][case] = {"runs": len(cs), "all_in_median_s": round(statistics.median(fin), 1) if fin else None,
                              "never_all_in": sum(c["all_in"] == float("inf") for c in cs), "far_bank": sum(c["far"] for c in cs)}
    return out


def seeds(root):
    """Every seed the run dealt, in any part (fights <arena>-<seed>.log, moves <task>-<seed>/, orders ...-s<seed>.log)."""
    out = set()
    d = os.path.join(root, "fights")
    if os.path.isdir(d):
        out |= {fight_seed(n) for n in os.listdir(d) if n.endswith(".log")}
    d = os.path.join(root, "moves")
    if os.path.isdir(d):
        out |= {run.rsplit("-", 1)[-1] for faction in os.listdir(d) for run in os.listdir(os.path.join(d, faction))}
    d = os.path.join(root, "orders")
    if os.path.isdir(d):
        out |= {SEED.search(n).group(1) for n in os.listdir(d) if SEED.search(n)}
    return sorted(out)


def by_seed(root):
    """Round 36 (the noise column): each seed's own fights / moves / orders, read the same way as the whole run. The seed is
    the unit a second seed block repeats, so the spread of these across two blocks of one main sizes each line's noise."""
    return {s: {"fights": fights(root, s), "moves": moves(root, s), "orders": orders(root, s)} for s in seeds(root)}


def script_errors(root):
    """SCRIPT ERROR lines in every log of the run, by part: a probe that breaks on an older main shows on the page."""
    out = {}
    for part in ("fights", "moves", "orders"):
        n = 0
        for base, _dirs, files in os.walk(os.path.join(root, part)):
            for name in files:
                if name.endswith(".log"):
                    n += sum(1 for line in open(os.path.join(base, name), errors="replace") if "SCRIPT ERROR" in line)
        out[part] = n
    return out


FIGHT_KEYS = ("ran", "read", "deaths", "open", "stuck", "jam", "jam_under_fire", "kills", "shots", "hits")


def backfill_held(row, raw):
    """Round 36 (traffic's ask after T8 shipped): add fights.held to a row scored before the line existed, from its own raw
    logs, ONLY when those logs read back to the row's every other fight number (whole run and each seed): the logs are that
    row's. Returns the reason it refused, or None."""
    whole = fights(raw)
    if any(whole.get(k) != row["fights"].get(k) for k in FIGHT_KEYS):
        return "the raw fights are not this row's: %s" % {k: (row["fights"].get(k), whole.get(k)) for k in FIGHT_KEYS
                                                           if whole.get(k) != row["fights"].get(k)}
    seeded = {}
    for s, unit in (row.get("by_seed") or {}).items():
        mine = fights(raw, s)
        if any(mine.get(k) != unit["fights"].get(k) for k in FIGHT_KEYS):
            return "seed %s's raw fights are not this row's" % s
        seeded[s] = mine.get("held")
    row["fights"]["held"] = whole.get("held")
    for s, held in seeded.items():
        row["by_seed"][s]["fights"]["held"] = held
    return None


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--backfill-held":
        if len(sys.argv) != 4:
            sys.exit("usage: score.py --backfill-held ROW_JSON RAW_DIR")
        row = json.load(open(sys.argv[2]))
        why = backfill_held(row, sys.argv[3])
        if why:
            sys.exit("score.py: NOT back-filled: %s" % why)
        with open(sys.argv[2] + ".tmp", "w") as f:
            json.dump(row, f, indent=1, sort_keys=True)
            f.write("\n")
        os.replace(sys.argv[2] + ".tmp", sys.argv[2])
        print("score.py: %s fights.held = %s" % (sys.argv[2], row["fights"]["held"]))
        return
    p = argparse.ArgumentParser()
    p.add_argument("raw")
    p.add_argument("--commit", required=True)
    p.add_argument("--machine", required=True)
    p.add_argument("--overlay", default="")
    p.add_argument("--remote-status", type=int, default=None)
    a = p.parse_args()
    run_txt = os.path.join(a.raw, "run.txt")
    header = open(run_txt).read().strip().splitlines() if os.path.exists(run_txt) else []
    row = {"commit": a.commit, "machine": a.machine, "overlay": a.overlay, "remote_status": a.remote_status,
           "run": header, "fights": fights(a.raw), "moves": moves(a.raw), "orders": orders(a.raw),
           "script_errors": script_errors(a.raw), "by_seed": by_seed(a.raw)}
    json.dump(row, sys.stdout, indent=1, sort_keys=True)
    print()


if __name__ == "__main__":
    main()
