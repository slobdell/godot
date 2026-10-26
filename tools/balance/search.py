#!/usr/bin/env python3
"""B4 (round 40, balance): the balance search harness. A CANDIDATE is a unit-overrides json in R40.2's shape (absolute
values, the same file native's `--unit-overrides` reads):

    {"name": "gangs_up", "units": {"gang_tank": {"max_health": 483, "armor": {"front": 8.05}}},
     "weapons": {"scrap_cannon": {"damage": 299}}}

His bounds (R40.1): each value within +/-15 % of today's (toughness = max_health, max_shield, armor faces; damage =
weapon damage; cost), no other key. Subcommands:

    search.py check CAND.json            bounds + shared-weapon check; prints the --tune string
    search.py scale NAME OUT.json gangs:hp=1.15,dmg=1.15 syndicate:hp=0.85 ...   a per-faction candidate
    search.py run CAND.json COMMIT SEEDS...   guard.sh on builder2 (GUARD_OVERRIDES, J16, its own folder)
    search.py score RAW [--base RAW]          the faction table and its flatness (and the paired change v BASE)

`run` passes the candidate through native's N3 (`GUARD_OVERRIDES` -> `--unit-overrides`, on main since b25b803e5), which
honours cost in the deal too; its commit must carry N3. (066d0ff95's dry run used `--tune`, which can't move a cost.)

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


def _literal(v: float, old: str) -> str:
    """A number written the way the catalog writes it: an int where it had an int, else a float with a point."""
    if "." not in old and float(v) == int(v):
        return str(int(v))
    text = format(float(v), ".6g")
    return text if "." in text or "e" in text else text + ".0"


def apply(cand: dict, units_path: Path, weapons_path: Path) -> list[str]:
    """Write a candidate's values into the catalogs' source (units.gd PROFILES, weapons.gd PROFILES), each inside its
    own profile's block. Returns what changed, one line each."""
    changed = []
    for path, section in ((units_path, cand.get("units", {})), (weapons_path, cand.get("weapons", {}))):
        text = path.read_text()
        for item_id, stats in section.items():
            start = text.index(f'\n\t"{item_id}": {{\n')
            end = text.index("\n\t},", start)
            block = text[start:end]
            for key, value in stats.items():
                if isinstance(value, dict):
                    m = re.search(rf'\n\t\t"{key}": \{{([^}}]*)\}}', block)
                    inner = m.group(1)
                    for face, v in value.items():
                        fm = re.search(rf'"{face}": ([0-9.]+)', inner)
                        inner = inner[:fm.start(1)] + _literal(v, fm.group(1)) + inner[fm.end(1):]
                    new = m.group(0).replace(m.group(1), inner)
                    changed.append(f"{item_id}.{key}: {m.group(1).strip()} -> {inner.strip()}")
                    block = block.replace(m.group(0), new)
                else:
                    m = re.search(rf'(\n\t\t"{key}": )([0-9.]+)', block)
                    if m is None:
                        raise SystemExit(f"apply: no {item_id}.{key} literal in {path}")
                    if key == "max_health":
                        value = math.floor(float(value) + 0.5)  # Tank: max_health = roundi(stat): ship what the sim used
                    lit = _literal(value, m.group(2))
                    changed.append(f"{item_id}.{key}: {m.group(2)} -> {lit}")
                    block = block[:m.start(2)] + lit + block[m.end(2):]
            text = text[:start] + block + text[end:]
        path.write_text(text)
    return changed


def _num(v: float) -> str:
    return format(float(v), ".6g")


