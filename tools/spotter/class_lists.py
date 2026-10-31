#!/usr/bin/env python3
"""Spotter S3 (round 48, C48.3): the class lists for the owners, from tools/spotter/classes.py's output. Stdlib only.

    python3 tools/spotter/class_lists.py main <classes_out_dir> --classes B [--top 12] [--label ...]
        the longest moments of each class (and of each B / E cause), each with its `make spotter-clip` line and its per-second rows
    python3 tools/spotter/class_lists.py clips <db.json> <fight_dir> [--label ...]
        a judging page's clips (labels.py's db export) run through the same rule: each clip's class = the class with the most
        flagged crew-seconds of that crew inside the clip's window (ties by A E C B D); 'none' = the rule does not see it
"""
import argparse
import json
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import classes as K  # noqa: E402
import features as F  # noqa: E402

COLS = ("s", "speed", "hp", "order", "choice", "phase", "blocked", "blocker_phase", "blocker_move", "blocker_order", "to_go",
        "gain_5", "route_off", "squad_d", "hit_dmg", "fire_far", "range", "shots", "touch_what", "intent")


def rows_table(rows, limit=14):
    cols = [c for c in COLS if any(c in r and r[c] not in ("", None) for r in rows)]
    out = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows[:limit]:
        out.append("| " + " | ".join(_cell(r.get(c, "")) for c in cols) + " |")
    if len(rows) > limit:
        out.append(f"| ... {len(rows) - limit} more seconds |" + " |" * (len(cols) - 1))
    return "\n".join(out)


def _cell(v):
    if isinstance(v, float):
        return f"{v:g}"
    return str(v).replace("|", "/")


def moment_block(m):
    cause = m.get("b_cause") or m.get("e_cause") or m.get("f_cause") or ""
    head = (f"- **{m['crew']}** ({m['unit']}, team {m['team']}) {m['arena']} seed {m['seed']}, {m['run_start_s']}-{m['end_s']} s, "
            f"{m['crew_seconds']} flagged s" + (f", cause: {cause}" if cause else "") + f"\n  `{m['repro']}`\n\n")
    return head + rows_table(m["rows"]) + "\n"


def main_lists(args):
    rates = json.load(open(os.path.join(args.dir, "classes.json")))
    out = [f"# Spotter class list{'s' if len(args.classes) > 1 else ''}: {', '.join(args.classes)} ({rates['rule']})\n",
           f"{args.label or rates.get('label', '')}; {rates['fights']} fights, seeds {rates['seeds']}, maps {' '.join(rates['maps'])}. "
           f"The {args.top} longest moments of each class (and each cause), by flagged crew-seconds. Every row is one second "
           "(the probe's own fields; blocker_* is the named blocker's own row at that tick).\n"]
    for cls in args.classes:
        c = rates["classes"][cls]
        out.append(f"\n## {cls}. {c['name']} ({c['owner']}): {c['moments_per_fight']:.2f} moments / fight, "
                   f"{c['crew_seconds_per_fight']:.1f} crew-s / fight\n")
        ms = [json.loads(l) for l in open(os.path.join(args.dir, f"class_{cls}.jsonl"))]
        causes = c.get("by_cause")
        groups = [(k, [m for m in ms if (m.get("b_cause") or m.get("e_cause") or m.get("f_cause")) == k]) for k in causes] if causes else [("", ms)]
        for name, group in groups:
            if name:
                v = causes[name]
                out.append(f"\n### {cls} / {name}: {v['moments_per_fight']:.2f} moments / fight, "
                           f"{v['crew_seconds_per_fight']:.1f} crew-s / fight\n")
            maps = Counter(m["arena"] for m in group)
            out.append(f"\n{len(group)} moments; by map: " + ", ".join(f"{a} {n}" for a, n in sorted(maps.items())) + "\n\n")
            for m in sorted(group, key=lambda m: -m["crew_seconds"])[: args.top]:
                out.append(moment_block(m) + "\n")
    text = "".join(out)
    if args.dest:
        open(args.dest, "w").write(text)
        print(f"class_lists: {args.dest}")
    else:
        print(text)


