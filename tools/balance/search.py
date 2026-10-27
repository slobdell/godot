#!/usr/bin/env python3
"""B4 (round 40, balance): the balance search harness. A CANDIDATE is a unit-overrides json in R40.2's shape (absolute
values, the same file native's `--unit-overrides` reads):

    {"name": "gangs_up", "units": {"gang_tank": {"max_health": 483, "armor": {"front": 8.05}}},
     "weapons": {"scrap_cannon": {"damage": 299}}}

His bounds (R40.1): each value within +/-15 % of today's (toughness = max_health, max_shield, armor faces; damage =
weapon damage; cost), no other key. Round 41 (B5, C41.5): his own two levers, a tank's turret traverse
(turret_turn_rate_deg) and hull speed / turn (max_forward_speed, max_reverse_speed, hull_turn_rate_deg), may be screened at
ANY size (LEVER_KEYS; `scale`'s turret= / speed= / hturn= multipliers are not clamped). Subcommands:

    search.py check CAND.json            bounds + shared-weapon check; prints the --tune string
    search.py scale NAME OUT.json gangs:hp=1.15,dmg=1.15 syndicate:hp=0.85 ...   a per-faction candidate
    search.py run CAND.json COMMIT SEEDS...   guard.sh on builder2 (GUARD_OVERRIDES, J16, its own folder); --probe runs
                                              tools/balance/guard_probe.sh instead (the face probe: FACE lines, B5)
    search.py score RAW [--base RAW]          the faction table and its flatness (and the paired change v BASE)
    search.py mono ROOT [--match X --base-match Y]   the mono-tank line (B5 / G8): win share, units, median length
    search.py faces ROOT [--match X --base-match Y]  B5's WHY: the mixed army's damage to tanks by the face it struck

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
import time
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BOUND = 0.15
FACTIONS = ["condemned", "gangs", "law", "syndicate"]
UNIT_KEYS = {"max_health", "max_shield", "cost"}
# Round 41 (C41.5): his levers, any size; `scale` multiplies them with turret= (turret_turn_rate_deg), speed= (forward AND
# reverse: a slower hull is slower both ways) and hturn= (hull_turn_rate_deg).
LEVER_KEYS = {"turret_turn_rate_deg", "max_forward_speed", "max_reverse_speed", "hull_turn_rate_deg"}
LEVER_MULT = {"turret": ("turret_turn_rate_deg",), "speed": ("max_forward_speed", "max_reverse_speed"),
              "hturn": ("hull_turn_rate_deg",)}
FACES = ("front", "side", "rear")
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
            elif key in LEVER_KEYS:
                if key not in units[unit_id]:
                    problems.append(f"{unit_id}.{key}: not in the catalog (re-run make balance-catalog)")
                elif not (float(value) > 0):
                    problems.append(f"{unit_id}.{key}={value}: a lever must stay positive")
            elif key not in UNIT_KEYS:
                problems.append(f"{unit_id}.{key}: not a stat he allowed (hp, shield, armour, damage, cost; levers: "
                                + ", ".join(sorted(LEVER_KEYS)) + ")")
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
    if all("armor" in row for row in units.values()) and all("penetration" in w for w in weapons.values()):
        problems += from_behind_breaks(cand, catalog)
    return problems


# Armor.penetration_multiplier (game/combat/armor.gd), mirrored so `check` refuses a candidate that breaks
# test_combat_mechanics::test_everything_hurts_from_behind (every weapon: rear >= front, rear >= 0.4) before it costs a series.
PENETRATION_FLOOR, PENETRATION_CAP = 0.05, 1.5


def penetration_multiplier(penetration: float, thickness: float) -> float:
    if penetration <= 0.0:
        return PENETRATION_FLOOR
    if thickness <= 0.0:
        return PENETRATION_CAP
    return min(PENETRATION_CAP, max(PENETRATION_FLOOR, 0.5 * math.log(1.6 * penetration / thickness) / math.log(2.0)))


def from_behind_breaks(cand: dict, catalog: dict) -> list[str]:
    out = []
    for unit_id, row in catalog["units"].items():
        armor = dict(row["armor"])
        armor.update(cand.get("units", {}).get(unit_id, {}).get("armor", {}))
        for weapon_id, weapon in catalog["weapons"].items():
            pen = float(weapon.get("penetration") or 0.0)
            front = penetration_multiplier(pen, float(armor["front"]))
            rear = penetration_multiplier(pen, float(armor["rear"]))
            if rear < front - 1e-9 or rear < 0.4 - 1e-9:
                out.append(f"{weapon_id} from behind into a {unit_id}: rear x{rear:.2f} v front x{front:.2f} (needs rear >= front, >= 0.4)")
    return out


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
        by_unit[unit_id] = {k: v if k in LEVER_MULT else min(1 + BOUND, max(1 - BOUND, v)) for k, v in by_unit[unit_id].items()}
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
            for lever, keys in LEVER_MULT.items():
                if lever in mult:
                    for key in keys:
                        if key not in row:
                            sys.exit(f"the catalog has no {unit_id}.{key}: re-run make balance-catalog")
                        over[key] = round(float(row[key]) * mult[lever], 3)
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
        if not root.is_dir():
            continue
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
        median_s = _median([arm[k]["seconds"] for k in keys])
        line = (f"  {faction:10} mono wins {100 * won:3.0f} % (n {len(keys)}, se {se:.0f}) | on Green "
                + " ".join(f"{t}={100 * sum(v) / len(v):.0f}%" for t, v in by_team.items() if v)
                + f" | units mono {units[0]:.1f} v mixed {units[1]:.1f} | median {median_s:.0f} s")
        rows[faction] = {"won": won, "n": len(keys), "se": se, "units": units, "median_s": median_s}
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
                base_median = _median([b[k]["seconds"] for k in keys if k in b])
                if base_median > 0:
                    line += f" | length {100 * (median_s / base_median - 1):+.0f} %"
                    rows[faction]["length_change_pct"] = 100 * (median_s / base_median - 1)
        print(line)
    return rows


# ---- B5 (round 41): WHY, the mixed army's damage to tanks by the face it struck (tests/tactics/face_probe.gd) ----------

def read_faces(root: Path, match: str = "") -> dict:
    """(faction, team, arena, seed) -> the MIXED side's FACE row against the mono-tank side: {"to_tanks": {face: points},
    "by_role": {role: {face: points}}, "dealt": its UnitTally total (cones included, which have no event)}."""
    out = {}
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        m = MONO_DIR.search(d.name)
        if not m or match not in d.name:
            continue
        mono_team = "green" if m["team"] == "player" else "rust"
        mixed = "rust" if mono_team == "green" else "green"
        for log in sorted((d / "none").glob("*-green.log")):
            lm = LOG.match(log.name)
            for line in log.read_text(errors="replace").splitlines():
                if line.startswith("FACE "):
                    r = json.loads(line[len("FACE "):])["teams"][mixed]
                    out[(m["faction"], m["team"], lm["arena"], int(lm["seed"]))] = {
                        "to_tanks": r["to_tanks"], "by_role": r["to_tanks_by_role"], "dealt": float(r["dealt"])}
                    break
    return out


INDIRECT_ROLES = {"artillery"}  # an indirect round comes down on top: its face is "side" by convention, not by flanking


def _direct(rows: list) -> dict:
    """The mixed army's faced damage to tanks from DIRECT fire (every shooter role but artillery), summed by face."""
    out = {f: 0.0 for f in FACES}
    for r in rows:
        for role, by in r["by_role"].items():
            if role not in INDIRECT_ROLES:
                for f in FACES:
                    out[f] += float(by.get(f, 0.0))
    return out


