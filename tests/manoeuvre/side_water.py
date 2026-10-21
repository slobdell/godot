#!/usr/bin/env python3
"""Round 36 (manoeuvre S2a, the orchestrator's condition): does an H1b side point ever take a hull over water?

usage: side_water.py DIR   (fights logs `<arena>-<seed>.log` with the lab probe's rows (lab/s2a-sideprobe 86e058424, measurement
                            only): `H1B_SIDE f <frame> <crew> here x z friend x z point x z|stand goal x z`)

Per side point chosen, against the arena's own terrain (arenas/<arena>.json; rect = [cx, cz, w, d], ArenaTerrain.bounds):
  in_carve  the point lies in water or a pit and not on a deck
  on_deck   the point lies on a bridge deck
  across    the hull and the point lie on opposite banks of a carve (both outside its short span, inside its long span)
  crosses   the straight line hull -> point passes over a carve where no deck is (sampled every 0.25 m)
Must be 0 (or traced) for in_carve, across and crosses. on_deck is listed with whether the hull was on that deck already.
Measurement only.
"""
import collections
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
ROW = re.compile(r"^H1B_SIDE f (\d+) (\S+) here (\S+) (\S+) friend (\S+) (\S+) point (stand|\S+ \S+) goal (\S+) (\S+)")


def terrain(arena):
    data = json.load(open(os.path.join(ROOT, "arenas", arena + ".json")))
    out = []
    for e in data.get("terrain", []):
        cx, cz, w, d = (float(v) for v in e["rect"])
        out.append((e["kind"], (cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2)))
    return out


def inside(b, x, z):
    return b[0] <= x <= b[2] and b[1] <= z <= b[3]


def over_carve(ter, x, z):
    return any(k != "bridge" and inside(b, x, z) for k, b in ter) and not any(k == "bridge" and inside(b, x, z) for k, b in ter)


def deck_of(ter, x, z):
    for i, (k, b) in enumerate(ter):
        if k == "bridge" and inside(b, x, z):
            return i
    return None


def opposite_banks(ter, a, p):
    for k, b in ter:
        if k == "bridge":
            continue
        long_x = (b[2] - b[0]) >= (b[3] - b[1])
        lo, hi = (b[1], b[3]) if long_x else (b[0], b[2])
        llo, lhi = (b[0], b[2]) if long_x else (b[1], b[3])
        sa, sp = (a[1], p[1]) if long_x else (a[0], p[0])
        la, lp = (a[0], p[0]) if long_x else (a[1], p[1])
        if not (llo <= la <= lhi and llo <= lp <= lhi):
            continue
        if (sa < lo and sp > hi) or (sa > hi and sp < lo):
            return True
    return False


def main():
    root = sys.argv[1]
    tally = collections.Counter()
    flagged = []
    decks = []
    for name in sorted(os.listdir(root)):
        if not name.endswith(".log"):
            continue
        arena = name.rsplit("-", 1)[0]
        ter = terrain(arena)
        for line in open(os.path.join(root, name), errors="replace"):
            m = ROW.match(line)
            if not m:
                continue
            tally[arena + " fires"] += 1
            if m.group(7) == "stand":
                tally[arena + " stands"] += 1
                continue
            tally[arena + " points"] += 1
            here = (float(m.group(3)), float(m.group(4)))
            px, pz = (float(v) for v in m.group(7).split())
            why = []
            if over_carve(ter, px, pz):
                why.append("in_carve")
            if opposite_banks(ter, here, (px, pz)):
                why.append("across")
            n = int(max(abs(px - here[0]), abs(pz - here[1])) / 0.25) + 1
            if any(over_carve(ter, here[0] + (px - here[0]) * i / n, here[1] + (pz - here[1]) * i / n) for i in range(n + 1)):
                why.append("crosses")
            deck = deck_of(ter, px, pz)
            if deck is not None:
                tally[arena + " on_deck"] += 1
                decks.append((name, m.group(1), m.group(2), deck_of(ter, *here) == deck, here, (px, pz)))
            for w in why:
                tally[arena + " " + w] += 1
            if why:
                flagged.append((name, m.group(1), m.group(2), why, here, (px, pz)))
    print("side points by arena: %s" % dict(sorted(tally.items())))
    print("flagged (in_carve / across / crosses), must be 0 or traced: %d" % len(flagged))
    for f in flagged:
        print("  %s f %s %s %s here %s point %s" % f)
    print("on a deck: %d (hull already on that deck: %d)" % (len(decks), sum(1 for d in decks if d[3])))
    for d in decks:
        print("  %s f %s %s hull_on_same_deck %s here %s point %s" % d)


if __name__ == "__main__":
    main()
