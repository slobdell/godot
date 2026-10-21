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
    fight(arm_root, "blob", "terminus", 1, "green", "rust", kills=(5, 10), losses=(10, 5))   # win -> loss
    fight(arm_root, "blob", "terminus", 1, "rust", "rust", kills=(5, 5), losses=(5, 5))      # loss -> win
    fight(arm_root, "blob", "terminus", 2, "green", "rust", kills=(5, 10), losses=(10, 5))   # win -> loss
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

print("%d failed" % len(failures))
sys.exit(1 if failures else 0)
