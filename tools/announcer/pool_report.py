"""How deep each of the booth's pools is, and how deep it needs to be (round 10, backlog item 1; research rows C9, C10).

Selection variety is bounded by pool size per (speaker, moment): the director can only vary what the library gives it
for the moment in front of it. This prints, per (speaker, moment):

  lines      library lines the moment can ever reach for that speaker (its kind tag, an act its beats ask for)
  λ/min      how often that speaker actually speaks at that moment, per match minute, over the fixture broadcasts
  pool       the director's candidate count when it picked (mean), and `eff`, the effective count (exp of the pick's
             entropy: eight lines where one carries the weight is about one); `min eff` is the narrowest pick seen
  starved    picks that found no unused line and skipped the step
  N_c        the pool the C9 formula wants: ⌈λ·τ⌉ + ⌈λ·T / −ln(1 − R)⌉ (τ the moment's cooldown, T the role's memory
             horizon, R the repeat-perception rate we accept)
  target     max(the brief's floor, N_c capped at CAP): the number the generation plan works towards
  deficit    target minus the smaller of `lines` and the mean pool at the pick
  d2         Distinct-2 over the pool's texts (unique word pairs / all pairs): low means the lines share a template

and then the narrow funnels: a specific tag set on the chosen line that fires often from few library lines.

The dynamic columns need the director's cues: `make announcer-pool-report` runs the CLI over every fixture for several
seeds first. Without --cues only the static columns print.
"""

from __future__ import annotations

import argparse
import collections
import glob
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LINES = os.path.join(ROOT, "assets", "announcer", "lines.json")
BEATS = os.path.join(ROOT, "assets", "announcer", "beats.json")

## The repeat-perception rate we accept (C9: 0.05).
REPEAT_RATE = 0.05
## Each role's memory horizon in minutes (C9). The caller's hype fades in 90-180 s; the Veteran's analysis is
## recognised across 5-10 min; the PA's one wrong detail is remembered across sessions, so her horizon is a whole
## evening of matches rather than one. These are the knobs of the formula, not measurements.
HORIZON_MIN = {"caller": 2.0, "color": 7.5, "pa": 30.0}
## The brief's floors: every caller and colour moment ≥ 12 lines, every PA moment ≥ 8, deep pools +25 %.
FLOOR = {"caller": 12, "color": 12, "pa": 8}
DEEP = 18
DEEP_GROWTH = 1.25
## N_c for a busy moment is in the hundreds (the PA's horizon especially); the plan caps what it asks of one pool so
## the round's credits spread over every thin moment first. A pool at the cap is "deep enough for this round". The PA's
## cap is lower: her lines are the hardest to write well (one wrong detail each, never the same kind twice in a pool),
## and a mass-produced wrong detail is the joke the lead told us to cut.
CAP = {"caller": 40, "color": 40, "pa": 24}
WORD = re.compile(r"\{[a-z_]+\}|[a-z']+")


def load(path: str) -> dict:
    with open(path) as handle:
        return json.load(handle)


def moment_acts(beats: dict) -> dict:
    """moment kind -> speaker -> acts its beats can ask that speaker for."""
    found: dict = {}
    for kind, config in beats["moments"].items():
        per = found.setdefault(kind, {})
        for beat in config.get("beats", []):
            for step in beat["steps"]:
                acts = step["act"] if isinstance(step["act"], list) else [step["act"]]
                per.setdefault(step["speaker"], set()).update(acts)
        # A caller cutting in ("hold on!") can open any interruptible beat.
        per.setdefault("caller", set()).add("interrupt")
    return found


def line_kinds(line: dict, kinds: set) -> list:
    """The moment kinds a line names (["any"] for lines that fit every moment)."""
    named = [tag for tag in line.get("tags", []) if tag in kinds]
    return named or (["any"] if "any" in line.get("tags", []) else [])


def static_pools(lines: list, beats: dict) -> dict:
    """(speaker, moment) -> the library lines that moment can reach for that speaker."""
    kinds = set(beats["moments"])
    acts = moment_acts(beats)
    pools: dict = collections.defaultdict(list)
    for line in lines:
        for kind in line_kinds(line, kinds):
            targets = kinds if kind == "any" else [kind]
            for moment in targets:
                if line["act"] in acts.get(moment, {}).get(line["speaker"], set()):
                    # "any" lines (the caller's interrupts) are counted once, under the moment they fit, not in every
                    # pool: they are shared, and would make every pool look deeper than it is.
                    if kind == "any" and line["act"] == "interrupt":
                        continue
                    pools[(line["speaker"], moment)].append(line)
    return pools


