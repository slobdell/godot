#!/usr/bin/env python3
"""C34.8 (a)'s moves list: build/pin-moves/<target>/{pin1,free1,pin2,free2}/ (mk/native.mk pin-moves) -> one row a stage.

A stage's text is its run.log plus every file under out/, each line with wall-clock noise masked (timestamps, "N ms",
"N s" durations, usec, FILE_TIME). For each stage: the exit codes, the test verdicts (PASS/FAIL lines), and how many
lines differ within an arm (pin1 v pin2, free1 v free2: run-to-run noise) and across arms (pin v free, the smaller of
the two same-index pairs). A stage MOVES when its verdicts differ across arms, or its cross-arm difference is larger
than both within-arm differences. Every mover then gets its reason in native's Status (read the diff: --show TARGET).
"""
import difflib
import os
import re
import sys

ARMS = ["pin1", "free1", "pin2", "free2"]
MASKS = [
    (re.compile(r"\d{4}-\d\d-\d\d[ T]\d\d[:-]\d\d[:-]\d\d(\.\d+)?"), "<ts>"),
    # Wall-clock measures (the timing stages time on purpose; a pinned run is no steadier there): reference ratios,
    # native speed-ups, and scenario-times' per-test milliseconds.
    (re.compile(r"ratio=\d+(\.\d+)?"), "ratio=<t>"),
    (re.compile(r"\(\d+x\)"), "(<t>x)"),
    (re.compile(r"\t\d+\t"), "\t<t>\t"),
    (re.compile(r"\b\d+(\.\d+)?\s*(ms|usec|us|s|secs|seconds)\b"), "<t>"),
    (re.compile(r"(usec|_ms|_s|wall|elapsed|took|cost=)[=: ]*\d+(\.\d+)?"), r"\1<t>"),
    (re.compile(r"/tmp/\S+"), "<tmp>"),
]
SKIP = re.compile(r"^(FILE_TIME|>> |make\[|test wall|SHARD|engine:|expected engine)")


def lines_of(arm_dir):
    out = []
    paths = [os.path.join(arm_dir, "run.log")]
    base = os.path.join(arm_dir, "out")
    if os.path.isfile(base):
        paths.append(base)
    elif os.path.isdir(base):
        for root, _, files in os.walk(base):
            for f in sorted(files):
                # twin.log: planner-twin's, written into build/planner while planner-trace-hull-rest's copy was taken.
                if f.endswith((".png", ".jpg", ".exr")) or f == "twin.log":
                    continue
                paths.append(os.path.join(root, f))
    for p in sorted(paths):
        try:
            text = open(p, errors="replace").read()
        except OSError:
            continue
        rel = os.path.relpath(p, arm_dir)
        for line in text.splitlines():
            if SKIP.match(line):
                continue
            for rx, rep in MASKS:
                line = rx.sub(rep, line)
            out.append(rel + "|" + line)
    return out


def ndiff(a, b):
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return sum(max(i2 - i1, j2 - j1) for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag != "equal")


def verdicts(lines):
    return sorted(l.split("|", 1)[1].strip() for l in lines if re.search(r"\|\s+(PASS|FAIL)\s", l))


def read(path, default="?"):
    try:
        return open(path).read().strip()
    except OSError:
        return default


def main():
    root = sys.argv[1]
    show = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--show" else None
    print("%-24s %-15s %-15s %6s %6s %6s %-8s %s" % ("stage", "exit p/f/p/f", "load p/f/p/f", "pp", "ff", "pf",
                                                       "verdict", "MOVES"))
    for target in sorted(os.listdir(root)):
        d = os.path.join(root, target)
        if not os.path.isdir(d):
            continue
        text = {a: lines_of(os.path.join(d, a)) for a in ARMS}
        if show == target:
            for line in difflib.unified_diff(text["pin1"], text["free1"], "pin1", "free1", lineterm="", n=0):
                print(line)
            continue
        pp = ndiff(text["pin1"], text["pin2"])
        ff = ndiff(text["free1"], text["free2"])
        pf = min(ndiff(text["pin1"], text["free1"]), ndiff(text["pin2"], text["free2"]))
        same_verdicts = verdicts(text["pin1"]) == verdicts(text["free1"]) == verdicts(text["pin2"]) == verdicts(text["free2"])
        moves = (not same_verdicts) or pf > max(pp, ff)
        print("%-24s %-15s %-15s %6d %6d %6d %-8s %s" % (
            target, "/".join(read(os.path.join(d, a, "exit")) for a in ARMS),
            "/".join(read(os.path.join(d, a, "load_before")) for a in ARMS), pp, ff, pf,
            "same" if same_verdicts else "DIFFER", "MOVES" if moves else "-"))


if __name__ == "__main__":
    main()
