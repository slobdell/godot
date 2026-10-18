#!/usr/bin/env python3
"""The distinct-pairs rule for hull-rest verdicts (round 33 overnight, as for CP-F's R33.23).

hull-rest barely varies with the seed, so two seeds can produce the same (base, candidate) rows. A judged se counts such
a pair once: within a cell (every key field but the seed), keep the first seed of each distinct (base row, candidate
row) pair. `distinct_keys(base, new, keys)` returns (kept keys, {cell: (distinct, all)}); a key is a tuple whose last
field is the seed and whose rows are JSON-able.
"""
import json


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