def clip_class(moments, crew, a, b):
    got = Counter()
    for m in moments:
        if m["crew"] != crew:
            continue
        for r in m["rows"]:
            if a <= int(r["s"]) <= b:
                got[m["cls"]] += 1
    if not got:
        return "none", got
    best = max(got.values())
    return next(c for c in K.ORDER if got.get(c) == best), got


def clips_mode(args):
    db = json.load(open(args.db))
    cache = {}
    rows = []
    for c in sorted(db["clips"], key=lambda c: c.get("rank", 0)):
        m = re.search(r"SPOT_FROM=(\d+) SPOT_TO=(\d+)", c["repro"])
        a, b = int(m.group(1)), int(m.group(2))
        key = (c["arena"], int(c["seed"]))
        if key not in cache:
            path = os.path.join(args.fights, f"{key[0]}-{key[1]}.jsonl")
            path = path if os.path.exists(path) else path + ".gz"
            header, frows = F.load_fight(path)
            cache[key] = K.classify_fight(header, frows, f"{key[0]}-{key[1]}")
        cls, got = clip_class(cache[key], c["crew"], a, b)
        cause = ""
        for mm in cache[key]:
            if mm["crew"] == c["crew"] and mm["cls"] == cls and mm["start_s"] <= b and mm["end_s"] >= a:
                cause = mm.get("b_cause") or mm.get("e_cause") or mm.get("f_cause") or ""
        rows.append({"id": c.get("id"), "rank": c.get("rank"), "control": bool(c.get("control")), "cls": cls, "cause": cause,
                     "seconds": dict(got), "crew": c["crew"], "arena": c["arena"], "seed": c["seed"], "repro": c["repro"],
                     "reasons": c.get("reasons", [])})
    json.dump(rows, open(args.dest + ".json", "w"), indent=1) if args.dest else None
    flagged = [r for r in rows if not r["control"]]
    controls = [r for r in rows if r["control"]]
    out = [f"# {args.title}\n\n{args.label}. Each clip run through `tools/spotter/classes.py` ({K.RULE_VERSION}) on its own fight; its class "
           "is the class with the most flagged crew-seconds of that crew inside the clip's window. `none` = the rule flags no second "
           "of the clip (a candidate new class, or a moment only the ranker's rarity sees).\n\n",
           "| class | flagged clips | controls |\n|---|---|---|\n"]
    for cls in K.ORDER + ["none"]:
        out.append(f"| {cls} {K.NAMES.get(cls, 'no class')} | {sum(r['cls'] == cls for r in flagged)} | "
                   f"{sum(r['cls'] == cls for r in controls)} |\n")
    for cls in K.ORDER + ["none"]:
        group = [r for r in flagged if r["cls"] == cls]
        if not group:
            continue
        out.append(f"\n## {cls}. {K.NAMES.get(cls, 'no class (the rule sees none of it)')} ({len(group)})\n\n")
        for r in group:
            out.append(f"- rank {r['rank']} **{r['crew']}** {r['arena']} seed {r['seed']}"
                       + (f", cause: {r['cause']}" if r["cause"] else "") + f"; rule seconds {r['seconds'] or '{}'}; ranker: "
                       f"{'; '.join(r['reasons']) or '-'}\n  `{r['repro']}`\n")
    text = "".join(out)
    if args.dest:
        open(args.dest, "w").write(text)
        print(f"class_lists: {args.dest}")
    else:
        print(text)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)
    a = sub.add_parser("main")
    a.add_argument("dir")
    a.add_argument("--classes", default="ABCDE", type=lambda s: [c for c in s.upper() if c in K.ORDER])
    a.add_argument("--top", type=int, default=12)
    a.add_argument("--label", default="")
    a.add_argument("--dest", default="")
    b = sub.add_parser("clips")
    b.add_argument("db")
    b.add_argument("fights")
    b.add_argument("--label", default="")
    b.add_argument("--title", default="Judged clips by class")
    b.add_argument("--dest", default="")
    args = ap.parse_args()
    main_lists(args) if args.mode == "main" else clips_mode(args)


if __name__ == "__main__":
    main()
