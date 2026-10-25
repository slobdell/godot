#!/usr/bin/env python3
"""B4 (round 40, balance): the balance search harness. A CANDIDATE is a unit-overrides json in R40.2's shape (absolute
values, the same file native's `--unit-overrides` reads):

    {"name": "gangs_up", "units": {"gang_tank": {"max_health": 483, "armor": {"front": 8.05}}},
     "weapons": {"scrap_cannon": {"damage": 299}}}

His bounds (R40.1): each value within +/-15 % of today's (toughness = max_health, max_shield, armor faces; damage =
weapon damage; cost), no other key. Subcommands:

    search.py check CAND.json            bounds + shared-weapon check; prints the --tune string
    search.py scale NAME OUT.json gangs:hp=1.15,dmg=1.15 syndicate:hp=0.85 ...   a per-faction candidate
    search.py run CAND.json COMMIT SEEDS...   guard.sh on builder2 (GUARD_ARGS=--tune=..., its own folder)
    search.py score RAW [--base RAW]          the faction table and its flatness (and the paired change v BASE)

Cost goes through `--unit-overrides` once native's N3 lands (Units.cost_of then honours it); until then a candidate that
moves a cost is refused by `run` (the deal would ignore it), `check` says so.

FLATNESS (lower is flatter): for each guard line (blob, turtle), the eight win shares "the guard's faction is F" and "the
CPU's faction is F", each minus the line's own mean; the root mean square over both lines' 16 cells, in points. Its se and
the paired change's se come from a bootstrap over seed units (one seed = every arena and both sides of it), the unit the
guard series samples.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BOUND = 0.15
FACTIONS = ["condemned", "gangs", "law", "syndicate"]
UNIT_KEYS = {"max_health", "max_shield", "cost"}
ARMOR_FACES = {"front", "side", "rear"}
WEAPON_KEYS = {"damage"}
LOG = re.compile(r"^(?P<arena>[a-z_]+)-(?P<seed>\d+)-(?P<side>green|rust)\.log$")


def load_catalog(path: Path | None) -> dict:
    # build/ is cleared by a remote run's copy-back, so a series' driver keeps its copy in ~/balance-runs/.
    for fallback in (ROOT / "build/balance/catalog.json", Path.home() / "balance-runs/catalog.json"):
        if path is None and fallback.exists():
            path = fallback
    path = path or ROOT / "build/balance/catalog.json"
    if not path.exists():
        sys.exit(f"no catalog at {path}: run `make balance-catalog`")
    return json.loads(path.read_text())


def _within(new: float, old: float) -> bool:
    if old == 0:
        return new == 0
    return abs(new / old - 1.0) <= BOUND + 1e-9


def check(cand: dict, catalog: dict) -> list[str]:
    """Problems with a candidate (empty = inside his bounds)."""
    problems = []
    units, weapons = catalog["units"], catalog["weapons"]
    for unit_id, over in cand.get("units", {}).items():
        if unit_id not in units:
            problems.append(f"no unit '{unit_id}'")
            continue
        for key, value in over.items():
            if key == "armor":
                for face, v in value.items():
                    if face not in ARMOR_FACES:
                        problems.append(f"{unit_id}.armor.{face}: no such face")
                    elif not _within(float(v), float(units[unit_id]["armor"][face])):
                        problems.append(f"{unit_id}.armor.{face}={v} is past +/-15 % of {units[unit_id]['armor'][face]}")
            elif key not in UNIT_KEYS:
                problems.append(f"{unit_id}.{key}: not a stat he allowed (hp, shield, armour, damage, cost)")
            elif not _within(float(value), float(units[unit_id][key])):
                problems.append(f"{unit_id}.{key}={value} is past +/-15 % of {units[unit_id][key]}")
    for weapon_id, over in cand.get("weapons", {}).items():
        if weapon_id not in weapons:
            problems.append(f"no weapon '{weapon_id}'")
            continue
        for key, value in over.items():
            if key not in WEAPON_KEYS:
                problems.append(f"{weapon_id}.{key}: not a stat he allowed (damage)")
            elif not _within(float(value), float(weapons[weapon_id][key])):
                problems.append(f"{weapon_id}.{key}={value} is past +/-15 % of {weapons[weapon_id][key]}")
        users = sorted({units[u]["faction"] for u in units if units[u]["weapon"] == weapon_id})
        if len(users) > 1:
            problems.append(f"{weapon_id} is shared by {', '.join(users)}: a damage change moves every one of them")
    return problems


def moves_cost(cand: dict) -> bool:
    return any("cost" in over for over in cand.get("units", {}).values())


def tune_string(cand: dict) -> str:
    """The `--tune=` value for everything but cost (Units.apply_tuning's owner.key[.face]=number)."""
    parts = []
    for unit_id, over in sorted(cand.get("units", {}).items()):
        for key, value in sorted(over.items()):
            if key == "armor":
                parts += [f"{unit_id}.armor.{face}={_num(v)}" for face, v in sorted(value.items())]
            elif key != "cost":
                parts.append(f"{unit_id}.{key}={_num(value)}")
    for weapon_id, over in sorted(cand.get("weapons", {}).items()):
        parts += [f"{weapon_id}.{key}={_num(v)}" for key, v in sorted(over.items())]
    return ",".join(parts)


def _num(v: float) -> str:
    return format(float(v), ".6g")


def scale(name: str, specs: list[str], catalog: dict) -> dict:
    """Per-faction multipliers -> a candidate. `gangs:hp=1.15,armor=1.1,dmg=1.15,cost=0.9`. A damage multiplier skips a
    weapon another faction also carries (check() would refuse it); the skipped ones are listed under "skipped"."""
    units, weapons = catalog["units"], catalog["weapons"]
    cand = {"name": name, "units": {}, "weapons": {}, "skipped": []}
    for spec in specs:
        faction, _, body = spec.partition(":")
        if faction not in FACTIONS:
            sys.exit(f"no faction '{faction}'")
        mult = {k: float(v) for k, v in (p.split("=") for p in body.split(",") if p)}
        for unit_id, row in sorted(units.items()):
            if row["faction"] != faction:
                continue
            over = {}
            if "hp" in mult:
                over["max_health"] = round(row["max_health"] * mult["hp"], 2)
                if row["max_shield"]:
                    over["max_shield"] = round(row["max_shield"] * mult["hp"], 2)
            if "armor" in mult:
                over["armor"] = {f: round(v * mult["armor"], 3) for f, v in row["armor"].items()}
            if "cost" in mult:
                over["cost"] = int(round(row["cost"] * mult["cost"]))
            if over:
                cand["units"][unit_id] = over
            if "dmg" in mult:
                weapon = row["weapon"]
                shared = {units[u]["faction"] for u in units if units[u]["weapon"] == weapon}
                base = float(weapons[weapon].get("damage") or 0)
                if len(shared) > 1:
                    cand["skipped"].append(f"{weapon} (shared by {', '.join(sorted(shared))})")
                elif base > 0:
                    cand["weapons"][weapon] = {"damage": round(base * mult["dmg"], 3)}
    return cand


# ---- scoring ------------------------------------------------------------------------------------------------------

def read_fights(roots: list[Path]) -> list[dict]:
    fights = []
    for root in roots:
        for kind_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            for log in sorted(kind_dir.glob("*.log")):
                m = LOG.match(log.name)
                if not m:
                    continue
                for line in log.read_text(errors="replace").splitlines():
                    if line.startswith("GUARD_RESULT "):
                        r = json.loads(line[len("GUARD_RESULT "):])
                        r["_key"] = (r["guard"], m["arena"], int(m["seed"]), m["side"])
                        fights.append(r)
                        break
    return fights


def cells(fights: list[dict]) -> dict:
    """(line, 'guard'|'cpu', faction) -> [wins, n]"""
    out = defaultdict(lambda: [0, 0])
    for f in fights:
        side = f["side"]
        other = "Rust" if side == "Green" else "Green"
        won = 1 if f["winner"] == side else 0
        for who, team in (("guard", side), ("cpu", other)):
            c = out[(f["guard"], who, f["factions"][team])]
            c[0] += won
            c[1] += 1
    return out


def flatness(fights: list[dict]) -> float:
    c = cells(fights)
    sq, n = 0.0, 0
    for line in sorted({k[0] for k in c}):
        mine = [v for k, v in c.items() if k[0] == line and v[1]]
        mean = sum(w for w, _ in mine) / sum(t for _, t in mine)
        for w, t in mine:
            sq += (100 * (w / t - mean)) ** 2
            n += 1
    return math.sqrt(sq / n) if n else float("nan")


def by_seed(fights: list[dict]) -> dict:
    out = defaultdict(list)
    for f in fights:
        out[f["_key"][2]].append(f)
    return out


def bootstrap(seeds: dict, stat, reps: int = 400, rng_seed: int = 40) -> float:
    rng = random.Random(rng_seed)
    keys = sorted(seeds)
    values = []
    for _ in range(reps):
        sample = [f for _ in keys for f in seeds[rng.choice(keys)]]
        values.append(stat(sample))
    mean = sum(values) / len(values)
    return math.sqrt(sum((v - mean) ** 2 for v in values) / (len(values) - 1))


def table(fights: list[dict]) -> str:
    c = cells(fights)
    rows = []
    for line in ("blob", "turtle", "none"):
        if not any(k[0] == line for k in c):
            continue
        total = [0, 0]
        for k, v in c.items():
            if k[0] == line and k[1] == "guard":
                total[0] += v[0]
                total[1] += v[1]
        parts = [f"{line:6} all {100 * total[0] / total[1]:3.0f} % (n {total[1]})"]
        for who in ("guard", "cpu"):
            parts.append(f"{who}: " + " ".join(
                f"{f[:4]} {100 * c[(line, who, f)][0] / c[(line, who, f)][1]:3.0f}" for f in FACTIONS
                if c[(line, who, f)][1]))
        rows.append(" | ".join(parts))
    return "\n".join(rows)


def score(raw: list[Path], base: list[Path] | None) -> dict:
    fights = read_fights(raw)
    seeds = by_seed(fights)
    report = {"fights": len(fights), "seeds": len(seeds), "flatness": flatness(fights),
              "flatness_se": bootstrap(seeds, flatness) if len(seeds) > 1 else float("nan")}
    print(f"BALANCE_SCORE fights={len(fights)} seeds={len(seeds)} flatness={report['flatness']:.1f} "
          f"se={report['flatness_se']:.1f} (points, lower is flatter)")
    print(table(fights))
    if base:
        base_fights = {f["_key"]: f for f in read_fights(base)}
        paired = [(base_fights[f["_key"]], f) for f in fights if f["_key"] in base_fights]
        pseeds = defaultdict(list)
        for b, a in paired:
            pseeds[a["_key"][2]].append((b, a))

        def diff(pairs):
            return flatness([a for _, a in pairs]) - flatness([b for b, _ in pairs])

        flat = [p for s in sorted(pseeds) for p in pseeds[s]]
        report["paired_n"] = len(flat)
        report["change"] = diff(flat)
        report["change_se"] = bootstrap(pseeds, diff) if len(pseeds) > 1 else float("nan")
        print(f"BALANCE_PAIRED n={len(flat)} base {flatness([b for b, _ in flat]):.1f} -> arm "
              f"{flatness([a for _, a in flat]):.1f}: change {report['change']:+.1f} se {report['change_se']:.1f}")
        print("base:\n" + table([b for b, _ in flat]))
    return report


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--catalog", type=Path)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("check")
    p.add_argument("cand", type=Path)
    p = sub.add_parser("scale")
    p.add_argument("name")
    p.add_argument("out", type=Path)
    p.add_argument("specs", nargs="+")
    p = sub.add_parser("run")
    p.add_argument("cand", type=Path)
    p.add_argument("commit")
    p.add_argument("seeds", nargs="+")
    p.add_argument("--out", type=Path, default=Path.home() / "balance-guard-raw")
    p = sub.add_parser("score")
    p.add_argument("raw", nargs="+", type=Path)
    p.add_argument("--base", nargs="+", type=Path)
    p.add_argument("--json", type=Path)
    args = ap.parse_args(argv)

    if args.cmd == "score":
        report = score(args.raw, args.base)
        if args.json:
            args.json.write_text(json.dumps(report, indent=1))
        return 0
    catalog = load_catalog(args.catalog)
    if args.cmd == "scale":
        cand = scale(args.name, args.specs, catalog)
        args.out.write_text(json.dumps(cand, indent=1) + "\n")
        problems = check(cand, catalog)
        print("\n".join(problems) or f"ok: {args.out}" + (f" (skipped shared: {cand['skipped']})" if cand["skipped"] else ""))
        return 1 if problems else 0
    cand = json.loads(args.cand.read_text())
    problems = check(cand, catalog)
    if args.cmd == "check":
        print("\n".join(problems) or "ok: inside +/-15 %")
        if moves_cost(cand):
            print("note: cost moves need native's --unit-overrides (N3); --tune can't move the deal")
        print(f"--tune={tune_string(cand)}")
        return 1 if problems else 0
    if problems:
        sys.exit("refused:\n" + "\n".join(problems))
    if moves_cost(cand):
        sys.exit("refused: the candidate moves a cost; needs native's --unit-overrides (N3)")
    name = cand.get("name") or args.cand.stem
    env = dict(os.environ, GUARD_ARGS=f"--tune={tune_string(cand)}", GUARD_TAG=f"bal-{name}",
               GUARD_SEEDS=" ".join(args.seeds), GUARD_OUT=str(args.out),
               GUARD_WORKTREE=os.environ.get("GUARD_WORKTREE", str(ROOT.parent / "godot-balance-guard")))
    return subprocess.call(["bash", str(ROOT / "tools/scoreboard/guard.sh"), args.commit], env=env, cwd=ROOT)


if __name__ == "__main__":
    sys.exit(main())
