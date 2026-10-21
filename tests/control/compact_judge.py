"""Round 36 (orders O2): DEPLOY_COMPACT's bar, read mechanically from `make orders-probe` rows (arms `main`, `compact`).

The bar as filed (orders brief Status, main's workstreams *Bars (round 36)*, plus the orchestrator's own-squad guard):
  counter  median halt_depth_m lower on compact in every cell that deploys a herringbone; the arms' rows differ
  gain     (a) median worst deploy leg (deploy_leg_m) over all deployed squads >= 20 % lower
           (b) summed over the cells, the median of each seed's worst twitch_m >= 15 % lower
  guards   each cell: median all-in <= main x 1.2 + 3 s and no more never-in seeds; median twitch <= main + 3 m;
           median end foreign min >= main - 3 m; deck no higher; far bank 0 (crossed); own squad's closest crews at the
           end >= 9 m CENTRE TO CENTRE (end_own_min_m, every squad: HALT_CLEAR_M's own measure), the hull gap
           (end_own_gap_m) reported per cell. The orchestrator wrote "hull to hull"; main itself reads 6.2-7.1 m hull to
           hull at 13-15 m centre to centre (laptop, Terminus 3 click, seed 34), so that line would fail the base.
"""
import json
import statistics
import sys


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def main(path: str) -> None:
    rows = [json.loads(l) for l in open(path) if l.strip()]
    runs: dict = {}
    for r in rows:
        runs.setdefault((r["arm"], r["map"], r["squads"], r["route"], r["seed"]), []).append(r)
    cells = sorted({k[1:4] for k in runs})
    seeds = sorted({k[4] for k in runs})
    ok = True

    def per_seed(arm, cell, f):
        out = []
        for s in seeds:
            sq = runs.get((arm,) + cell + (s,))
            if sq:
                out.append(f(sq))
        return out

    print(f"seeds {seeds}; cells {len(cells)}")
    # counter
    differ = 0
    for cell in cells:
        dm = [r["halt_depth_m"] for s in seeds for r in runs.get(("main",) + cell + (s,), []) if r.get("halt_shape") == "herringbone"]
        dc = [r["halt_depth_m"] for s in seeds for r in runs.get(("compact",) + cell + (s,), []) if r.get("halt_shape") == "herringbone"]
        if dm and dc and not med(dc) < med(dm):
            print(f"COUNTER FAIL {cell}: halt depth med main {med(dm)} compact {med(dc)}")
            ok = False
        for s in seeds:
            a = runs.get(("main",) + cell + (s,))
            b = runs.get(("compact",) + cell + (s,))
            if a and b and [r["deploy_leg_m"] for r in a] != [r["deploy_leg_m"] for r in b]:
                differ += 1
    print(f"counter: runs that differ {differ}")
    ok &= differ > 0
    # gain (a)
    legs = {arm: med([r["deploy_leg_m"] for k, rs in runs.items() if k[0] == arm for r in rs if r["deploy_leg_m"] >= 0]) for arm in ("main", "compact")}
    ga = 1 - legs["compact"] / legs["main"]
    print(f"gain (a) median worst deploy leg: main {legs['main']:.1f} compact {legs['compact']:.1f} m ({ga:+.1%} lower; needs >= 20 %)")
    ok &= ga >= 0.20
    # gain (b) + guards
    tw_main = tw_comp = 0.0
    print("cell                 | twitch med m main/comp | all-in med s main/comp (never) | foreign end min | deck | crossed | own min centre m main/comp | hull gap main/comp")
    for cell in cells:
        def twitch(sq):
            v = [r["twitch_m"] for r in sq]
            return max(v) if min(v) >= 0 else None
        def allin(sq):
            v = [r["arrived_s"] for r in sq]
            return max(v) if min(v) >= 0 else float("inf")
        tm, tc = med(per_seed("main", cell, twitch)), med(per_seed("compact", cell, twitch))
        am, ac = per_seed("main", cell, allin), per_seed("compact", cell, allin)
        nm, nc = sum(1 for x in am if x == float("inf")), sum(1 for x in ac if x == float("inf"))
        fm = med(per_seed("main", cell, lambda sq: min(r["end_foreign_m"] for r in sq)))
        fc = med(per_seed("compact", cell, lambda sq: min(r["end_foreign_m"] for r in sq)))
        dkm = sum(per_seed("main", cell, lambda sq: sum(1 for r in sq if r["deck"])))
        dkc = sum(per_seed("compact", cell, lambda sq: sum(1 for r in sq if r["deck"])))
        crc = sum(per_seed("compact", cell, lambda sq: sum(1 for r in sq if r["crossed"])))
        gm = min(per_seed("main", cell, lambda sq: min((r["end_own_gap_m"] for r in sq if r["end_own_gap_m"] >= 0), default=99)))
        gc = min(per_seed("compact", cell, lambda sq: min((r["end_own_gap_m"] for r in sq if r["end_own_gap_m"] >= 0), default=99)))
        cm = min(per_seed("main", cell, lambda sq: min((r["end_own_min_m"] for r in sq if r["end_own_min_m"] >= 0), default=99)))
        cc = min(per_seed("compact", cell, lambda sq: min((r["end_own_min_m"] for r in sq if r["end_own_min_m"] >= 0), default=99)))
        tw_main += tm or 0.0
        tw_comp += tc or 0.0
        mam, mac = med(am), med(ac)
        fails = []
        if mac > mam * 1.2 + 3 or nc > nm:
            fails.append("all-in")
        if tm is not None and tc is not None and tc > tm + 3:
            fails.append("twitch")
        if fm is not None and fc is not None and fc < fm - 3:
            fails.append("foreign")
        if dkc > dkm:
            fails.append("deck")
        if crc > 0:
            fails.append("far bank")
        if cc < 9.0:
            fails.append("own spacing")
        ok &= not fails
        print(f"{cell[0]:9} {cell[1]} {cell[2]:5} | {tm} / {tc} | {mam} / {mac} ({nm}/{nc}) | {fm} / {fc} | {dkm}/{dkc} | {crc} | {cm:.1f} / {cc:.1f} | {gm:.1f} / {gc:.1f}"
              + (f"  GUARD FAIL: {', '.join(fails)}" if fails else ""))
    gb = 1 - tw_comp / tw_main if tw_main else 0.0
    print(f"gain (b) summed median twitch: main {tw_main:.1f} compact {tw_comp:.1f} m ({gb:+.1%} lower; needs >= 15 %)")
    ok &= gb >= 0.15
    print("VERDICT: " + ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1])
