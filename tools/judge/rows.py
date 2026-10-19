#!/usr/bin/env python3
"""Readers for every judged-row format kept under `_agents/streams/references/` (rounds 27-30), each returning PAIRS
of runs keyed the way the runner wrote them, so the judge tools never re-derive a format.

  traffic_pairs(base, arm)      traffic-series jsonl (tests/traffic/traffic_probe.gd rows; `which == both`), per case
  approach_pairs(path)          ApproachStage jsonl (brains B1/B2): one file, arms = `approach` east v none
  census_pairs(off_dir, on_dir, tag)   one Godot log per seed, the `TAG {json}` summary line (CONTACT_CENSUS, SCOUT_CENSUS)
  terminus_rows(path)           a Terminus judged text, both formats: round 29's `terminus-<squad>-<seed>.log base a/n c |
                                new a/n c` lines and round 30's `== <squad> (13 seeds)` + `per seed arrived(contacts):
                                <seed>:<a>><a>(<c>><c>) ...` lines (m1b / m2b / m4b run 2 / kturnarc)
  class_lines(path)             the hull-rest table's `M1_CLASS task | class | n | new | base | diff | se | ...` lines
  guard_lines(path, tag)        `FIGHT_GUARD <name>: base B new N diff D se S ...` / `PINNED <name> crew-seconds: ...` lines
  cell_pairs(path, cell)        brains' gate-series jsonl (`cell`, `arm` columns): off v on per (seed, start_tick)
  arrive_pairs(off, on)         brains' arrive-series jsonl pair, a cell = (arena, seed, units)
  bridge_cells(path)            his bridge 108 jsonl: {(side, seed, start_tick): passed} by tools/tactics/bridge_verdict's rule
  jsonl_pairs(base, arm, key)   any two jsonl files paired on `key` fields (optional `where` filter)

A pair is (key, base_row, arm_row). `diffs(pairs, metric)` turns pairs into per-run paired differences, in the
RUNNER'S ORDER (seed-major, start tick minor: mk/traffic.mk's loop), which is the order sequential judging walks.
"""
import functools
import gzip
import json
import os
import re

TRAFFIC_TICKS = (1, 3, 6, 8, 11, 16)


@functools.lru_cache(maxsize=256)
def _read_jsonl_cached(path):
    opener = gzip.open if path.endswith(".gz") else open  # round 32's traffic rows are filed gzipped
    with opener(path, "rt") as handle:
        return tuple(json.loads(line) for line in handle if line.strip())


def read_jsonl(path):
    """Rows of a jsonl file (cached per path: the table reads every judged pair dozens of times; rows are never mutated)."""
    return list(_read_jsonl_cached(os.path.abspath(path)))


def all_in_s(row):
    """Every crew's last arrival; a crew that never arrived counts as the run's end (tests/traffic/traffic_table.py)."""
    times = [t if t >= 0 else row["end_s"] for t in row["arrive_s"].values()]
    return max(times) if times else row["end_s"]


def cross_clear_s(row):
    """Round 30's crossing clock (both squads past the meeting point; tests/traffic/turns_verdict.py `clock`): never (-1)
    reads as the run's end. None on rows older than the clock (rounds 28-29), so a pooled reader can skip them."""
    v = row.get("cross_clear_s")
    if v is None:
        return None
    return v if v >= 0 else row["end_s"]


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
    "xclear": cross_clear_s,
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
    """{squad: [(seed, {'arrived': a, 'crews': n, 'contacts': c}, {...new})]} from a Terminus judged text.

    Round 29's M4 table writes one line a run (`terminus-rigs-14.log base 13/16 1204 | new 11/16 2345`); round 30's
    tables (m1b, m2b, m4b run 2, kturnarc) write a `== rigs (13 seeds)` header, an `arrivals base A new B of N` line
    (crews a run = N / seeds) and one `per seed arrived(contacts): 36:16>15(134>270) ...` line a squad."""
    out = {}
    squad, crews = None, None
    with open(path) as handle:
        for line in handle:
            m = re.search(r"terminus-(\w+)-(\d+)\.log base (\d+)/(\d+) (\d+) \| new (\d+)/(\d+) (\d+)", line)
            if m:
                sq, seed = m.group(1), int(m.group(2))
                base = {"arrived": int(m.group(3)), "crews": int(m.group(4)), "contacts": int(m.group(5))}
                new = {"arrived": int(m.group(6)), "crews": int(m.group(7)), "contacts": int(m.group(8))}
                out.setdefault(sq, []).append((seed, base, new))
                continue
            m = re.match(r"\s*== (\w+) \((\d+) seeds\)", line)
            if m:
                squad, crews = m.group(1), None
                continue
            m = re.search(r"arrivals base (\d+) new (\d+) of (\d+)", line)
            if m and squad:
                crews = int(m.group(3))
                continue
            m = re.search(r"per seed arrived\(contacts\): (.*)", line)
            if m and squad:
                cells = re.findall(r"(\d+):(\d+)>(\d+)\((\d+)>(\d+)\)", m.group(1))
                n_run = crews // len(cells) if crews and cells else 0
                for seed, ba, na, bc, nc in cells:
                    out.setdefault(squad, []).append((int(seed), {"arrived": int(ba), "crews": n_run, "contacts": int(bc)},
                                                      {"arrived": int(na), "crews": n_run, "contacts": int(nc)}))
    return out


