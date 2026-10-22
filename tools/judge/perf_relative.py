#!/usr/bin/env python3
"""Round 38 (native N3): perf-judge's two lines side by side, over many checks and trials.

    python3 tools/judge/perf_relative.py FILE_OR_DIR [...] [--json]

Each FILE is a perf-judge.txt (tools/perf_judge.sh's per-attempt lines); a DIR is searched for them. Every
`PERF_JUDGE_RELATIVE` line is one attempt: its host, cpu model, the absolute state (PASS / FAIL / REFUSED / CRASHED /
NO_RESULT), the relative verdict (usec a tick per reference ms v the line) and the numbers. Grouped by (host, cpu):
attempts, how often each line passed, how often they agree where both judged (absolute PASS or FAIL), and the spread of
usec per reference ms (median, min, max). The switch to the relative line waits on agreement on builder0's checks and a
narrow per_ref spread across builder2's Intel and AMD starts (the reference must scale with the brains across machines).
"""
import argparse
import json
import os
import re
import sys

LINE = re.compile(r"^PERF_JUDGE_RELATIVE (?P<body>.*)$")
FIELD = re.compile(r'(\w+)=("[^"]*"|\S+)')


def parse(line):
    m = LINE.match(line.strip())
    if not m:
        return None
    rec = {k: v.strip('"') for k, v in FIELD.findall(m["body"])}
    for key in ("per_ref_ms", "line", "ai_usec_per_tick"):
        try:
            rec[key] = int(rec[key])
        except (KeyError, ValueError):
            rec[key] = None
    return rec


def files(paths):
    for path in paths:
        if os.path.isdir(path):
            for root, _dirs, names in os.walk(path):
                for name in sorted(names):
                    if name == "perf-judge.txt":
                        yield os.path.join(root, name)
        else:
            yield path


def read(paths):
    out = []
    for path in files(paths):
        with open(path, errors="replace") as f:
            for line in f:
                rec = parse(line)
                if rec:
                    rec["path"] = path
                    out.append(rec)
    return out


def summarize(records):
    groups = {}
    for r in records:
        groups.setdefault((r.get("host", "?"), r.get("cpu", "?")), []).append(r)
    report = []
    for (host, cpu), rows in sorted(groups.items()):
        judged = [r for r in rows if r.get("absolute") in ("PASS", "FAIL") and r.get("relative") in ("PASS", "FAIL")]
        agree = sum(1 for r in judged if r["absolute"] == r["relative"])
        per_ref = sorted(r["per_ref_ms"] for r in rows if r["per_ref_ms"] is not None)
        report.append({"host": host, "cpu": cpu, "attempts": len(rows),
                       "absolute": {s: sum(1 for r in rows if r.get("absolute") == s) for s in sorted({r.get("absolute") for r in rows})},
                       "relative": {s: sum(1 for r in rows if r.get("relative") == s) for s in sorted({r.get("relative") for r in rows})},
                       "both_judged": len(judged), "agree": agree,
                       "disagree": [os.path.basename(os.path.dirname(r["path"])) + ":" + r.get("attempt", "?") for r in judged
                                    if r["absolute"] != r["relative"]],
                       "per_ref_median": per_ref[len(per_ref) // 2] if per_ref else None,
                       "per_ref_min": per_ref[0] if per_ref else None, "per_ref_max": per_ref[-1] if per_ref else None,
                       "line": rows[0]["line"]})
    return report


def render(report):
    out = []
    for g in report:
        out.append("%s (%s): %d attempts; absolute %s; relative %s" % (g["host"], g["cpu"], g["attempts"],
                   ", ".join("%s %d" % kv for kv in g["absolute"].items()), ", ".join("%s %d" % kv for kv in g["relative"].items())))
        out.append("  both judged %d, agree %d%s" % (g["both_judged"], g["agree"],
                   ("; DISAGREE " + ", ".join(g["disagree"])) if g["disagree"] else ""))
        if g["per_ref_median"] is not None:
            out.append("  usec per reference ms: median %d (min %d, max %d) v the line %s" % (g["per_ref_median"], g["per_ref_min"],
                       g["per_ref_max"], g["line"]))
    return "\n".join(out)


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("paths", nargs="+")
    p.add_argument("--json", action="store_true")
    args = p.parse_args(argv)
    report = summarize(read(args.paths))
    print(json.dumps(report, indent=1) if args.json else render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