def scale(name: str, specs: list[str], catalog: dict) -> dict:
    """Per-faction multipliers -> a candidate. `gangs:hp=1.15,armor=1.1,dmg=1.15,cost=0.9`. A damage multiplier skips a
    weapon another faction also carries (check() would refuse it); the skipped ones are listed under "skipped"."""
    units, weapons = catalog["units"], catalog["weapons"]
    cand = {"name": name, "units": {}, "weapons": {}, "skipped": []}
    # B5: "role:<role>:hp=0.9,cost=1.1" multiplies on top of a faction's spec (both apply to a gangs tank), and the
    # product is clamped to his +/-15 %.
    by_unit: dict = defaultdict(dict)
    for spec in specs:
        head, _, body = spec.rpartition(":")
        mult = {k: float(v) for k, v in (p.split("=") for p in body.split(",") if p)}
        if head.startswith("role:"):
            match = [u for u, r in units.items() if r["role"] == head[len("role:"):]]
        elif head in FACTIONS:
            match = [u for u, r in units.items() if r["faction"] == head]
        else:
            sys.exit(f"no faction or role:<role> '{head}'")
        if not match:
            sys.exit(f"'{head}' matches no unit")
        for unit_id in match:
            for k, v in mult.items():
                by_unit[unit_id][k] = by_unit[unit_id].get(k, 1.0) * v
    for unit_id in by_unit:
        by_unit[unit_id] = {k: min(1 + BOUND, max(1 - BOUND, v)) for k, v in by_unit[unit_id].items()}
    for unit_id, row in sorted(units.items()):
        mult = by_unit.get(unit_id)
        if mult:
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
        for line in ("blob", "turtle", "none"):
            lp = {seed: [(b, a) for b, a in pairs if a["guard"] == line] for seed, pairs in pseeds.items()}
            lp = {k: v for k, v in lp.items() if v}
            if not lp:
                continue

            def share(pairs, line=line):
                return 100 * sum((a["winner"] == a["side"]) - (b["winner"] == b["side"]) for b, a in pairs) / len(pairs)

            allp = [p for v in lp.values() for p in v]
            d, dse = share(allp), bootstrap(lp, share) if len(lp) > 1 else float("nan")
            report[f"{line}_change"], report[f"{line}_change_se"] = d, dse
            print(f"BALANCE_LINE {line} guard win share paired change {d:+.1f} se {dse:.1f} (n {len(allp)})")
        print("base:\n" + table([b for b, _ in flat]))
    return report


# ---- B5 / G8: the mono line -----------------------------------------------------------------------------------------

MONO_DIR = re.compile(r"mono-(?:.*-)?(?P<faction>condemned|gangs|law|syndicate)-(?P<team>player|enemy)$")


def read_mono(root: Path, match: str = "") -> dict:
    """(faction, team, arena, seed) -> {"mono_won": 0|1, "mono_units", "mixed_units", "seconds"} from every
    <...>mono-<faction>-<player|enemy> folder under `root` (guard none; the green-side log only: the none line's two
    guard sides are the same fight)."""
    out = {}
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        m = MONO_DIR.search(d.name)
        if not m or match not in d.name:
            continue
        mono_team = "green" if m["team"] == "player" else "rust"
        for log in sorted((d / "none").glob("*-green.log")):
            lm = LOG.match(log.name)
            for line in log.read_text(errors="replace").splitlines():
                if line.startswith("GUARD_RESULT "):
                    r = json.loads(line[len("GUARD_RESULT "):])
                    other = "rust" if mono_team == "green" else "green"
                    out[(m["faction"], m["team"], lm["arena"], int(lm["seed"]))] = {
                        "mono_won": 1 if r["winner"].lower() == mono_team else 0,
                        "mono_units": r["tanks"][mono_team], "mixed_units": r["tanks"][other], "seconds": r["seconds"]}
                    break
    return out


