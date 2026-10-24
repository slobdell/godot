#!/usr/bin/env python3
"""Round 39 (settle S1): the lab table. Per probe log in DIR (<map>-<n>-<route>-s<seed>-<arm>.log): each squad's arrived_s
(-1 = never in), the run's all_in_s, and the seats the deploys cleared (DEPLOY_TRACE "cleared")."""
import json, os, sys

d = sys.argv[1]
for name in sorted(os.listdir(d)):
    if not name.endswith(".log"):
        continue
    squads, run, cleared, deploys = [], {}, 0, 0
    for line in open(os.path.join(d, name), errors="replace"):
        if line.startswith("ORDERS_PROBE_SQUAD "):
            squads.append(json.loads(line.split(" ", 1)[1]))
        elif line.startswith("ORDERS_PROBE {"):
            run = json.loads(line.split(" ", 1)[1])
        elif line.startswith("DEPLOY_TRACE "):
            deploys += 1
            cleared += int(json.loads(line.split(" ", 1)[1]).get("cleared", 0))
    arr = " ".join("%s" % s.get("arrived_s") for s in squads)
    never = sum(1 for s in squads if float(s.get("arrived_s", -1)) < 0)
    print("%-40s arrived [%s] never-in %d all_in %s deploys %d cleared %d%s" % (name[:-4], arr, never, run.get("all_in_s"),
          deploys, cleared, "" if run else " (NO RUN LINE)"))
