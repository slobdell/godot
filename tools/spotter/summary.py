#!/usr/bin/env python3
"""Spotter S0: the night shift's one-page morning report, ~/spotter-night/<date>/SUMMARY.md, rewritten after every batch.

    python3 tools/spotter/summary.py ~/spotter-night/2026-10-31 [--state ~/spotter-night/state] [--top 20]

It reads each commit folder's fights/moments.json (tools/spotter/rank.py), yields.txt and batch.log, and the night log's lines
for that date. Stdlib only.
"""
import argparse
import glob
import json
import os
import socket
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rank as R  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("day_dir")
    ap.add_argument("--state", default=os.path.expanduser("~/spotter-night/state"))
    ap.add_argument("--top", type=int, default=20)
    args = ap.parse_args()
    day = os.path.basename(os.path.normpath(args.day_dir))
    log_lines = []
    log_path = os.path.join(args.state, "night.log")
    if os.path.exists(log_path):
        log_lines = [l.rstrip() for l in open(log_path) if l.startswith(day)]
    tree = ""
    tree_path = os.path.expanduser("~/tank_squad/spotter-night/.spotter-commit")
    if os.path.exists(tree_path):
        tree = open(tree_path).read().strip()
    out = [f"# Spotter night shift, {day}", ""]
    out.append(f"Machine: {socket.gethostname()} (builder3). Tree now: game `{tree.split(':')[0][:9]}`, kit "
               f"`{tree.split(':')[-1][:9]}`. Written {_now()}.")
    out.append("")
    out.append("What it is: CPU-v-CPU fights of main's named green commit, every crew-second scored for how unusual it looks "
               "(tools/spotter/rank.py), the oddest moments listed with their reasons and a reproduction line. Candidates "
               "for a human to judge, not verdicts. Stop it: `make spotter-night-stop` (or on builder3 "
               "`~/spotter-night/bin/night.sh stop`); remove it: `make spotter-night-uninstall`.")
    out.append("")
    batches = [l for l in log_lines if " batch done:" in l]
    yields = [l for l in log_lines if " yield:" in l]
    if log_lines:
        out.append(f"Ran {log_lines[0][11:19]} - {log_lines[-1][11:19]} ({log_lines[0][20:23].strip()}): "
                   f"{len(batches)} batches finished, {len(yields)} yields to other work.")
    for cdir in sorted(glob.glob(os.path.join(args.day_dir, "*", "fights"))):
        commit = os.path.basename(os.path.dirname(cdir))
        mpath = os.path.join(cdir, "moments.json")
        fights = len(glob.glob(os.path.join(cdir, "*.jsonl*")))
        out += ["", f"## Commit {commit}: {fights} fights", ""]
        if not os.path.exists(mpath):
            out.append("(no ranking yet)")
            continue
        data = json.load(open(mpath))
        out.append(f"{data['stamp']}. {data['crew_seconds']} crew-seconds, {data['moments_scored']} moments scored; the "
                   f"full top {len(data['top'])}: `{os.path.join(cdir, 'moments.md')}`.")
        out += ["", "| # | score | fight | crew (unit, team) | seconds | what a player would see |", "|---|---|---|---|---|---|"]
        for i, m in enumerate(data["top"][: args.top], 1):
            out.append(f"| {i} | {m['score']:.2f} | {m['fight']} | {m['crew']} ({m['unit']}, {m['team']}) | "
                       f"{m['start_s']}-{m['end_s']} | {R.reason_line(m)} |")
        out += ["", "Reproduce one: the row's fight is `<arena>-<seed>`; " + "`" + R.repro(data["top"][0]) + "`" if data["top"] else ""]
        cpath = os.path.join(cdir, "clips.json")
        if os.path.exists(cpath):
            clips = json.load(open(cpath))["clips"]
            good = sum(1 for c in clips if c.get("reproduced"))
            out += ["", f"Clips: {good} of {len(clips)} reproduced their moment, in `{os.path.join(cdir, 'clips')}/` "
                        "(tools/spotter/clips.py; a clip that did not reproduce is a bug, never evidence)."]
        kpath = os.path.join(os.path.dirname(cdir), "classes", "classes.md")
        if os.path.exists(kpath):  # round 48 S4: the class rule's rates at this commit, paired v the round's before
            text = open(kpath).read().split("\n## By map")[0]
            paired = open(kpath).read().split("\n## Paired")
            out += ["", "### Class rates (tools/spotter/classes.py)", ""] + text.splitlines()[2:]
            if len(paired) > 1:
                out += ["", "### Paired" + paired[1].rstrip()]
        ypath = os.path.join(os.path.dirname(cdir), "yields.txt")
        if os.path.exists(ypath):
            out += ["", "Yields (it stopped for):", ""] + [f"- {l.strip()}" for l in open(ypath) if l.strip()][-10:]
    out += ["", "## The night's log", "", "```"] + log_lines[-30:] + ["```", ""]
    path = os.path.join(args.day_dir, "SUMMARY.md")
    with open(path, "w") as handle:
        handle.write("\n".join(out))
    print(f"summary: {path}")


def _now():
    import time
    return time.strftime("%Y-%m-%d %H:%M %Z")


if __name__ == "__main__":
    main()