def guard_lines(path, tag):
    """{name: {base, new, diff, se, n}} from a judged table's paired-sum lines: `FIGHT_GUARD kills: base 1001 new 984 diff
    -17 se 21.5 within 2 se`, `PINNED all crew-seconds: base 2902 new 1040 diff -1862 se 459.6 DOWN beyond 2 se`, and the
    paired-mean form `FIGHT_GUARD hit rate: base 0.717 new 0.714 paired mean diff -0.003 se 0.012 within 2 se (n 24)`.
    `n` is the `runs paired N` line's count (the sum's n) and the `(n 24)` of a mean line."""
    out = {}
    runs = None
    num = r"([-+]?\d+(?:\.\d+)?)"
    with open(path) as handle:
        for line in handle:
            if not line.startswith(tag + " "):
                continue
            m = re.search(r"runs paired (\d+)", line)
            if m:
                runs = int(m.group(1))
                continue
            m = re.match(re.escape(tag) + r" (.+?): base " + num + " new " + num + r" (paired mean )?diff " + num + " se " + num + r"(.*)$", line)
            if not m:
                continue
            name = m.group(1).replace(" crew-seconds", "")
            n_mean = re.search(r"\(n (\d+)\)", m.group(7))
            out[name] = {"base": float(m.group(2)), "new": float(m.group(3)), "diff": float(m.group(5)), "se": float(m.group(6)),
                         "n": int(n_mean.group(1)) if n_mean else runs, "mean": bool(m.group(4))}
    return out


def cell_pairs(path, cell, off="off", on="on"):
    """[((seed, start_tick), off_row, on_row)] for one cell of brains' gate-series jsonl (B5c-v4: `cell` and `arm` columns)."""
    by = {}
    for r in read_jsonl(path):
        if r.get("cell") != cell:
            continue
        by.setdefault((r["seed"], r["start_tick"]), {})[r["arm"]] = r
    return [(k, v[off], v[on]) for k, v in sorted(by.items()) if off in v and on in v]


def arrive_pairs(off_path, on_path, key_fields=("arena", "seed", "units")):
    """[(cell, off_row, on_row)] for brains' arrive series (squad-arrive-series: 5 arenas x seeds x 5 rosters = 100 cells)."""
    def load(path):
        return {tuple(str(r.get(f)) for f in key_fields): r for r in read_jsonl(path)}
    off, on = load(off_path), load(on_path)
    return [(k, off[k], on[k]) for k in off if k in on]


def all_in8_or_end(row, end=90.0):
    """A cell's all-within-8 m time, a cell that never got there read as the run's end (cell_table.py prints 'never';
    B5c-v4's Sumps medians 37.5 v 24.5 are this reading)."""
    v = row.get("all_in8_s")
    return end if v is None else v


def bridge_cells(path):
    """{(side, seed, start_tick): passed} for his bridge 108 (BRIDGE_PROBE rows), by tools/tactics/bridge_verdict.py's rule:
    every surviving crew across (a dead crew excused if it was not stuck first) and no crew pressed at the rim."""
    out = {}
    for r in read_jsonl(path):
        uncrossed_dead = sum(1 for d in r.get("dead", []) if not d.get("crossed"))
        passed = int(r["crossed"]) + uncrossed_dead >= int(r["crews"]) and int(r.get("rim_crews", 1)) == 0
        out[(r["side"], int(r["seed"]), int(r["start_tick"]))] = passed
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


def jsonl_pairs(base_path, arm_path, key_fields, where=None):
    """[(key, base_row, arm_row)] pairing two jsonl files on a tuple of fields, in the base file's order; `where`
    ({field: value}) keeps only the rows matching it (t1c-b's ApproachStage drawn rows: {"approach": "east"})."""
    def load(path):
        out = {}
        for r in read_jsonl(path):
            if r.get("missing"):
                continue
            if where and any(r.get(f) != v for f, v in where.items()):
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


