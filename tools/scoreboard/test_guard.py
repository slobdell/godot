"""Known answers for tools/scoreboard/guard.py (round 37, CP37.1): a guard-run folder written by hand, every number read back.
Run by tools/test_scoreboard.sh (so shell-tools-test carries it)."""
import json
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import guard  # noqa: E402

failures = []


def check(name, got, want):
    ok = (abs(got - want) < 1e-9) if isinstance(want, float) and got is not None else got == want
    print(("PASS " if ok else "FAIL ") + "%s: got %r want %r" % (name, got, want))
    if not ok:
        failures.append(name)


def fight(root, kind, arena, seed, side, winner, reason="control", kills=(0, 0), losses=(0, 0), control=(0, 0),
          factions=("law", "gangs"), seconds=100.0):
    path = os.path.join(root, kind, "%s-%d-%s.log" % (arena, seed, side))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    role = "draw" if winner == "draw" else ("tactics" if kind == "none" or winner != side else "guard")
    # As the probe prints them: side and winner and the factions' keys in Match.TEAM_NAMES' case; kills etc lower case.
    result = {"guard": kind, "arena": arena, "seed": seed, "side": side.capitalize(), "winner": winner.capitalize(), "role": role, "reason": reason, "seconds": seconds,
              "kills": {"green": kills[0], "rust": kills[1]}, "losses": {"green": losses[0], "rust": losses[1]},
              "control": {"green": control[0], "rust": control[1]},
              "factions": {"Green": factions[0], "Rust": factions[1]}}
    with open(path, "w") as f:
        f.write("noise line\nGUARD_RESULT %s\n" % json.dumps(result))


with tempfile.TemporaryDirectory() as root:
    # Seed 1: the blob (green) loses on points; the blob (rust) wins by elimination.
    fight(root, "blob", "terminus", 1, "green", "rust", kills=(4, 10), losses=(10, 4), control=(20, 90), seconds=120.0)
    fight(root, "blob", "terminus", 1, "rust", "rust", reason="elimination", kills=(2, 8), losses=(8, 2), control=(0, 30))
    # Seed 2: one capped draw, one loss; and one fight that never printed (a crash).
    fight(root, "blob", "terminus", 2, "green", "draw", reason="cap", kills=(5, 5), losses=(5, 5), control=(40, 40),
          seconds=600.0)
    fight(root, "blob", "terminus", 2, "rust", "green", kills=(1, 3), losses=(3, 1), control=(90, 10))
    os.makedirs(os.path.join(root, "blob"), exist_ok=True)
    with open(os.path.join(root, "blob", "locks-2-green.log"), "w") as f:
        f.write("SCRIPT ERROR: boom\n")
    report = guard.lines(guard.read([root]))
    blob = report["blob"]
    check("run", blob["run"], 5)
    check("read", blob["read"], 4)
    check("missing", blob["missing"], ["locks-2-green.log"])
    a = blob["all"]
    check("win", a["win"], 0.25)
    check("loss", a["loss"], 0.5)
    check("draw", a["draw"], 0.25)
    check("capped", a["capped"], 0.25)
    # The guard's own kills / losses: green 4+5, rust 8+3 -> 20 kills; losses green 10+5, rust 2+1 -> 18.
    check("kills", a["kills"], 20)
    check("losses", a["losses"], 18)
    check("kill_ratio", a["kill_ratio"], 20 / 18)
    # Margins: -70, +30, 0, -80 -> mean -30.
    check("margin", a["margin"], -30.0)
    check("median_s", a["median_s"], 120.0)
    # By faction: green guard = law (seeds 1, 2), rust guard = gangs.
    check("law n", blob["by_faction"]["law"]["n"], 2)
    check("gangs win", blob["by_faction"]["gangs"]["win"], 0.5)
    check("pairing law v gangs n", blob["by_pairing"]["law v gangs"]["n"], 2)
    check("pairing gangs v law win", blob["by_pairing"]["gangs v law"]["win"], 0.5)
    # Noise: seed win shares 0.5 and 0.0 -> sd = sqrt(0.125), se = sd / sqrt(2), 2 se of a difference = 2 sqrt2 se.
    sd = math.sqrt(0.125)
    check("noise win", blob["noise"]["win"], 2 * math.sqrt(2) * sd / math.sqrt(2))
    check("noise seeds", blob["noise"]["seeds"], 2)
    text = guard.render(report)
    check("render names the line", "BLOB: 4 of 5 fights read" in text, True)
    check("render says missing", "MISSING: locks-2-green.log" in text, True)

