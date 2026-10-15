#!/usr/bin/env python3
"""The early-stop hook (round 31, traffic I4; C31.3, C31.9): the RUNNING reading of a judged series, printed by the
runner beside each row it finishes. It never stops a run; the stream decides by judging.md's one rule and records the row.

  seq_hook.py series --base B.jsonl --runs DIR --lines 'yard_open/cross=xclear:guard:abs=1.0:allow=3.0 terminus/cross=...'
                     [--counter tr_cross_verdicts] [--grid N]
  seq_hook.py census --base B.jsonl --runs DIR --lines 'rwf_any:rate:0.02:0.44 art_shots:guard:0.2' [--grid N]

DIR is the runner's own row folder (build/traffic-runs, build/traffic-census-runs): whatever rows exist so far. A case is
walked only over the longest PREFIX of its grid in the runner's order (seed-major, start tick minor) that has finished, so
a row that finished early out of order never moves a verdict. Each case prints one line:

  SEQ <case> k/N: <line> <state> llr <x> | ... -> SERIES CONTINUE | SERIES PASS at run j | SERIES FAIL at run j

Lines are tools/judge/sequential.py's (METRIC:KIND:EFFECT[:P0]) plus one extension for an ALLOWANCE the lead set: a guard
written `metric:guard:abs=H:allow=X` walks d - X (harm = a further H beyond the allowance X), so his "the crossing clock
within base + 3 s" is `xclear:guard:abs=1.0:allow=3.0`. The sd is the table's (references/round30/sizing/table.csv) and
the effect is a share of THIS series' base level, exactly as sequential.py; a metric without a table row says so and uses
the rows' own sd (POST HOC: no stop on it).
"""
import argparse
import glob
import json
import math
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "judge"))
import rows  # noqa: E402
import sequential  # noqa: E402
import stats  # noqa: E402

# Census row metrics by the name a bar uses, and their table names (probe "traffic-census (3 arenas x seeds)").
CENSUS_METRICS = {
    "art_shots": lambda r: r.get("art_shots", 0),
    "fast": lambda r: r["contacts_friend_fast"],
    "fstuck": lambda r: r["stuck_friend_s"],
    "rwf": lambda r: r.get("repacks_while_firing", 0),
    "rwf_any": lambda r: r.get("repacks_while_firing", 0) > 0,
}
CENSUS_TABLE = {"art_shots": "artillery shots", "fast": "fast friendly contacts", "fstuck": "friendly-stuck s"}
CENSUS_PROBE = "traffic-census (3 arenas x seeds)"
SERIES_TABLE = {"xclear": "xclear (crossing clock, s)"}


def read_rows(paths):
    out = []
    for p in sorted(paths):
        with open(p) as handle:
            for line in handle:
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except ValueError:
                        pass  # a row still being written
    return out


def series_pairs(base_rows, arm_rows, case):
    """[(key, base, arm)] for one case, key = (seed, tick), runner order, `which == both` rows only."""
    def by(rs):
        return {(r["seed"], r["start_tick"]): r for r in rs
                if r.get("which") == "both" and not r.get("missing") and r.get("arena") + "/" + r.get("kind") == case}
    b, a = by(base_rows), by(arm_rows)
    return [(k, b[k], None) for k in sorted(b)], a


def census_pairs(base_rows, arm_rows):
    """[(key, base, arm)], key = (seed, arena): seed-major (mk/traffic.mk's census loop runs arenas within a seed)."""
    def by(rs):
        return {(r["seed"], r["arena"]): r for r in rs if not r.get("missing")}
    b, a = by(base_rows), by(arm_rows)
    return [(k, b[k], None) for k in sorted(b)], a


def prefix(grid_pairs, arm_by_key):
    """The longest prefix of the base grid whose arm rows exist (out-of-order finishes wait for their turn)."""
    out = []
    for k, b, _a in grid_pairs:
        if k not in arm_by_key:
            break
        out.append((k, b, arm_by_key[k]))
    return out


