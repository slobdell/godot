#!/usr/bin/env python3
"""B1 (round 40, balance): the per-unit tally of a guard series, read from the fight logs it already wrote.

Every guard fight log carries GUARD_RESULT (factions, winner, guard kind, the guard's side) and one line per kill,
"<Team>_<Squad>_<n> destroyed <Team>_<Squad>_<n>". A faction army's squads are pure by role (Army.squads_for_scale),
so a squad name (Guns, Hunters3, Spears2, ...) and the faction name the unit type. That is enough for kills and losses
by unit type with no new fights; damage dealt waits on CP40.0's per-unit GUARD_RESULT fields (native N1), which this
reads when present ("units" in GUARD_RESULT).

    tools/balance/tally.py --catalog build/balance/catalog.json RUN_DIR [RUN_DIR ...] [--json OUT]

RUN_DIR holds blob/ and/or turtle/ (guard.sh's layout: <arena>-<seed>-<side>.log). The catalog comes from
`make balance-catalog` (tools/balance/catalog_dump.gd).
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

# A squad name is its role's base name, a number for the 2nd+ squad of a role (Guns2), or a roman numeral when the
# skirmish renames a squad (Eyes II). Friendly fire reads "destroyed teammate <name> (friendly fire)".
_NAME = r"(Green|Rust)_([A-Za-z]+?)(\d+| [IVX]+)?_(\d+)"
KILL = re.compile(rf"^{_NAME} destroyed (?:teammate )?{_NAME}\b")
ARMY = re.compile(r"^SKIRMISH_ARMY (Green|Rust) .*?\((\d+) pts\)")
FACTION_ORDER = ["condemned", "gangs", "law", "syndicate"]


def squad_unit_map(catalog: dict) -> dict:
    """(faction, squad base name) -> unit id, from Army.SQUADS and each unit's squad key."""
    names = {key: spec["name"] for key, spec in catalog["squads"].items()}
    out = {}
    for unit_id, row in catalog["units"].items():
        out[(row["faction"], names[row["squad_key"]])] = unit_id
    return out


def parse_fight(path: Path, squads: dict) -> dict | None:
    result = None
    kills = []
    names: dict[str, str] = {}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("GUARD_RESULT "):
            result = json.loads(line[len("GUARD_RESULT "):])
            continue
        m = KILL.match(line)
        if m:
            kills.append(m.groups())
    if result is None:
        return None
    factions = {team: f for team, f in result["factions"].items()}

    def unit_of(team: str, squad: str) -> str:
        return squads.get((factions[team], squad), f"?{factions[team]}/{squad}")

    events = []
    for kt, ks, _kn, kidx, vt, vs, vn, vidx in kills:
        events.append({"killer_team": kt, "killer": unit_of(kt, ks), "victim_team": vt, "victim": unit_of(vt, vs),
                       "victim_name": f"{vt}_{vs}{vn or ''}_{vidx}"})
    return {"file": path.name, "result": result, "events": events}


def deal_from_log(path: Path) -> dict:
    """Team -> unit display counts from SKIRMISH_ARMY (the dealt army, as the log describes it)."""
    out = {}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("SKIRMISH_ARMY "):
            team = line.split()[1]
            body = line.split(":", 1)[1].strip()
            out[team] = body
    return out


DISPLAY_COUNT = re.compile(r"(\d+) ([^,(]+?)(?:,|\s*\()")


