"""Round 36 (orders, R36.6): the post-deploy twitch NOT explained by the deploy move ("neither": neither seating nor
depth, deploy_move_causes.py), split by what the off-seat crews were doing (the probe's `twitch_seen`: brain option ticks
while a crew stood > 3 m off its placed seat after the place window; "@goal" = it had an order goal then).

  ENGAGEMENT     a fight option (anything but MOVE / HOLD) shown for >= FIGHT_TICKS: the crew left its seat to fight
  STOPPED SHORT  otherwise, HOLD with no goal outweighs MOVE@goal: it sits off its seat, no longer sent to it
  TRAFFIC        otherwise: it is still driving to its seat (MOVE@goal), held up among other crews

Counted over every twitchy squad (twitch_m >= TWITCH_M) and over the "neither" ones, per cell, with an example of each
(cell, seed, squad) for a trace.
"""
import collections
import json
import sys

TWITCH_M = 15.0
SEAT_M = 8.0
DEPTH_M = 5.0
FIGHT_TICKS = 30  # 0.5 s at 60 Hz


def kind(seen: dict) -> str:
    fight = sum(v for k, v in seen.items() if k.split("@")[0] not in ("MOVE", "HOLD", "-", ""))
    if fight >= FIGHT_TICKS:
        return "ENGAGEMENT"
    hold = sum(v for k, v in seen.items() if k == "HOLD")
    move = sum(v for k, v in seen.items() if k == "MOVE@goal")
    return "STOPPED SHORT" if hold > move else "TRAFFIC"


def main(path: str) -> None:
    rows = [json.loads(l) for l in open(path) if l.strip()]
    rows = [r for r in rows if r.get("deploy_leg_m", -1) >= 0 and "twitch_seen" in r]
    twitchy = [r for r in rows if r["twitch_m"] >= TWITCH_M]
    neither = [r for r in twitchy if not (r["deploy_leg_m"] - r["leg_minmax_m"] >= SEAT_M)
               and not (r["leg_minmax_m"] - r["leg_compact_m"] >= DEPTH_M)]
    print(f"deployed squads {len(rows)}, twitchy (>= {TWITCH_M:.0f} m) {len(twitchy)}, of them neither seating nor depth {len(neither)}")
    for label, sel in (("all twitchy", twitchy), ("neither", neither)):
        c = collections.Counter(kind(r["twitch_seen"]) for r in sel)
        print(f"  {label:12}: " + ", ".join(f"{k} {c[k]}" for k in ("ENGAGEMENT", "STOPPED SHORT", "TRAFFIC")))
    print("per cell (neither): engagement / stopped short / traffic")
    cells = collections.defaultdict(collections.Counter)
    for r in neither:
        cells[(r["map"], r["squads"], r["route"])][kind(r["twitch_seen"])] += 1
    for cell in sorted(cells):
        c = cells[cell]
        print(f"  {cell[0]:9} {cell[1]} {cell[2]:5}  {c['ENGAGEMENT']:2} / {c['STOPPED SHORT']:2} / {c['TRAFFIC']:2}")
    by_squad = collections.defaultdict(collections.Counter)
    for r in neither:
        by_squad[r["squad"]][kind(r["twitch_seen"])] += 1
    print("per squad number (neither): " + "; ".join(f"{k}: {dict(v)}" for k, v in sorted(by_squad.items())))
    fights = collections.Counter()
    for r in neither:
        if kind(r["twitch_seen"]) == "ENGAGEMENT":
            for k, v in r["twitch_seen"].items():
                if k.split("@")[0] not in ("MOVE", "HOLD", "-", ""):
                    fights[k.split("@")[0]] += v
    print(f"fight options among ENGAGEMENT (ticks): {dict(fights)}")
    print("examples (largest twitch of each kind): map squads route seed squad twitch_m")
    for k in ("ENGAGEMENT", "STOPPED SHORT", "TRAFFIC"):
        ex = sorted((r for r in neither if kind(r["twitch_seen"]) == k), key=lambda r: -r["twitch_m"])[:2]
        for r in ex:
            print(f"  {k:13} {r['map']} {r['squads']} {r['route']} {r['seed']} sq{r['squad']} {r['twitch_m']} {r['twitch_seen']}")


if __name__ == "__main__":
    main(sys.argv[1])
