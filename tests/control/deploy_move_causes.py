"""Round 36 (orders O2): the deploy move's two causes, counted over `make orders-probe`'s rows.jsonl.

Per deployed squad (the probe's columns 1 s after the deploy): `deploy_leg_m` (worst leg as seated), `leg_minmax_m` (the best
seating of the same seats), `leg_compact_m` (that halt's depth halved, best seating), `halt_depth_m`, `twitch_m`.
  SEATING  the seating costs >= SEAT_M: deploy_leg_m - leg_minmax_m >= SEAT_M
  DEPTH    the depth costs >= DEPTH_M even seated best: leg_minmax_m - leg_compact_m >= DEPTH_M
A squad can be both. Counted over every deployed squad and over the TWITCHY ones (twitch_m >= TWITCH_M), by arm, with the
summed legs each fix would save (an upper bound: the counterfactuals are geometry, not driven).
"""
import json
import statistics
import sys

SEAT_M = 8.0
DEPTH_M = 5.0
TWITCH_M = 15.0


def main(path: str) -> None:
    by_arm: dict = {}
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        if float(r.get("deploy_leg_m", -1)) < 0 or float(r.get("leg_minmax_m", -1)) < 0:
            continue
        by_arm.setdefault(r.get("arm", ""), []).append(r)
    for arm, rows in sorted(by_arm.items()):
        for label, sel in (("all deployed", rows), (f"twitch >= {TWITCH_M:.0f} m", [r for r in rows if r["twitch_m"] >= TWITCH_M])):
            if not sel:
                print(f"{arm:10} {label:16} n 0")
                continue
            seat = [r for r in sel if r["deploy_leg_m"] - r["leg_minmax_m"] >= SEAT_M]
            depth = [r for r in sel if r["leg_minmax_m"] - r["leg_compact_m"] >= DEPTH_M]
            both = [r for r in seat if r in depth]
            print(f"{arm:10} {label:16} n {len(sel):3} | seating {len(seat):3} | depth {len(depth):3} | both {len(both):3} | "
                  f"neither {len(sel) - len(seat) - len(depth) + len(both):3} | legs: as seated med "
                  f"{statistics.median(r['deploy_leg_m'] for r in sel):5.1f}, best seating "
                  f"{statistics.median(r['leg_minmax_m'] for r in sel):5.1f}, half depth "
                  f"{statistics.median(r['leg_compact_m'] for r in sel):5.1f} | depth med "
                  f"{statistics.median(r['halt_depth_m'] for r in sel):5.1f} m")
        cells: dict = {}
        for r in rows:
            cells.setdefault((r["map"], r["squads"], r["route"]), []).append(r)
        for cell, rs in sorted(cells.items()):
            seat = sum(1 for r in rs if r["deploy_leg_m"] - r["leg_minmax_m"] >= SEAT_M)
            depth = sum(1 for r in rs if r["leg_minmax_m"] - r["leg_compact_m"] >= DEPTH_M)
            tw = sum(1 for r in rs if r["twitch_m"] >= TWITCH_M)
            print(f"  {arm:8} {cell[0]:9} {cell[1]} {cell[2]:5} squads {len(rs):3} twitchy {tw:3} seating {seat:3} depth {depth:3}")


if __name__ == "__main__":
    main(sys.argv[1])
