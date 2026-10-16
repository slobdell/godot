#!/usr/bin/env python3
"""Round 32 (manoeuvre H1b): classify the H1B_FAR rows of `make manoeuvre-h1b-drive` logs (the H1b arm's loops that
were not settled). Kinds: MUTUAL (the blocker is itself blocked by this hull), PARKED (the blocker has arrived),
MOVING (the blocker is under way, blocked by someone else or driving), and why each was 'far': SLIDING (the goal moves
>= 0.5 m/s) or ROUTE (> 12 m of route left). Also: the last ask's answer, who `_negotiate` says gives way, yields."""
import json, os, sys
from collections import Counter

# Hull lengths (Units.PROFILES hull_size[2], metres) and the escape's clearance (Movement.UNSTICK_CLEARANCE).
LENGTH = {"scout": 3.04, "tank": 9.70, "ifv": 7.54, "artillery": 8.20, "lancer": 6.46, "burner": 7.54, "gang_scout": 2.93,
          "gang_ifv": 3.44, "gang_tank": 14.00, "gang_artillery": 6.89, "gang_support": 6.58, "law_scout": 3.80,
          "law_ifv": 6.26, "law_tank": 7.30, "law_artillery": 4.95}
CLEARANCE = 2.0
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
# Traffic's draft (C32.10): the yielder backs until the end-to-end gap >= the other's length + clearance. Straight-line,
# nose-to-nose approximation from the centre gap; compared with the straight room the escape's sweep finds (<= 3 m).
need = []
for r in rows:
    mine, theirs = LENGTH.get(r["id"], 7.0), LENGTH.get(r["blocker_id"], 7.0)
    edge = r["gap_m"] - mine / 2 - theirs / 2
    need.append((max(0.0, theirs + CLEARANCE - edge), r.get("my_room_back_m", 0.0), max(0.0, mine + CLEARANCE - edge), r.get("blocker_room_back_m", 0.0)))
mine_need = sorted(n[0] for n in need)
print("H1B_FAR back-off needed if I yield p10/50/90 %s m | if the blocker yields %s m" % (q(mine_need), q(sorted(n[2] for n in need))))
print("H1B_FAR straight room back p10/50/90: me %s | blocker %s (the sweep caps it at 3 m)" % (
      q(sorted(n[1] for n in need)), q(sorted(n[3] for n in need))))
print("H1B_FAR need met by the straight room (<= 3 m): me %d, blocker %d, either %d of %d" % (
      sum(1 for n in need if n[0] <= n[1]), sum(1 for n in need if n[2] <= n[3]),
      sum(1 for n in need if n[0] <= n[1] or n[2] <= n[3]), len(need)))
print("H1B_FAR worst pairs: " + "; ".join("%s %s on %s x%d" % (k[0], k[1], k[2], n) for k, n in pair.most_common(8)))