def make_line(text, pairs, metric_fn, probe, table_names, table_path):
    """(sequential.Line, its per-run diffs, a note) for one line of the bar, with the allowance extension."""
    parts = text.split(":")
    allow = 0.0
    keep = []
    for p in parts:
        if p.startswith("allow="):
            allow = float(p[6:])
        else:
            keep.append(p)
    core = ":".join(keep)
    metric, kind = keep[0], keep[1]
    f = metric_fn(metric)
    if kind == "rate":
        d = [1 if f(a) else 0 for _k, _b, a in pairs]
        return sequential.Line(core, 0.0, 0.0), d, ""
    d = [f(a) - f(b) - allow for _k, b, a in pairs]
    base = statistics.mean([f(b) for _k, b, _a in pairs]) if pairs else 0.0
    sd, _ = sequential.table_sd(probe, table_names.get(metric, metric), table_path)
    note = ""
    if sd is None:
        sd = stats.paired_sd(d) if len(d) > 1 else 0.0
        note = " (no table row: rows' own sd, POST HOC)"
    ln = sequential.Line(core, sd, base)
    ln.name = text
    return ln, d, note


def reading(lines, diffs, n_grid, min_runs, untouched=None):
    """'<cells> -> SERIES ...' for the rows so far."""
    a = math.log((1 - sequential.BETA) / sequential.ALPHA)
    b = math.log(sequential.BETA / (1 - sequential.ALPHA))
    k = len(next(iter(diffs.values()))) if diffs else 0
    cells, decided = [], []
    for ln in lines:
        d = diffs[ln.name]
        if not d:
            cells.append("%s CONTINUE" % ln.name)
            decided.append(None)
            continue
        dec, stop, path, trunc = ln.judge(d, a, b, min_runs)
        if trunc and k < n_grid:  # the grid is not run out: a truncated reading is not a verdict yet
            dec, stop = None, None
        cells.append("%s %s llr %+.2f" % (ln.name, dec or "CONTINUE", path[-1]))
        decided.append((dec, stop))
    if any(x is not None and x[0] == "FAIL" for x in decided):
        verdict = "SERIES FAIL at run %d" % min(x[1] for x in decided if x is not None and x[0] == "FAIL")
    elif decided and all(x is not None and x[0] == "PASS" for x in decided):
        verdict = "SERIES PASS at run %d" % max(x[1] for x in decided)
    elif untouched is not None and all(ln.kind == "guard" for ln in lines):
        verdict = "SERIES PASS at run %d (UNTOUCHED: an equality check)" % untouched
    else:
        verdict = "SERIES CONTINUE"
    return " | ".join(cells) + " -> " + verdict


def parse_case_lines(spec):
    """'case=l1,l2 case2=l3' -> {case: [l1, l2], case2: [l3]}."""
    out = {}
    for chunk in spec.split():
        case, _, lines = chunk.partition("=")
        out[case] = [x for x in lines.split(",") if x]
    return out


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mode", choices=("series", "census"))
    p.add_argument("--base", required=True)
    p.add_argument("--runs", required=True, help="the runner's row folder (rows so far)")
    p.add_argument("--lines", required=True)
    p.add_argument("--counter", default="")
    p.add_argument("--grid", type=int, default=0, help="runs a case's full grid holds (default: the base's)")
    p.add_argument("--min-runs", type=int, default=6)
    p.add_argument("--table", default=sequential.TABLE_CSV)
    args = p.parse_args(argv)
    base_rows = rows.read_jsonl(args.base)
    arm_rows = read_rows(glob.glob(os.path.join(args.runs, "*.json")))
    if args.mode == "series":
        for case, texts in parse_case_lines(args.lines).items():
            grid, arm_by = series_pairs(base_rows, arm_rows, case)
            pairs = prefix(grid, arm_by)
            n_grid = args.grid or len(grid)
            lines, diffs, notes = [], {}, ""
            for t in texts:
                ln, d, note = make_line(t, pairs, rows.metric_fn, "traffic-series " + case, SERIES_TABLE, args.table)
                lines.append(ln)
                diffs[ln.name] = d
                notes += note
            untouched = sequential.untouched_stop(pairs, args.counter, args.min_runs) if args.counter and pairs else None
            print("SEQ %s %d/%d: %s%s" % (case, len(pairs), n_grid, reading(lines, diffs, n_grid, args.min_runs, untouched), notes))
    else:
        grid, arm_by = census_pairs(base_rows, arm_rows)
        pairs = prefix(grid, arm_by)
        n_grid = args.grid or len(grid)
        lines, diffs, notes = [], {}, ""
        for t in args.lines.split():
            ln, d, note = make_line(t, pairs, lambda m: CENSUS_METRICS[m], CENSUS_PROBE, CENSUS_TABLE, args.table)
            lines.append(ln)
            diffs[ln.name] = d
            notes += note
        print("SEQ census %d/%d: %s%s" % (len(pairs), n_grid, reading(lines, diffs, n_grid, args.min_runs), notes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
