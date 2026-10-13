#!/usr/bin/env python3
"""Round 28 (brains B3): the table for `make contact-census` (CONTACT_CENSUS lines, one per seed and arm).

Per arm (standoff on / off): enemy hull contacts in all, under MOVE, by role; recon deaths; screen tasks per recon
squad-minute; each side's survivors; then the paired change per seed. Exit 1 on a missing run.
"""
import json
import sys


def main(paths):
    rows = []
    for path in paths:
        for line in open(path):
            if line.startswith("CONTACT_CENSUS "):
                rows.append(json.loads(line[len("CONTACT_CENSUS "):]))
    arms = {"on": [r for r in rows if not r["screen_off"]], "off": [r for r in rows if r["screen_off"]]}
    for arm, runs in arms.items():
        if not runs:
            continue
        roles = {}
        for r in runs:
            for k, v in r["by_role"].items():
                roles[k] = roles.get(k, 0) + v
        minutes = sum(r["recon_squad_minutes"] for r in runs)
        print("CONTACT_TABLE arm=%s runs=%d contacts=%d under_move=%d recon_deaths=%d of %d recon crews "
              "screen_tasks=%d (%.2f per recon squad-minute) alive green/rust=%d/%d by_role=%s" % (
                  arm, len(runs), sum(r["contacts"] for r in runs), sum(r["under_move"] for r in runs),
                  sum(r["recon_deaths"] for r in runs), sum(r["recon_crews"] for r in runs),
                  sum(r["screen_tasks"] for r in runs), sum(r["screen_tasks"] for r in runs) / max(minutes, 1e-6),
                  sum(r["alive"][0] for r in runs), sum(r["alive"][1] for r in runs), json.dumps(roles, sort_keys=True)))
    on = {r["seed"]: r for r in arms["on"]}
    off = {r["seed"]: r for r in arms["off"]}
    for seed in sorted(set(on) & set(off)):
        a, b = on[seed], off[seed]
        print("CONTACT_PAIR seed=%d under_move %d v %d contacts %d v %d recon_deaths %d v %d alive %s v %s" % (
            seed, a["under_move"], b["under_move"], a["contacts"], b["contacts"], a["recon_deaths"], b["recon_deaths"],
            a["alive"], b["alive"]))
    missing = (set(on) | set(off)) - (set(on) & set(off))
    if missing:
        print("CONTACT_TABLE missing one arm for seeds %s" % sorted(missing))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
