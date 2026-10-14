#!/usr/bin/env python3
"""Readers for every judged-row format kept under `_agents/streams/references/` (rounds 27-29), each returning PAIRS
of runs keyed the way the runner wrote them, so the judge tools never re-derive a format.

  traffic_pairs(base, arm)      traffic-series jsonl (tests/traffic/traffic_probe.gd rows; `which == both`), per case
  approach_pairs(path)          ApproachStage jsonl (brains B1/B2): one file, arms = `approach` east v none
  census_pairs(off_dir, on_dir, tag)   one Godot log per seed, the `TAG {json}` summary line (CONTACT_CENSUS, SCOUT_CENSUS)
  terminus_rows(path)           the M4 judged text: `terminus-<squad>-<seed>.log base a/n c | new a/n c` lines
  class_lines(path)             the hull-rest table's `M1_CLASS task | class | n | new | base | diff | se | ...` lines
  jsonl_pairs(base, arm, key)   any two jsonl files paired on `key` fields

A pair is (key, base_row, arm_row). `diffs(pairs, metric)` turns pairs into per-run paired differences, in the
RUNNER'S ORDER (seed-major, start tick minor: mk/traffic.mk's loop), which is the order sequential judging walks.
"""
import functools
import json
import os
import re

TRAFFIC_TICKS = (1, 3, 6, 8, 11, 16)


@functools.lru_cache(maxsize=256)
def _read_jsonl_cached(path):
    with open(path) as handle:
        return tuple(json.loads(line) for line in handle if line.strip())


def read_jsonl(path):
    """Rows of a jsonl file (cached per path: the table reads every judged pair dozens of times; rows are never mutated)."""
    return list(_read_jsonl_cached(os.path.abspath(path)))


def all_in_s(row):
    """Every crew's last arrival; a crew that never arrived counts as the run's end (tests/traffic/traffic_table.py)."""
    times = [t if t >= 0 else row["end_s"] for t in row["arrive_s"].values()]
    return max(times) if times else row["end_s"]


# Per-run metrics of a traffic-series row, by the name a bar uses.
TRAFFIC_METRICS = {
    "fast": lambda r: r["contacts_fast"],
    "xfast": lambda r: r.get("contacts_cross_fast", 0),
    "ownfast": lambda r: r["contacts_fast"] - r.get("contacts_cross_fast", 0),
    "arrived": lambda r: r["arrived"],
    "missing": lambda r: r["crews"] - r["arrived"],
    "allin": all_in_s,
    "fstuck": lambda r: r["friend_stuck_s"],
    "stuck": lambda r: r["stuck_s"],
}


def traffic_pairs(base_path, arm_path, which="both"):
    """{case: [(key, base_row, arm_row), ...]} with case = 'arena/kind' and key = (seed, start_tick), runner order."""
    def load(path):
        out = {}
        for r in read_jsonl(path):
            if r.get("which") != which or r.get("missing"):
                continue
            out[(r["arena"] + "/" + r["kind"], r["seed"], r["start_tick"])] = r
        return out
    base, arm = load(base_path), load(arm_path)
    cases = {}
    for key in sorted(arm, key=lambda k: (k[0], k[1], k[2])):
        if key in base:
            cases.setdefault(key[0], []).append(((key[1], key[2]), base[key], arm[key]))
    return cases


def approach_pairs(path, treat="east", control="none", field="approach"):
    """[(key, control_row, treat_row)] from one ApproachStage jsonl, key = (seed, start_tick)."""
    rows = read_jsonl(path)
    by = {}
    for r in rows:
        by.setdefault((r["seed"], r["start_tick"]), {})[r[field]] = r
    return [(k, v[control], v[treat]) for k, v in sorted(by.items()) if control in v and treat in v]


def census_pairs(off_dir, on_dir, tag, pattern=r"(?:off-|on-)?(\d+)\.log$"):
    """[(seed, off_json, on_json)] from two folders of Godot logs, one per seed, read at their `TAG {...}` line."""
    def summary(path):
        with open(path, errors="replace") as handle:
            for line in handle:
                if line.startswith(tag + " {"):
                    return json.loads(line.split(" ", 1)[1])
        return None

    def by_seed(folder):
        out = {}
        for name in os.listdir(folder):
            m = re.search(pattern, name)
            if m:
                row = summary(os.path.join(folder, name))
                if row is not None:
                    out[int(m.group(1))] = row
        return out
    off, on = by_seed(off_dir), by_seed(on_dir)
    return [(s, off[s], on[s]) for s in sorted(off) if s in on]


