#!/usr/bin/env python3
"""Round 37 (CP37.1, native): read the guard lines from `make guard-run` logs.

    python3 tools/scoreboard/guard.py RAW [RAW2 ...] [--json]

RAW is a guard-run output folder (build/guards/ or a copy: <kind>/<arena>-<seed>-<side>.log, each with one GUARD_RESULT
line). Several RAWs are seed blocks of ONE main (2601+, 2701+): their fights pool into the line, and the noise is sized
from the seed-to-seed spread across all of them (a "seed unit" = one seed's fights over every arena and both sides).

Per line (blob, turtle, none): fights read, the guard's win / loss / draw share, the share capped at the time limit (won on
points), its kill ratio (its kills / its losses, totals), its zone-point margin (guard minus tactics, per fight), match
length; per faction (the guard's). Noise: each statistic's sd across seed units -> se = sd / sqrt(units) -> "± 2 se of a
difference" = 2 * sqrt(2) * se, the scoreboard's ± column (references/scoreboard/README.md).
"""
import argparse
import glob
import json
import math
import os
import re
import sys

NAME = re.compile(r"^(?P<arena>[a-z_]+)-(?P<seed>\d+)-(?P<side>green|rust)\.log$")


def read(roots):
    fights = []
    for root in roots:
        for path in sorted(glob.glob(os.path.join(root, "*", "*.log"))):
            m = NAME.match(os.path.basename(path))
            if not m:
                continue
            result = None
            with open(path, errors="replace") as f:
                for line in f:
                    if line.startswith("GUARD_RESULT "):
                        result = json.loads(line[len("GUARD_RESULT "):])
            kind = os.path.basename(os.path.dirname(path))
            fights.append({"kind": kind, "arena": m["arena"], "seed": int(m["seed"]), "side": m["side"], "r": result,
                           "path": path})
    return fights


def stats_of(rows):
    """The line's numbers over `rows` (fights that printed a result)."""
    n = len(rows)
    if n == 0:
        return {"n": 0}
    won = sum(1 for f in rows if f["r"]["role"] == "guard")
    lost = sum(1 for f in rows if f["r"]["role"] == "tactics")
    capped = sum(1 for f in rows if f["r"]["reason"] == "cap")
    kills = sum(_mine(f, "kills") for f in rows)
    losses = sum(_mine(f, "losses") for f in rows)
    margin = sum(_margin(f) for f in rows) / n
    seconds = sorted(float(f["r"]["seconds"]) for f in rows)
    return {"n": n, "win": won / n, "loss": lost / n, "draw": (n - won - lost) / n, "capped": capped / n,
            "kills": kills, "losses": losses, "kill_ratio": kills / losses if losses else None,
            "margin": margin, "median_s": seconds[n // 2]}


def _side(f):
    return f["r"]["side"].lower()  # the probe prints Match.TEAM_NAMES ("Green"); kills / losses / control are keyed lower case


def _other(f):
    return "rust" if _side(f) == "green" else "green"


def _mine(f, key):
    return int(f["r"][key][_side(f)])


def _margin(f):
    control = f["r"].get("control") or {}
    return float(control.get(_side(f), 0)) - float(control.get(_other(f), 0))


def guard_faction(f):
    factions = {k.lower(): v for k, v in (f["r"].get("factions") or {}).items()}
    return factions.get(_side(f), "?")


def pairing(f):
    """The seed's faction pair as "guard v tactics" (Syndicate v Law reads apart from Law v Syndicate)."""
    factions = {k.lower(): v for k, v in (f["r"].get("factions") or {}).items()}
    return "%s v %s" % (factions.get(_side(f), "?"), factions.get(_other(f), "?"))


def noise(rows):
    """2 se of a difference for win share, kill ratio and margin, from the per-seed spread (None under 2 seeds)."""
    by_seed = {}
    for f in rows:
        by_seed.setdefault(f["seed"], []).append(f)
    units = [stats_of(v) for v in by_seed.values()]
    out = {"seeds": len(units)}
    for key in ("win", "kill_ratio", "margin", "capped"):
        values = [u[key] for u in units if u.get(key) is not None]
        if len(values) < 2:
            out[key] = None
            continue
        mean = sum(values) / len(values)
        sd = math.sqrt(sum((v - mean) ** 2 for v in values) / (len(values) - 1))
        out[key] = 2.0 * math.sqrt(2.0) * sd / math.sqrt(len(values))
    return out


def lines(fights):
    report = {}
    for kind in sorted({f["kind"] for f in fights}):
        all_rows = [f for f in fights if f["kind"] == kind]
        rows = [f for f in all_rows if f["r"] is not None]
        line = {"run": len(all_rows), "read": len(rows), "all": stats_of(rows), "noise": noise(rows),
                "missing": [os.path.basename(f["path"]) for f in all_rows if f["r"] is None]}
        line["by_faction"] = {fac: stats_of([f for f in rows if guard_faction(f) == fac])
                              for fac in sorted({guard_faction(f) for f in rows})}
        line["by_pairing"] = {p: stats_of([f for f in rows if pairing(f) == p]) for p in sorted({pairing(f) for f in rows})}
        line["by_side"] = {side: stats_of([f for f in rows if f["side"] == side]) for side in ("green", "rust")}
        line["by_arena"] = {a: stats_of([f for f in rows if f["arena"] == a]) for a in sorted({f["arena"] for f in rows})}
        report[kind] = line
    return report


def _pct(x):
    return "n/a" if x is None else "%d %%" % round(100 * x)


def _num(x, digits=2):
    return "n/a" if x is None else ("%." + str(digits) + "f") % x


def render(report):
    out = []
    for kind, line in report.items():
        a, nz = line["all"], line["noise"]
        who = {"blob": "the blob", "turtle": "the turtle", "none": "Green (CPU v CPU)"}.get(kind, kind)
        out.append("%s: %d of %d fights read" % (kind.upper(), line["read"], line["run"]))
        if a["n"] == 0:
            continue
        out.append("  %s wins %s (± %s), loses %s, draws %s; capped %s (± %s)" % (who, _pct(a["win"]), _pct(nz["win"]),
                   _pct(a["loss"]), _pct(a["draw"]), _pct(a["capped"]), _pct(nz["capped"])))
        out.append("  kill ratio %s (± %s; %d kills / %d losses); zone margin %s points a fight (± %s); median %s s" % (
            _num(a["kill_ratio"]), _num(nz["kill_ratio"]), a["kills"], a["losses"], _num(a["margin"], 1),
            _num(nz["margin"], 1), _num(a["median_s"], 0)))
        for group in ("by_faction", "by_pairing", "by_side", "by_arena"):
            parts = ["%s %s win, kr %s (n %d)" % (k, _pct(v["win"]), _num(v["kill_ratio"]), v["n"])
                     for k, v in line[group].items() if v["n"]]
            out.append("  %s: %s" % (group.replace("_", " "), "; ".join(parts)))
        if line["missing"]:
            out.append("  MISSING: %s" % ", ".join(line["missing"]))
        out.append("  noise from %d seeds (2 se of a difference between two mains)" % nz["seeds"])
    return "\n".join(out)


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("raw", nargs="+")
    p.add_argument("--json", action="store_true")
    args = p.parse_args(argv)
    report = lines(read(args.raw))
    print(json.dumps(report, indent=1, sort_keys=True) if args.json else render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
