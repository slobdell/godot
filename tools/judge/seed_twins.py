#!/usr/bin/env python3
"""R34.15 (planner): a `--arena=random` fight whose seed deals a map the series ALSO runs as a fixed arena on that same
seed is a byte-identical twin of that fight (traffic: 14 of the 48 random seeds in 1200-1247 dealt the Locks or the
Terminus). Paired readings are unaffected, but pooled totals and n count the fight twice. `drop_twins` removes the
random-arena twin, keeping the fixed-arena row.

Which map a random seed deals is Godot's (Arena.resolve_name: its hash and RNG), so it is read from a table written by
tests/planner/random_arenas.gd (references/round34/planner/sizing/random_arenas.txt, seeds 0-3000). The table names
Arena.ROTATION on its first line: a rotation that has changed since (a map added or removed) deals different maps, so
re-write the table first. `load(path, rotation=None)` refuses a table whose rotation differs from the one given.

    python3 tools/judge/seed_twins.py rows.jsonl [--arena-field arena] [--seed-field seed]   (prints what it drops)

Round 35 (C35.9): series tools that read a folder of `<arena>-<seed>.log` files (traffic-far-census and the tables built
on it) call `filter_logs(files)` before pooling. A random log's own census line (`<NAME>_CENSUS {..."arena": ...}`,
Arena.active's name) says which map it was dealt, so the table is needed only for a log without one. The fixed log
it twins must be in the same folder (one folder = one series arm).

    python3 tools/judge/seed_twins.py --logs DIR [DIR ...]   (prints what it would drop)
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(os.path.dirname(os.path.dirname(HERE)), "references/round34/planner/sizing/random_arenas.txt")


def load(path=TABLE, rotation=None):
    """({seed: map}, rotation list) from random_arenas.gd's output."""
    dealt, rot = {}, None
    with open(path) as handle:
        for line in handle:
            if line.startswith("# Arena.ROTATION "):
                rot = json.loads(line[len("# Arena.ROTATION "):])
                continue
            m = re.match(r"RANDOM_ARENA (\d+) (\w+)", line)
            if m:
                dealt[int(m.group(1))] = m.group(2)
    if rotation is not None and rot != list(rotation):
        raise ValueError("random_arenas table was written for rotation %s, not %s: re-run tests/planner/random_arenas.gd"
                         % (rot, list(rotation)))
    return dealt, rot


def drop_twins(rows, dealt, arena_field="arena", seed_field="seed", random_name="random"):
    """(kept rows, dropped rows): a random-arena row is dropped when its seed dealt a map that a fixed-arena row of the
    SAME seed already covers. A random row whose seed is outside the table is kept (and should be: say so)."""
    fixed = {(str(r[arena_field]), int(r[seed_field])) for r in rows if str(r[arena_field]) != random_name}
    kept, dropped = [], []
    for r in rows:
        if str(r[arena_field]) == random_name:
            seed = int(r[seed_field])
            if seed in dealt and (dealt[seed], seed) in fixed:
                dropped.append(r)
                continue
        kept.append(r)
    return kept, dropped


LOG_NAME = re.compile(r"^(\w+)-(\d+)\.log$")
CENSUS = re.compile(r'^[A-Z][A-Z_]*CENSUS \{.*?"arena": ?"(\w+)"')


def census_arena(path):
    """The map a log's census line says was dealt, or None."""
    with open(path, errors="replace") as handle:
        for line in handle:
            m = CENSUS.match(line)
            if m:
                return m.group(1)
    return None


def _table_or_empty():
    try:
        return load()[0]
    except OSError:
        return {}


def drop_twin_logs(files, dealt=None, random_name="random"):
    """(kept files, dropped [(file, seed, map)]) in the given order: `<random>-<seed>.log` is dropped when the map it was
    dealt (its census line, else `dealt`, else the R34.15 table) has `<map>-<seed>.log` in the same folder."""
    present = set()
    for f in files:
        m = LOG_NAME.match(os.path.basename(f))
        if m and m.group(1) != random_name:
            present.add((os.path.dirname(f), m.group(1), int(m.group(2))))
    kept, dropped = [], []
    for f in files:
        m = LOG_NAME.match(os.path.basename(f))
        if m and m.group(1) == random_name:
            seed = int(m.group(2))
            got = census_arena(f)
            if got is None:
                if dealt is None:
                    dealt = _table_or_empty()
                got = dealt.get(seed)
            if got is not None and (os.path.dirname(f), got, seed) in present:
                dropped.append((f, seed, got))
                continue
        kept.append(f)
    return kept, dropped


def filter_logs(files, dealt=None):
    """(kept files, the lines a tool prints): one SEED_TWIN line per drop, then the SEED_TWINS count."""
    kept, dropped = drop_twin_logs(files, dealt)
    lines = ["SEED_TWIN dropped random seed %d (dealt %s, also run as a fixed arena): %s" % (seed, got, f)
             for f, seed, got in dropped]
    lines.append("SEED_TWINS kept %d of %d logs, dropped %d" % (len(kept), len(files), len(dropped)))
    return kept, lines


def main(argv):
    if argv and argv[0] == "--logs":
        import glob
        files = [f for d in argv[1:] for f in sorted(glob.glob(os.path.join(d, "*.log")))]
        for line in filter_logs(files)[1]:
            print(line)
        return 0
    ap = argparse.ArgumentParser()
    ap.add_argument("rows")
    ap.add_argument("--arena-field", default="arena")
    ap.add_argument("--seed-field", default="seed")
    ap.add_argument("--table", default=TABLE)
    args = ap.parse_args(argv)
    dealt, _rot = load(args.table)
    rows = [json.loads(line) for line in open(args.rows) if line.strip()]
    kept, dropped = drop_twins(rows, dealt, args.arena_field, args.seed_field)
    for r in dropped:
        print("SEED_TWIN dropped random seed %s (dealt %s, also run as a fixed arena)" % (r[args.seed_field], dealt[int(r[args.seed_field])]))
    print("SEED_TWINS kept %d of %d rows, dropped %d" % (len(kept), len(rows), len(dropped)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