def parse_deal(body: str, catalog: dict, faction: str) -> dict:
    """'4 skimmers, 6 limousine gunships, 3 railgun platforms (5190 pts)' -> {unit_id: n}."""
    by_name = {}
    for unit_id, row in catalog["units"].items():
        if row["faction"] != faction:
            continue
        label = row["display_name"].lower() if unit_id != "ifv" else "IFV"
        by_name[label] = unit_id
        by_name[label + "s"] = unit_id
    out = {}
    for n, name in DISPLAY_COUNT.findall(body):
        name = name.strip()
        unit_id = by_name.get(name) or by_name.get(name.lower())
        if unit_id is None:
            raise ValueError(f"unknown unit '{name}' in '{body}'")
        out[unit_id] = out.get(unit_id, 0) + int(n)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("runs", nargs="+", type=Path)
    ap.add_argument("--catalog", type=Path, required=True)
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    catalog = json.loads(args.catalog.read_text())
    squads = squad_unit_map(catalog)
    units = catalog["units"]

    # per (guard kind, faction, unit) and per (faction, unit) across both kinds
    stat = defaultdict(lambda: defaultdict(float))
    armies = defaultdict(lambda: defaultdict(float))  # (kind, faction, role-in-fight) -> fights, units, cost
    fights = 0
    unknown = 0
    kill_mismatch = 0
    for run in args.runs:
        for kind_dir in sorted(p for p in run.iterdir() if p.is_dir()):
            kind = kind_dir.name
            for log in sorted(kind_dir.glob("*.log")):
                fight = parse_fight(log, squads)
                if fight is None:
                    continue
                fights += 1
                r = fight["result"]
                deals = deal_from_log(log)
                side = r["side"]  # the guard (blob/turtle) side, "Green" or "Rust"
                for team in ("Green", "Rust"):
                    faction = r["factions"][team]
                    who = kind if team == side else "cpu"
                    won = r["winner"] == team
                    deal = parse_deal(deals[team], catalog, faction)
                    a = armies[(kind, who, faction)]
                    a["fights"] += 1
                    a["wins"] += 1 if won else 0
                    a["units"] += sum(deal.values())
                    a["cost"] += sum(units[u]["cost"] * n for u, n in deal.items())
                    for unit_id, n in deal.items():
                        for key in ((kind, who, unit_id), ("all", "all", unit_id)):
                            s = stat[key]
                            s["fielded"] += n
                            s["cost"] += units[unit_id]["cost"] * n
                            s["fights"] += 1
                            s["win_fielded"] += n if won else 0
                tallied = {"Green": 0, "Rust": 0}
                for e in fight["events"]:
                    if e["killer"].startswith("?") or e["victim"].startswith("?"):
                        unknown += 1
                        continue
                    k_who = kind if e["killer_team"] == side else "cpu"
                    v_who = kind if e["victim_team"] == side else "cpu"
                    friendly = e["killer_team"] == e["victim_team"]
                    for key in ((kind, k_who, e["killer"]), ("all", "all", e["killer"])):
                        if friendly:
                            stat[key]["friendly_kills"] += 1
                        else:
                            stat[key]["kills"] += 1
                            stat[key]["kill_value"] += units[e["victim"]]["cost"]
                    for key in ((kind, v_who, e["victim"]), ("all", "all", e["victim"])):
                        stat[key]["losses"] += 1
                    if not friendly:
                        tallied[e["killer_team"]] += 1
                for team in ("Green", "Rust"):
                    if tallied[team] != r["kills"][team.lower()]:
                        kill_mismatch += 1

    rows = []
    for (kind, who, unit_id), s in stat.items():
        row = units[unit_id]
        f = s["fielded"]
        rows.append({
            "kind": kind, "who": who, "unit": unit_id, "name": row["display_name"], "faction": row["faction"],
            "role": row["role"], "unit_cost": row["cost"], "fights": int(s["fights"]), "fielded": int(f),
            "kills": int(s["kills"]), "losses": int(s["losses"]), "friendly_kills": int(s["friendly_kills"]),
            "kills_per_unit": s["kills"] / f if f else 0.0,
            "survival": 1.0 - s["losses"] / f if f else 0.0,
            "kill_value_per_credit": s["kill_value"] / s["cost"] if s["cost"] else 0.0,
            "kr": s["kills"] / s["losses"] if s["losses"] else math.inf,
        })
    army_rows = []
    for (kind, who, faction), a in armies.items():
        army_rows.append({"kind": kind, "who": who, "faction": faction, "fights": int(a["fights"]),
                          "win_rate": a["wins"] / a["fights"], "units": a["units"] / a["fights"],
                          "cost": a["cost"] / a["fights"]})

    print(f"BALANCE_TALLY fights={fights} unknown_events={unknown} kill_count_mismatch_sides={kill_mismatch}")
    print("\nDealt army per fight (mean units, mean cost, win %):")
    for r in sorted(army_rows, key=lambda r: (r["kind"], r["who"], FACTION_ORDER.index(r["faction"]))):
        print(f"  {r['kind']:7} {r['who']:7} {r['faction']:10} n={r['fights']:4} units={r['units']:5.1f} "
              f"cost={r['cost']:6.0f} win={100 * r['win_rate']:4.0f} %")
    print("\nBy unit type, both guard kinds and both sides (kills/unit, survival, killed value per credit, kr):")
    for r in sorted((r for r in rows if r["kind"] == "all"),
                    key=lambda r: (FACTION_ORDER.index(r["faction"]), -r["unit_cost"])):
        print(f"  {r['faction']:10} {r['name'][:20]:20} {r['unit_cost']:4} fielded={r['fielded']:6} "
              f"k/unit={r['kills_per_unit']:4.2f} surv={100 * r['survival']:3.0f} % "
              f"value/credit={r['kill_value_per_credit']:4.2f} kr={r['kr']:5.2f} ff={r['friendly_kills']}")
    print("\nBy faction, both kinds and both sides (fielded a fight, kills/unit, survival, killed value per credit):")
    for faction in FACTION_ORDER:
        mine = [r for r in rows if r["kind"] == "all" and r["faction"] == faction]
        if not mine:
            continue
        f = sum(r["fielded"] for r in mine)
        spent = sum(r["fielded"] * r["unit_cost"] for r in mine)
        value = sum(r["kill_value_per_credit"] * r["fielded"] * r["unit_cost"] for r in mine)
        print(f"  {faction:10} kills/unit={sum(r['kills'] for r in mine) / f:4.2f} "
              f"surv={100 * (1 - sum(r['losses'] for r in mine) / f):3.0f} % value/credit={value / spent:4.2f}")
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps({"fights": fights, "units": rows, "armies": army_rows}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
