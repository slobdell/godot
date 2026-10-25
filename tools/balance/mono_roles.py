#!/usr/bin/env python3
"""B5 (round 40, balance): in the mono-tank line, what each unit type of the MIXED army trades per credit against the tank
blob, from CP40.0's per-unit GUARD_RESULT rows (dealt/taken are hull+shield points between enemies). The orchestrator's cut:
if the anti-armour units die without trading because of how the CPU fights them, part of the gap is doctrine, not numbers.

    tools/balance/mono_roles.py ROOT [--match -mono-base-]
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

DIR = re.compile(r"mono-(?:.*-)?(?P<faction>condemned|gangs|law|syndicate)-(?P<team>player|enemy)$")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=Path)
    ap.add_argument("--match", default="")
    args = ap.parse_args()
    acc = defaultdict(lambda: defaultdict(float))
    for d in sorted(p for p in args.root.iterdir() if p.is_dir()):
        m = DIR.search(d.name)
        if not m or args.match not in d.name:
            continue
        mono = "green" if m["team"] == "player" else "rust"
        mixed = "rust" if mono == "green" else "green"
        for log in (d / "none").glob("*-green.log"):
            for line in log.read_text(errors="replace").splitlines():
                if not line.startswith("GUARD_RESULT "):
                    continue
                r = json.loads(line[13:])
                for side, who in ((mixed, "mixed"), (mono, "MONO")):
                    for u in r.get("units", {}).get(side, []):
                        a = acc[(m["faction"], who, u["type"])]
                        a["n"] += 1
                        a["cost"] += u["cost"]
                        a["dealt"] += u["dealt"]
                        a["taken"] += u["taken"]
                        a["kills"] += u["kills"]
                        a["alive"] += 1 if u["death"] < 0 else 0
                        a["death_s"] += (u["death"] / 30.0) if u["death"] >= 0 else 0
                        a["dead"] += 0 if u["death"] < 0 else 1
                break
    print("faction    side  type             fielded  dealt/c  taken/c  kills/1kc  lived  mean death s")
    for (faction, who, typ), a in sorted(acc.items()):
        print(f"{faction:10} {who:5} {typ:16} {int(a['n']):7} {a['dealt'] / a['cost']:8.2f} {a['taken'] / a['cost']:8.2f} "
              f"{1000 * a['kills'] / a['cost']:9.2f} {100 * a['alive'] / a['n']:5.0f} % "
              f"{a['death_s'] / a['dead'] if a['dead'] else float('nan'):8.0f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
