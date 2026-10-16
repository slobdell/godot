#!/usr/bin/env python3
"""Round 32 (manoeuvre H1b): classify the H1B_FAR rows of `make manoeuvre-h1b-drive` logs (the H1b arm's loops that
were not settled). Kinds: MUTUAL (the blocker is itself blocked by this hull), PARKED (the blocker has arrived),
MOVING (the blocker is under way, blocked by someone else or driving), and why each was 'far': SLIDING (the goal moves
>= 0.5 m/s) or ROUTE (> 12 m of route left). Also: the last ask's answer, who `_negotiate` says gives way, yields."""
import json, os, sys
from collections import Counter

rows = []
for path in sys.argv[1:]:
    run = os.path.basename(path)[:-4]
    for line in open(path, errors="replace"):
        if line.startswith("H1B_FAR "):
            r = json.loads(line[len("H1B_FAR "):])
            r["run"] = run
            rows.append(r)
if not rows:
    print("H1B_FAR none")
    sys.exit(0)
kind, why, answer, neg, pair = Counter(), Counter(), Counter(), Counter(), Counter()
for r in rows:
    if r["blocker_phase"] == "arrived" or not r["blocker_under_way"]:
        k = "PARKED"
    elif r["blocker_blocked_by"] == r["unit"]:
        k = "MUTUAL"
    else:
        k = "MOVING(%s)" % (r["blocker_phase"] or "?")
    kind[k] += 1
    why["SLIDING" if r["goal_v"] >= 0.5 else "ROUTE"] += 1
    answer["ask " + ("yes" if r["last_ask_answer"] else "no")] += 1
    neg["negotiate: I give way" if r["negotiate_i_give_way"] else "negotiate: it gives way"] += 1
    pair[(r["run"], r["unit"], r["blocker"])] += 1
print("H1B_FAR rows %d, distinct (run, hull, blocker) pairs %d" % (len(rows), len(pair)))
for c in (kind, why, answer, neg):
    print("H1B_FAR " + " | ".join("%s %d" % kv for kv in c.most_common()))
rem = sorted(r["remaining_m"] for r in rows)
brem = sorted(r["blocker_remaining_m"] for r in rows)
q = lambda a: [a[int(len(a) * p)] for p in (0.1, 0.5, 0.9)]
print("H1B_FAR route left p10/50/90 %s | blocker's %s | gap %s" % (q(rem), q(brem), q(sorted(r["gap_m"] for r in rows))))
print("H1B_FAR yielding at the fire: me %d, blocker %d (to me %d)" % (sum(1 for r in rows if r["my_yield_to"]),
      sum(1 for r in rows if r["blocker_yield_to"]), sum(1 for r in rows if r["blocker_yield_to"] == r["unit"])))
both = sum(1 for r in rows if r.get("blocker_escaping_on_me") and not r["last_ask_answer"] and not r.get("blocker_last_ask_answer"))
print("H1B_FAR refused BOTH ways (the blocker escaping on me too, both asks no): %d of %d" % (both, len(rows)))
back = Counter(("me" if r.get("my_room_back_m", 0) >= 1.0 else "-") + "/" + ("blocker" if r.get("blocker_room_back_m", 0) >= 1.0 else "-") for r in rows)
print("H1B_FAR straight room back >= 1 m (me/blocker): " + " | ".join("%s %d" % kv for kv in back.most_common()))
print("H1B_FAR worst pairs: " + "; ".join("%s %s on %s x%d" % (k[0], k[1], k[2], n) for k, n in pair.most_common(8)))