# --pair (a rule's bar): the same fights, one flipped to a loss, one to a win, one more flipped to a loss.
with tempfile.TemporaryDirectory() as base_root, tempfile.TemporaryDirectory() as arm_root:
    for seed in (1, 2):
        fight(base_root, "blob", "terminus", seed, "green", "green", kills=(10, 5), losses=(5, 10))
        fight(base_root, "blob", "terminus", seed, "rust", "green", kills=(5, 5), losses=(5, 5))
    fight(arm_root, "blob", "terminus", 1, "green", "rust", kills=(5, 10), losses=(10, 5), seconds=60.0)   # win -> loss
    fight(arm_root, "blob", "terminus", 1, "rust", "rust", kills=(5, 5), losses=(5, 5))      # loss -> win
    fight(arm_root, "blob", "terminus", 2, "green", "rust", kills=(5, 10), losses=(10, 5), seconds=40.0)   # win -> loss
    fight(arm_root, "blob", "terminus", 2, "rust", "green", kills=(5, 5), losses=(5, 5))     # loss, unchanged
    fight(arm_root, "blob", "locks", 9, "rust", "green")                                     # no base: not paired
    paired = guard.pair([base_root], [arm_root])["blob"]
    check("pair n", paired["n"], 4)
    check("pair unpaired", paired["unpaired_in_arm"], 1)
    check("pair worse", paired["worse"], 2)
    check("pair better", paired["better"], 1)
    check("pair mcnemar", paired["mcnemar_p_worse"], 4 / 8.0)   # P(>= 2 of 3) = (3 + 1) / 8
    check("pair win diff", paired["win_diff"], 0.25 - 0.5)
    check("pair seeds", paired["seeds"], 2)
    # Round 38 (doctrine's Bar G2): the guard's kills and losses a fight and the median length, all and per guard faction
    # (green's guard is law, rust's gangs), each with its paired se from the per-seed differences.
    law, gangs = paired["by_faction"]["law"], paired["by_faction"]["gangs"]
    check("pair kills a fight base", paired["all"]["kills_pf"]["base"], 7.5)
    check("pair kills a fight diff", paired["all"]["kills_pf"]["diff"], 5.0 - 7.5)
    check("pair kills a fight se", paired["all"]["kills_pf"]["se"], 0.0)
    check("pair losses a fight diff", paired["all"]["losses_pf"]["diff"], 7.5 - 5.0)
    check("pair law n", law["n"], 2)
    check("pair law kills diff", law["kills_pf"]["diff"], -5.0)
    check("pair law median base", law["median_s"]["base"], 100.0)
    check("pair law median arm", law["median_s"]["arm"], 60.0)   # sorted (40, 60)[n // 2], stats_of's median
    check("pair law median se", law["median_s"]["se"], 10.0)    # per-seed diffs -40, -60: sd 14.14 / sqrt 2
    check("pair gangs kills diff", gangs["kills_pf"]["diff"], 0.0)
    # Round 42 (R42.13, Bar E1's G3): the length's paired line is the MEAN, the statistic its se is of. Here the pooled medians
    # don't move (100 -> 100: arm (40, 60, 100, 100)[2]) while the paired mean drops 25 s (se 5: per-seed diffs -20, -30).
    check("pair mean s base", paired["all"]["mean_s"]["base"], 100.0)
    check("pair mean s arm", paired["all"]["mean_s"]["arm"], 75.0)
    check("pair mean s diff", paired["all"]["mean_s"]["diff"], -25.0)
    check("pair mean s se", round(paired["all"]["mean_s"]["se"], 6), 5.0)
    check("pair median s diff (extra)", paired["all"]["median_s"]["diff"], 0.0)
    check("pair law mean s diff", law["mean_s"]["diff"], -50.0)
    check("pair law mean s se", law["mean_s"]["se"], 10.0)
    pair_text = guard.render_pair(guard.pair([base_root], [arm_root]))
    check("render pair faction line",
          "law (n 2): kills a fight 10.00 -> 5.00 (paired mean diff -5.00, se 0.00)" in pair_text, True)
    check("render pair mean length", "mean s 100.0 -> 75.0 (paired mean diff -25.0, se 5.0)" in pair_text, True)
    check("render pair median labelled extra", "extra: median s 100.0 -> 100.0 (not paired)" in pair_text, True)
    check("render pair no median se", "median s 100.0 -> 100.0 (diff" in pair_text, False)
    # Jsonl input reads the same fights as the logs.
    jsonl = os.path.join(base_root, "fights.jsonl")
    with open(jsonl, "w") as out:
        for path in sorted(__import__("glob").glob(os.path.join(base_root, "blob", "*.log"))):
            for line in open(path):
                if line.startswith("GUARD_RESULT "):
                    out.write(line[len("GUARD_RESULT "):])
    check("jsonl same win", guard.lines(guard.read([jsonl]))["blob"]["all"]["win"],
          guard.lines(guard.read([base_root]))["blob"]["all"]["win"])

