#!/usr/bin/env python3
"""Round 27 (scout CP-S): the census, paired by seed (new arm minus off arm, same seed): gun-on-target share, the share
of fight time inside the turning room, enemy contacts under a fight option (from the SCOUT_EVENT lines), and the mean
difference with its standard error (the orchestrator's ruling: the gain counts only outside 2 se).

    tests/scout/census_paired.py <new_dir> <off_dir>
"""
import json
import math
import os
import re
import sys

FIGHT = {"ENGAGE", "ORBIT", "FLANK", "COVER_FIRE", "CLEAR_LANE", "SUPPRESS", "BOMBARD", "PURSUE"}


def read(path):
    row, fight_contacts, move_contacts = None, 0, 0
    for line in open(path, errors="replace"):
        if line.startswith("SCOUT_CENSUS "):
            row = json.loads(line[len("SCOUT_CENSUS "):])
        elif line.startswith("SCOUT_EVENT"):
            m = re.search(r"option=([A-Z_]*)", line)
            option = m.group(1) if m else ""
            if option in FIGHT:
                fight_contacts += 1
            elif option == "MOVE":
                move_contacts += 1
    if row is not None:
        row["fight_contacts"] = fight_contacts
        row["move_contacts"] = move_contacts
    return row


def stats(values):
    n = len(values)
    mean = sum(values) / n
    sd = math.sqrt(sum((v - mean) ** 2 for v in values) / (n - 1)) if n > 1 else 0.0
    return mean, sd / math.sqrt(n) if n else 0.0


def engage_in_reach(row):
    """(seconds in reach, seconds bearing) under ENGAGE: the lay planner's domain (v2's primary)."""
    reach = bear = 0.0
    for label, cell in row.get("breakdown", {}).items():
        if label.startswith("ENGAGE/"):
            reach += cell[1]
            bear += cell[2]
    return reach, bear


def primary(new_dir, off_dir):
    """v2's primary: gun on target within reach during ENGAGE, paired by seed."""
    seeds = sorted({f[:-4] for f in os.listdir(new_dir) if f.endswith(".log")}, key=lambda s: int(s))
    diffs, guard, share, contacts = [], [], [], []
    seconds = {"off": [0.0, 0.0], "new": [0.0, 0.0]}
    print("%-5s %-12s %-20s | %6s %6s %6s %6s %6s | %6s %6s" % ("seed", "arena", "factions", "rOFF", "rNEW", "bOFF",
          "bNEW", "diff", "allOFF", "allNEW"))
    for seed in seeds:
        new = read(os.path.join(new_dir, seed + ".log"))
        off = read(os.path.join(off_dir, seed + ".log"))
        if new is None or off is None:
            print("%-5s missing" % seed)
            continue
        rn, bn = engage_in_reach(new)
        ro, bo = engage_in_reach(off)
        if rn <= 0 or ro <= 0 or new["fight_s"] <= 0 or off["fight_s"] <= 0:
            print("%-5s no ENGAGE in reach (off %.0f s, new %.0f s): not paired" % (seed, ro, rn))
            continue
        diffs.append(100 * (bn / rn - bo / ro))
        a_new, a_off = new["on_target_s"] / new["fight_s"], off["on_target_s"] / off["fight_s"]
        guard.append(100 * (a_new - a_off))
        share.append(100 * (rn / new["fight_s"] - ro / off["fight_s"]))
        contacts.append(new["fight_contacts"] - off["fight_contacts"])
        seconds["off"][0] += ro
        seconds["off"][1] += off["fight_s"]
        seconds["new"][0] += rn
        seconds["new"][1] += new["fight_s"]
        print("%-5s %-12s %-20s | %5.0fs %5.0fs %5.1f%% %5.1f%% %+5.1f | %5.1f%% %5.1f%%" % (seed, new["arena"],
              "/".join(new["factions"]), ro, rn, 100 * bo / ro, 100 * bn / rn, diffs[-1], 100 * a_off, 100 * a_new))
    # The guards with a denominator outside the primary's (every seed with fight time in both arms), and outcomes.
    guard, contacts, outcomes = [], [], {"kills": [], "damage": [], "deaths": []}
    for seed in seeds:
        new = read(os.path.join(new_dir, seed + ".log"))
        off = read(os.path.join(off_dir, seed + ".log"))
        if new is None or off is None or new["fight_s"] <= 0 or off["fight_s"] <= 0:
            continue
        guard.append(100 * (new["on_target_s"] / new["fight_s"] - off["on_target_s"] / off["fight_s"]))
        contacts.append(new["fight_contacts"] - off["fight_contacts"])
        if "kills" in new and "kills" in off:
            for k in outcomes:
                outcomes[k].append((off[k], new[k]))
    if outcomes["kills"]:
        for k in outcomes:
            d = [n - o for o, n in outcomes[k]]
            dm, dse = stats(d)
            print("OUTCOME n=%d fixed-gun %s off %.0f new %.0f, paired diff mean %+.1f a seed, se %.1f" % (len(d), k,
                  sum(o for o, _ in outcomes[k]), sum(n for _, n in outcomes[k]), dm, dse))
    m, se = stats(diffs)
    gm, gse = stats(guard)
    print("PRIMARY n=%d engage_in_reach_on_target diff mean %+.2f pts, se %.2f (2 se %.2f)" % (len(diffs), m, se, 2 * se))
    print("GUARD   n=%d all_fight_on_target diff mean %+.2f pts, se %.2f (2 se %.2f)" % (len(guard), gm, gse, 2 * gse))
    sm, sse = stats(share)
    print("GUARD   n=%d engage_in_reach_share diff mean %+.2f pts, se %.2f (2 se %.2f)" % (len(share), sm, sse, 2 * sse))
    cm, cse = stats(contacts)
    print("GUARD   n=%d fight_option_contacts diff mean %+.2f a seed, se %.2f (2 se %.2f)" % (len(contacts), cm, cse, 2 * cse))
    for arm in ("off", "new"):
        print("SECONDS %s engage_in_reach=%.0f fight=%.0f" % (arm, seconds[arm][0], seconds[arm][1]))


