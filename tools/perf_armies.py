#!/usr/bin/env python3
"""Army files (Doctrine v2 JSON) for perf's measured fights (round 22), written under build/ and loaded by the skirmish as
res://build/... (a path with "://", so Army.load_army reads the file; build/ has a .gdignore, nothing is imported).

    python3 tools/perf_armies.py recording <match.jsonl[.gz]> <out_dir>
        his armies from a match recording's header: the squads by name (Green_Guns_3 -> squad Guns), in order, as
        <out_dir>/green.json and <out_dir>/rust.json; prints the arena and seed the match was played with.
    python3 tools/perf_armies.py size <n> <out_dir>
        P1's sizes: <out_dir>/green_<n>.json (gangs) and <out_dir>/rust_<n>.json (condemned), n vehicles each in squads
        of five, the faction's whole roster in fixed shares (cheap-heavy, since only a cheap army reaches 50).

Both sides hold at the start (`verb: hold`), as the garage's armies do; the measurement drives his side."""
import collections
import gzip
import json
import os
import sys

SQUAD = 5
# Shares of n per faction, in roster order: (unit id, share). The rounding remainder goes to the first entry.
MIX = {
    "gangs": [("gang_scout", 0.5), ("gang_ifv", 0.2), ("gang_tank", 0.1), ("gang_artillery", 0.1), ("gang_support", 0.1)],
    "condemned": [("scout", 0.3), ("ifv", 0.2), ("tank", 0.2), ("lancer", 0.1), ("burner", 0.1), ("artillery", 0.1)],
}
NAMES = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima"]


def _open(path):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path)


def from_recording(header):
    """{team: [squad dicts]} from a recording's first line, squads in first-seen order, units in name order. Pure."""
    teams = {0: collections.OrderedDict(), 1: collections.OrderedDict()}
    for unit in header["units"]:
        # Green_Guns_3 -> Guns; Rust_Eyes2_1 -> Eyes2
        squad = unit["name"].split("_", 1)[1].rsplit("_", 1)[0]
        teams[int(unit["team"])].setdefault(squad, []).append(unit["id"])
    # A doctrine squad holds at most SQUAD; his 8-strong Guns were folded by SquadConsolidation from Guns + Guns2 (the
    # family overflow names), so they are written that way and the skirmish folds them back the same.
    result = {}
    for team, squads in teams.items():
        result[team] = []
        for name, units in squads.items():
            for i in range(0, len(units), SQUAD):
                result[team].append({"name": name if i == 0 else "%s%d" % (name, i // SQUAD + 1), "verb": "hold",
                                     "units": [{"unit": u} for u in units[i:i + SQUAD]]})
    return result


def mix(faction, n):
    """n unit ids of `faction` in MIX's shares, cheap first. Pure."""
    counts = [(unit, int(n * share)) for unit, share in MIX[faction]]
    counts[0] = (counts[0][0], counts[0][1] + n - sum(c for _, c in counts))
    return [unit for unit, count in counts for _ in range(count)]


def squads_of(units):
    """Squads of SQUAD units, named Alpha, Bravo, ... Pure."""
    return [{"name": NAMES[i // SQUAD], "verb": "hold", "units": [{"unit": u} for u in units[i:i + SQUAD]]}
            for i in range(0, len(units), SQUAD)]


def write(path, name, squads):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump({"name": name, "squads": squads}, f, indent=1)
    print("PERF_ARMY %s %d vehicles in %d squads" % (path, sum(len(s["units"]) for s in squads), len(squads)))


def main(args):
    if len(args) == 3 and args[0] == "recording":
        with _open(args[1]) as f:
            header = json.loads(f.readline())
        teams = from_recording(header)
        write(os.path.join(args[2], "green.json"), "His army (recording)", teams[0])
        write(os.path.join(args[2], "rust.json"), "The CPU's army (recording)", teams[1])
        print("PERF_ARMY_MATCH arena=%s seed=%s" % (header.get("arena"), header.get("seed")))
        return 0
    if len(args) == 3 and args[0] == "size":
        n = int(args[1])
        write(os.path.join(args[2], "green_%d.json" % n), "Gangs %d" % n, squads_of(mix("gangs", n)))
        write(os.path.join(args[2], "rust_%d.json" % n), "Condemned %d" % n, squads_of(mix("condemned", n)))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
