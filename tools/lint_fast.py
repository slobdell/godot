#!/usr/bin/env python3
"""Read `make lint-fast`'s one Godot process (tests/lint/lint_fast.gd) into findings and a verdict (round 41 native N5).

    lint_fast.py LOG --files N --selftest a.gd,b.gd,... [--out FINDINGS]

A finding is `<file>:<line>: <message>`, attributed by the `at: ... (res://<file>:<line>)` line Godot prints under a
`SCRIPT ERROR:`, or by the `res://<file>:<line> - Parse Error` inside an `ERROR:` line. A file that did not load and printed
no error of its own is a finding too (LINT_FAST_NOLOAD). Exit 0 only when ALL of:
  * the loader finished and counted exactly N files (a killed or short run is never a clean tree: lint's lesson);
  * every --selftest file (planted errors, one per class the gate must see) has at least one finding of its own;
  * the tree's findings, the self-test files' removed, are none.
An error with no file to pin it on is a finding (`?: <message>`), never dropped.
"""
import argparse
import re
import sys

AT = re.compile(r"\(res://([^():]+):(\d+)\)")
INLINE = re.compile(r"res://([^\s:]+):(\d+) - (Parse Error.*)$")
NOISE = re.compile(r'^ERROR: Failed to load script "res://')  # repeats the SCRIPT ERROR above it


def findings(lines):
    out = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip("\n")
        s = line.strip()
        if s.startswith("LINT_FAST_NOLOAD "):
            out.append(("nl", s.split(" ", 1)[1], 0, "did not load"))
        elif s.startswith("SCRIPT ERROR:") or (s.startswith("ERROR:") and "Parse Error" in s and not NOISE.match(s)):
            m = INLINE.search(s)
            if m:
                out.append(("e", m.group(1), int(m.group(2)), m.group(3)))
            else:
                where = None
                for j in range(i + 1, min(i + 4, len(lines))):
                    nxt = lines[j].strip()
                    if nxt.startswith("at:"):
                        where = AT.search(nxt)
                        break
                    if nxt.startswith(("SCRIPT ERROR:", "ERROR:", "LINT_FAST")):
                        break
                msg = s
                if where:
                    out.append(("e", where.group(1), int(where.group(2)), msg))
                else:
                    out.append(("e", "?", 0, msg))
        i += 1
    # a NOLOAD line counts only when its file printed nothing else
    errfiles = {f for k, f, _, _ in out if k == "e"}
    return sorted({(f, ln, msg) for k, f, ln, msg in out if k == "e" or f not in errfiles})


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--files", type=int, required=True)
    ap.add_argument("--selftest", default="")
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    lines = open(a.log, errors="replace").readlines()
    found = findings(lines)
    done = [l for l in lines if l.startswith("LINT_FAST_DONE ")]
    planted = [p for p in a.selftest.split(",") if p]
    tree = [f for f in found if f[0] not in planted]
    text = ["%s:%d: %s" % f for f in tree]
    if a.out:
        with open(a.out, "w") as fh:
            fh.write("".join(t + "\n" for t in text))
    bad = False
    m = re.search(r"files=(\d+) ms=(\d+)", done[-1]) if done else None
    if not m:
        print("lint-fast FAILED: the loader never finished (no LINT_FAST_DONE line): killed, OOM, or a bad path. This run says")
        print("  NOTHING about the tree.")
        return 1
    if int(m.group(1)) != a.files:
        print("lint-fast FAILED: the loader counted %s files, the list had %d. A short list is not a clean tree." % (m.group(1), a.files))
        bad = True
    blind = [p for p in planted if not any(f[0] == p for f in found)]
    if blind:
        print("lint-fast FAILED: the planted error(s) in %s were NOT reported. A checker that cannot see an error it was" % ", ".join(blind))
        print("  pointed at cannot be trusted to have seen a real one.")
        bad = True
    if text:
        print("lint-fast FAILED over %d files -- findings (one process, every script loaded once):" % a.files)
        for t in text:
            print("  " + t)
        bad = True
    if bad:
        return 1
    print("lint-fast: all %d scripts load in one process (%.1f s, %d planted errors seen)" % (a.files, int(m.group(2)) / 1000, len(planted)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