def main(new_dir, off_dir):
    seeds = sorted({f[:-4] for f in os.listdir(new_dir) if f.endswith(".log")}, key=lambda s: int(s))
    print("%-5s %-12s %-20s %7s %7s | %6s %6s %6s | %5s %5s | %5s %5s | %5s %5s" % ("seed", "arena", "factions",
          "fight", "fight", "onOFF", "onNEW", "diff", "inOFF", "inNEW", "fcOFF", "fcNEW", "mvOFF", "mvNEW"))
    diffs, room_diffs = [], []
    tot = {"off": [0, 0, 0, 0, 0], "new": [0, 0, 0, 0, 0]}
    for seed in seeds:
        new = read(os.path.join(new_dir, seed + ".log"))
        off = read(os.path.join(off_dir, seed + ".log"))
        if new is None or off is None or new["fight_s"] <= 0 or off["fight_s"] <= 0:
            print("%-5s missing or no fight (new %s, off %s)" % (seed, new is not None, off is not None))
            continue
        on_new = new["on_target_s"] / new["fight_s"]
        on_off = off["on_target_s"] / off["fight_s"]
        in_new = new["close_s"] / new["fight_s"]
        in_off = off["close_s"] / off["fight_s"]
        diffs.append(100 * (on_new - on_off))
        room_diffs.append(100 * (in_new - in_off))
        for arm, row in (("off", off), ("new", new)):
            for i, k in enumerate(["fight_s", "on_target_s", "close_s", "fight_contacts", "move_contacts"]):
                tot[arm][i] += row[k]
        print("%-5s %-12s %-20s %7.0f %7.0f | %5.1f%% %5.1f%% %+5.1f | %4.0f%% %4.0f%% | %5d %5d | %5d %5d" % (seed,
              new["arena"], "/".join(new["factions"]), off["fight_s"], new["fight_s"], 100 * on_off, 100 * on_new,
              diffs[-1], 100 * in_off, 100 * in_new, off["fight_contacts"], new["fight_contacts"],
              off["move_contacts"], new["move_contacts"]))
    mean, se = stats(diffs)
    rmean, rse = stats(room_diffs)
    print("PAIRED n=%d gun_on_target diff mean %+.2f pts, se %.2f (2 se %.2f) | inside_room diff mean %+.2f pts, se %.2f"
          % (len(diffs), mean, se, 2 * se, rmean, rse))
    for arm in ("off", "new"):
        f, o, c, fc, mc = tot[arm]
        print("POOLED %s fight_s=%.0f on_target=%.1f%% inside_room=%.1f%% fight_contacts=%d move_contacts=%d" % (arm, f,
              100 * o / f, 100 * c / f, fc, mc))




def breakdown(directory):
    """Fight time by option/motion, pooled over seeds: seconds, share in reach, share bearing (of all), bearing in reach."""
    pooled = {}
    for f in os.listdir(directory):
        if not f.endswith(".log"):
            continue
        row = read(os.path.join(directory, f))
        if row is None:
            continue
        for label, cell in row.get("breakdown", {}).items():
            acc = pooled.setdefault(label, [0.0, 0.0, 0.0])
            for i in range(3):
                acc[i] += cell[i]
    total = sum(c[0] for c in pooled.values()) or 1e-9
    print("%-22s %7s %6s %7s %7s %9s" % ("option/motion", "fight_s", "share", "reach", "bearing", "bear|reach"))
    for label, (t, r, b) in sorted(pooled.items(), key=lambda kv: -kv[1][0]):
        print("%-22s %7.0f %5.1f%% %6.0f%% %6.0f%% %8.0f%%" % (label, t, 100 * t / total, 100 * r / max(t, 1e-9),
              100 * b / max(t, 1e-9), 100 * b / max(r, 1e-9)))


if __name__ == "__main__":
    if sys.argv[1] == "--primary":
        primary(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "--breakdown":
        breakdown(sys.argv[2])
    else:
        main(sys.argv[1], sys.argv[2])
