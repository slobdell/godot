#!/usr/bin/env python3
"""Round 29 (manoeuvre M4): pinned crew-seconds in hull-rest runs, two arms paired by run.

Usage: pinned_table.py BASE_DIR NEW_DIR (each <faction>/<task>-<seed>/run.log with MANOEUVRE_STATE lines, --turn-states).
A crew is PINNED while, for >= 10 consecutive 1 s state lines, it is on a move_to with |throttle| > 0.3 and its distance to
its goal changes by < 0.05 m between lines: defined by command and real displacement, not by the reported velocity (the
reading M4 changes). Pinned crew-seconds per run (the whole streak counts once it reaches 10), summed, paired by run, se.
Scouts (scout, law_scout, gang_scout) and tracks (`tank`) reported apart; plus the STUCK reading (below). Report only.
"""
import pathlib
import re
import statistics
import sys

STATE = re.compile(r"MANOEUVRE_STATE f (\d+) (.+?) (\S+) order (\S*) from (\S*) v ([-\d.]+) moved ([-\d.]+) "
                   r"cmd ([-\d.]+)/([-\d.]+) .* goal ([-\d.]+)")
SCOUTS = {"scout", "law_scout", "gang_scout"}
RIG = "gang_tank"


## Round 30 (M4b): a second reading, STUCK crew-seconds: on a move_to with |throttle| > 0.3, seconds in a run of >= 10
## during which the crew never got PROGRESS_M closer to its goal than it had been at the run's start. A pinned crew is
## stuck; so is one that backs off 1.5 m and drives straight back into the same blocker every 3 s (the tuning seeds'
## mixed-21 IFV: 73 s of that under M4b, which the pinned count above cannot see because its goal distance moves).
PROGRESS_M = 1.0


def run_pinned(log):
    hist = {}
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("SCREEN {"):
            break
        m = STATE.search(line)
        if m:
            hist.setdefault(m.group(2), []).append((m.group(3), m.group(4), float(m.group(8)), float(m.group(10))))
    total = {"all": 0, "scouts": 0, "crews": 0, "stuck": 0, "stuck_crews": 0, "tracks": 0, "rigs": 0, "short": 0}
    for unit, rows in hist.items():
        streak, pinned, uid = 0, 0, rows[0][0]
        for a, b in zip(rows, rows[1:]):
            if b[1] == "move_to" and abs(b[2]) > 0.3 and abs(a[3] - b[3]) < 0.05:
                streak += 1
            else:
                if streak >= 10:
                    pinned += streak
                streak = 0
        if streak >= 10:
            pinned += streak
        total["all"] += pinned
        if uid in SCOUTS:
            total["scouts"] += pinned
        if uid == "tank":
            total["tracks"] += pinned
        if uid == RIG:
            total["rigs"] += pinned  # round 30 (M4b run 2): the 14 m hull the fix does not reach, apart
        else:
            total["short"] += pinned  # ...and every hull it does (<= 10 m)
        if pinned:
            total["crews"] += 1
        # stuck: no PROGRESS_M of progress toward the goal over a run of driving seconds
        stuck, run, best = 0, 0, None
        for r in rows:
            driving = r[1] == "move_to" and abs(r[2]) > 0.3
            if driving and best is not None and r[3] <= best - PROGRESS_M:
                best, run = r[3], 0  # progress: the run restarts here
            elif driving:
                if best is None:
                    best = r[3]
                run += 1
            else:
                if run >= 10:
                    stuck += run
                run, best = 0, None
        if run >= 10:
            stuck += run
        total["stuck"] += stuck
        if stuck:
            total["stuck_crews"] += 1
    return total


def load(root):
    return {str(p.parent.relative_to(root)): run_pinned(p) for p in pathlib.Path(root).glob("*/*/run.log")}


def main(base_dir, new_dir):
    base, new = load(base_dir), load(new_dir)
    keys = sorted(set(base) & set(new))
    print(f"PINNED runs paired {len(keys)} (base {len(base)}, new {len(new)})")
    for k in ("all", "short", "rigs", "scouts", "tracks", "crews", "stuck", "stuck_crews"):
        d = [new[r][k] - base[r][k] for r in keys]
        se = statistics.stdev(d) * len(d) ** 0.5 if len(d) > 1 else float("nan")
        tot = sum(d)
        print(f"PINNED {k} crew-seconds: base {sum(base[r][k] for r in keys)} new {sum(new[r][k] for r in keys)} diff {tot:+d} "
              f"se {se:.1f} {'DOWN beyond 2 se' if tot < -2 * se else ('UP beyond 2 se' if tot > 2 * se else 'within 2 se')}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
