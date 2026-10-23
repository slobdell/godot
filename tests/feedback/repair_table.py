#!/usr/bin/env python3
"""Round 38 (feedback F3, C38.4): the Tanker repairs under fire, read off the guard fights.

    python3 tests/feedback/repair_table.py BASE ARM [--json]

BASE and ARM are tools/scoreboard/guard.sh output folders (<kind>/<arena>-<seed>-<side>.log) of the same commit and seeds, run
with GUARD_ARGS="--repair-report" (base) and "--repair-under-fire --repair-report" (arm). Each log holds GUARD_RESULT (native's
guard_line.gd) and MATCH_MENDED (Match._exit_tree under --repair-report). Fights pair on (kind, arena, seed, side).

Deciding (the bar in _agents/streams/feedback.md): hp mended per fight by the GANG side (the faction with the Resupply Tanker),
base -> arm, paired, se from per-seed differences. Guards: per faction (the guard's faction), the guard's win share base -> arm,
kills per fight and fight length; tools/scoreboard/guard.py --pair BASE ARM gives each line's McNemar p.
"""
import argparse
import glob
import json
import math
import os
import re
import sys

NAME = re.compile(r"^(?P<arena>[a-z_]+)-(?P<seed>\d+)-(?P<side>green|rust)\.log$")
GANGS = "gangs"


def read(root):
    fights = {}
    for path in sorted(glob.glob(os.path.join(root, "*", "*.log"))):
        m = NAME.match(os.path.basename(path))
        if not m:
            continue
        result, mended = None, None
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("GUARD_RESULT "):
                    result = json.loads(line[len("GUARD_RESULT "):])
                elif line.startswith("MATCH_MENDED "):
                    mended = json.loads(line[len("MATCH_MENDED "):])
        kind = os.path.basename(os.path.dirname(path))
        fights[(kind, m["arena"], int(m["seed"]), m["side"])] = {"r": result, "m": mended}
    return fights


def factions(r):
    return {k.lower(): v for k, v in (r.get("factions") or {}).items()}


def gang_mended(f, key="hp_mended"):
    """hp mended by the gang team(s) in this fight, or None when no side is the gangs."""
    fac = factions(f["r"])
    teams = [i for i, side in enumerate(["green", "rust"]) if fac.get(side) == GANGS]
    if not teams or f["m"] is None:
        return None
    return sum(float(f["m"][key][i]) for i in teams)


def mean(values):
    return sum(values) / len(values) if values else None


def se_of(values):
    if len(values) < 2:
        return None
    mu = mean(values)
    return math.sqrt(sum((v - mu) ** 2 for v in values) / (len(values) - 1)) / math.sqrt(len(values))


def table(base, arm):
    keys = sorted(k for k in arm if k in base and arm[k]["r"] and base[k]["r"])
    out = {"paired": len(keys), "missing_mended": sum(1 for k in keys if arm[k]["m"] is None or base[k]["m"] is None)}
    # Deciding: gang hp mended a fight.
    rows = [(k, gang_mended(base[k]), gang_mended(arm[k]), gang_mended(arm[k], "hp_mended_under_fire")) for k in keys]
    rows = [r for r in rows if r[1] is not None and r[2] is not None]
    per_seed = {}
    for k, b, a, _ in rows:
        per_seed.setdefault(k[2], []).append(a - b)
    seed_means = [mean(v) for v in per_seed.values()]
    out["deciding"] = {"gang_fights": len(rows), "base_mean": mean([r[1] for r in rows]), "arm_mean": mean([r[2] for r in rows]),
                       "arm_under_fire_mean": mean([r[3] for r in rows]), "diff": mean([r[2] - r[1] for r in rows]),
                       "diff_se_seeds": se_of(seed_means), "seeds": len(per_seed),
                       "up": sum(1 for r in rows if r[2] > r[1]), "down": sum(1 for r in rows if r[2] < r[1])}
    # Guards per guard faction and line.
    guards = {}
    for k in keys:
        b, a = base[k]["r"], arm[k]["r"]
        fac = factions(b).get(k[3], "?")
        g = guards.setdefault("%s %s" % (k[0], fac), {"n": 0, "base_win": 0, "arm_win": 0, "flip_win": 0, "flip_loss": 0,
                                                      "base_kills": 0.0, "arm_kills": 0.0, "base_s": [], "arm_s": []})
        g["n"] += 1
        bw, aw = b["role"] == "guard", a["role"] == "guard"
        g["base_win"] += bw
        g["arm_win"] += aw
        g["flip_win"] += aw and not bw
        g["flip_loss"] += bw and not aw
        g["base_kills"] += sum(b["kills"].values())
        g["arm_kills"] += sum(a["kills"].values())
        g["base_s"].append(float(b.get("seconds") or 0.0))
        g["arm_s"].append(float(a.get("seconds") or 0.0))
    for g in guards.values():
        g["base_s"] = sorted(g["base_s"])[len(g["base_s"]) // 2]
        g["arm_s"] = sorted(g["arm_s"])[len(g["arm_s"]) // 2]
        n = g["flip_win"] + g["flip_loss"]
        # Exact one-sided p that the arm made this guard WIN more (the gangs must not start winning).
        g["p_more_wins"] = sum(math.comb(n, i) for i in range(g["flip_win"], n + 1)) / 2.0 ** n if n else 1.0
    out["guards"] = guards
    return out


def render(t):
    d = t["deciding"]
    lines = ["paired fights %d (MATCH_MENDED missing in %d)" % (t["paired"], t["missing_mended"]),
             "DECIDING gang hp mended a fight: base %.1f -> arm %.1f (under fire %.1f); diff %+.1f, se %s over %d seeds; "
             "up %d, down %d of %d gang fights" % (d["base_mean"] or 0, d["arm_mean"] or 0, d["arm_under_fire_mean"] or 0,
                                                   d["diff"] or 0, "%.1f" % d["diff_se_seeds"] if d["diff_se_seeds"] else "n/a",
                                                   d["seeds"], d["up"], d["down"], d["gang_fights"]),
             "GUARDS (the guard's faction): wins base -> arm, flips to a win / a loss, p(arm wins more), kills/fight, median s"]
    for name, g in sorted(t["guards"].items()):
        lines.append("  %-20s n %3d  wins %3d -> %3d  flips +%d/-%d  p %.3f  kills %.1f -> %.1f  len %.0f -> %.0f" % (
            name, g["n"], g["base_win"], g["arm_win"], g["flip_win"], g["flip_loss"], g["p_more_wins"],
            g["base_kills"] / g["n"], g["arm_kills"] / g["n"], g["base_s"], g["arm_s"]))
    return "\n".join(lines)


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("base")
    p.add_argument("arm")
    p.add_argument("--json", action="store_true")
    a = p.parse_args(argv)
    t = table(read(a.base), read(a.arm))
    print(json.dumps(t, indent=1, sort_keys=True) if a.json else render(t))
    return 0


if __name__ == "__main__":
    sys.exit(main())
