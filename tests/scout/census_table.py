#!/usr/bin/env python3
"""Round 27 (scout S0): the scout census table, one row per seed and the pooled line (mk/scout.mk scout-census)."""
import json
import sys

KEYS = ["fight_s", "on_target_s", "close_s", "reverse_s", "contacts", "contacts_target"]


def main(paths):
    pooled = {k: 0.0 for k in KEYS}
    scouts = 0
    print("%-6s %-10s %-22s %6s %8s %9s %7s %8s %8s %8s" % ("seed", "arena", "factions", "scouts", "fight_s",
          "on_tgt", "close", "reverse", "contacts", "on_tgt_c"))
    for path in paths:
        row = None
        for line in open(path, errors="replace"):
            if line.startswith("SCOUT_CENSUS "):
                row = json.loads(line[len("SCOUT_CENSUS "):])
        if row is None:
            print("%-6s MISSING (%s)" % (path.rsplit("/", 1)[-1], path))
            continue
        fight = row["fight_s"] or 1e-9
        print("%-6s %-10s %-22s %6d %8.1f %8.0f%% %6.0f%% %7.0f%% %8d %8d" % (row["seed"], row["arena"],
              "/".join(row["factions"]), row["scouts"], row["fight_s"], 100 * row["on_target_s"] / fight,
              100 * row["close_s"] / fight, 100 * row["reverse_s"] / fight, row["contacts"], row["contacts_target"]))
        scouts += row["scouts"]
        for k in KEYS:
            pooled[k] += row[k]
    fight = pooled["fight_s"] or 1e-9
    print("SCOUT_CENSUS_POOLED scouts=%d fight_s=%.0f on_target=%.1f%% close=%.1f%% reverse=%.1f%% contacts=%d "
          "contacts_target=%d contacts_per_fight_min=%.2f" % (scouts, pooled["fight_s"],
          100 * pooled["on_target_s"] / fight, 100 * pooled["close_s"] / fight, 100 * pooled["reverse_s"] / fight,
          pooled["contacts"], pooled["contacts_target"], 60 * pooled["contacts"] / fight))


if __name__ == "__main__":
    main(sys.argv[1:])