def mono_report(root: Path, match: str = "", base_match: str | None = None) -> dict:
    arm = read_mono(root, match)
    rows = {}
    print(f"BALANCE_MONO fights={len(arm)} (mono-tank army v its own faction's deal, equal budget, CPU v CPU)")
    for faction in FACTIONS + ["all"]:
        keys = [k for k in arm if faction in ("all", k[0])]
        if not keys:
            continue
        won = sum(arm[k]["mono_won"] for k in keys) / len(keys)
        by_team = {t: [arm[k]["mono_won"] for k in keys if k[1] == t] for t in ("player", "enemy")}
        units = (sum(arm[k]["mono_units"] for k in keys) / len(keys), sum(arm[k]["mixed_units"] for k in keys) / len(keys))
        seeds = defaultdict(list)
        for k in keys:
            seeds[k[3]].append(arm[k])
        se = bootstrap(seeds, lambda fs: 100 * sum(f["mono_won"] for f in fs) / len(fs)) if len(seeds) > 1 else float("nan")
        line = (f"  {faction:10} mono wins {100 * won:3.0f} % (n {len(keys)}, se {se:.0f}) | on Green "
                + " ".join(f"{t}={100 * sum(v) / len(v):.0f}%" for t, v in by_team.items() if v)
                + f" | units mono {units[0]:.1f} v mixed {units[1]:.1f}")
        rows[faction] = {"won": won, "n": len(keys), "se": se, "units": units}
        if base_match is not None:
            b = read_mono(root, base_match)
            paired = [(b[k]["mono_won"], arm[k]["mono_won"], k[3]) for k in keys if k in b]
            if paired:
                ps = defaultdict(list)
                for bw, aw, seed in paired:
                    ps[seed].append((bw, aw))
                change = 100 * sum(aw - bw for bw, aw, _ in paired) / len(paired)
                cse = bootstrap(ps, lambda xs: 100 * sum(a - b for b, a in xs) / len(xs)) if len(ps) > 1 else float("nan")
                line += f" | paired v base {change:+.0f} (se {cse:.0f}, n {len(paired)})"
                rows[faction]["change"], rows[faction]["change_se"] = change, cse
        print(line)
    return rows


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
    p.add_argument("--tag", help="folder tag (default bal-<name>); GUARD_ARGS / GUARD_KINDS pass through the environment")
    p = sub.add_parser("apply")
    p.add_argument("cand", type=Path)
    p = sub.add_parser("mono")
    p.add_argument("root", type=Path, help="the folder holding <commit>-<tag>mono-<faction>-<player|enemy>/ runs")
    p.add_argument("--match", default="", help="only folders whose name contains this (e.g. -mono-base-)")
    p.add_argument("--base-match", help="pair with the folders whose name contains this")
    p = sub.add_parser("score")
    p.add_argument("raw", nargs="+", type=Path)
    p.add_argument("--base", nargs="+", type=Path)
    p.add_argument("--json", type=Path)
    args = ap.parse_args(argv)

    if args.cmd == "mono":
        mono_report(args.root, args.match, args.base_match)
        return 0
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
    if args.cmd == "apply":
        if problems:
            sys.exit("refused:\n" + "\n".join(problems))
        print("\n".join(apply(cand, ROOT / "game/units/units.gd", ROOT / "game/combat/weapons.gd")))
        return 0
    if args.cmd == "check":
        print("\n".join(problems) or "ok: inside +/-15 %")
        print(f"--tune={tune_string(cand)}")
        return 1 if problems else 0
    if problems:
        sys.exit("refused:\n" + "\n".join(problems))
    name = cand.get("name") or args.cand.stem
    # N3 (native, on main b25b803e5): `--unit-overrides` reads only {"units", "weapons"}; it honours cost in the deal.
    clean = {k: cand[k] for k in ("units", "weapons") if cand.get(k)}
    args.out.mkdir(parents=True, exist_ok=True)
    over = args.out / f"overrides-{name}.json"
    over.write_text(json.dumps(clean, indent=1) + "\n")
    env = dict(os.environ, GUARD_OVERRIDES=str(over), GUARD_TAG=args.tag or f"bal-{name}", GUARD_SEEDS=" ".join(args.seeds),
               GUARD_OUT=str(args.out), GUARD_JOBS=os.environ.get("GUARD_JOBS", "16"),
               GUARD_WORKTREE=os.environ.get("GUARD_WORKTREE", str(ROOT.parent / "godot-balance-guard")))
    if not clean:
        env.pop("GUARD_OVERRIDES")
    return subprocess.call(["bash", str(ROOT / "tools/scoreboard/guard.sh"), args.commit], env=env, cwd=ROOT)

if __name__ == "__main__":
    sys.exit(main())
