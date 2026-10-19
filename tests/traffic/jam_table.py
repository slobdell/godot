#!/usr/bin/env python3
"""Round 34 (traffic T5, measurement on main): crews that die jammed by friendly traffic, from `make traffic-jam-census` logs.

    python3 tests/traffic/jam_table.py DIR [--top 3]

Deaths by cause; jam deaths by what the crew was doing (yielding / blocked by a friend) x who held it (own squad / other
squad / unseated; a set-up battery named) x where (terrain dense/lanes/open; at the base = within BASE_M of the team's start);
under fire (its last hit landed during the jam, or >= 2 hits in the 10 s before); how long jammed before dying; and the
largest EPISODES (jam deaths of one team in one fight within EP_S seconds and EP_M metres of each other), listed.
"""
import collections
import glob
import json
import os
import sys

BASE_M = 40.0
EP_S = 20.0
EP_M = 40.0


def load(folder):
    deaths, census = [], []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        fight = os.path.basename(path)[:-4]
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_DEATH "):
                    r = json.loads(line[10:]); r["fight"] = fight; deaths.append(r)
                elif line.startswith("JAM_CENSUS "):
                    c = json.loads(line[11:]); c["fight"] = fight; census.append(c)
    return deaths, census


def where(r):
    base = r.get("base_m")
    return "base" if base is not None and base <= BASE_M else r.get("terrain", "?")


def under_fire(r):
    return bool(r.get("hit_in_jam")) or int(r.get("hits_10s", 0)) >= 2


def episodes(deaths):
    out = []
    by = collections.defaultdict(list)
    for r in deaths:
        if str(r.get("cause", "")).startswith("jam:"):
            by[(r["fight"], r["team"])].append(r)
    for key, rows in by.items():
        rows = sorted(rows, key=lambda r: r["s"])
        used = [False] * len(rows)
        for i, r in enumerate(rows):
            if used[i]:
                continue
            group = [r]; used[i] = True
            for j in range(i + 1, len(rows)):
                q = rows[j]
                if used[j]:
                    continue
                if any(abs(q["s"] - g["s"]) <= EP_S and ((q["at"][0] - g["at"][0]) ** 2 + (q["at"][1] - g["at"][1]) ** 2) ** 0.5 <= EP_M for g in group):
                    group.append(q); used[j] = True
            out.append((key, group))
    out.sort(key=lambda kg: -len(kg[1]))
    return out


def main(argv):
    top = 3
    if "--top" in argv:
        i = argv.index("--top"); top = int(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
    deaths, census = load(argv[0])
    fights = len(census)
    print("jam census: %d fights with JAM_CENSUS, %d deaths; parkedroom_on %s" % (fights, len(deaths), sorted({c.get("parkedroom_on") for c in census})))
    causes = collections.Counter(str(r.get("cause")) for r in deaths)
    print("\nDeaths by cause (share of all):")
    for cause, n in sorted(causes.items()):
        print("  %-14s %5d  (%4.1f %%)" % (cause, n, 100.0 * n / max(1, len(deaths))))
    jam = [r for r in deaths if str(r.get("cause", "")).startswith("jam:")]
    print("\nJAM deaths %d of %d (%.1f %%), %.2f a fight" % (len(jam), len(deaths), 100.0 * len(jam) / max(1, len(deaths)), len(jam) / max(1, fights)))
    tab = collections.Counter((r["cause"], r.get("blocker_rel") or "?", "battery" if r.get("blocker_setup") else "crew", where(r)) for r in jam)
    print("  what it was doing | held by | that crew | where | n")
    for key, n in tab.most_common():
        print("  %-13s | %-11s | %-7s | %-6s | %d" % (key[0], key[1], key[2], key[3], n))
    print("\n  by who held it: %s" % dict(collections.Counter((r.get("blocker_rel") or "?") + ("/battery" if r.get("blocker_setup") else "") for r in jam)))
    print("  by where: %s" % dict(collections.Counter(where(r) for r in jam)))
    print("  by arena: %s" % dict(collections.Counter(r["fight"].split("-")[0] for r in jam)))
    print("  by hull: %s" % dict(collections.Counter(r.get("hull") for r in jam).most_common(8)))
    uf = sum(1 for r in jam if under_fire(r))
    print("\nUnder fire while jammed (last hit during the jam, or >= 2 hits in the 10 s before): %d of %d (%.0f %%); hit_in_jam alone %d; hits_10s median %s" % (
        uf, len(jam), 100.0 * uf / max(1, len(jam)), sum(1 for r in jam if r.get("hit_in_jam")),
        sorted(int(r.get("hits_10s", 0)) for r in jam)[len(jam) // 2] if jam else "-"))
    js = sorted(float(r.get("jam_s", 0)) for r in jam)
    if js:
        print("Jammed for (s) before dying: p10 %.1f median %.1f p90 %.1f max %.1f; >= 5 s: %d" % (
            js[len(js) // 10], js[len(js) // 2], js[min(len(js) - 1, 9 * len(js) // 10)], js[-1], sum(1 for v in js if v >= 5.0)))
    eps = episodes(deaths)
    sizes = collections.Counter(len(g) for _, g in eps)
    print("\nEpisodes (one team, within %.0f s and %.0f m): %d; by size %s" % (EP_S, EP_M, len(eps), dict(sorted(sizes.items()))))
    for key, group in eps[:top]:
        print("  %s team %s: %d jam deaths %.1f-%.1f s at %s" % (key[0], key[1], len(group), group[0]["s"], group[-1]["s"], where(group[0])))
        for r in group:
            print("    %6.1f s %-18s %-14s %-13s held by %-18s (%s%s) jam %4.1f s hits10s %d hit_in_jam %s v %.1f" % (
                r["s"], r["unit"], r.get("hull"), r["cause"], r.get("blocked_by"), r.get("blocker_rel") or "?",
                "/battery" if r.get("blocker_setup") else "", float(r.get("jam_s", 0)), int(r.get("hits_10s", 0)), r.get("hit_in_jam"), float(r.get("v", 0))))


if __name__ == "__main__":
    main(sys.argv[1:])
