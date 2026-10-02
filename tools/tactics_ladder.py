#!/usr/bin/env python3
"""Tactics ladder (round-5 ai X3, _agents/unit_ai.md "Tactics ladder"): doctrine variants, brain variants and arenas,
played against each other in seeded headless matches, with an ELO table and a report PER DRILL.

A side is "<label>=<brain>[:<doctrine table>[-drill...][+commander]]" (e.g. "trim=x4t9:-far_ambush-bait", each
faction's own table without those drills; "flank=x4t9:+pin_and_flank"):
    brains=x4t9           the brains alone (no elements: the round-4 CPU)
    standard=x4t9:standard  the army formed into elements under an ElementCommander, fighting by doctrine_standard.json
    faction=x4t9:          elements with each faction's own table
Every pairing plays the same army on both sides (a mirror, so only the tactics differ) on every arena, each seed four
ways: {A as Green, A as Rust} x {normal bases, --swap-bases}.

What earns a drill its place (game_design.md): the exchange it buys. Every match prints TACTICS_LEDGER (TacticsLedger):
damage dealt and taken, kills and deaths, and unit-seconds, charged to what each unit was doing at the time -
"drill:<name>", "<task verb>:<formation>/<technique>" or "brain". The report sums them per side label and per arena:
    exchange = dealt / taken   (above the same label's "brain" rows, or above the brains-only side, it earns its keep)

Round 15 (squad P2): THE WINNER RULE travels with every rating. ELO is computed from `Match.result`'s `winner`, and
what a winner IS changed at 5f562dd0 (garage G3: an elimination match that hits the time limit is judged on points
destroyed, equal = draw; before it, on tanks standing then total health). Two ladders taken under different rules
are different measurements, so the rule's version (a hash of the code that decides `winner`, comments ignored) is
printed beside every ELO and stored in the json, and `--compare REF.json` REFUSES (exit 3) to set a run beside a
reference taken under another rule, another army, other arenas, sides, seeds or time limit. The reference for the
current rule is `tools/tactics/ladder_reference.json` (`make tactics-ladder-reference` writes it).

Usage: tactics_ladder.py --godot PATH --sides brains=x4t9,standard=x4t9:standard [--arenas foundry,yard]
                         [--army combined_arms] [--runs 2] [--jobs 2] [--time-limit 240] [--json out.json]
                         [--compare tools/tactics/ladder_reference.json]
"""
import argparse
import concurrent.futures
import itertools
import json
import subprocess
import sys
import time
import os
import hashlib
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_conditions  # noqa: E402

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")

K = 16
PASSES = 20

MATCH_GD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "match", "match.gd")
# The functions whose code decides `winner`. Their bodies, comments and blank lines stripped, are hashed.
WINNER_FUNCS = ("result", "_points_lost", "_team_standing")
# Rule versions this file knows by name (hash -> name). An unknown hash is still a version: it prints as "unnamed".
KNOWN_RULES = {
    "8013ff13f91d": "r13 (time-out on tanks standing, then health; before 5f562dd0)",
    "cc490e53eeb9": "r14 (time-out on points destroyed, equal = draw; garage G3, 5f562dd0)",
}
# What must match for two ladders to be set side by side, besides the rule.
COMPARABLE_KEYS = ("army", "arenas", "factions", "budget", "control", "runs", "first_seed", "time_limit", "extra")


def _function_body(source, name):
    """The code of `func name(` up to the next top-level declaration; `result` only up to the winner (`units_left`)."""
    match = re.search(r"^(static )?func %s\(" % re.escape(name), source, re.M)
    if match is None:
        return ""
    rest = source[match.start():]
    first = rest.find("\n") + 1
    end = re.search(r"^\S", rest[first:], re.M)
    body = rest[: first + end.start()] if end else rest
    if name == "result" and "var units_left" in body:
        body = body[: body.index("var units_left")]
    lines = []
    for line in body.splitlines():
        code = line.split("#", 1)[0].strip()
        if code:
            lines.append(code)
    return "\n".join(lines)


def winner_rule(source):
    """{'hash', 'name'}: the version of the rule that turns a match into a winner."""
    digest = hashlib.sha1("\n--\n".join(_function_body(source, f) for f in WINNER_FUNCS).encode()).hexdigest()[:12]
    return {"hash": digest, "name": KNOWN_RULES.get(digest, "unnamed")}


