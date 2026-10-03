"""The thin pools, as the lead hears them (round 16, booth B1).

The lead: *"I keep hearing a lot of the same statements across gameplay"*. The pool report (round 10) works per
(speaker, moment) over fixtures replayed alone; what he hears is an EVENING: different matches in a row, one memory
across them (AnnouncerHistory). `announcer_cli.gd --evening` writes every cue of such an evening; this groups them by
the pool the line came from, (speaker, act, the line's tags), which is the effective pool after the context filters,
and prints per pool:

  lines     library lines in that exact pool
  calls/m   lines said from it per match
  fresh     unused lines the director could pick from at the pick (mean), `eff` the effective count (exp entropy)
  again5    the share of its calls whose line was also said in the previous 4 matches (a repeat he can hear)
  rep/m     calls/m × again5: repeats heard per match from this pool, the ranking
  first     the first repeat of the evening from an empty memory: match number and minutes of play before it
  need5     the lines the pool needs for its first repeat to land past 5 matches at this rate: ceil(5 × calls/m)
            with strict least-recently-heard picking; the director's history is a weighting, not a queue, so the
            plan adds a quarter (`target`)

`--history PATH` adds what HIS user://announcer_history.json says: per pool, the distinct lines per match over his
real matches (`his/m`) and how many of the pool's lines he has heard.

    python3 tools/announcer/thin_pools.py build/announcer/evening.jsonl [--history FILE] [--top 15] [--json OUT]
"""

from __future__ import annotations

import argparse
import collections
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LINES = os.path.join(ROOT, "assets", "announcer", "lines.json")
WINDOW = 5
SLACK = 1.25


def pool_key(speaker: str, act: str, tags) -> str:
    return "%s %s [%s]" % (speaker, act, ",".join(sorted(tags)))


def load_rows(path: str) -> list:
    with open(path) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def library_pools(lines: list) -> dict:
    pools: dict = collections.defaultdict(list)
    for line in lines:
        pools[pool_key(line["speaker"], line["act"], line.get("tags", []))].append(line)
    return pools


def analyse(rows: list, lines: list, history: list | None = None, window: int = WINDOW) -> list:
    pools = library_pools(lines)
    by_id = {line["id"]: line for line in lines}
    matches = max((row["match"] for row in rows), default=-1) + 1
    lengths: dict = {}
    for row in rows:
        lengths[row["match"]] = float(row.get("length_min", 0.0))
    played_before = {}
    total = 0.0
    for index in range(matches):
        played_before[index] = total
        total += lengths.get(index, 0.0)
    # Which matches each line was said in, for the window test and the first repeat.
    said_in: dict = collections.defaultdict(set)
    stats: dict = {}
    for row in sorted(rows, key=lambda r: (r["match"], r["minute"])):
        key = pool_key(row["speaker"], row["act"], row.get("line_tags", []))
        entry = stats.setdefault(key, {"calls": 0, "again": 0, "fresh": 0.0, "eff": 0.0, "first": None, "lines_said": set()})
        entry["calls"] += 1
        pool = row.get("pool") or {}
        entry["fresh"] += float(pool.get("fresh", 0))
        entry["eff"] += float(pool.get("effective", 0))
        before = said_in[row["line"]]
        if any(row["match"] - window < m < row["match"] for m in before):
            entry["again"] += 1
        if entry["first"] is None and any(m < row["match"] for m in before):
            entry["first"] = {"match": row["match"] + 1, "minutes": round(played_before[row["match"]] + row["minute"], 1),
                              "line": row["line"]}
        before.add(row["match"])
        entry["lines_said"].add(row["line"])
    heard: dict = {}
    if history:
        for ids in history:
            for line_id in ids:
                line = by_id.get(line_id)
                if line is None:
                    continue
                key = pool_key(line["speaker"], line["act"], line.get("tags", []))
                heard.setdefault(key, collections.Counter())[line_id] += 1
    out = []
    for key, entry in stats.items():
        calls_pm = entry["calls"] / max(matches, 1)
        again = entry["again"] / max(entry["calls"], 1)
        need = math.ceil(window * calls_pm)
        his = heard.get(key)
        out.append({
            "pool": key,
            "lines": len(pools.get(key, [])),
            "calls_per_match": round(calls_pm, 2),
            "fresh": round(entry["fresh"] / entry["calls"], 1),
            "effective": round(entry["eff"] / entry["calls"], 1),
            "again5": round(again, 3),
            "repeats_per_match": round(calls_pm * again, 2),
            "first_repeat": entry["first"],
            "need5": need,
            "target": max(need, math.ceil(need * SLACK)),
            "his_per_match": round(sum(his.values()) / len(history), 2) if his and history else None,
            "his_heard": len(his) if his else 0,
            "texts": [line["text"] for line in pools.get(key, [])],
            "ids": [line["id"] for line in pools.get(key, [])],
        })
    out.sort(key=lambda r: (-r["repeats_per_match"], -r["calls_per_match"]))
    return out


def render(result: list, matches: int, minutes: float, top: int, quote: int) -> str:
    out = ["THIN POOLS over one evening of %d matches (%.0f min of play), window %d" % (matches, minutes, WINDOW),
           "%-46s %5s %7s %6s %5s %7s %6s %18s %6s %6s %6s %6s" % (
               "pool (speaker act [line tags])", "lines", "calls/m", "fresh", "eff", "again5", "rep/m", "first repeat",
               "need5", "target", "his/m", "heard")]
    for row in result[:top]:
        first = row["first_repeat"]
        first_text = "m%d @%.0f min" % (first["match"], first["minutes"]) if first else "none"
        out.append("%-46s %5d %7.2f %6.1f %5.1f %6.0f%% %6.2f %18s %6d %6d %6s %6s" % (
            row["pool"][:46], row["lines"], row["calls_per_match"], row["fresh"], row["effective"], row["again5"] * 100,
            row["repeats_per_match"], first_text, row["need5"], row["target"],
            "-" if row["his_per_match"] is None else "%.2f" % row["his_per_match"], row["his_heard"] or "-"))
    if quote:
        out.append("")
        for row in result[:top]:
            out.append("%s (%d lines)" % (row["pool"], row["lines"]))
            for text in row["texts"][:quote]:
                out.append("    " + text)
    return "\n".join(out)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("evening", help="the cues of an evening (announcer_cli.gd --evening)")
    parser.add_argument("--lines", default=LINES)
    parser.add_argument("--history", help="a user://announcer_history.json (the lead's real matches)")
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument("--quote", type=int, default=0, help="quote this many lines of each listed pool")
    parser.add_argument("--json", help="write the whole table here")
    args = parser.parse_args(argv)
    rows = load_rows(args.evening)
    with open(args.lines) as handle:
        lines = json.load(handle)["lines"]
    history = None
    if args.history:
        with open(args.history) as handle:
            history = json.load(handle).get("matches", [])
    result = analyse(rows, lines, history)
    matches = max((row["match"] for row in rows), default=-1) + 1
    lengths = {row["match"]: float(row.get("length_min", 0.0)) for row in rows}
    print(render(result, matches, sum(lengths.values()), args.top, args.quote))
    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w") as handle:
            json.dump({"matches": matches, "pools": result}, handle, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