def planner_series_lines(path):
    """{squad: {n, base_arrived, arrived_mean, arrived_se, contacts_base_median, contacts_mean, contacts_se}} from the
    planner series verdict's PLANNER_SERIES_SQUAD lines (round 33): paired MEANS a seed and their se, no per-seed rows."""
    out = {}
    pat = re.compile(r"PLANNER_SERIES_SQUAD (\w+): n (\d+) \| arrivals base (\d+) candidate (\d+) of (\d+), paired mean ([-+.\d]+) "
                     r"se ([.\d]+).*?contact-ticks median base (\d+) candidate (\d+), paired mean ([-+.\d]+) se ([.\d]+)")
    with open(path) as handle:
        for line in handle:
            m = pat.search(line)
            if m:
                n = int(m.group(2))
                out[m.group(1)] = {"n": n, "base_arrived": int(m.group(3)) / n, "arrived_mean": float(m.group(6)),
                                   "arrived_se": float(m.group(7)), "contacts_base_median": float(m.group(8)),
                                   "contacts_mean": float(m.group(10)), "contacts_se": float(m.group(11))}
    return out


def far_lines(path):
    """{name: {base, arm, n, se, differing}} from far_ab's paired-sum lines (round 33 traffic: `L1 parked far loops`, `L2 all
    far loops`, `L3 kills`, `L3 deaths`) and {"hit rate": {base, arm, n, se_mean}} from its paired-mean hit-rate line (n is
    the L3 kills line's fights)."""
    out = {}
    pat = re.compile(r"^(L1 parked far loops|L2 all far loops|L3 kills|L3 deaths): base (\d+), arm (\d+) over (\d+) paired fights; "
                     r"drop -?\d+, paired se of the sum ([.\d]+).*?fights differing (\d+)")
    hit = re.compile(r"^L3 hit rate: base ([.\d]+), arm ([.\d]+) \(mean of fights\), paired se of the mean ([.\d]+)")
    with open(path) as handle:
        for line in handle:
            m = pat.search(line)
            if m:
                out[m.group(1)] = {"base": int(m.group(2)), "arm": int(m.group(3)), "n": int(m.group(4)),
                                   "se": float(m.group(5)), "differing": int(m.group(6))}
                continue
            m = hit.search(line)
            if m:
                out["hit rate"] = {"base": float(m.group(1)), "arm": float(m.group(2)), "se_mean": float(m.group(3))}
    if "hit rate" in out and "L3 kills" in out:
        out["hit rate"]["n"] = out["L3 kills"]["n"]
        out["hit rate"]["differing"] = out["L3 kills"]["differing"]
    return out


def hull_aa_cells(path):
    """[{mode, task, klass, metric, n, base_median, new_median, mean_diff, sd_run}] from the planner's HULL_AA_CELL lines."""
    out = []
    with open(path) as handle:
        for line in handle:
            if not line.startswith("HULL_AA_CELL ") or "mode task class" in line:
                continue
            parts = [p.strip() for p in line[len("HULL_AA_CELL "):].split("|")]
            head = parts[0].split()
            try:
                medians = parts[2].split()
                out.append({"mode": head[0], "task": head[1], "klass": head[2], "metric": head[3], "n": int(parts[1]),
                            "base_median": float(medians[0]), "new_median": float(medians[1]), "mean_diff": float(parts[3]),
                            "sd_run": float(parts[4])})
            except (ValueError, IndexError):
                continue
    return out


def m1_aa_lines(path):
    """[{task, metric, pairs, a, b, sd_run, se_sum, swing}] from manoeuvre's M1 hull-rest A/A table (round 34, the new
    ruler: `faced_move  moving_real  36 |  3.0  4.0 |  0.51  3.0  5.0 |  29%`)."""
    out = []
    pat = re.compile(r"^(faced_\w+)\s+(\w+)\s+(\d+) \|\s+([-.\d]+)\s+([-.\d]+) \|\s+([.\d]+)\s+([.\d]+)\s+[.\d]+ \|\s+(\d+)%")
    with open(path) as handle:
        for line in handle:
            m = pat.search(line)
            if m:
                out.append({"task": m.group(1), "metric": m.group(2), "pairs": int(m.group(3)), "a": float(m.group(4)),
                            "b": float(m.group(5)), "sd_run": float(m.group(6)), "se_sum": float(m.group(7)),
                            "swing": int(m.group(8))})
    return out
