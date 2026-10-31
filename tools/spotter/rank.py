#!/usr/bin/env python3
"""Spotter S2: rank the oddest crew-seconds of a batch and merge them into MOMENTS, no training. Stdlib only.

    python3 tools/spotter/rank.py build/spotter/fights [--top 50]
        -> features.csv, moments.json (machine), moments.md (a person) in that folder

The score is an EMPIRICAL TAIL, per unit class: for each signal, how rare a value this large is among every crew-second of the
same unit type in the batch, as -log10 of the share at or above it (2.0 = rarer than 1 in 100; 0 for a signal at 0). It is a
robust z-score's non-parametric cousin: no mean, no spread, so the zero-heavy signals (most crews are never stuck) neither blow up
nor wash out. A crew-second's score is the sum of its two largest surprises; seconds of one crew scoring >= --hot (1 s gaps
allowed) merge into a moment; a moment scores its peak plus half a point per doubling of its length. Each moment says which
signals made it, in words, with the raw value and how rare it was.
"""
import argparse
import json
import math
import os
import sys
from bisect import bisect_left

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import features as F  # noqa: E402

LEAD_S = 2   # a clip starts this long before the moment
TAIL_S = 2   # and runs this long after it
CLIP_MAX_S = 10  # a longer moment is clipped to the CLIP_MAX_S around its peak (a judge watches dozens)


class Tail:
    """value -> surprise over one class's values of one signal."""

    def __init__(self, values):
        self.sorted = sorted(values)
        self.n = len(self.sorted)

    def surprise(self, value):
        if value <= 0.0 or self.n == 0:
            return 0.0
        at_or_above = self.n - bisect_left(self.sorted, value)
        return -math.log10(max(at_or_above, 1) / self.n)

    def share_below(self, value):
        return bisect_left(self.sorted, value) / self.n if self.n else 0.0


def build_tails(table):
    by_class = {}
    for row in table:
        by_class.setdefault(row["unit"], []).append(row)
    tails = {}
    for unit, rows in by_class.items():
        tails[unit] = {key: Tail([float(r[key]) for r in rows]) for key in F.SIGNALS}
    return tails


def score_rows(table, tails):
    for row in table:
        tail = tails[row["unit"]]
        surprises = {key: tail[key].surprise(float(row[key])) for key in F.SIGNALS}
        top = sorted(surprises.values(), reverse=True)
        row["_surprise"] = surprises
        row["_score"] = top[0] + (top[1] if len(top) > 1 else 0.0)
    return table


def moments(table, hot=2.0, gap_s=1):
    by_crew = {}
    for row in table:
        by_crew.setdefault((row["fight"], row["crew"]), []).append(row)
    found = []
    for (fight, crew), seq in by_crew.items():
        seq.sort(key=lambda r: int(r["s"]))
        group = []
        for row in seq + [None]:
            if row is not None and row["_score"] >= hot and (not group or int(row["s"]) - int(group[-1]["s"]) <= gap_s + 1):
                group.append(row)
                continue
            if group:
                found.append(_moment(group))
            group = [row] if row is not None and row["_score"] >= hot else []
    found.sort(key=lambda m: -m["score"])
    return found


def _moment(group):
    first, peak = group[0], max(group, key=lambda r: r["_score"])
    run_back = max([float(first[k]) for k in F.SIGNALS if k.endswith("_s")] + [1.0])
    start = int(first["s"]) - int(run_back) + 1  # a run signal began before it got rare
    end = int(group[-1]["s"])
    length = end - start + 1
    best = {}
    for row in group:
        for key, value in row["_surprise"].items():
            if value > best.get(key, (0.0, 0.0))[0]:
                best[key] = (value, float(row[key]))
    reasons = []
    for key, (surprise, raw) in sorted(best.items(), key=lambda kv: -kv[1][0]):
        if surprise < 1.0:
            continue
        words, unit = F.SIGNALS[key]
        reasons.append({"signal": key, "words": words, "value": round(raw, 1), "unit": unit,
                        "surprise": round(surprise, 2), "rarer_than": round(100.0 * (1.0 - 10 ** -surprise), 2)})
    return {
        "fight": first["fight"], "arena": first["arena"], "seed": int(first["seed"]), "crew": first["crew"],
        "team": int(first["team"]), "unit": first["unit"], "squad": first.get("squad", ""),
        "start_s": start, "end_s": end, "length_s": length, "peak_s": int(peak["s"]),
        "peak_tick": int(peak["tick"]), "at": [float(peak["x"]), float(peak["z"])],
        "score": round(peak["_score"] + 0.5 * math.log2(max(length, 1)), 2), "reasons": reasons[:4],
        # Every signal's peak value and rarity over the moment: S6's feature vector (the reasons above are only the top four).
        "signals_max": {k: round(v[1], 2) for k, v in best.items()},
        "surprise_max": {k: round(v[0], 3) for k, v in best.items()},
        "context": {k: peak.get(k, "") for k in ("order", "move", "phase", "intent", "choice", "blocked", "touch_what")},
        "clip": _clip(first, start, end, int(peak["s"])),
    }