# The scoreboard table's guard section (N3): a main with a guard read gets the lines; one without reads "not run".
import table  # noqa: E402
with tempfile.TemporaryDirectory() as root:
    os.makedirs(os.path.join(root, "guards"))
    with open(os.path.join(root, "mains.txt"), "w") as f:
        f.write("aaaaaaaaa older main\nbbbbbbbbb newer main\n")
    with open(os.path.join(root, "guards", "bbbbbbbbb.json"), "w") as f:
        json.dump(report, f)
    page = table.render(root)
    blob_row = [l for l in page.splitlines() if l.startswith("| A blob frontal assault WINS")][0]
    check("table blob win cells", blob_row.split(" | ")[1:3], ["not run", "25 %"])
    check("table blob noise", blob_row.split(" | ")[-1].rstrip(" |"), "± 71 %")
    read_row = [l for l in page.splitlines() if l.startswith("| Guard fights read")][0]
    check("table read cell", read_row.split(" | ")[2], "4 of 5")

# Round 40 (N2): --by-unit on rows with `units` (CP40.0). Seed 1: g1 (law tank 200) kills r1 (gangs buggy 70) and r2; seed 2
# (the arm's twin of seed 1, and its base): the same units, g1 kills r1 only. An older row without `units` is skipped.
def units_row(seed, side, g1_kills):
    dead = ["r1", "r2"][:g1_kills]
    rows = {"green": [{"id": "g1", "type": "law_tank", "faction": "law", "cost": 200, "kills": g1_kills, "death": -1,
                       "killer": "", "dealt": 100.0 * g1_kills, "taken": 30.0}],
            "rust": [{"id": r, "type": "gang_buggy", "faction": "gangs", "cost": 70, "kills": 0,
                      "death": 90 if r in dead else -1, "killer": "g1" if r in dead else "", "dealt": 15.0,
                      "taken": 100.0 if r in dead else 0.0} for r in ("r1", "r2")]}
    return {"guard": "blob", "arena": "locks", "seed": seed, "side": side, "winner": "Green", "role": "guard",
            "reason": "elimination", "seconds": 90.0, "kills": {"green": g1_kills, "rust": 0},
            "losses": {"green": 0, "rust": g1_kills}, "factions": {"Green": "law", "Rust": "gangs"}, "units": rows}


with tempfile.TemporaryDirectory() as root:
    base_path, arm_path = os.path.join(root, "base.jsonl"), os.path.join(root, "arm.jsonl")
    with open(base_path, "w") as out:
        for seed in (1, 2):
            out.write(json.dumps(units_row(seed, "Green", 2)) + "\n")
        old = units_row(3, "Green", 2)
        del old["units"]
        out.write(json.dumps(old) + "\n")
    with open(arm_path, "w") as out:
        out.write(json.dumps(units_row(1, "Green", 1)) + "\n")
        out.write(json.dumps(units_row(2, "Green", 2)) + "\n")
    bu = guard.by_unit(guard.read([base_path]))
    check("by-unit skipped old rows", bu["fights_without_units"], 1)
    tank = bu["groups"]["law law_tank"]
    check("by-unit fielded", tank["fielded"], 2)
    check("by-unit credits", tank["credits"], 400.0)
    check("by-unit kills a 1000 credits", tank["kills_pkc"], 10.0)        # 4 kills / 400 credits
    check("by-unit killed value a credit", tank["killed_value_pc"], 0.7)  # 4 x 70 / 400
    check("by-unit dealt a credit", tank["dealt_pc"], 1.0)                # 400 / 400
    check("by-unit lived", tank["survived"], 1.0)
    gangs = bu["groups"]["gangs *"]
    check("by-unit army fielded", gangs["fielded"], 4)
    check("by-unit army lost value", gangs["lost_value_pc"], 1.0)
    check("by-unit army lived", gangs["survived"], 0.0)
    check("by-unit kills sum to the rows", sum(g["kills"] for k, g in bu["groups"].items() if not k.endswith("*")), 4)
    bp = guard.by_unit_pair([base_path], [arm_path])
    check("by-unit pair n", bp["n"], 2)
    kv = bp["groups"]["law law_tank"]["killed_value_pc"]
    check("by-unit pair base", kv["base"], 0.7)
    check("by-unit pair arm", kv["arm"], 0.525)                          # 3 x 70 / 400
    check("by-unit pair diff", kv["diff"], 0.525 - 0.7)
    check("by-unit pair se", kv["se"], 0.175)                             # per-seed diffs -0.35, 0: sd 0.2475 / sqrt 2
    check("by-unit pair lived", bp["groups"]["gangs gang_buggy"]["survived"]["arm"], 0.25)
    check("by-unit render", "law law_tank" in guard.render_by_unit(bu), True)
    check("by-unit pair render", "killed_value_pc 0.700 -> 0.525" in guard.render_by_unit_pair(bp), True)

print("%d failed" % len(failures))
sys.exit(1 if failures else 0)