def distinct_2(texts: list) -> float:
    """Unique word pairs over all word pairs: 1.0 means no two lines share a phrase."""
    pairs = []
    for text in texts:
        words = WORD.findall(text.lower())
        pairs.extend(zip(words, words[1:]))
    return len(set(pairs)) / len(pairs) if pairs else 1.0


def n_c(rate: float, cooldown_min: float, horizon_min: float, repeat_rate: float = REPEAT_RATE) -> int:
    """C9: the pool a moment needs so a listener hears a repeat with probability ≤ repeat_rate."""
    if rate <= 0:
        return 0
    return math.ceil(rate * cooldown_min) + math.ceil(rate * horizon_min / -math.log(1.0 - repeat_rate))


def target(speaker: str, current: int, needed: int, used: bool = True) -> int:
    """The pool size the plan works towards. A moment the fixtures never reach for this speaker gets only its floor:
    a deep pool nobody hears is credits spent on silence."""
    floor = FLOOR[speaker]
    if current >= DEEP and used:
        floor = max(floor, math.ceil(current * DEEP_GROWTH))
    return max(floor, min(needed, CAP[speaker]))


def read_runs(folder: str) -> list:
    runs = []
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        data = load(path)
        if "cues" in data and "events" in data:
            runs.append(data)
    return runs


STARVED = re.compile(r"skip (\w+) \(.*\): no unused (\w+) line")


def dynamic_stats(runs: list, lines_by_id: dict) -> tuple:
    """(speaker, moment) -> {n, pools, fresh, effective, starved}; total match minutes; funnels."""
    stats: dict = collections.defaultdict(lambda: {"n": 0, "pool": [], "fresh": [], "effective": [], "starved": 0})
    minutes = 0.0
    funnels: dict = collections.Counter()
    for run in runs:
        minutes += float(run["events"][-1].get("duration_seconds", run["events"][-1]["t"])) / 60.0
        for cue in run["cues"]:
            entry = stats[(cue["speaker"], cue["moment"])]
            entry["n"] += 1
            pool = cue.get("pool", {})
            if pool:
                entry["pool"].append(pool["pool"])
                entry["fresh"].append(pool["fresh"])
                entry["effective"].append(pool["effective"])
            line = lines_by_id.get(cue["line_id"], {})
            specific = tuple(sorted(tag for tag in line.get("tags", []) if tag != cue["moment"] and tag != "any"))
            if specific:
                funnels[(cue["speaker"], cue["moment"], specific)] += 1
        for decision in run.get("decisions", []):
            found = STARVED.search(decision["text"])
            if found:
                stats[(found.group(2), found.group(1))]["starved"] += 1
    return stats, minutes, funnels


def mean(values: list) -> float:
    return sum(values) / len(values) if values else 0.0


