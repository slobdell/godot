#!/usr/bin/env python3
"""Bar B1's staged corpus judge (round 44, R44's conditions): NOSED_ROW lines from tests/test_manoeuvre_nosed_corpus.gd
(NOSED_CORPUS=on, NOSED_SEED=<n> for the bar's fresh jittered poses), off v on per pose, time to clear CLEAR_M.
A pose is BASE-STUCK (R44.12) when the base has not cleared within STUCK_TICKS of the order (180 = 6 s: a rig turning away at
its own lock clears 8 m in 2-5 s) AND the base's rig had no yielding or blocked-by-a-friend ticks in its first 6 s (a squadmate
pinning it is not the box); both read from the base row. A pose over 6 s WITH such ticks is "pinned": it goes under the ceiling; a pose that never clears in the
window counts as the window's end. Deciding (on the base-stuck poses, floor STUCK_FLOOR): ON clears sooner in >= WIN_SHARE of them
and the median gain is MEDIAN_S or better. The cost ceiling (on the other poses): every pose ON <= OFF + CEIL_S, and the median
<= CEIL_MEDIAN_S. Reported per pose: the first reversing tick, the metres crept before it, the pose's nose room and route angle.
    python3 tests/manoeuvre/nosed_judge.py <test log(s)...>"""
import json, sys, statistics

WATCH_TICKS = 12 * 30
STUCK_TICKS = 180
STUCK_FLOOR = 8
WIN_SHARE = 0.8
MEDIAN_S = -1.0
CEIL_S = 3.0
CEIL_MEDIAN_S = 1.0


def main():
    paths = [a for a in sys.argv[1:] if not a.startswith("--")]
    rows = {}
    for path in paths:
        for line in open(path):
            if line.startswith("NOSED_ROW "):
                r = json.loads(line[len("NOSED_ROW "):])
                key = (str(r.get("seed", "")), int(r["pose"]))
                rows.setdefault(key, {})[r["arm"]] = r
    stuck, open_ = [], []
    for key in sorted(rows):
        pair = rows[key]
        if "off" not in pair or "on" not in pair:
            continue
        b = pair["off"]["clear_tick"] if pair["off"]["clear_tick"] > 0 else WATCH_TICKS
        a = pair["on"]["clear_tick"] if pair["on"]["clear_tick"] > 0 else WATCH_TICKS
        d = (a - b) / 30.0
        # R44.12: base-stuck = the base has not cleared within STUCK_TICKS AND its rig had no yield / blocked-by-friend seconds in
        # its first 6 s (both read from the BASE row: a squadmate pinning the rig is not the box).
        pinned = int(pair["off"].get("yield_ticks_6s", 0)) + int(pair["off"].get("blocked_friend_ticks_6s", 0)) > 0
        kind = "STUCK" if (b > STUCK_TICKS and not pinned) else ("pinned" if b > STUCK_TICKS else "open")
        (stuck if kind == "STUCK" else open_).append(d)
        print("  %s pose %2d %-8s %-5s %+4.0f deg (route %+4.0f, nose %4.1f m) %s: clear t%d -> t%d (%+.1f s); first reverse t%d -> t%d; crept %.2f -> %.2f m; looks %d kturns %d; native_drive %s" % (
            key[0] or "dev", key[1], pair["off"]["arena"], pair["off"]["shape"], pair["off"]["angle"], pair["off"].get("depart_deg", 0.0),
            pair["off"].get("nose_room_m", -1.0), kind, b, a, d, pair["off"]["first_reverse"], pair["on"]["first_reverse"],
            pair["off"]["crept_m"], pair["on"]["crept_m"], pair["on"]["looks"], pair["on"].get("kturns", 0), pair["on"]["native_drive"]))
    wins = sum(1 for d in stuck if d < 0)
    med = statistics.median(stuck) if stuck else 0.0
    d_ok = len(stuck) >= STUCK_FLOOR and wins >= WIN_SHARE * len(stuck) and med <= MEDIAN_S
    print("D (base-stuck poses, floor %d): %d poses, ON sooner in %d (line >= %.0f %%), median %+.2f s (line <= %+.1f): %s" % (
        STUCK_FLOOR, len(stuck), wins, WIN_SHARE * 100, med, MEDIAN_S, "PASS" if d_ok else ("INCONCLUSIVE" if len(stuck) < STUCK_FLOOR else "FAIL")))
    worst = max(open_) if open_ else 0.0
    omed = statistics.median(open_) if open_ else 0.0
    c_ok = worst <= CEIL_S and omed <= CEIL_MEDIAN_S
    print("C (the other poses' cost ceiling): %d poses, worst %+.1f s (line <= +%.1f), median %+.2f s (line <= +%.1f): %s" % (
        len(open_), worst, CEIL_S, omed, CEIL_MEDIAN_S, "PASS" if c_ok else "FAIL"))
    print("VERDICT: %s" % ("PASS" if d_ok and c_ok else ("NOT JUDGED (under the floor of %d base-stuck poses)" % STUCK_FLOOR if len(stuck) < STUCK_FLOOR else "FAIL")))


if __name__ == "__main__":
    main()