def _clip(first, start, end, peak_s):
    from_s, to_s = max(0, start - LEAD_S), end + TAIL_S
    if to_s - from_s > CLIP_MAX_S:
        from_s = max(from_s, min(peak_s - CLIP_MAX_S // 2, to_s - CLIP_MAX_S))
        to_s = from_s + CLIP_MAX_S
    return {"seed": int(first["seed"]), "arena": first["arena"], "crew": first["crew"], "from_s": from_s, "to_s": to_s}


def pick(found, top, per_fight=8, per_crew=1):
    """The top moments with a cap per fight and per crew, so one wedged crew or one odd fight cannot fill the page."""
    chosen, fights, crews = [], {}, {}
    for m in found:
        key = (m["fight"], m["crew"])
        if fights.get(m["fight"], 0) >= per_fight or crews.get(key, 0) >= per_crew:
            continue
        chosen.append(m)
        fights[m["fight"]] = fights.get(m["fight"], 0) + 1
        crews[key] = crews.get(key, 0) + 1
        if len(chosen) >= top:
            break
    return chosen


def controls(table, found, n, seed=7, length=8):
    """n random windows of ordinary driving the ranker did NOT flag (no hot second, no moment overlapping): the judging page's
    hidden controls, so his labels say the base rate as well as the ranker's precision. Same shape as a moment, `control: true`."""
    import random
    rng = random.Random(seed)
    busy = {}
    for m in found:
        busy.setdefault((m["fight"], m["crew"]), []).append((m["start_s"] - 3, m["end_s"] + 3))
    by_crew = {}
    for row in table:
        by_crew.setdefault((row["fight"], row["crew"]), []).append(row)
    keys = sorted(by_crew)
    rng.shuffle(keys)
    out = []
    for key in keys:
        seq = sorted(by_crew[key], key=lambda r: int(r["s"]))
        if len(seq) < length + 10:
            continue
        i = rng.randrange(5, len(seq) - length)
        window = seq[i:i + length]
        a, b = int(window[0]["s"]), int(window[-1]["s"])
        if any(lo <= b and a <= hi for lo, hi in busy.get(key, [])) or max(r["_score"] for r in window) >= 1.0:
            continue
        m = _moment(window)
        m.update({"control": True, "start_s": a, "end_s": b, "length_s": b - a + 1})
        m["clip"].update({"from_s": a, "to_s": b + 1})
        out.append(m)
        if len(out) >= n:
            break
    return out


def reason_line(m):
    return "; ".join(f"{r['words']} ({r['value']:g} {r['unit']}, rarer than {r['rarer_than']:g} %)" for r in m["reasons"])


def repro(m):
    c = m["clip"]
    return (f"make spotter-clip SPOT_SEED={c['seed']} SPOT_ARENA={c['arena']} SPOT_CREW={c['crew']} "
            f"SPOT_FROM={c['from_s']} SPOT_TO={c['to_s']}")


def write_md(chosen, found, table, path, stamp):
    fights = sorted({r["fight"] for r in table})
    with open(path, "w") as out:
        out.write(f"# Spotter: the {len(chosen)} oddest moments\n\n")
        out.write(f"{stamp}. {len(table)} crew-seconds, {len(fights)} fights, {len(found)} moments scored; "
                  f"capped 8 a fight, 1 a crew.\n\n")
        out.write("| # | score | fight | crew (unit, team) | seconds | what a player would see | reproduce |\n|---|---|---|---|---|---|---|\n")
        for i, m in enumerate(chosen, 1):
            out.write(f"| {i} | {m['score']:.2f} | {m['fight']} | {m['crew']} ({m['unit']}, {m['team']}) | "
                      f"{m['start_s']}-{m['end_s']} | {reason_line(m)} | `{repro(m)}` |\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fight_dir", nargs="?", default="build/spotter/fights")
    ap.add_argument("--top", type=int, default=50)
    ap.add_argument("--hot", type=float, default=2.0)
    ap.add_argument("--controls", type=int, default=0, help="also pick N hidden random controls (unflagged windows)")
    args = ap.parse_args()
    table = F.load_dir(args.fight_dir)
    if not table:
        sys.exit(f"rank: no fights in {args.fight_dir}")
    F.write_csv(table, os.path.join(args.fight_dir, "features.csv"))
    score_rows(table, build_tails(table))
    found = moments(table, hot=args.hot)
    chosen = pick(found, args.top)
    stamp = _stamp(args.fight_dir)
    with open(os.path.join(args.fight_dir, "moments.json"), "w") as out:
        json.dump({"stamp": stamp, "crew_seconds": len(table), "moments_scored": len(found), "top": chosen,
                   "controls": controls(table, found, args.controls)}, out, indent=1)
    write_md(chosen, found, table, os.path.join(args.fight_dir, "moments.md"), stamp)
    print(f"rank: {len(table)} crew-seconds, {len(found)} moments, top {len(chosen)} -> {args.fight_dir}/moments.md")
    for i, m in enumerate(chosen[:10], 1):
        print(f"  {i:2d}. {m['score']:5.2f} {m['fight']:18s} {m['crew']:22s} {m['start_s']:4d}-{m['end_s']:<4d} {reason_line(m)}")


def _stamp(fight_dir):
    run = os.path.join(fight_dir, "run.txt")
    if os.path.exists(run):
        lines = [l.strip() for l in open(run) if l.strip()]
        if lines:
            return lines[-1].lstrip("> ")
    return "unstamped"


if __name__ == "__main__":
    main()
