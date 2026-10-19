#!/usr/bin/env python3
"""C33.9's bar (main 82752ecc) over manoeuvre-c339-cells rows (one JSON object per line; any number of files).

Player-post cells (his case):
  (a) median in-arc % ON >= 2x OFF and >= 25        (b) median scout shots ON >= 1.5x OFF
  (c) median hits ON <= OFF; per cell (OFF median hits >= 10) ON no worse than +20 %; smaller cells reported
  (d) ON, while a face order holds: 0 reverse ticks in every run, <= 2 gear changes per run
  (e) ON's furthest point from the post <= 29 m (18 m leash + 11 m turning circle)
Free cells: (g) ON no worse than OFF on (a)-(c) (medians).
Usage: c339_table.py rows.jsonl [more.jsonl ...]
"""
import json
import statistics
import sys

med = statistics.median


def cells_of(rows):
    cells = {}
    for r in rows:
        key = (r["subject"], r["enemy"], int(r["radius"]), bool(r["player"]))
        cells.setdefault(key, {True: [], False: []})[bool(r["on"])].append(r)
    return cells


def main(paths):
    rows = [json.loads(line) for p in paths for line in open(p) if line.strip()]
    cells = cells_of(rows)
    seeds = sorted({r["seed"] for r in rows})
    print("rows %d, seeds %s" % (len(rows), seeds))
    print("%-10s %-9s %3s %-6s %2s | %-11s | %-9s | %-9s | %7s %7s %6s" % (
        "subject", "enemy", "r", "post", "n", "in-arc off/on", "shots", "hits", "revface", "flipsf", "far"))
    worst = []
    small = []
    d_rev = d_flips = e_far = 0
    pooled = {pl: {on: {"in_arc_pct": [], "shots": [], "hits_taken": []} for on in (False, True)} for pl in (False, True)}
    for key in sorted(cells):
        off, on = cells[key][False], cells[key][True]
        for arm, rs in ((False, off), (True, on)):
            for k in pooled[key[3]][arm]:
                pooled[key[3]][arm][k] += [float(r[k]) for r in rs]
        h_off, h_on = med([r["hits_taken"] for r in off]), med([r["hits_taken"] for r in on])
        if key[3]:
            change = (h_on / h_off - 1.0) if h_off > 0 else 0.0
            (worst if h_off >= 10 else small).append((change, key, h_off, h_on))
            d_rev = max([d_rev] + [r.get("rev_face", 0) for r in on])
            d_flips = max([d_flips] + [r.get("flips_face", 0) for r in on])
            e_far = max([e_far] + [r["far_m"] for r in on])
        print("%-10s %-9s %3d %-6s %2d | %5.1f %5.1f | %4.0f %4.0f | %4.0f %4.0f | %7s %7s %6s" % (
            key[0], key[1], key[2], "player" if key[3] else "free", min(len(off), len(on)),
            med([r["in_arc_pct"] for r in off]), med([r["in_arc_pct"] for r in on]),
            med([r["shots"] for r in off]), med([r["shots"] for r in on]), h_off, h_on,
            max(r.get("rev_face", 0) for r in on) if key[3] else "-", max(r.get("flips_face", 0) for r in on) if key[3] else "-",
            "%.1f" % max(r["far_m"] for r in on) if key[3] else "-"))
    # The ruling (main, round 33 overnight): (a) and (c) are read on IN-REACH cells (the orbit radius within the scout's
    # gun's effective reach, `reach_m`); out-of-reach cells: pooled hits ON <= OFF and no cell worse than +20 % (OFF hits
    # >= 10), in-arc reported. (b) stays on every player cell.
    def reach_of(key):
        rs = cells[key][True] + cells[key][False]
        return float(rs[0].get("reach_m", 1e9)) if rs else 1e9
    inr = {k: c for k, c in cells.items() if k[3] and k[2] <= reach_of(k)}
    outr = {k: c for k, c in cells.items() if k[3] and k[2] > reach_of(k)}
    def pool(cs, arm, field):
        return [float(r[field]) for c in cs.values() for r in c[arm]]
    a_off, a_on = med(pool(inr, False, "in_arc_pct")), med(pool(inr, True, "in_arc_pct"))
    b_off, b_on = med(pooled[True][False]["shots"]), med(pooled[True][True]["shots"])
    c_off, c_on = med(pool(inr, False, "hits_taken")), med(pool(inr, True, "hits_taken"))
    worst_in = max(((v[0], v[1]) for v in worst if v[1] in inr), default=(0.0, None))
    worst_out = max(((v[0], v[1]) for v in worst if v[1] in outr), default=(0.0, None))
    print()
    print("PLAYER-POST CELLS (in reach: %s)" % sorted("%s/%s/%d" % (k[0], k[1], k[2]) for k in inr))
    print("(a) in-arc %% on in-reach cells: off %.1f on %.1f -> %s" % (a_off, a_on, "PASS" if a_on >= 2 * a_off and a_on >= 25 else "FAIL"))
    print("(b) shots, every player cell: off %.0f on %.0f -> %s" % (b_off, b_on, "PASS" if b_on >= 1.5 * b_off else "FAIL"))
    # (c) in reach, the ruling (workstreams.md, main, before 31-36): the EXCHANGE. Pooled damage dealt / taken ON >= OFF;
    # no in-reach cell's exchange worse than OFF's by more than 20 % (cells with OFF hits >= 10); hits taken reported.
    def exchange(rs):
        taken = sum(float(r["damage"]) for r in rs)
        return sum(float(r.get("damage_dealt", 0.0)) for r in rs) / taken if taken > 0 else float("inf")
    x_off = exchange([r for c in inr.values() for r in c[False]])
    x_on = exchange([r for c in inr.values() for r in c[True]])
    x_worst = (0.0, None)
    for key, c in inr.items():
        if med([r["hits_taken"] for r in c[False]]) < 10:
            continue
        xo, xn = exchange(c[False]), exchange(c[True])
        change = (xn / xo - 1.0) if xo > 0 else 0.0
        if x_worst[1] is None or change < x_worst[0]:
            x_worst = (change, key)
    print("(c) exchange on in-reach cells (damage dealt / taken): off %.2f on %.2f; worst cell %+.0f %% %s -> %s" % (
        x_off, x_on, 100 * x_worst[0], x_worst[1], "PASS" if x_on >= x_off and x_worst[0] >= -0.20 else "FAIL"))
    print("    reported: in-reach hits taken off %.0f on %.0f; worst cell %+.0f %% %s" % (c_off, c_on, 100 * worst_in[0], worst_in[1]))
    if outr:
        co_off, co_on = med(pool(outr, False, "hits_taken")), med(pool(outr, True, "hits_taken"))
        print("(c-out) out-of-reach cells: pooled hits off %.0f on %.0f; worst cell with off >= 10: %+.0f %% %s -> %s" % (
            co_off, co_on, 100 * worst_out[0], worst_out[1], "PASS" if co_on <= co_off and worst_out[0] <= 0.20 else "FAIL"))
        print("    reported: out-of-reach in-arc off %.1f on %.1f" % (med(pool(outr, False, "in_arc_pct")), med(pool(outr, True, "in_arc_pct"))))
    for change, key, h_off, h_on in sorted(small, reverse=True):
        print("    reported (off < 10): %s %.0f -> %.0f (%+.0f %%)" % (key, h_off, h_on, 100 * change))
    print("    damage (reported, not judged): off %.0f on %.0f; mean distance off %.1f on %.1f m" % (
        med([float(r["damage"]) for k, c in cells.items() if k[3] for r in c[False]]),
        med([float(r["damage"]) for k, c in cells.items() if k[3] for r in c[True]]),
        med([float(r.get("mean_d", 0)) for k, c in cells.items() if k[3] for r in c[False]]),
        med([float(r.get("mean_d", 0)) for k, c in cells.items() if k[3] for r in c[True]])))
    # (d) as filed on main after R33.23: reverse ticks under a REVERSE COMMAND 0 in every run, gear changes counted by
    # command <= 2; total reverse ticks (contact bounces under a forward command) REPORTED with what they touched.
    on_player = [r for k, c in cells.items() if k[3] for r in c[True]]
    d_cmd = max(r.get("rev_face_cmd", 0) for r in on_player)
    d_flips_cmd = max(r.get("flips_face_cmd", 0) for r in on_player)
    print("(d) while a face holds: reverse ticks under a reverse command max %d, commanded gear changes max %d -> %s" % (
        d_cmd, d_flips_cmd, "PASS" if d_cmd == 0 and d_flips_cmd <= 2 else "FAIL"))
    d2 = max(r.get("rev_stop", 0) for r in on_player)
    off_player = [r for k, c in cells.items() if k[3] for r in c[False]]
    print("(d2) while the order is stop: reverse ticks max %d -> %s; OFF max %d (median %d); stop swings turned in, ON median %d" % (
        d2, "PASS" if d2 == 0 else "FAIL", max(r.get("rev_stop", 0) for r in off_player),
        med([r.get("rev_stop", 0) for r in off_player]), med([r.get("stop_turn_ins", 0) for r in on_player])))
    touched = {}
    for r in on_player:
        for who, n in r.get("bounces", {}).items():
            touched[who] = touched.get(who, 0) + n
    print("    reported: total reverse ticks max %d (runs with any %d of %d), plant gear changes max %d; bounces touched %s" % (
        d_rev, sum(1 for r in on_player if r.get("rev_face", 0) > 0), len(on_player), d_flips,
        dict(sorted(touched.items(), key=lambda kv: -kv[1]))))
    print("(e) furthest from post %.1f m -> %s" % (e_far, "PASS" if e_far <= 29.0 else "FAIL"))
    print("    while a face holds (the turn-in's): %.1f m" % max([r.get("far_face_m", 0.0) for k, c in cells.items() if k[3] for r in c[True]]))
    f = pooled[False]
    g = [med(f[True]["in_arc_pct"]) >= med(f[False]["in_arc_pct"]), med(f[True]["shots"]) >= med(f[False]["shots"]),
         med(f[True]["hits_taken"]) <= med(f[False]["hits_taken"])]
    print("FREE CELLS (g): in-arc off %.1f on %.1f, shots off %.0f on %.0f, hits off %.0f on %.0f -> %s" % (
        med(f[False]["in_arc_pct"]), med(f[True]["in_arc_pct"]), med(f[False]["shots"]), med(f[True]["shots"]),
        med(f[False]["hits_taken"]), med(f[True]["hits_taken"]), "PASS" if all(g) else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1:])
