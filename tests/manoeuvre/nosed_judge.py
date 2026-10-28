#!/usr/bin/env python3
"""Bar B1's staged corpus judge: NOSED_ROW lines from tests/test_manoeuvre_nosed_corpus.gd (NOSED_CORPUS=on), off v on per pose.
Deciding: ON clears CLEAR_M sooner than OFF in at least WIN_OF of the poses (a pose that never clears in the window counts as the
window's end), and the median of (ON - OFF) is MEDIAN_S seconds or better. Reported: the first reversing tick and the metres crept
forward before it, per pose.    python3 tests/manoeuvre/nosed_judge.py <test log> [--win=10] [--median=-1.0]"""
import json, sys, statistics

WATCH_TICKS = 12 * 30


def main():
    path = [a for a in sys.argv[1:] if not a.startswith("--")][0]
    opt = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    win_of, median_line = int(opt.get("win", 10)), float(opt.get("median", -1.0))
    rows = {}
    for line in open(path):
        if line.startswith("NOSED_ROW "):
            r = json.loads(line[len("NOSED_ROW "):])
            rows.setdefault(int(r["pose"]), {})[r["arm"]] = r
    diffs, wins, n = [], 0, 0
    for pose in sorted(rows):
        pair = rows[pose]
        if "off" not in pair or "on" not in pair:
            continue
        n += 1
        b = pair["off"]["clear_tick"] if pair["off"]["clear_tick"] > 0 else WATCH_TICKS
        a = pair["on"]["clear_tick"] if pair["on"]["clear_tick"] > 0 else WATCH_TICKS
        d = (a - b) / 30.0
        diffs.append(d)
        wins += 1 if a < b else 0
        print("  pose %2d %-8s %-5s %+4.0f deg (route %+4.0f, nose %4.1f m): clear t%d -> t%d (%+.1f s); first reverse t%d -> t%d; crept %.2f -> %.2f m; looks %d swings %d kturns %d; native_drive %s" % (
            pose, pair["off"]["arena"], pair["off"]["shape"], pair["off"]["angle"], pair["off"].get("depart_deg", 0.0), pair["off"].get("nose_room_m", -1.0),
            b, a, d, pair["off"]["first_reverse"], pair["on"]["first_reverse"],
            pair["off"]["crept_m"], pair["on"]["crept_m"], pair["on"]["looks"], pair["on"].get("swings", 0), pair["on"].get("kturns", 0), pair["on"]["native_drive"]))
    med = statistics.median(diffs) if diffs else 0.0
    ok = n >= 12 and wins >= win_of and med <= median_line
    print("Bar B1 corpus: %d poses, ON sooner in %d (line >= %d), median %+.2f s (line <= %+.1f): %s" % (n, wins, win_of, med, median_line, "PASS" if ok else "FAIL"))
    print("VERDICT: %s" % ("PASS" if ok else ("INCONCLUSIVE (under 12 poses)" if n < 12 else "FAIL")))


if __name__ == "__main__":
    main()
