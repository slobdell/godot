#!/usr/bin/env python3
"""Brains B1 (C34.5, scout try 2): the bar's orbit-cell lines over `make scout-cells` rows.

Rows are manoeuvre's C339_CELL objects (tests/test_manoeuvre_orbit.gd), one file per scout-rule arm. "on" in a row is
manoeuvre's TURN-IN switch, not the scout rule: turn-in OFF rows are judged, turn-in ON rows reported.
The lines (workstreams.md *Bars (round 34)*, brains B1):
  (a) pooled scout shots ON >= OFF; on ENGAGED cells (ON's ENGAGE ticks >= 30 a run, i.e. >= 1 s), pooled shots ON >= 1.25x OFF
  (b) per cell with OFF median hits >= 10: median damage taken ON <= 1.2x OFF (smaller cells reported)
  (c) ENGAGE ticks ON > 0; out-of-reach cells (orbit radius > the scout's reach): ENGAGE ticks reported
Usage: scout_cells_table.py on.jsonl off.jsonl
"""
import json
import statistics
import sys

med = statistics.median
TICKS_PER_S = 30


def load(path):
    return [json.loads(line) for line in open(path) if line.strip()]


def cells_of(rows, turn_in):
    cells = {}
    for r in rows:
        if bool(r["on"]) != turn_in:
            continue
        key = (r["subject"], r["enemy"], int(r["radius"]), bool(r["player"]))
        cells.setdefault(key, []).append(r)
    return cells


def engage(r):
    return int(r.get("whys", {}).get("ENGAGE", 0))


def table(on_rows, off_rows, turn_in):
    on, off = cells_of(on_rows, turn_in), cells_of(off_rows, turn_in)
    keys = sorted(set(on) & set(off))
    label = "turn-in ON (reported)" if turn_in else "turn-in OFF (judged)"
    print("== %s: %d cells, rows %d v %d, seeds %s" % (label, len(keys), sum(len(on[k]) for k in keys),
          sum(len(off[k]) for k in keys), sorted({r["seed"] for k in keys for r in on[k]})))
    print("%-10s %-9s %3s %-6s %2s | %-11s | %-11s | %-9s | %-11s | %s" % (
        "subject", "enemy", "r", "post", "n", "shots on/off", "dmg on/off", "hits off", "ENGAGE on", "exch on/off"))
    shots = [0, 0]
    eng_shots = [0, 0]
    engaged = []
    worse = []
    small = []
    engage_total = 0
    out_engage = 0
    out_cells = 0
    dmg_all = [[], []]
    for k in keys:
        a, b = on[k], off[k]
        n = min(len(a), len(b))
        s_on, s_off = sum(r["shots"] for r in a), sum(r["shots"] for r in b)
        shots[0] += s_on
        shots[1] += s_off
        e_on = sum(engage(r) for r in a)
        engage_total += e_on
        reach = float(a[0].get("reach_m", 0.0))
        if k[2] > reach:
            out_engage += e_on
            out_cells += 1
        if e_on >= TICKS_PER_S * len(a):
            engaged.append(k)
            eng_shots[0] += s_on
            eng_shots[1] += s_off
        d_on, d_off = med([r["damage"] for r in a]), med([r["damage"] for r in b])
        dmg_all[0] += [r["damage"] for r in a]
        dmg_all[1] += [r["damage"] for r in b]
        h_off = med([r["hits_taken"] for r in b])
        change = (d_on / d_off - 1.0) if d_off > 0 else (0.0 if d_on <= 0 else 1.0)
        (worse if h_off >= 10 else small).append((change, k, d_on, d_off))
        x_on = sum(r["damage_dealt"] for r in a) / max(sum(r["damage"] for r in a), 1e-6)
        x_off = sum(r["damage_dealt"] for r in b) / max(sum(r["damage"] for r in b), 1e-6)
        print("%-10s %-9s %3d %-6s %2d | %5d %5d | %5.0f %5.0f | %9.0f | %11d | %.2f %.2f%s" % (
            k[0], k[1], k[2], "player" if k[3] else "free", n, s_on, s_off, d_on, d_off, h_off, e_on, x_on, x_off,
            "  (out of reach %.0f m)" % reach if k[2] > reach else ""))
    bad = [w for w in worse if w[0] > 0.20]
    a_ok = shots[0] >= shots[1]
    a2_ok = (not engaged) or eng_shots[0] >= 1.25 * eng_shots[1]
    print("(a) pooled shots %d v %d (x%.2f) %s | engaged cells %d: shots %d v %d (x%.2f, bar 1.25) %s" % (
        shots[0], shots[1], shots[0] / max(shots[1], 1), "PASS" if a_ok else "FAIL", len(engaged), eng_shots[0],
        eng_shots[1], eng_shots[0] / max(eng_shots[1], 1), "PASS" if a2_ok else "FAIL"))
    print("(b) cells (OFF hits >= 10) worse by > 20 %%: %d %s %s | pooled damage median %.0f v %.0f (reported)" % (
        len(bad), [(w[1], round(w[2]), round(w[3])) for w in bad], "PASS" if not bad else "FAIL",
        med(dmg_all[0]) if dmg_all[0] else 0, med(dmg_all[1]) if dmg_all[1] else 0))
    for w in sorted(small, reverse=True)[:3]:
        print("    small cell (OFF hits < 10, reported): %s dmg %.0f v %.0f" % (w[1], w[2], w[3]))
    print("(c) ENGAGE ticks ON %d %s | out-of-reach cells %d: ENGAGE ticks %d (reported)" % (
        engage_total, "PASS" if engage_total > 0 else "FAIL", out_cells, out_engage))
    worst = sorted(worse + small, reverse=True)[:1]
    if worst:
        print("worst ON cell (trace it before the medians): %s dmg %.0f v %.0f" % (worst[0][1], worst[0][2], worst[0][3]))
    return a_ok and a2_ok and not bad and engage_total > 0


def main(on_path, off_path):
    on_rows, off_rows = load(on_path), load(off_path)
    judged = table(on_rows, off_rows, False)
    table(on_rows, off_rows, True)
    print("SCOUT_CELLS (1) %s (turn-in OFF judged)" % ("PASS" if judged else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