def current_winner_rule(path=MATCH_GD):
    with open(path) as handle:
        return winner_rule(handle.read())


def comparison_refusals(run, reference):
    """Why `run` may not be set beside `reference` (both ladder jsons); empty when they are comparable."""
    reasons = []
    rule, ref_rule = run.get("winner_rule") or {}, reference.get("winner_rule") or {}
    if not ref_rule.get("hash"):
        reasons.append("the reference carries no winner rule (taken before round 15: its rule is unknown)")
    elif rule.get("hash") != ref_rule.get("hash"):
        reasons.append("winner rule %s (%s) vs the reference's %s (%s): a winner means a different thing"
                       % (rule.get("hash"), rule.get("name"), ref_rule.get("hash"), ref_rule.get("name")))
    args, ref_args = run.get("args", {}), reference.get("args", {})
    for key in COMPARABLE_KEYS:
        if args.get(key) != ref_args.get(key):
            reasons.append("%s %r vs the reference's %r" % (key, args.get(key), ref_args.get(key)))
    if sorted(run.get("ratings", {})) != sorted(reference.get("ratings", {})):
        reasons.append("sides %s vs the reference's %s" % (sorted(run.get("ratings", {})), sorted(reference.get("ratings", {}))))
    return reasons


def compare(run, reference):
    """Print the run beside the reference, or refuse. Returns the exit code (3 = refused)."""
    reasons = comparison_refusals(run, reference)
    if reasons:
        print("LADDER_COMPARE REFUSED: " + "; ".join(reasons))
        return 3
    print("LADDER_COMPARE rule %s (%s); reference %s at %s" % (run["winner_rule"]["hash"], run["winner_rule"]["name"],
                                                               reference.get("conditions", {}).get("machine"),
                                                               reference.get("conditions", {}).get("commit")))
    for label in sorted(run["ratings"]):
        print("  %-10s ELO %5.0f  reference %5.0f  (%+.0f)" % (label, run["ratings"][label], reference["ratings"][label],
                                                              run["ratings"][label] - reference["ratings"][label]))
    return 0


def parse_side(text):
    label, _, spec = text.partition("=")
    brain, colon, table = spec.partition(":")
    return {"label": label, "brain": brain, "table": table if colon else None}


def side_flags(color, side):
    flags = [f"--{color}-brain={side['brain']}"]
    if side["table"] is not None:
        flags.append(f"--{color}-elements" + (f"={side['table']}" if side["table"] else ""))
    return flags


def army_path(army):
    return army if army.startswith(("cpu", "res://")) else f"res://doctrines/{army}.json"


def run_match(args, green, rust, arena, seed, swap, factions):
    if factions[0] is None:
        doctrine = army_path(args.army)
        armies = [f"--green-doctrine={doctrine}", f"--rust-doctrine={doctrine}"]
    else:
        # Faction armies (X4): each side's army falls out of its faction's costs at the budget, with the control point on
        # (the way combat's faction matrix plays them).
        armies = [f"--green-faction={factions[0]}", f"--rust-faction={factions[1]}", f"--budget={args.budget}"]
        if args.control == "on":
            armies.append("--control")
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--", "--match", "--elimination",
               *armies, f"--arena={arena}",
               *side_flags("green", green), *side_flags("rust", rust), "--tactics-ledger",
               f"--time-limit={args.time_limit}", f"--seed={seed}"]
    if swap:
        command.append("--swap-bases")
    command += args.extra.split()
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit + 600)
    result = ledger = None
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
        elif line.startswith("TACTICS_LEDGER "):
            ledger = json.loads(line[len("TACTICS_LEDGER "):])
    if result is None:
        errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
        raise RuntimeError(f"{green['label']} vs {rust['label']} on {arena} seed {seed} swap {swap}: no MATCH_RESULT "
                           f"(exit {completed.returncode}) {errors}")
    return {"green": green["label"], "rust": rust["label"], "arena": arena, "seed": seed, "swap": swap,
            "green_faction": factions[0], "rust_faction": factions[1],
            "winner": result["winner"], "sim_seconds": result["sim_seconds"], "ledger": ledger or {"green": {}, "rust": {}}}


def score_for(match, label):
    if match["winner"] == "draw":
        return 0.5
    side = "green" if match["winner"] == "Green" else "rust"
    return 1.0 if match[side] == label else 0.0


