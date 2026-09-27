#!/usr/bin/env python3
"""Read a match recording (the black box) and print what happened, in the terms the lead reports things in.

    python3 tools/read_recording.py                      # the newest recording
    python3 tools/read_recording.py --unit Rust_Law_3     # everything about one unit
    python3 tools/read_recording.py --damage              # who shot whom, and what got through
    python3 tools/read_recording.py --orders              # every order, with refusals

The point of this tool is to answer "why did that not die / why did they not move" WITHOUT replaying by eye. Its
headline section is the one that answers the unkillable-unit class of report directly: per victim, how much damage
arrived, how much the SHIELD ate, how much reached the HULL, and how its health actually moved over time.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

DIR = "build/recordings"


def load(path):
    rows = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    pass  # a half-written last line: the game may still be running
    return rows


def newest():
    stamp = os.path.join(DIR, "latest.txt")
    if os.path.exists(stamp):
        path = open(stamp).read().strip()
        if os.path.exists(path):
            return path
    files = sorted(f for f in os.listdir(DIR) if f.endswith(".jsonl")) if os.path.isdir(DIR) else []
    if not files:
        sys.exit(f"no recordings in {DIR}/ — play a skirmish first (recording is on by default)")
    return os.path.join(DIR, files[-1])


def seconds(rows, tick):
    rate = next((r.get("tick_rate", 30) for r in rows if r["t"] == "match"), 30)
    return tick / float(rate)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", nargs="?")
    ap.add_argument("--unit")
    ap.add_argument("--damage", action="store_true")
    ap.add_argument("--orders", action="store_true")
    args = ap.parse_args()

    path = args.path or newest()
    rows = load(path)
    if not rows:
        sys.exit(f"{path} is empty")
    head = next((r for r in rows if r["t"] == "match"), {})
    roster = {u["name"]: u for u in head.get("units", [])}
    print(f"=== {path}")
    print(f"    arena {head.get('arena')}  seed {head.get('seed')}  {len(roster)} units"
          + (f"  TUNING {head.get('tuning')}" if head.get("tuning") else ""))

    census = [r for r in rows if r["t"] == "census"]
    hits = [r for r in rows if r["t"] == "hit"]
    dead = {r["unit"]: r for r in rows if r["t"] == "dead"}

    if args.orders or not (args.damage or args.unit):
        print("\n--- ORDERS (what you told them)")
        for r in rows:
            if r["t"] == "order":
                who = r.get("units", [])
                where = r.get("to") or r.get("target") or ""
                shape = f" formation={r['formation']}" if r.get("formation") else ""
                bad = f"   << REFUSED: {r['error']}" if r.get("error") else ""
                print(f"  {seconds(rows, r['tick']):6.1f}s {r['verb']:<12} x{len(who):<3} {str(where):<18}"
                      f" src={r.get('source',''):<8}{shape}{bad}")
            elif r["t"] == "task":
                t = r.get("task", {})
                print(f"  {seconds(rows, r['tick']):6.1f}s   [{r.get('element')}] task {t.get('verb')} "
                      f"{t.get('to','')} formation={r.get('formation')} — {r.get('why','')}")

    if args.damage or args.unit or not args.orders:
        print("\n--- DAMAGE (what actually landed)")
        took = defaultdict(lambda: {"hits": 0, "damage": 0.0, "faces": defaultdict(int)})
        for h in hits:
            if args.unit and h.get("target") != args.unit:
                continue
            e = took[h.get("target", "?")]
            e["hits"] += 1
            e["damage"] += h.get("damage", 0.0)
            e["faces"][h.get("face", "?")] += 1
        for name, e in sorted(took.items(), key=lambda kv: -kv[1]["damage"]):
            unit = roster.get(name, {})
            pool = unit.get("hp_max", 0) + unit.get("shield", 0)
            end = None
            for c in reversed(census):
                for u in c["units"]:
                    if u["n"] == name:
                        end = u
                        break
                if end:
                    break
            state = "DESTROYED" if name in dead else (
                f"hp {end['hp']:.0f}/{unit.get('hp_max',0):.0f} shield {end['shield']:.0f}" if end else "gone")
            faces = ",".join(f"{k}x{v}" for k, v in e["faces"].items())
            print(f"  {name:<20} {unit.get('display','?'):<18} took {e['hits']:>4} hits,"
                  f" {e['damage']:>8.0f} damage (pool {pool:.0f}) [{faces}]  -> {state}")
            rate = unit.get("shield_rate", 0.0)
            delay = unit.get("shield_delay", 0.0)
            if pool > 0 and e["damage"] > pool * 1.5 and name not in dead and rate > 0:
                # The floor: a shield back at `rate`/s after `delay`s of quiet means anything slower than this
                # never reaches the hull at all. This is the "several squads and it would not die" answer.
                print(f"       ^^ SURVIVED {e['damage']/pool:.1f}x its own pool. Its shield returns at"
                      f" {rate:.0f}/s after {delay:.1f}s without a hit, so fire arriving slower than"
                      f" ~{rate:.0f} damage/second NEVER reaches its hull.")

    if args.unit:
        print(f"\n--- {args.unit} OVER TIME")
        for c in census:
            for u in c["units"]:
                if u["n"] == args.unit:
                    print(f"  {seconds(rows, c['tick']):6.1f}s hp {u['hp']:>7.1f} shield {u['shield']:>6.1f}"
                          f"  order {u['order']:<11} src={u['src']:<7} phase {u['phase']:<9} {u['blocked']}")
        if args.unit in dead:
            d = dead[args.unit]
            print(f"  {seconds(rows, d['tick']):6.1f}s DESTROYED by {d['killer']} ({d['cause']})")


if __name__ == "__main__":
    main()