def terminus_rows(path):
    """{squad: [(seed, {'arrived': a, 'crews': n, 'contacts': c}, {...new})]} from the M4 judged text's per-run lines."""
    out = {}
    with open(path) as handle:
        for line in handle:
            m = re.search(r"terminus-(\w+)-(\d+)\.log base (\d+)/(\d+) (\d+) \| new (\d+)/(\d+) (\d+)", line)
            if m:
                squad, seed = m.group(1), int(m.group(2))
                base = {"arrived": int(m.group(3)), "crews": int(m.group(4)), "contacts": int(m.group(5))}
                new = {"arrived": int(m.group(6)), "crews": int(m.group(7)), "contacts": int(m.group(8))}
                out.setdefault(squad, []).append((seed, base, new))
    return out


def class_lines(path, tag="M1_CLASS"):
    """[{task, klass, n, new, base, diff, se}] from a hull-rest table's per-class paired lines."""
    out = []
    with open(path) as handle:
        for line in handle:
            if not line.startswith(tag + " ") or "|" not in line or "runs paired" in line:
                continue
            parts = [p.strip() for p in line[len(tag) + 1:].split("|")]
            try:
                out.append({"task": parts[0], "klass": parts[1], "n": int(parts[2]), "new": int(parts[3]),
                            "base": int(parts[4]), "diff": int(parts[5]), "se": float(parts[6])})
            except (ValueError, IndexError):
                continue
    return out


def moving_lines(path, tag="M1_MOVING"):
    """[{task, new_drawn, base_drawn, new_clicked, base_clicked}] from a hull-rest table's M1_MOVING lines."""
    out = []
    with open(path) as handle:
        for line in handle:
            if not line.startswith(tag + " ") or "guard" in line:
                continue
            parts = [p.strip() for p in line[len(tag) + 1:].split("|")]
            try:
                out.append({"task": parts[0], "new_drawn": int(parts[1]), "base_drawn": int(parts[2]),
                            "new_clicked": int(parts[3]), "base_clicked": int(parts[4])})
            except (ValueError, IndexError):
                continue
    return out


def hull_medians(path, tag):
    """{(task, klass, arm): median} from HULL_TABLE / M1_HULL lines (median is the 5th column)."""
    out = {}
    with open(path) as handle:
        for line in handle:
            if not line.startswith(tag + " ") or "|" not in line or "median" in line:
                continue
            parts = [p.strip() for p in line[len(tag) + 1:].split("|")]
            try:
                out[(parts[0], parts[1], parts[2])] = float(parts[4])
            except (ValueError, IndexError):
                continue
    return out


def jsonl_pairs(base_path, arm_path, key_fields):
    """[(key, base_row, arm_row)] pairing two jsonl files on a tuple of fields, in the base file's order."""
    def load(path):
        out = {}
        for r in read_jsonl(path):
            if r.get("missing"):
                continue
            out[tuple(str(r.get(f)) for f in key_fields)] = r  # str: a list-valued field (t1c's `units`) must still key
        return out
    base, arm = load(base_path), load(arm_path)
    return [(k, base[k], arm[k]) for k in base if k in arm]


def metric_fn(metric):
    """A callable on a row from a callable, a traffic metric name (TRAFFIC_METRICS) or a plain row key."""
    if callable(metric):
        return metric
    if metric in TRAFFIC_METRICS:
        return TRAFFIC_METRICS[metric]
    return lambda r: r[metric]


def diffs(pairs, metric):
    """Per-run paired differences arm - base of `metric` (a callable on a row, or a key) in the pairs' order."""
    f = metric_fn(metric)
    return [f(a) - f(b) for _k, b, a in pairs]


def values(pairs, metric, side):
    f = metric_fn(metric)
    return [f(b if side == "base" else a) for _k, b, a in pairs]


def by_seed(pairs, metric):
    """{seed: [paired diffs over that seed's ticks]} for variance components; key[0] is the seed."""
    f = metric_fn(metric)
    out = {}
    for k, b, a in pairs:
        seed = k[0] if isinstance(k, tuple) else k
        out.setdefault(seed, []).append(f(a) - f(b))
    return out