def elo(labels, matches):
    ratings = {v: 1000.0 for v in labels}
    ordered = sorted(matches, key=lambda m: (m["green"], m["rust"], m["arena"], m["seed"], m["swap"], str(m["green_faction"])))
    history = []
    for _ in range(PASSES):
        for m in ordered:
            a, b = m["green"], m["rust"]
            expected = 1.0 / (1.0 + 10 ** ((ratings[b] - ratings[a]) / 400.0))
            actual = score_for(m, a)
            ratings[a] += K * (actual - expected)
            ratings[b] -= K * (actual - expected)
        history.append(dict(ratings))
    tail = history[PASSES // 2:]
    return {v: sum(h[v] for h in tail) / len(tail) for v in labels}


def activity_family(activity):
    """drill:<name> stays itself; "<verb>:<formation>/<technique>" is reported by technique and by formation too."""
    return activity


def sum_ledgers(matches, label, arena=None):
    """{activity: {seconds, dealt, taken, kills, deaths}} summed over every side of every match played by `label`."""
    totals = {}
    for m in matches:
        if arena is not None and m["arena"] != arena:
            continue
        for color in ("green", "rust"):
            if m[color] != label:
                continue
            for activity, row in m["ledger"].get(color, {}).items():
                t = totals.setdefault(activity, {"seconds": 0.0, "dealt": 0.0, "taken": 0.0, "kills": 0, "deaths": 0})
                for key in t:
                    t[key] += row.get(key, 0)
    return totals


def exchange(row):
    return row["dealt"] / row["taken"] if row["taken"] > 0 else float("inf") if row["dealt"] > 0 else 0.0


def by_drill(totals):
    """Collapse the ledger to drills, techniques and 'brain' (formations are listed separately)."""
    drills, techniques, formations = {}, {}, {}
    for activity, row in totals.items():
        if activity.startswith("drill:") or activity == "brain":
            target = drills.setdefault(activity, dict.fromkeys(row, 0))
            for key in row:
                target[key] += row[key]
            continue
        verb, _, shape = activity.partition(":")
        formation, _, technique = shape.partition("/")
        for table, key_name in ((techniques, f"technique:{technique}"), (formations, f"formation:{formation}")):
            target = table.setdefault(key_name, dict.fromkeys(row, 0))
            for key in row:
                target[key] += row[key]
    return drills, techniques, formations


def print_rows(title, rows):
    total_seconds = sum(r["seconds"] for r in rows.values()) or 1.0
    print(f"  {title}")
    print("  | activity | share of time | dealt | taken | exchange | kills | deaths |")
    print("  |---|---|---|---|---|---|---|")
    for activity, row in sorted(rows.items(), key=lambda kv: -kv[1]["seconds"]):
        ratio = exchange(row)
        ratio_text = "inf" if ratio == float("inf") else f"{ratio:.2f}"
        print(f"  | {activity} | {100.0 * row['seconds'] / total_seconds:.0f}% | {row['dealt']:.0f} | {row['taken']:.0f} "
              f"| {ratio_text} | {row['kills']} | {row['deaths']} |")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--sides", required=True, help="comma-separated label=brain[:table]")
    parser.add_argument("--arenas", default="foundry")
    parser.add_argument("--army", default="combined_arms")
    parser.add_argument("--factions", default="", help="two factions, e.g. gangs,law: faction armies instead of a mirror "
                        "army, every side playing each faction")
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--control", default="on", choices=["on", "off"], help="faction armies: the centre control point")
    parser.add_argument("--runs", type=int, default=2, help="seeds per pairing per arena (each played 4 ways)")
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--time-limit", type=int, default=240)
    parser.add_argument("--extra", default="")
    parser.add_argument("--json")
    parser.add_argument("--compare", help="a ladder json to set this run beside; refused (exit 3) across a winner rule")
    args = parser.parse_args()
    rule = current_winner_rule()
    conditions = run_conditions.describe()
    sides = [parse_side(s) for s in args.sides.split(",") if s]
    labels = [s["label"] for s in sides]
    arenas = [a for a in args.arenas.split(",") if a]
    if len(sides) < 2:
        sys.exit("need at least two sides")

    faction_list = [f for f in args.factions.split(",") if f]
    faction_orders = [(None, None)] if not faction_list else [tuple(faction_list), tuple(reversed(faction_list))]
    started = time.time()
    jobs = []
    for a, b in itertools.combinations(sides, 2):
        for arena in arenas:
            for seed in range(args.first_seed, args.first_seed + args.runs):
                for green, rust in ((a, b), (b, a)):
                    for swap in (False, True):
                        for factions in faction_orders:
                            jobs.append((green, rust, arena, seed, swap, factions))
    matches, failures = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_match, args, *job) for job in jobs]
        for future in concurrent.futures.as_completed(futures):
            try:
                matches.append(future.result())
            except Exception as err:
                failures.append(str(err))

    ratings = elo(labels, matches)
    army_text = f"{args.army} mirror" if not faction_list else \
        f"{' vs '.join(faction_list)} at {args.budget}, both ways, control point {args.control}"
    print(f"TACTICS LADDER: {len(matches)} matches ({army_text}; arenas {', '.join(arenas)}; {args.runs} seeds x 4 "
          f"per pairing per arena), {time.time() - started:.0f}s wall, {run_conditions.header(conditions)}")
    print(f"WINNER RULE {rule['hash']} {rule['name']}: an ELO below is comparable only with another taken under this rule")
    print("| Side | Brain | Doctrine | ELO | Winner rule | W | L | D |")
    print("|---|---|---|---|---|---|---|---|")
    for side in sorted(sides, key=lambda s: -ratings[s["label"]]):
        v = side["label"]
        played = [m for m in matches if v in (m["green"], m["rust"])]
        w = sum(1 for m in played if score_for(m, v) == 1.0)
        l = sum(1 for m in played if score_for(m, v) == 0.0)
        d = sum(1 for m in played if m["winner"] == "draw")
        table = "brains only" if side["table"] is None else (side["table"] or "faction's own")
        print(f"| {v} | {side['brain']} | {table} | {ratings[v]:.0f} | {rule['hash']} | {w} | {l} | {d} |")
    print("Head to head by arena (row's wins-losses-draws vs column):")
    for arena in arenas:
        for a in labels:
            cells = []
            for b in labels:
                if a == b:
                    continue
                pair = [m for m in matches if {m["green"], m["rust"]} == {a, b} and m["arena"] == arena]
                w = sum(1 for m in pair if score_for(m, a) == 1.0)
                l = sum(1 for m in pair if score_for(m, a) == 0.0)
                cells.append(f"{b} {w}-{l}-{len(pair) - w - l}")
            print(f"  {arena:10s} {a}: " + "  ".join(cells))
    if faction_list:
        print("By faction (row's wins-losses-draws playing that faction):")
        for v in labels:
            cells = []
            for faction in faction_list:
                played = [m for m in matches if (m["green"] == v and m["green_faction"] == faction)
                          or (m["rust"] == v and m["rust_faction"] == faction)]
                w = sum(1 for m in played if score_for(m, v) == 1.0)
                l = sum(1 for m in played if score_for(m, v) == 0.0)
                cells.append(f"{faction} {w}-{l}-{len(played) - w - l}")
            print(f"  {v}: " + "  ".join(cells))
    print("Per drill (every arena): damage charged to what the units were doing when the round landed")
    report = {}
    for side in sides:
        totals = sum_ledgers(matches, side["label"])
        drills, techniques, formations = by_drill(totals)
        report[side["label"]] = {"drills": drills, "techniques": techniques, "formations": formations,
                                 "by_arena": {arena: by_drill(sum_ledgers(matches, side["label"], arena))[0] for arena in arenas}}
        print(f"- {side['label']}")
        print_rows("drills", drills)
        if techniques:
            print_rows("movement techniques (outside drills)", techniques)
            print_rows("formations (outside drills)", formations)
    for failure in failures:
        print("  FAILED: " + failure)
    output = {"args": vars(args), "winner_rule": rule, "conditions": conditions, "ratings": ratings, "report": report,
              "matches": matches, "failures": failures}
    if args.json:
        with open(args.json, "w") as handle:
            json.dump(output, handle, indent=2)
    code = 1 if failures else 0
    if args.compare:
        with open(args.compare) as handle:
            code = code or compare(output, json.load(handle))
    sys.exit(code)


if __name__ == "__main__":
    main()