def build(lines_data: dict, beats: dict, runs: list) -> dict:
    lines = lines_data["lines"]
    by_id = {line["id"]: line for line in lines}
    pools = static_pools(lines, beats)
    stats, minutes, funnels = dynamic_stats(runs, by_id)
    rows = []
    keys = set(pools) | {key for key in stats if stats[key]["n"] or stats[key]["starved"]}
    for speaker, moment in sorted(keys):
        pool = pools.get((speaker, moment), [])
        entry = stats.get((speaker, moment), {"n": 0, "pool": [], "fresh": [], "effective": [], "starved": 0})
        rate = entry["n"] / minutes if minutes else 0.0
        cooldown_min = float(beats["moments"].get(moment, {}).get("cooldown_s") or 0.0) / 60.0
        needed = n_c(rate, cooldown_min, HORIZON_MIN[speaker])
        # A pool can be deep on paper and narrow at the pick (army lines are per unit and faction), so the target and
        # the deficit are measured against whichever is smaller: the library count or the mean pool the director
        # actually saw.
        base = min(len(pool), round(mean(entry["pool"]))) if entry["pool"] else len(pool)
        goal = target(speaker, base, needed, entry["n"] > 0)
        rows.append({"speaker": speaker, "moment": moment, "lines": len(pool), "rate_per_min": round(rate, 3),
                     "uses": entry["n"], "pool_mean": round(mean(entry["pool"]), 2),
                     "fresh_mean": round(mean(entry["fresh"]), 2), "effective_mean": round(mean(entry["effective"]), 2),
                     "effective_min": round(min(entry["effective"]), 2) if entry["effective"] else None,
                     "starved": entry["starved"], "n_c": needed, "target": goal,
                     "deficit": max(0, goal - base), "distinct_2": round(distinct_2([l["text"] for l in pool]), 3)})
    library_count = collections.Counter()
    for line in lines:
        library_count[(line["speaker"], tuple(sorted(line.get("tags", []))))] += 1
    narrow = []
    matches = len(runs) or 1
    for (speaker, moment, tags), uses in funnels.items():
        # Library lines that carry every one of these tags for this speaker and moment.
        have = sum(1 for line in pools.get((speaker, moment), []) if set(tags) <= set(line.get("tags", [])))
        per_match = uses / matches
        if have and per_match / have >= 0.25:
            narrow.append({"speaker": speaker, "moment": moment, "tags": list(tags), "lines": have,
                           "uses_per_match": round(per_match, 2), "pressure": round(per_match / have, 2)})
    narrow.sort(key=lambda row: -row["pressure"])
    return {"lines": len(lines), "runs": len(runs), "match_minutes": round(minutes, 2),
            "knobs": {"repeat_rate": REPEAT_RATE, "horizon_min": HORIZON_MIN, "floor": FLOOR, "deep": DEEP,
                      "deep_growth": DEEP_GROWTH, "cap": CAP},
            "rows": rows, "funnels": narrow,
            "deficit_total": sum(row["deficit"] for row in rows)}


def render(report: dict) -> str:
    out = [f"POOL REPORT: {report['lines']} lines; {report['runs']} broadcasts, {report['match_minutes']} match minutes",
           f"  N_c knobs: R={report['knobs']['repeat_rate']}, horizon (min) {report['knobs']['horizon_min']}, "
           f"cap {report['knobs']['cap']}; floors {report['knobs']['floor']}, deep pools (≥{report['knobs']['deep']}) "
           f"×{report['knobs']['deep_growth']}",
           "",
           f"{'speaker':7} {'moment':14} {'lines':>5} {'λ/min':>6} {'uses':>5} {'pool':>5} {'eff':>5} {'min eff':>7} "
           f"{'starved':>7} {'N_c':>5} {'target':>6} {'deficit':>7} {'d2':>5}"]
    for row in sorted(report["rows"], key=lambda r: (-r["deficit"], r["speaker"], r["moment"])):
        low = "" if row["effective_min"] is None else f"{row['effective_min']:.1f}"
        out.append(f"{row['speaker']:7} {row['moment']:14} {row['lines']:5d} {row['rate_per_min']:6.2f} {row['uses']:5d} "
                   f"{row['pool_mean']:5.1f} {row['effective_mean']:5.1f} {low:>7} {row['starved']:7d} {row['n_c']:5d} "
                   f"{row['target']:6d} {row['deficit']:7d} {row['distinct_2']:5.2f}")
    out.append("")
    out.append(f"deficit: {report['deficit_total']} lines to reach every target")
    if report["funnels"]:
        out.append("")
        out.append("narrow funnels (a specific tag set firing often from few lines; pressure = uses per match per line):")
        for row in report["funnels"][:20]:
            out.append(f"  {row['speaker']:7} {row['moment']:14} [{', '.join(row['tags'])}] {row['lines']} lines, "
                       f"{row['uses_per_match']:.2f} uses/match, pressure {row['pressure']:.2f}")
    return "\n".join(out) + "\n"


def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--lines", default=LINES)
    parser.add_argument("--beats", default=BEATS)
    parser.add_argument("--cues", help="a folder of the announcer CLI's per-broadcast JSON (make announcer-pool-report)")
    parser.add_argument("--json", help="also write the report as JSON here (the review page reads it)")
    args = parser.parse_args(argv)
    runs = read_runs(args.cues) if args.cues else []
    report = build(load(args.lines), load(args.beats), runs)
    print(render(report), end="")
    if args.json:
        with open(args.json, "w") as handle:
            json.dump(report, handle, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