def _flank_share(rows: list) -> float:
    """B5's WHY: of the mixed army's DIRECT-fire damage on tanks, the percent that struck a side or rear (did it get round?)."""
    d = _direct(rows)
    faced = sum(d.values())
    return 100 * (d["side"] + d["rear"]) / faced if faced else float("nan")


def faces_report(root: Path, match: str = "", base_match: str | None = None) -> dict:
    arm = read_faces(root, match)
    base = read_faces(root, base_match) if base_match is not None else {}
    print(f"BALANCE_FACES fights={len(arm)} (the mixed army's damage to the mono-tank army's tanks, by the face struck)")
    out = {}
    for faction in FACTIONS + ["all"]:
        keys = [k for k in arm if faction in ("all", k[0])]
        if not keys:
            continue
        rows = [arm[k] for k in keys]
        faced = {f: sum(r["to_tanks"][f] for r in rows) for f in FACES}
        total_faced = sum(faced.values()) or float("nan")
        dealt = sum(r["dealt"] for r in rows) or float("nan")
        seeds = defaultdict(list)
        for k in keys:
            seeds[k[3]].append(arm[k])
        share = _flank_share(rows)
        se = bootstrap(seeds, _flank_share) if len(seeds) > 1 else float("nan")
        direct = _direct(rows)
        direct_total = sum(direct.values()) or float("nan")
        line = (f"  {faction:10} direct fire on tanks: front {100 * direct['front'] / direct_total:3.0f} % side "
                f"{100 * direct['side'] / direct_total:3.0f} % rear {100 * direct['rear'] / direct_total:3.0f} % | side+rear {share:.1f} "
                f"(se {se:.1f}) | direct {100 * direct_total / total_faced:.0f} % of faced, faced {100 * total_faced / dealt:.0f} % of dealt")
        out[faction] = {"share": share, "se": se, "faced": faced, "n": len(keys)}
        if base:
            pairs = defaultdict(list)
            for k in keys:
                if k in base:
                    pairs[k[3]].append((base[k], arm[k]))
            if pairs:
                diff = lambda ps: _flank_share([a for _, a in ps]) - _flank_share([b for b, _ in ps])
                d, dse, n = _change(pairs, diff)
                line += f" | paired v base {d:+.1f} (se {dse:.1f}, n {n})"
                out[faction]["change"], out[faction]["change_se"] = d, dse
        print(line)
        roles = defaultdict(lambda: {f: 0.0 for f in FACES})
        for r in rows:
            for role, by in r["by_role"].items():
                for f in FACES:
                    roles[role][f] += float(by.get(f, 0.0))
        for role, by in sorted(roles.items(), key=lambda kv: -sum(kv[1].values())):
            t = sum(by.values())
            if t > 0:
                print(f"             {role:10} {100 * t / total_faced:3.0f} % of it: front {100 * by['front'] / t:3.0f} side "
                      f"{100 * by['side'] / t:3.0f} rear {100 * by['rear'] / t:3.0f}")
    return out


