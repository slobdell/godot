#!/usr/bin/env python3
"""The distinct-pairs rule for hull-rest verdicts (round 33 overnight, as for CP-F's R33.23).

hull-rest barely varies with the seed, so two seeds can produce the same (base, candidate) rows. A judged se counts such
a pair once: within a cell (every key field but the seed), keep the first seed of each distinct (base row, candidate
row) pair. `distinct_keys(base, new, keys)` returns (kept keys, {cell: (distinct, all)}); a key is a tuple whose last
field is the seed and whose rows are JSON-able.

Round 34 (planner P4 (a)): ONE run identity for every tool. Each tool used to apply the rule to its OWN rows (hull rows,
face counters, face episodes), so one series read 48, 32 and 36 distinct pairs (p3-pairs-923fcb97f): a pair whose face
counters matched another seed's was dropped by face_keep_table and kept by hull_aa. `distinct_runs` keys the rule on the
whole run instead (its screen.json plus its last PLANNER_SEAM_REPORT, `run_identity`), so every tool keeps the same pairs.
"""
import hashlib
import json
import pathlib


def signature(row):
    return json.dumps(row, sort_keys=True, default=str)


def distinct_keys(base, new, keys):
    seen, kept, cells = set(), [], {}
    for key in keys:
        cell = key[:-1]
        distinct, total = cells.get(cell, (0, 0))
        mark = (cell, signature(base[key]), signature(new[key]))
        if mark not in seen:
            seen.add(mark)
            kept.append(key)
            distinct += 1
        cells[cell] = (distinct, total + 1)
    return kept, cells


def summary(cells, prefix):
    """One line a mode: distinct pairs of all, and the cells that repeat."""
    lines = []
    for mode in sorted({cell[0] for cell in cells}):
        mine = {c: v for c, v in cells.items() if c[0] == mode}
        d = sum(v[0] for v in mine.values())
        n = sum(v[1] for v in mine.values())
        repeats = ", ".join("%s %d/%d" % ("/".join(str(x) for x in c[1:]), v[0], v[1])
                            for c, v in sorted(mine.items()) if v[0] < v[1])
        lines.append("%s %s | distinct pairs %d of %d | cells that repeat: %s" % (prefix, mode, d, n, repeats or "none"))
    return lines


def run_identity(root, arm, faction, task, seed):
    """One run's identity: a hash of its screen.json and its last PLANNER_SEAM_REPORT line (each "" when absent), from
    the hull-rest layout <root>/<arm>/<faction>/<task>-<seed>/. Everything any planner series tool reads is in the two."""
    run = pathlib.Path(root, arm, faction, "%s-%s" % (task, seed))
    screen = run / "screen.json"
    log = run / "run.log"
    report = ""
    if log.exists():
        for line in log.read_text(errors="replace").splitlines():
            if line.startswith("PLANNER_SEAM_REPORT "):
                report = line
    text = (screen.read_text() if screen.exists() else "") + "\n" + report
    return hashlib.sha1(text.encode()).hexdigest()


def distinct_runs(root, keys, arms):
    """The distinct-pairs rule on run identity: `keys` end (faction, task, seed); `arms(key)` names the key's
    (base arm, candidate arm) folders. Returns (kept keys, {cell: (distinct, all)}) like `distinct_keys`."""
    base, new = {}, {}
    for key in keys:
        faction, task, seed = key[-3:]
        base_arm, new_arm = arms(key)
        base[key] = run_identity(root, base_arm, faction, task, seed)
        new[key] = run_identity(root, new_arm, faction, task, seed)
    return distinct_keys(base, new, keys)
