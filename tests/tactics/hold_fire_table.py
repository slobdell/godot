#!/usr/bin/env python3
"""Round 38 (doctrine D1): who fires on the move, and why, from tactics-hold-fire's rows.jsonl (HOLD_FIRE lines).

    python3 tests/tactics/hold_fire_table.py rows.jsonl [--top N]

Per line (blob / turtle) and side (the ordered guard / the CPU): direct rounds and 2 Hz crew samples split by the CPU's
posture, the shooter's element task verb, its brain option and how far it stood from its slot, each with its share
moving (>= 0.15 of top speed, R37.26's "faster than a crawl"). Rows are sorted by moving rounds, so the top rows are where
a stop-to-fire doctrine has the most to take back.
"""
import json
import math
import sys


def merged(rows, who, part):
    out = {}
    for r in rows:
        for key, counts in r[part][who].items():
            acc = out.setdefault(key, [0, 0, 0])
            for i in range(3):
                acc[i] += counts[i]
    return out


def by_field(table, index):
    out = {}
    for key, counts in table.items():
        field = key.split("|")[index] if index >= 0 else "all"
        acc = out.setdefault(field, [0, 0, 0])
        for i in range(3):
            acc[i] += counts[i]
    return out


def seed_se(rows, who, part, pick):
    """The per-seed se of the moving share among the keys `pick` accepts (seeds are the 2-seed blocks' unit)."""
    by_seed = {}
    for r in rows:
        acc = by_seed.setdefault(r["seed"], [0, 0])
        for key, c in r[part][who].items():
            if pick(key):
                acc[0] += c[1] + c[2]
                acc[1] += sum(c)
    shares = [m / t for m, t in by_seed.values() if t]
    if len(shares) < 2:
        return None
    mean = sum(shares) / len(shares)
    return math.sqrt(sum((x - mean) ** 2 for x in shares) / (len(shares) - 1)) / math.sqrt(len(shares))


def show(title, table, total, top):
    print("    %s" % title)
    ordered = sorted(table.items(), key=lambda kv: -(kv[1][1] + kv[1][2]))
    for key, c in [kv for kv in ordered if sum(kv[1])][:top]:
        n = sum(c)
        print("      %-44s n %6d (%4.1f %% of all)  still %5.1f  slow %5.1f  fast %5.1f  | moving %5.1f %%  (%4.1f %% of all moving)" % (
            key, n, 100 * n / total["n"] if total["n"] else 0, 100 * c[0] / n, 100 * c[1] / n, 100 * c[2] / n,
            100 * (c[1] + c[2]) / n, 100 * (c[1] + c[2]) / total["moving"] if total["moving"] else 0))


def main(argv):
    path = argv[1]
    top = int(argv[argv.index("--top") + 1]) if "--top" in argv else 14
    rows = [json.loads(line) for line in open(path) if line.strip()]
    print("fights %d, args %s, not listening %d" % (len(rows), sorted({r["args"] for r in rows}),
                                                    sum(1 for r in rows if not r["listening"])))
    for kind in sorted({r["guard"] for r in rows}):
        line = [r for r in rows if r["guard"] == kind]
        print("%s line: %d fights" % (kind.upper(), len(line)))
        for who in ("tactics", "guard"):
            label = "CPU" if who == "tactics" else kind
            for part, unit in (("shots", "rounds"), ("dmg", "damage fired (rounds x damage a round)"), ("time", "crew samples at 2 Hz")):
                if not all(part in r for r in line):
                    continue
                table = merged(line, who, part)
                total = {"n": sum(sum(c) for c in table.values()),
                         "moving": sum(c[1] + c[2] for c in table.values())}
                if not total["n"]:
                    continue
                se = seed_se(line, who, part, lambda k: True)
                print("  %s %s: %d, moving %.1f %% (per-seed se %s)" % (label, unit, total["n"],
                      100 * total["moving"] / total["n"], "n/a" if se is None else "%.1f" % (100 * se)))
                if who == "tactics":
                    for name, index in (("posture", 0), ("verb", 1), ("option", 2), ("seat", 3)):
                        show("by %s" % name, by_field(table, index), total, top)
                    held = {k: v for k, v in table.items() if k.split("|")[0] == "hold"}
                    show("posture hold, by verb|option|seat", {"|".join(k.split("|")[1:]): v for k, v in held.items()},
                         total, top)
                else:
                    show("by option", by_field(table, 2), total, 6)
        if all("why" in r for r in line):
            why = {}
            for r in line:
                for key, c in r["why"].items():
                    acc = why.setdefault(key, [0, 0, 0])
                    for i in range(3):
                        acc[i] += c[i]
            for suffix, unit in (("", "rounds"), ("|dmg", "damage")):
                part = {k[:-len(suffix)] if suffix else k: v for k, v in why.items() if k.endswith("|dmg") == bool(suffix)}
                total = {"n": sum(sum(c) for c in part.values()), "moving": sum(c[1] + c[2] for c in part.values())}
                if total["n"]:
                    show("CPU %s by posture reason|shooter's half" % unit, part, total, 12)


if __name__ == "__main__":
    main(sys.argv)
