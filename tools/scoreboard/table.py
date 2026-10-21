#!/usr/bin/env python3
"""Round 35 extension (X5 (a), native): the round scoreboard as one page, a column per main, in the words a player would
use. Reads references/scoreboard/mains.txt (one main a line, oldest first: `<commit> <label>`) and each main's row in
references/scoreboard/rows/<commit>.json (tools/scoreboard/score.py); writes references/scoreboard/README.md.

usage: table.py [SCOREBOARD_DIR]     (default references/scoreboard beside this repo's tools/)

A main with no row yet shows "not run"; a number its logs cannot give shows "n/a" (an older main that never printed it).
Counts are per fight / per order, so a main with a fight that failed to report still reads on the same scale (n is shown)."""
import json
import math
import os
import statistics
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
    ("Fights", "... killed while held at a street mouth (waiting its turn)", "lower",
     lambda r: per(r["fights"].get("held"), r["fights"]["read"])),
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


# Round 36 (the noise column): each line as a number per seed unit (the part it reads, the number, and the scale that puts
# a fraction back on the column's own scale: "13 of 48" is a fraction x the main's 48 orders).
def _frac(n, d):
    return None if n is None or not d else n / d


NUM = {
    "Tanks lost per fight, any cause": ("fights", lambda r: _frac(r["fights"].get("deaths"), r["fights"]["read"]), None),
    "... shot in the open (the fight itself)": ("fights", lambda r: _frac(r["fights"].get("open"), r["fights"]["read"]), None),
    "... stuck: wedged against terrain or a wreck when killed": ("fights", lambda r: _frac(r["fights"].get("stuck"), r["fights"]["read"]), None),
    "... jammed in our own traffic when killed": ("fights", lambda r: _frac(r["fights"].get("jam"), r["fights"]["read"]), None),
    "... jammed AND under fire (the killing-zone case)": ("fights", lambda r: _frac(r["fights"].get("jam_under_fire"), r["fights"]["read"]), None),
    "... killed while held at a street mouth (waiting its turn)": ("fights", lambda r: _frac(r["fights"].get("held"), r["fights"]["read"]), None),
    "Kills per fight": ("fights", lambda r: _frac(r["fights"].get("kills"), r["fights"]["read"]), None),
    "Hit rate": ("fights", lambda r: None if r["fights"].get("hit_rate") is None else 100.0 * r["fights"]["hit_rate"], None),
    "Orders where the squad never settled in 75 s": ("moves", lambda r: _frac(r["moves"].get("never_settled"), r["moves"]["read"]),
                                                     lambda r: r["moves"]["read"]),
    "Crews left 25+ m behind their squad, per order": ("moves", lambda r: _frac(r["moves"].get("crews_left_behind"), r["moves"]["read"]), None),
    "Crews still driving toward the spot at the end, per order": ("moves", lambda r: _frac(r["moves"].get("still_moving"), r["moves"]["read"]), None),
    "Crews rocking in place at the end (stuck), per order": ("moves", lambda r: _frac(r["moves"].get("movers", {}).get("jitter"), r["moves"]["read"]), None),
    "Seconds until every squad is in (median)": ("orders", lambda r: r["orders"].get("all_in_median_s"), None),
    "Orders where some squad never got in (90 s)": ("orders", lambda r: _frac(r["orders"].get("never_all_in"), r["orders"]["read"]),
                                                    lambda r: r["orders"]["read"]),
    "Squads that drove across to the far bank (should be 0)": ("orders", lambda r: _frac(r["orders"].get("far_bank_squads"), r["orders"]["read"]),
                                                               lambda r: r["orders"]["read"]),
    "Twitch after placing, median (metres a crew shuffles)": ("orders", lambda r: r["orders"].get("twitch_median_m"), None),
}
UNITS = {"Hit rate": " %", "Seconds until every squad is in (median)": " s", "Twitch after placing, median (metres a crew shuffles)": " m"}


def noise(rows, text):
    """2 standard errors of a DIFFERENCE between two columns for `text`, on the column's scale, from the seed units of the
    noise rows (one main, two or more seed blocks): sd over every seed unit, se of one column = sd / sqrt(seeds a column
    has), a difference = sqrt(2) x that. None without NUM, rows or 3+ units. Returns (value, units, seeds a column)."""
    if text not in NUM or not rows:
        return None
    part, num, scale = NUM[text]
    values, per_block = [], []
    for r in rows:
        units = [num(u) for u in (r.get("by_seed") or {}).values() if (u.get(part) or {}).get("read")]
        units = [v for v in units if v is not None]
        values += units
        per_block.append(len(units))
    if len(values) < 3 or not min(per_block):
        return None
    n = min(per_block)
    se = statistics.stdev(values) / math.sqrt(n)
    value = 2.0 * math.sqrt(2.0) * se * (scale(rows[0]) if scale else 1.0)
    return value, len(values), n


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
    # noise.txt: the rows (file names under rows/, one main's seed blocks) whose seed units size the noise column.
    noise_names, noise_rows = [], []
    if os.path.exists(os.path.join(root, "noise.txt")):
        for line in open(os.path.join(root, "noise.txt")):
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                path = os.path.join(root, "rows", name + ".json")
                if os.path.exists(path):
                    noise_names.append(name)
                    noise_rows.append(json.load(open(path)))
    out = ["# The round scoreboard", "",
           "The same fixed workload run against each main, so the columns compare: what a player would notice. Oldest main "
           "on the left. Each number is read from that main's own run by today's readers (`tools/scoreboard/`), so the method "
           "is the same in every column; \"n/a\" means that main's game never printed it (older than the thing measured).", "",
           "**The workload** (`mk/scoreboard.mk`, native, pinned at 30 Hz): 40 showmatch fights (Terminus, Locks, Sumps, Gorge, "
           "Parade x 8 seeds, 180 s, CPU v CPU); 48 move orders drawn with a facing (attack-move and move, every faction x 6 "
           "seeds, Foundry, a quiet enemy); 36 group orders (Locks, Crossing, Terminus x 3 and 5 squads x one click and a "
           "route x 3 seeds). Seeds 2601+ on every main.", ""]
    header = "| | " + " | ".join("**%s**<br>`%s`" % (label, commit) for commit, label in mains) + " | better | ± noise |"
    out += [header, "|" + "---|" * (len(mains) + 3)]
    section = None
    for sec, text, better, get in LINES:
        if sec != section:
            out.append("| **%s** |" % sec + " |" * (len(mains) + 2))
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
        sized = noise(noise_rows, text)
        if sized and sized[0] == 0.0:
            cell = "no spread"  # the same in every seed of the noise block: nothing to size it from, not a zero noise
        else:
            cell = "± %s%s" % (fmt(round(sized[0], 2)), UNITS.get(text, "")) if sized else ("" if text not in NUM else "not sized")
        out.append("| %s | %s | %s | %s |" % (text, " | ".join(cells), better, cell))
    if noise_rows:
        out += ["", "**± noise** is two standard errors of a difference between two columns: a line moved only when two mains "
                "differ by more than it. Sized from the seed-to-seed spread of %s (one main, %s seed blocks; each seed's fights "
                "/ move orders / group orders read on their own), se of one column = sd / sqrt(seeds a column has), a difference "
                "x sqrt(2). Medians and counts are approximate this way; a line near its noise needs a second block on both mains. \"no spread\" = the line read the same in every seed of the noise block (often 0), so nothing sizes it."
                % (", ".join("`%s`" % n for n in noise_names), len(noise_rows))]
    else:
        out += ["", "**± noise**: not sized yet (references/scoreboard/noise.txt names no rows): no move is called."]
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
