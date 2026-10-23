#!/usr/bin/env python3
"""Round 38 (doctrine D2 lab): two tactics-hold-fire runs paired fight by fight (guard, arena, seed, side).

    python3 tests/tactics/hold_fire_pair.py OFF_DIR ON_DIR

Each dir holds the run's *.log (HOLD_FIRE and GUARD_RESULT lines). Prints, on the fights both runs have: the guard's wins
each arm and the flips, kills and losses a side, and the CPU's damage fired: its share moving, its share in "defend"
posture and in attack posture with nothing held. A lab read, not a judged line (the bar's series is guard.sh + guard.py).
"""
import glob
import json
import os
import sys


def load(path):
    out = {}
    for log in glob.glob(os.path.join(path, "*.log")):
        hold, result = None, None
        for line in open(log, errors="replace"):
            if line.startswith("HOLD_FIRE "):
                hold = json.loads(line[len("HOLD_FIRE "):])
            elif line.startswith("GUARD_RESULT "):
                result = json.loads(line[len("GUARD_RESULT "):])
        if hold and result:
            out[(hold["guard"], hold["arena"], hold["seed"], hold["side"])] = (hold, result)
    return out


def cpu_damage(hold):
    total = moving = defend = nothing_own = 0.0
    for key, c in hold.get("why", {}).items():
        if not key.endswith("|dmg"):
            continue
        n = sum(c)
        total += n
        moving += c[1] + c[2]
        if key.startswith("defend|"):
            defend += n
        if key.startswith("nothing|own"):
            nothing_own += n
    return total, moving, defend, nothing_own


def main(off_dir, on_dir):
    off, on = load(off_dir), load(on_dir)
    keys = sorted(set(off) & set(on))
    print("paired fights %d (off %d, on %d)" % (len(keys), len(off), len(on)))
    for kind in sorted({k[0] for k in keys}):
        ks = [k for k in keys if k[0] == kind]
        wins = [0, 0]
        flips = [0, 0]  # guard win -> loss, loss -> win
        dmg = [[0.0] * 4, [0.0] * 4]
        kills = [[0, 0], [0, 0]]  # [arm][guard, cpu]
        cover = [[0, 0], [0, 0]]  # [arm][guard, cpu]: seats moved behind low cover (--cover-seat=on), elements' maxima
        for k in ks:
            res = []
            for arm, runs in enumerate((off, on)):
                hold, result = runs[k]
                won = result["role"] == "guard"
                res.append(won)
                wins[arm] += won
                for i, v in enumerate(cpu_damage(hold)):
                    dmg[arm][i] += v
                g = result["side"].lower()
                c = "rust" if g == "green" else "green"
                kills[arm][0] += result["kills"][g]
                kills[arm][1] += result["kills"][c]
                cover[arm][0] += hold.get("cover", {}).get("guard", 0)
                cover[arm][1] += hold.get("cover", {}).get("tactics", 0)
            if res[0] and not res[1]:
                flips[0] += 1
            if res[1] and not res[0]:
                flips[1] += 1
        n = len(ks)
        print("%s line, %d fights" % (kind.upper(), n))
        print("  guard wins off %d (%.0f %%) on %d (%.0f %%); flips win->loss %d, loss->win %d" % (
            wins[0], 100 * wins[0] / n, wins[1], 100 * wins[1] / n, flips[0], flips[1]))
        for arm, name in ((0, "off"), (1, "on")):
            t, m, d, no = dmg[arm]
            print("  %-3s guard kills %4d  CPU kills %4d | CPU damage moving %5.1f %%  in defend %5.1f %%  attack/nothing/own %5.1f %%" % (
                name, kills[arm][0], kills[arm][1], 100 * m / t if t else 0, 100 * d / t if t else 0,
                100 * no / t if t else 0))
            print("      cover seats moved: guard %d, CPU %d" % tuple(cover[arm]))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