# ---- Bar B2s (filed d479a17a1 + 16bfd1cc6): the verdict, one line a rule ---------------------------------------------

def _median(xs: list) -> float:
    xs = sorted(xs)
    n = len(xs)
    return float("nan") if n == 0 else (xs[n // 2] if n % 2 else 0.5 * (xs[n // 2 - 1] + xs[n // 2]))


def _paired_seeds(base: list[dict], arm: list[dict], keep=lambda f: True) -> dict:
    bmap = {f["_key"]: f for f in base if keep(f)}
    out = defaultdict(list)
    for a in arm:
        if keep(a) and a["_key"] in bmap:
            out[a["_key"][2]].append((bmap[a["_key"]], a))
    return out


def _change(pairs_by_seed: dict, stat) -> tuple[float, float, int]:
    allp = [p for v in pairs_by_seed.values() for p in v]
    if not allp:
        return float("nan"), float("nan"), 0
    return stat(allp), bootstrap(pairs_by_seed, stat) if len(pairs_by_seed) > 1 else float("nan"), len(allp)


def bar(root: Path, base_c: str, arm_c: str) -> int:
    """Judge Bar B2s from guard.sh folders <commit>-lines, <commit>-none, <commit>-mono-<faction>-<team> under `root`."""
    lines_b, lines_a = read_fights([root / f"{base_c}-lines"]), read_fights([root / f"{arm_c}-lines"])
    none_b, none_a = read_fights([root / f"{base_c}-none"]), read_fights([root / f"{arm_c}-none"])
    verdict = []

    def judge(name, d, se, n, fail_if, note=""):
        bad = fail_if(d, se)
        verdict.append(not bad)
        print(f"BAR_B2S {name:42} {d:+7.2f} se {se:5.2f} (n {n}) -> {'FAIL' if bad else 'pass'} {note}")

    ps = _paired_seeds(lines_b, lines_a)
    flat_change = lambda pairs: flatness([a for _, a in pairs]) - flatness([b for b, _ in pairs])
    d, se, n = _change(ps, flat_change)
    print(f"BAR_B2S flatness base {flatness([b for v in ps.values() for b, _ in v]):.1f} -> arm "
          f"{flatness([a for v in ps.values() for _, a in v]):.1f}")
    judge("DECIDING flatness change (down > 2 se)", d, se, n, lambda d, se: not d < -2 * se)
    cb, ca = cells([b for v in ps.values() for b, _ in v]), cells([a for v in ps.values() for _, a in v])
    for faction, way in (("gangs", -1), ("syndicate", +1)):
        wb = 100 * cb[("blob", "cpu", faction)][0] / max(1, cb[("blob", "cpu", faction)][1])
        wa = 100 * ca[("blob", "cpu", faction)][0] / max(1, ca[("blob", "cpu", faction)][1])
        ok = (wa - wb) * way > 0
        verdict.append(ok)
        print(f"BAR_B2S DECIDING blob v a {faction} CPU {wb:.0f} -> {wa:.0f} % ({'toward' if ok else 'NOT toward'} the line mean) -> "
              f"{'pass' if ok else 'FAIL'}")

    def share(line):
        return lambda pairs: 100 * sum((a["winner"] == a["side"]) - (b["winner"] == b["side"]) for b, a in pairs) / len(pairs)

    for g, line in (("G1", "blob"), ("G2", "turtle")):
        d, se, n = _change(_paired_seeds(lines_b, lines_a, lambda f, line=line: f["guard"] == line), share(line))
        judge(f"{g} {line} line guard win share (not up)", d, se, n, lambda d, se: d > 2 * se)
    # G3: median length a line within +/-15 %, a guard faction within +/-20 % (a median ratio; se by the same bootstrap).
    for line in ("blob", "turtle"):
        keep = lambda f, line=line: f["guard"] == line
        ratio = lambda pairs: 100 * (_median([a["seconds"] for _, a in pairs]) / _median([b["seconds"] for b, _ in pairs]) - 1)
        d, se, n = _change(_paired_seeds(lines_b, lines_a, keep), ratio)
        judge(f"G3 {line} median length % (within 15)", d, se, n, lambda d, se: abs(d) > 15 and abs(d) > 2 * se)
        for faction in FACTIONS:
            kf = lambda f, line=line, faction=faction: f["guard"] == line and f["factions"][f["side"]] == faction
            d, se, n = _change(_paired_seeds(lines_b, lines_a, kf), ratio)
            judge(f"G3 {line} {faction} median length % (within 20)", d, se, n, lambda d, se: abs(d) > 20 and abs(d) > 2 * se)
    capped = lambda pairs: 100 * sum((a["reason"] in ("time_limit", "cap")) - (b["reason"] in ("time_limit", "cap"))
                                      for b, a in pairs) / len(pairs)
    d, se, n = _change(ps, capped)
    judge("G4 time-cap share (not up)", d, se, n, lambda d, se: d > 2 * se)
    pn = _paired_seeds(none_b, none_a)
    if pn:
        d, se, n = _change(pn, flat_change)
        judge("G5 none line flatness (not worse)", d, se, n, lambda d, se: d > 2 * se)
    else:
        print("BAR_B2S G5 none line: NOT READ")
        verdict.append(False)
    mb, ma = read_mono(root, f"{base_c}-mono-"), read_mono(root, f"{arm_c}-mono-")
    mp = defaultdict(list)
    for k, a in ma.items():
        if k in mb:
            mp[k[3]].append((mb[k]["mono_won"], a["mono_won"]))
    if mp:
        d, se, n = _change(mp, lambda xs: 100 * sum(a - b for b, a in xs) / len(xs))
        judge("G8 mono-tank line win share (not up)", d, se, n, lambda d, se: d > 2 * se)
    else:
        print("BAR_B2S G8 mono line: NOT READ")
        verdict.append(False)
    print("BAR_B2S G6 perf / G7 full check: read from ARM's check (not here)")
    print(f"BAR_B2S VERDICT {'PASS' if all(verdict) else 'FAIL'} ({sum(verdict)} of {len(verdict)} rules hold)")
    return 0 if all(verdict) else 1


# ---- Bar B5 (round 41; DRAFT in the brief until filed): the verdict, one line a rule ---------------------------------

def bar_b5(root: Path, base_c: str, arm_c: str) -> int:
    """Judge Bar B5 from guard.sh folders <commit>-lines (blob + turtle, both sides) and <commit>-mono-<faction>-<team>
    (the mono-tank line) under `root`. Deciding: the all-tank army's win share v its own faction's mixed deal DOWN by > 2
    paired se. Guards as Bar B2s's G1-G4 on the lines, G5 = the lines' flatness not worse (the faction table kept)."""
    verdict = []

    def judge(name, d, se, n, fail_if, note=""):
        bad = fail_if(d, se)
        verdict.append(not bad)
        print(f"BAR_B5 {name:42} {d:+7.2f} se {se:5.2f} (n {n}) -> {'FAIL' if bad else 'pass'} {note}")

    mb, ma = read_mono(root, f"{base_c}-mono-"), read_mono(root, f"{arm_c}-mono-")
    mp = defaultdict(list)
    for k, a in ma.items():
        if k in mb:
            mp[k[3]].append((mb[k]["mono_won"], a["mono_won"]))
    if mp:
        allp = [p for v in mp.values() for p in v]
        wb, wa = 100 * sum(b for b, _ in allp) / len(allp), 100 * sum(a for _, a in allp) / len(allp)
        print(f"BAR_B5 mono-tank wins base {wb:.0f} -> arm {wa:.0f} % (target 35-40; gap {wa - 40:+.0f} to 40)")
        d, se, n = _change(mp, lambda xs: 100 * sum(a - b for b, a in xs) / len(xs))
        judge("DECIDING mono-tank win share (down > 2 se)", d, se, n, lambda d, se: not d < -2 * se)
        for faction in FACTIONS:
            fp = {seed: [(mb[k]["mono_won"], ma[k]["mono_won"]) for k in ma if k[0] == faction and k[3] == seed and k in mb]
                  for seed in mp}
            fp = {k: v for k, v in fp.items() if v}
            if fp:
                d, se, n = _change(fp, lambda xs: 100 * sum(a - b for b, a in xs) / len(xs))
                fa = [ma[k]["mono_won"] for k in ma if k[0] == faction and k in mb]
                print(f"BAR_B5   {faction:10} mono wins {100 * sum(fa) / len(fa):3.0f} % arm, change {d:+.1f} se {se:.1f} (n {n})")
    else:
        print("BAR_B5 DECIDING mono line: NOT READ")
        verdict.append(False)
    lines_b, lines_a = read_fights([root / f"{base_c}-lines"]), read_fights([root / f"{arm_c}-lines"])
    ps = _paired_seeds(lines_b, lines_a)
    if not ps:
        print("BAR_B5 G1-G5 lines: NOT READ")
        verdict.append(False)
    else:
        def share(line):
            return lambda pairs: 100 * sum((a["winner"] == a["side"]) - (b["winner"] == b["side"]) for b, a in pairs) / len(pairs)

        for g, line in (("G1", "blob"), ("G2", "turtle")):
            d, se, n = _change(_paired_seeds(lines_b, lines_a, lambda f, line=line: f["guard"] == line), share(line))
            judge(f"{g} {line} line guard win share (not up)", d, se, n, lambda d, se: d > 2 * se)
        for line in ("blob", "turtle"):
            keep = lambda f, line=line: f["guard"] == line
            ratio = lambda pairs: 100 * (_median([a["seconds"] for _, a in pairs]) / _median([b["seconds"] for b, _ in pairs]) - 1)
            d, se, n = _change(_paired_seeds(lines_b, lines_a, keep), ratio)
            judge(f"G3 {line} median length % (within 15)", d, se, n, lambda d, se: abs(d) > 15 and abs(d) > 2 * se)
            for faction in FACTIONS:
                kf = lambda f, line=line, faction=faction: f["guard"] == line and f["factions"][f["side"]] == faction
                d, se, n = _change(_paired_seeds(lines_b, lines_a, kf), ratio)
                judge(f"G3 {line} {faction} median length % (within 20)", d, se, n, lambda d, se: abs(d) > 20 and abs(d) > 2 * se)
        capped = lambda pairs: 100 * sum((a["reason"] in ("time_limit", "cap")) - (b["reason"] in ("time_limit", "cap"))
                                          for b, a in pairs) / len(pairs)
        d, se, n = _change(ps, capped)
        judge("G4 time-cap share (not up)", d, se, n, lambda d, se: d > 2 * se)
        flat_change = lambda pairs: flatness([a for _, a in pairs]) - flatness([b for b, _ in pairs])
        d, se, n = _change(ps, flat_change)
        print(f"BAR_B5 flatness base {flatness([b for v in ps.values() for b, _ in v]):.1f} -> arm "
              f"{flatness([a for v in ps.values() for _, a in v]):.1f}")
        judge("G5 lines flatness (not worse)", d, se, n, lambda d, se: d > 2 * se)
    print("BAR_B5 G6 perf / G7 full check: read from ARM's check (not here)")
    print(f"BAR_B5 VERDICT {'PASS' if all(verdict) else 'FAIL'} ({sum(verdict)} of {len(verdict)} rules hold)")
    return 0 if all(verdict) else 1


# ---- Bar B7 (round 42; FILED in the brief before any number on 9901-9940): the CPU counter-lineup, ON v OFF -------------

B7_SEEDS = range(9901, 9941)
B7_ARENAS = ["terminus", "locks", "sumps", "gorge", "parade"]  # ONE arena a seed: 9901-9908 terminus, 9909-9916 locks, ...
B7_G1_SEEDS = range(9901, 9911)  # G1: CPU v CPU, terminus
MAX_ARMY_UNITS = 45  # game/units/army.gd: a dealt faction army's cap (desktop preset)


def b7_arena(seed: int) -> str:
    return B7_ARENAS[(seed - B7_SEEDS[0]) // 8]


def b7_fights(arm: str) -> list:
    """The fight list of one arm (`off` = BASE, `on` = ARM) for mk/balance.mk's balance-fights-run: the deciding line
    (all-tanks v the plain cpu deal, same faction, mono on each team, one arena a seed) and G1 (two plain CPUs, mirrored)."""
    lines = []
    for f in FACTIONS:
        for team, other in (("player", "enemy"), ("enemy", "player")):
            for seed in B7_SEEDS:
                lines.append(f"b7-{arm}-mono-{f}-{team} {b7_arena(seed)} {seed} --player-faction={f} --enemy-faction={f} "
                             f"--{team}=cpu:mono_tank --{other}=cpu --cpu-counter={arm}")
        for seed in B7_G1_SEEDS:
            lines.append(f"g1-{arm}-{f} terminus {seed} --player-faction={f} --enemy-faction={f} --player=cpu --enemy=cpu "
                         f"--cpu-counter={arm}")
    return lines


def _results(folder: Path) -> dict:
    """arena-seed -> {"result": GUARD_RESULT dict or None, "fielded": (green, rust) or None, "cap": int or None, "counter": n}."""
    out = {}
    for log in sorted((folder / "none").glob("*-green.log")):
        lm = LOG.match(log.name)
        row = {"result": None, "fielded": None, "cap": None, "counter": 0}
        for line in log.read_text(errors="replace").splitlines():
            if line.startswith("GUARD_RESULT "):
                row["result"] = json.loads(line[len("GUARD_RESULT "):])
            elif line.startswith("ARMY_CAP_FIELDED "):
                kv = dict(x.split("=") for x in line.split()[1:])
                row["fielded"] = (int(kv["green"]), int(kv["rust"]))
            elif line.startswith("ARMY_CAP "):
                row["cap"] = int(dict(x.split("=") for x in line.split()[1:] if "=" in x)["units"])
            elif line.startswith("CPU_COUNTER "):
                row["counter"] += 1
        out[(lm["arena"], int(lm["seed"]))] = row
    return out


def bar_b7(root: Path, commit: str, firing: list) -> int:
    """Judge Bar B7 (R42.3, R42.17): DECIDING per faction whose counter fires: ARM <= 60 % AND paired change < 0 by >= 2 se; the
    counter ships ON for each firing faction that passes it (and OFF for the rest) when every guard passes; pooled reported. G1 every CPU v CPU fight identical ON v OFF; G2 median length within +/-20 %; G3 every ARM fight
    loads and fields within its cap. G4 (the tests) is the frozen commit's check."""
    verdict, ships = [], []

    def judge(name, ok, text):
        verdict.append(ok)
        print(f"BAR_B7 {name:34} {text} -> {'pass' if ok else 'FAIL'}")

    base, arm = read_mono(root, f"{commit}-b7-off-"), read_mono(root, f"{commit}-b7-on-")
    print(f"BAR_B7 commit {commit}: BASE --cpu-counter=off {len(base)} fights, ARM on {len(arm)} (expect 320 each); "
          f"firing: {', '.join(firing) or 'none'}")
    lengths = {}
    for faction in FACTIONS + ["fired", "all"]:
        keys = [k for k in arm if k in base and (faction == "all" or faction == k[0] or (faction == "fired" and k[0] in firing))]
        if not keys:
            continue
        share = 100 * sum(arm[k]["mono_won"] for k in keys) / len(keys)
        ps = defaultdict(list)
        for k in keys:
            ps[k[3]].append((base[k]["mono_won"], arm[k]["mono_won"]))
        change = 100 * sum(a - b for v in ps.values() for b, a in v) / len(keys)
        cse = bootstrap(ps, lambda xs: 100 * sum(a - b for b, a in xs) / len(xs))
        bshare = 100 * sum(base[k]["mono_won"] for k in keys) / len(keys)
        text = f"all-tanks {bshare:3.0f} -> {share:3.0f} % (n {len(keys)}), paired {change:+.1f} se {cse:.1f}"
        lengths[faction] = (_median([base[k]["seconds"] for k in keys]), _median([arm[k]["seconds"] for k in keys]))
        if faction in firing:
            ok = share <= 60 and change + 2 * cse < 0
            ships += [faction] if ok else []
            print(f"BAR_B7 {'DECIDING ' + faction:34} {text} (line <= 60 % and < -2 se) -> {'pass: ON' if ok else 'FAIL: stays OFF'}")
        else:
            print(f"BAR_B7 {'reported ' + faction:34} {text}")
    for name in ("fired", "all"):
        if name in lengths and (name == "all" or firing):
            b, a = lengths[name]
            judge(f"G2 median length ({name})", abs(a / b - 1) <= 0.20, f"{b:.0f} -> {a:.0f} s ({100 * (a / b - 1):+.1f} %)")
    same, n, diffs = 0, 0, []
    for f in FACTIONS:
        off, on = _results(root / f"{commit}-g1-off-{f}"), _results(root / f"{commit}-g1-on-{f}") if (root / f"{commit}-g1-on-{f}").is_dir() else {}
        if not (root / f"{commit}-g1-off-{f}").is_dir():
            off = {}
        for k in sorted(set(off) | set(on)):
            n += 1
            ro, ra = (off.get(k) or {}).get("result"), (on.get(k) or {}).get("result")
            key = lambda r: (r["winner"], r["seconds"], r["tanks"]) if r else None
            if ro and ra and key(ro) == key(ra) and on[k]["counter"] == 0:
                same += 1
            else:
                diffs.append(f"{f} {k[0]} s{k[1]}")
    judge("G1 CPU v CPU identical", n == 40 and same == n, f"{same} of {n} identical (expect 40)" + (f": {diffs[:6]}" if diffs else ""))
    # G3 as filed: the COUNTERED (plain cpu) side within its cap. On the desktop preset a dealt faction army's cap is
    # Army.MAX_ARMY_UNITS; ARMY_CAP's `units=` is the player's squads x five, applied only under the ceiling (C25.6), and the
    # all-tanks side is a named lineup, the same ON and OFF. (First run judged max(both sides) <= 25: wrong side, wrong cap.)
    loaded, fielded_ok, fired, total, largest = 0, 0, defaultdict(int), 0, 0
    for d in sorted(root.glob(f"{commit}-b7-on-mono-*")):
        m = MONO_DIR.search(d.name)
        for k, row in _results(d).items():
            total += 1
            loaded += row["result"] is not None and row["fielded"] is not None
            cpu = None if row["fielded"] is None else row["fielded"][1 if m["team"] == "player" else 0]
            fielded_ok += cpu is not None and cpu <= MAX_ARMY_UNITS
            largest = max(largest, cpu or 0)
            fired[m["faction"]] += row["counter"] > 0
    judge("G3 loads and fields", total == 320 and loaded == total and fielded_ok == total,
          f"{loaded} loaded, {fielded_ok} CPU armies within {MAX_ARMY_UNITS} (largest {largest}), of {total} (expect 320)")
    print("BAR_B7 reported: counter fired in " + ", ".join(f"{f} {fired[f]}/80" for f in FACTIONS))
    passed = all(verdict) and ships
    print(f"BAR_B7 VERDICT {'PASS' if passed else 'FAIL'}: guards {sum(verdict)} of {len(verdict)}; "
          f"ships ON for {', '.join(ships) or 'no faction'}" + (f"; stays OFF for {', '.join(f for f in firing if f not in ships)}"
                                                              if any(f not in ships for f in firing) else ""))
    return 0 if passed else 1


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
    p.add_argument("--probe", action="store_true", help="B5: run the fights through tests/tactics/face_probe.gd (FACE lines)")
    p = sub.add_parser("apply")
    p.add_argument("cand", type=Path)
    p.add_argument("--tree", type=Path, default=ROOT,
                   help="the checkout to write into (default: this script's own tree, NOT the current directory: round 41 wrote "
                        "a dry run into stream/balance's working tree that way)")
    p = sub.add_parser("bar")
    p.add_argument("root", type=Path)
    p.add_argument("base_commit")
    p.add_argument("arm_commit")
    p = sub.add_parser("bar-b5")
    p.add_argument("root", type=Path)
    p.add_argument("base_commit")
    p.add_argument("arm_commit")
    p = sub.add_parser("b7-lists")
    p.add_argument("out", type=Path, help="writes b7-off.txt and b7-on.txt (tools/balance/fights.sh lists) here")
    p = sub.add_parser("bar-b7")
    p.add_argument("root", type=Path)
    p.add_argument("commit")
    p.add_argument("--firing", default="", help="the factions whose counter fires (R42.3), comma-separated")
    p = sub.add_parser("mono")
    p.add_argument("root", type=Path, help="the folder holding <commit>-<tag>mono-<faction>-<player|enemy>/ runs")
    p.add_argument("--match", default="", help="only folders whose name contains this (e.g. -mono-base-)")
    p.add_argument("--base-match", help="pair with the folders whose name contains this")
    p = sub.add_parser("faces")
    p.add_argument("root", type=Path, help="the folder holding <commit>-<tag>mono-<faction>-<player|enemy>/ runs (face-probed)")
    p.add_argument("--match", default="")
    p.add_argument("--base-match")
    p = sub.add_parser("score")
    p.add_argument("raw", nargs="+", type=Path)
    p.add_argument("--base", nargs="+", type=Path)
    p.add_argument("--json", type=Path)
    args = ap.parse_args(argv)

    if args.cmd == "bar":
        return bar(args.root, args.base_commit, args.arm_commit)
    if args.cmd == "bar-b5":
        return bar_b5(args.root, args.base_commit, args.arm_commit)
    if args.cmd == "b7-lists":
        args.out.mkdir(parents=True, exist_ok=True)
        for arm in ("off", "on"):
            (args.out / f"b7-{arm}.txt").write_text("\n".join(b7_fights(arm)) + "\n")
        print(f"b7-lists: {len(b7_fights('off'))} fights an arm -> {args.out}")
        return 0
    if args.cmd == "bar-b7":
        return bar_b7(args.root, args.commit, [f for f in args.firing.split(",") if f])
    if args.cmd == "mono":
        mono_report(args.root, args.match, args.base_match)
        return 0
    if args.cmd == "faces":
        faces_report(args.root, args.match, args.base_match)
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
        tree = args.tree.resolve()
        print(f"apply: writing into {tree}")
        print("\n".join(apply(cand, tree / "game/units/units.gd", tree / "game/combat/weapons.gd")))
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
    driver = ROOT / ("tools/balance/guard_probe.sh" if args.probe else "tools/scoreboard/guard.sh")
    # Round 42: a series pauses at its next leg (another stream's turn on the builder) while this file exists.
    pause = Path(os.environ.get("BALANCE_PAUSE", str(Path.home() / "balance-runs/PAUSE")))
    if pause.exists():
        print(f"run: paused while {pause} exists", flush=True)
        while pause.exists():
            time.sleep(30)
        print("run: resumed", flush=True)
    return subprocess.call(["bash", str(driver), args.commit], env=env, cwd=ROOT)

if __name__ == "__main__":
    sys.exit(main())
