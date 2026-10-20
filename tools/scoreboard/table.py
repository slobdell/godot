#!/usr/bin/env python3
"""Round 35 extension (X5 (a), native): the round scoreboard as one page, a column per main, in the words a player would
use. Reads references/scoreboard/mains.txt (one main a line, oldest first: `<commit> <label>`) and each main's row in
references/scoreboard/rows/<commit>.json (tools/scoreboard/score.py); writes references/scoreboard/README.md.

usage: table.py [SCOREBOARD_DIR]     (default references/scoreboard beside this repo's tools/)

A main with no row yet shows "not run"; a number its logs cannot give shows "n/a" (an older main that never printed it).
Counts are per fight / per order, so a main with a fight that failed to report still reads on the same scale (n is shown)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "references", "scoreboard")


def per(n, d, digits=2):
    return None if n is None or not d else round(n / d, digits)


def fmt(v, unit=""):
    if v is None:
        return "n/a"
    if isinstance(v, float):
        v = ("%.2f" % v).rstrip("0").rstrip(".") if abs(v) < 10 else "%.1f" % v
    return "%s%s" % (v, unit)


# (section, line in his words, better, getter)
LINES = [
    ("Fights", "Tanks lost per fight, any cause", "lower", lambda r: per(r["fights"].get("deaths"), r["fights"]["read"])),
    ("Fights", "... shot in the open (the fight itself)", "", lambda r: per(r["fights"].get("open"), r["fights"]["read"])),
    ("Fights", "... stuck: wedged against terrain or a wreck when killed", "lower",
     lambda r: per(r["fights"].get("stuck"), r["fights"]["read"])),
    ("Fights", "... jammed in our own traffic when killed", "lower", lambda r: per(r["fights"].get("jam"), r["fights"]["read"])),
    ("Fights", "... jammed AND under fire (the killing-zone case)", "lower",
     lambda r: per(r["fights"].get("jam_under_fire"), r["fights"]["read"])),
    ("Fights", "Kills per fight", "", lambda r: per(r["fights"].get("kills"), r["fights"]["read"])),
    ("Fights", "Hit rate", "", lambda r: None if r["fights"].get("hit_rate") is None else "%d %%" % round(100 * r["fights"]["hit_rate"])),
    ("Fights", "Fights read (of fights run)", "", lambda r: "%d of %d" % (r["fights"]["read"], r["fights"]["ran"])),
    ("Moving out", "Orders where the squad never settled in 75 s", "lower",
     lambda r: None if not r["moves"]["read"] else "%d of %d" % (r["moves"]["never_settled"], r["moves"]["read"])),
    ("Moving out", "Crews left 25+ m behind their squad, per order", "lower",
     lambda r: per(r["moves"].get("crews_left_behind"), r["moves"]["read"])),
    ("Moving out", "Crews still driving toward the spot at the end, per order", "lower",
     lambda r: per(r["moves"].get("still_moving"), r["moves"]["read"])),
    ("Moving out", "Crews rocking in place at the end (stuck), per order", "lower",
     lambda r: per(r["moves"].get("movers", {}).get("jitter"), r["moves"]["read"])),
    ("Group orders", "Seconds until every squad is in (median)", "lower", lambda r: fmt(r["orders"].get("all_in_median_s"), " s")),
    ("Group orders", "Orders where some squad never got in (90 s)", "lower",
     lambda r: None if not r["orders"]["read"] else "%d of %d" % (r["orders"]["never_all_in"], r["orders"]["read"])),
    ("Group orders", "Squads that drove across to the far bank (should be 0)", "lower",
     lambda r: r["orders"].get("far_bank_squads")),
    ("Group orders", "Twitch after placing, median (metres a crew shuffles)", "lower",
     lambda r: fmt(r["orders"].get("twitch_median_m"), " m")),
]


def render(root):
    mains = []
    for line in open(os.path.join(root, "mains.txt")):
        line = line.strip()
        if line and not line.startswith("#"):
            commit, _, label = line.partition(" ")
            mains.append((commit, label.strip()))
    rows = {}
    for commit, _label in mains:
        path = os.path.join(root, "rows", commit + ".json")
        if os.path.exists(path):
            rows[commit] = json.load(open(path))
    out = ["# The round scoreboard", "",
           "The same fixed workload run against each main, so the columns compare: what a player would notice. Oldest main "
           "on the left. Each number is read from that main's own run by today's readers (`tools/scoreboard/`), so the method "
           "is the same in every column; \"n/a\" means that main's game never printed it (older than the thing measured).", "",
           "**The workload** (`mk/scoreboard.mk`, native, pinned at 30 Hz): 40 showmatch fights (Terminus, Locks, Sumps, Gorge, "
           "Parade x 8 seeds, 180 s, CPU v CPU); 48 move orders drawn with a facing (attack-move and move, every faction x 6 "
           "seeds, Foundry, a quiet enemy); 36 group orders (Locks, Crossing, Terminus x 3 and 5 squads x one click and a "
           "route x 3 seeds). Seeds 2601+ on every main.", ""]
    header = "| | " + " | ".join("**%s**<br>`%s`" % (label, commit) for commit, label in mains) + " | better |"
    out += [header, "|" + "---|" * (len(mains) + 2)]
    section = None
    for sec, text, better, get in LINES:
        if sec != section:
            out.append("| **%s** |" % sec + " |" * (len(mains) + 1))
            section = sec
        cells = []
        for commit, _label in mains:
            r = rows.get(commit)
            if r is None:
                cells.append("not run")
                continue
            try:
                cells.append(fmt(get(r)))
            except (KeyError, TypeError, ZeroDivisionError):
                cells.append("n/a")
        out.append("| %s | %s | %s |" % (text, " | ".join(cells), better))
    out += ["", "**Where each column ran:**", ""]
    for commit, label in mains:
        r = rows.get(commit)
        if r is None:
            out.append("- `%s` (%s): not run yet." % (commit, label))
            continue
        errors = r.get("script_errors") or {}
        out.append("- `%s` (%s): %s, workload and probes from `%s`, remote exit %s, SCRIPT ERROR lines %s. %s" % (
            commit, label, r["machine"], r.get("overlay") or "?", r.get("remote_status"),
            " / ".join("%s %d" % kv for kv in sorted(errors.items())) or "n/a", (r.get("run") or [""])[0]))
    out += ["", "**How each line is read** (`tools/scoreboard/score.py`): fight deaths by T5's causes (tests/traffic/jam_ab.py; "
            "\"under fire\" = the last hit landed during the jam, or 2+ hits in the 10 s before); never settled = no "
            "`settled_after_s` inside the 75 s judge; left behind = more than 25 m off its slot in its element's last trace "
            "row (tests/tactics/e1_bar.py); still driving / rocking = brains' mover kinds (a crew moving at the judge that "
            "closed 3+ m on its goal or wandered, v one that moved under 1 m net in its last 10 s); group orders = "
            "tests/control/orders_probe_table.py (all-in = the last squad's arrival; twitch = the most a crew moved after "
            "its place; on a main older than the deploy step, from the squad's arrival).", ""]
    return "\n".join(out)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    text = render(root)
    with open(os.path.join(root, "README.md"), "w") as f:
        f.write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
