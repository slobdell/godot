#!/usr/bin/env python3
"""Spotter S2 (round 48, C48.2): THE CLASS RULE. Assigns crew-seconds of a CPU-v-CPU fight to the five ways batch 1-2 caught our
units looking dumb, with FIXED thresholds (not the ranker's per-batch rarity), so a "before" and an "after" read the same rule.
Stdlib only; runs on builder3's system python and on the laptop.

    python3 tools/spotter/classes.py <fight_dir> [<fight_dir> ...] [--out <dir>] [--label <commit>] [--before <classes.json>]
        -> <out>/classes.json (rates + per fight), classes.md (a person), class_<X>.jsonl (every moment with its per-second rows)
        --before: a "before" classes.json (the round's is tools/spotter/baselines/classes-df9aacc1a.json): classes.md gains the
        PAIRED read, class by class, on the fights both have run (same arena-seed), after - before a fight with its standard error

THE RULE, v2 (one crew-second; a "run" is the consecutive seconds a condition has held, a sample gap > 1.5 s breaks it; a second
is flagged from the second its run reaches the threshold; the first class that matches, in the order A E STUCK C B D, wins):
  A  hurt crew retreats by abandoning the squad   choice RETREAT and (squad centre >= A_SPREAD_M away, squad_n > 1, for A_FAR_S,
                                                  or reversing < -0.6 m/s on a move for A_REVERSE_S)
  E  shot from beyond its range, no answer        >= E_HITS of the last E_WINDOW_S seconds hit by a shooter > 1.05 x its own
                                                  range (hits come in salvos), and NOT closing: the shooter's distance at the
                                                  window's first outranged hit minus now < E_CLOSE_M (closing is E10's answer;
                                                  breaking line of sight ends the hits)
  STUCK (by cause)                                on a move, > 15 m to go, < 1 m gained in 5 s, for STUCK_S: the second goes to
                                                  A if RETREAT, B if blocked / yielding to a CREW, C if blocked by terrain /
                                                  no_path or touching a prop, else D
  C  stuck on terrain / no path                   phase blocked by 'terrain' / 'no_path' for C_RUN_S, or against a prop on a move
                                                  while still or reversing for C_RUN_S
  B  squadmates jam each other (give-way loops)   phase blocked / yielding with a CREW named as the blocker for B_RUN_S;
                                                  a crew on a HOLD order yielding for B_HOLD_S (a held crew leaving its post)
  D  drives away from where it is going           on a move, phase driving, > 15 m to go, not RETREAT: nose > 100 deg off its
                                                  route while driving forward for D_WRONGWAY_S; a FOLLOW crew reversing, or
                                                  turning on the spot > D_SPIN_DPS, for D_FOLLOW_S
  F  holds fire, enemy in sight and in range      (v4, batch 2's new class; LAST in the order, so A-E read exactly as v3)
                                                  a direct-fire crew on fire-at-will, the nearest enemy in its line of sight
                                                  within 0.9 x its range, no shot this second and none for >= 3 s, for F_RUN_S
A MOMENT is one crew's consecutive flagged seconds of one class (a 1 s hole merges). The rates: moments a fight and flagged
crew-seconds a fight, per class, over every fight in the folder (and per map).
"""
import argparse
import glob
import json
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import features as F  # noqa: E402

RULE_VERSION = "classes v4 (2026-10-31; v3 + F, A-E unchanged)"
ORDER = ["A", "E", "C", "B", "D", "F"]
NAMES = {
    "A": "hurt crews retreat by abandoning the squad",
    "B": "squadmates jam each other: give-way loops",
    "C": "stuck on terrain / no path, never gives up",
    "D": "drives away from where it is going",
    "E": "shot from beyond its range, no answer",
    "F": "holds fire with an enemy in sight and in range",
}
OWNERS = {"A": "engage", "B": "manoeuvre", "C": "manoeuvre", "D": "orders", "E": "engage", "F": "engage"}

A_SPREAD_M = 40.0
A_FAR_S = 3
A_REVERSE_S = 5
E_HITS = 5
E_WINDOW_S = 8
E_CLOSE_M = 10.0
STUCK_S = 6
C_RUN_S = 8
B_RUN_S = 8
B_HOLD_S = 3
D_WRONGWAY_S = 5
D_FOLLOW_S = 3
D_SPIN_DPS = 40.0
F_RUN_S = 8

SLOW = F.SLOW_MPS
NOT_CREW = ("", "terrain", "no_path")
KEEP = ("s", "tick", "x", "z", "yaw", "speed", "hp", "order", "choice", "intent", "move", "phase", "blocked", "touch_what", "to_go",
        "gain_5", "route_off", "squad_d", "hit_dmg", "fire_far", "range", "shots", "near_enemy", "since_fire", "weap", "arc")


def _f(r, k, d=0.0):
    return F._f(r, k, d)


def _conditions(r, spin_dps):
    move = r.get("move") == "move_to"
    speed = _f(r, "speed")
    retreat = r.get("choice") == "RETREAT"
    has_goal = "to_go" in r and _f(r, "to_go") > F.FAR_M
    driving = move and r.get("phase") == "driving" and not retreat and has_goal
    blocked = r.get("blocked", "") or ""
    follow = r.get("order") == "follow"
    return {
        "a_far": retreat and int(r.get("squad_n", 0) or 0) > 1 and _f(r, "squad_d") >= A_SPREAD_M,
        "a_rev": retreat and move and speed < -SLOW,
        "stuck": move and has_goal and "gain_5" in r and _f(r, "gain_5") < F.PROGRESS_M,
        "c_ter": r.get("phase") == "blocked" and blocked in ("terrain", "no_path"),
        "c_wall": move and bool(r.get("touch")) and (r.get("touch_cause") or "") != "" and speed < SLOW,
        "b_crew": r.get("phase") in ("blocked", "yielding") and blocked not in NOT_CREW,
        "b_hold": r.get("order") == "hold" and r.get("phase") == "yielding",
        "d_away": driving and speed > SLOW and _f(r, "route_off") > F.WRONGWAY_DEG,
        "d_follow": follow and (speed < -SLOW or (abs(speed) < SLOW and spin_dps > D_SPIN_DPS)),
        "f_hold": (not r.get("arc")) and (r.get("weap") or "fire_at_will") == "fire_at_will"
        and 0.0 <= _f(r, "near_enemy", -1.0) <= 0.9 * _f(r, "range") and int(r.get("shots", 0) or 0) == 0
        and _f(r, "since_fire") >= F.HOLD_TICKS,
    }


NEED = {"a_far": A_FAR_S, "a_rev": A_REVERSE_S, "stuck": STUCK_S, "c_ter": C_RUN_S, "c_wall": C_RUN_S, "b_crew": B_RUN_S,
        "b_hold": B_HOLD_S, "d_away": D_WRONGWAY_S, "d_follow": D_FOLLOW_S, "f_hold": F_RUN_S}


def _stuck_cause(r):
    blocked = r.get("blocked", "") or ""
    if r.get("choice") == "RETREAT":
        return "A"
    if r.get("phase") in ("blocked", "yielding") and blocked not in NOT_CREW:
        return "B"
    if blocked in ("terrain", "no_path") or (bool(r.get("touch")) and (r.get("touch_cause") or "") != ""):
        return "C"
    return "D"


def _e_flag(window):
    """window: the last E_WINDOW_S seconds as fire_far of an outranged hit, else None."""
    hits = [d for d in window if d is not None]
    return len(hits) >= E_HITS and hits[0] - hits[-1] < E_CLOSE_M


def _class_of(runs, e_flag, r):
    """(class, the seconds of history that made it) for this second, or ("", 0)."""
    if runs["a_far"] >= A_FAR_S or runs["a_rev"] >= A_REVERSE_S:
        return "A", A_FAR_S if runs["a_far"] >= A_FAR_S else A_REVERSE_S
    if e_flag:
        return "E", E_WINDOW_S
    if runs["stuck"] >= STUCK_S:
        return _stuck_cause(r), STUCK_S
    if runs["c_ter"] >= C_RUN_S or runs["c_wall"] >= C_RUN_S:
        return "C", C_RUN_S
    if runs["b_crew"] >= B_RUN_S:
        return "B", B_RUN_S
    if runs["b_hold"] >= B_HOLD_S:
        return "B", B_HOLD_S
    if runs["d_away"] >= D_WRONGWAY_S:
        return "D", D_WRONGWAY_S
    if runs["d_follow"] >= D_FOLLOW_S:
        return "D", D_FOLLOW_S
    if runs["f_hold"] >= F_RUN_S:
        return "F", F_RUN_S
    return "", 0


def classify_fight(header, rows, fight=""):
    by_crew = defaultdict(list)
    for r in rows:
        by_crew[r["crew"]].append(r)
    at = {(r["crew"], r["tick"]): r for r in rows}  # the blocker's own row, the same tick (manoeuvre's B sub-cause, C48.3)
    found = []
    for crew, seq in by_crew.items():
        seq.sort(key=lambda r: r["tick"])
        runs = {k: 0 for k in NEED}
        window = []  # the last E_WINDOW_S seconds: the shooter's distance on an outranged hit, else None
        prev, cur = None, None
        for r in seq:
            if r.get("order") == "follow" and not r.get("follow_live"):
                r = {k: v for k, v in r.items() if k not in ("to_go", "gain_2", "gain_5", "route_off")}
            gap = prev is not None and r["tick"] - prev["tick"] > 1.5 * F.TICK_RATE
            spin = 0.0
            if prev is not None and not gap:
                spin = F._turn(_f(prev, "yaw"), _f(r, "yaw")) / max((r["tick"] - prev["tick"]) / F.TICK_RATE, 1e-6)
            for k, held in _conditions(r, spin).items():
                runs[k] = ((0 if gap else runs[k]) + 1) if held else 0
            if gap:
                window = []
            out = _f(r, "hit_dmg") > 0.0 and _f(r, "fire_far") > 1.05 * _f(r, "range")
            window = (window + [_f(r, "fire_far") if out else None])[-E_WINDOW_S:]
            cls, need = _class_of(runs, _e_flag(window), r)
            s = int(r["s"])
            if cur and ((cls and cls != cur["cls"]) or gap or s - cur["end_s"] > 2):
                found.append(_close(cur, header, fight))
                cur = None
            if cls:
                if cur is None:
                    cur = {"cls": cls, "crew": crew, "team": int(r.get("team", 0)), "unit": r.get("unit", ""),
                           "squad": r.get("squad", ""), "start_s": s, "run_start_s": s - need + 1, "end_s": s, "rows": []}
                cur["end_s"] = s
                kept = {k: r[k] for k in KEEP if k in r}
                other = at.get((r.get("blocked") or "", r["tick"]))
                if other is not None:
                    kept.update({"blocker_phase": other.get("phase", ""), "blocker_move": other.get("move", ""),
                                 "blocker_order": other.get("order", "")})
                cur["rows"].append(kept)
            prev = r
        if cur:
            found.append(_close(cur, header, fight))
    return found


F_CAUSES = ("support by fire", "ambush (holds fire on purpose)", "holding", "moving")


def f_cause(rows):
    """Class F by what the crew is doing (its intent / order, most seconds): a base of fire / support-by-fire crew whose job is
    to shoot; a spring ambush (holds fire by design: read it apart); any other HOLD; on the move."""
    def one(r):
        intent = r.get("intent") or ""
        if "support by fire" in intent:
            return F_CAUSES[0]
        if "ambush" in intent:
            return F_CAUSES[1]
        if r.get("order") == "hold" or r.get("choice") == "HOLD":
            return F_CAUSES[2]
        return F_CAUSES[3]
    return Counter(one(r) for r in rows).most_common(1)[0][0]


def e_cause(rows):
    """Engage's split of class E: 'answering' when most seconds' intent carries E10's outranged answer (closing by cover /
    breaking line of sight) and it still takes the hits; 'no answer' otherwise (holding, moving on, going round)."""
    answering = sum(1 for r in rows if "outranged" in (r.get("intent") or ""))
    return "answering" if answering * 2 > len(rows) else "no answer"


def b_cause(rows):
    """Manoeuvre's split of class B (round 48, M1): who is in the way.
    'held crew gives way'     the crew itself is on HOLD and yields (leaves its post)
    'parked blocker'          most seconds' blocker is itself yielding in place (move face) or on HOLD: giving way frees no room
    'moving squadmates'       anything else (two movers in each other's way)"""
    if sum(1 for r in rows if r.get("order") == "hold") * 2 > len(rows):
        return "held crew gives way"
    parked = sum(1 for r in rows if r.get("blocker_order") == "hold"
                 or (r.get("blocker_phase") == "yielding" and r.get("blocker_move") == "face"))
    named = sum(1 for r in rows if "blocker_phase" in r)
    return "parked blocker" if named and parked * 2 > named else "moving squadmates"


def _close(m, header, fight):
    arena, seed = header.get("arena", ""), int(header.get("seed", 0) or 0)
    from_s = max(0, m["run_start_s"] - 2)
    to_s = min(m["end_s"] + 2, from_s + 12)
    if m["cls"] == "B":
        m["b_cause"] = b_cause(m["rows"])
    if m["cls"] == "E":
        m["e_cause"] = e_cause(m["rows"])
    if m["cls"] == "F":
        m["f_cause"] = f_cause(m["rows"])
    m.update({"fight": fight, "arena": arena, "seed": seed, "crew_seconds": len(m["rows"]),
              "length_s": m["end_s"] - m["run_start_s"] + 1,
              "repro": f"make spotter-clip SPOT_SEED={seed} SPOT_ARENA={arena} SPOT_CREW={m['crew']} SPOT_FROM={from_s} SPOT_TO={to_s}"})
    return m


def rates(moments, fights, maps):
    out = {"fights": len(fights), "classes": {}, "by_map": {}}
    for cls in ORDER:
        ms = [m for m in moments if m["cls"] == cls]
        out["classes"][cls] = {"name": NAMES[cls], "owner": OWNERS[cls], "moments": len(ms),
                               "crew_seconds": sum(m["crew_seconds"] for m in ms),
                               "moments_per_fight": round(len(ms) / max(len(fights), 1), 3),
                               "crew_seconds_per_fight": round(sum(m["crew_seconds"] for m in ms) / max(len(fights), 1), 2)}
    bs = [m for m in moments if m["cls"] == "B"]
    out["classes"]["B"]["by_cause"] = {c: {"moments_per_fight": round(sum(1 for m in bs if m.get("b_cause") == c) / max(len(fights), 1), 3),
                                           "crew_seconds_per_fight": round(sum(m["crew_seconds"] for m in bs if m.get("b_cause") == c)
                                                                           / max(len(fights), 1), 2)}
                                       for c in ("held crew gives way", "parked blocker", "moving squadmates")}
    es = [m for m in moments if m["cls"] == "E"]
    out["classes"]["E"]["by_cause"] = {c: {"moments_per_fight": round(sum(1 for m in es if m.get("e_cause") == c) / max(len(fights), 1), 3),
                                           "crew_seconds_per_fight": round(sum(m["crew_seconds"] for m in es if m.get("e_cause") == c)
                                                                           / max(len(fights), 1), 2)}
                                       for c in ("no answer", "answering")}
    fs = [m for m in moments if m["cls"] == "F"]
    out["classes"]["F"]["by_cause"] = {c: {"moments_per_fight": round(sum(1 for m in fs if m.get("f_cause") == c) / max(len(fights), 1), 3),
                                           "crew_seconds_per_fight": round(sum(m["crew_seconds"] for m in fs if m.get("f_cause") == c)
                                                                           / max(len(fights), 1), 2)}
                                       for c in F_CAUSES}
    for arena in sorted(maps):
        nf = maps[arena]
        out["by_map"][arena] = {"fights": nf}
        for cls in ORDER:
            ms = [m for m in moments if m["cls"] == cls and m["arena"] == arena]
            out["by_map"][arena][cls] = {"moments_per_fight": round(len(ms) / nf, 3),
                                         "crew_seconds_per_fight": round(sum(m["crew_seconds"] for m in ms) / nf, 2)}
    return out


def per_fight(moments, fights):
    out = {f: {c: [0, 0] for c in ORDER} for f in fights}
    for m in moments:
        if m["fight"] in out:
            out[m["fight"]][m["cls"]][0] += 1
            out[m["fight"]][m["cls"]][1] += m["crew_seconds"]
    return out


def compare(before, after):
    """Paired by fight over the fights both have: per class, before / after moments a fight and the mean difference with its se."""
    common = sorted(set(before.get("per_fight", {})) & set(after.get("per_fight", {})))
    out = {"fights": len(common), "classes": {}}
    for cls in ORDER:
        rows = [(before["per_fight"][f].get(cls, [0, 0]), after["per_fight"][f].get(cls, [0, 0])) for f in common]
        res = {}
        for i, key in ((0, "moments"), (1, "crew_seconds")):
            d = [a[i] - b[i] for b, a in rows]
            n = len(d)
            mean = sum(d) / n if n else 0.0
            var = sum((x - mean) ** 2 for x in d) / (n - 1) if n > 1 else 0.0
            res[key] = {"before": round(sum(b[i] for b, _ in rows) / max(n, 1), 3), "after": round(sum(a[i] for _, a in rows) / max(n, 1), 3),
                        "diff": round(mean, 3), "se": round((var / n) ** 0.5, 3) if n else 0.0}
        out["classes"][cls] = res
    return out


def compare_md(cmp, before_label, after_label):
    lines = [f"\n## Paired v the before ({cmp['fights']} fights both ran; before = {before_label}, after = {after_label})\n",
             "| Class | moments / fight before | after | diff (se) | crew-s / fight before | after | diff (se) |",
             "|---|---|---|---|---|---|---|"]
    for cls in ORDER:
        m, c = cmp["classes"][cls]["moments"], cmp["classes"][cls]["crew_seconds"]
        lines.append(f"| {cls} {NAMES[cls]} | {m['before']:.2f} | {m['after']:.2f} | {m['diff']:+.2f} ({m['se']:.2f}) | "
                     f"{c['before']:.1f} | {c['after']:.1f} | {c['diff']:+.1f} ({c['se']:.1f}) |")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fight_dir", nargs="+")
    ap.add_argument("--before", default="", help="a before classes.json (with per_fight): add the paired read to classes.md")
    ap.add_argument("--out", default=None)
    ap.add_argument("--label", default="", help="the commit / machine stamp printed with every rate")
    args = ap.parse_args()
    out = args.out or args.fight_dir[0]
    os.makedirs(out, exist_ok=True)
    paths, seen = [], set()
    for d in args.fight_dir:  # one commit's fights may lie in several date folders: each arena-seed once, the first found
        for path in sorted(glob.glob(os.path.join(d, "*.jsonl.gz")) + glob.glob(os.path.join(d, "*.jsonl"))):
            name = os.path.basename(path).split(".jsonl")[0]
            if name not in seen:
                seen.add(name)
                paths.append(path)
    moments, fights, maps = [], [], defaultdict(int)
    for path in paths:
        header, rows = F.load_fight(path)
        if not header or not rows:
            continue
        name = os.path.basename(path)
        name = name[: name.index(".jsonl")]
        fights.append(name)
        maps[header.get("arena", "")] += 1
        moments.extend(classify_fight(header, rows, name))
    if not fights:
        sys.exit(f"classes: no fights in {' '.join(args.fight_dir)}")
    seeds = sorted({int(f.rsplit("-", 1)[1]) for f in fights if f.rsplit("-", 1)[-1].isdigit()})
    result = rates(moments, fights, maps)
    result.update({"rule": RULE_VERSION, "label": args.label, "seeds": f"{seeds[0]}-{seeds[-1]} ({len(seeds)})" if seeds else "",
                   "maps": sorted(maps), "per_fight": per_fight(moments, fights)})
    json.dump(result, open(os.path.join(out, "classes.json"), "w"), indent=1)
    for cls in ORDER:
        with open(os.path.join(out, f"class_{cls}.jsonl"), "w") as h:
            for m in sorted((m for m in moments if m["cls"] == cls), key=lambda m: -m["crew_seconds"]):
                h.write(json.dumps(m) + "\n")
    with open(os.path.join(out, "classes.md"), "w") as h:
        h.write(f"# Spotter class rates ({RULE_VERSION})\n\n{args.label}; {len(fights)} fights, seeds {result['seeds']}, "
                f"maps {' '.join(sorted(maps))}.\n\n| Class | Owner | moments / fight | flagged crew-s / fight | moments | crew-s |\n"
                "|---|---|---|---|---|---|\n")
        for cls in ORDER:
            c = result["classes"][cls]
            h.write(f"| {cls} {c['name']} | {c['owner']} | {c['moments_per_fight']:.2f} | {c['crew_seconds_per_fight']:.1f} | "
                    f"{c['moments']} | {c['crew_seconds']} |\n")
        h.write("\nClass B by cause (moments / fight, crew-s / fight): " + "; ".join(
            f"{c} {v['moments_per_fight']:.2f} / {v['crew_seconds_per_fight']:.1f}"
            for c, v in result["classes"]["B"]["by_cause"].items()) + "\n")
        h.write("Class E by cause: " + "; ".join(
            f"{c} {v['moments_per_fight']:.2f} / {v['crew_seconds_per_fight']:.1f}"
            for c, v in result["classes"]["E"]["by_cause"].items()) + "\n")
        h.write("Class F by cause: " + "; ".join(
            f"{c} {v['moments_per_fight']:.2f} / {v['crew_seconds_per_fight']:.1f}"
            for c, v in result["classes"]["F"]["by_cause"].items()) + "\n")
        h.write("\n## By map (moments / fight, crew-s / fight)\n\n| map | fights | " + " | ".join(ORDER) + " |\n|---|---|"
                + "---|" * len(ORDER) + "\n")
        for arena, d in result["by_map"].items():
            h.write(f"| {arena} | {d['fights']} | " + " | ".join(
                f"{d[c]['moments_per_fight']:.2f} / {d[c]['crew_seconds_per_fight']:.1f}" for c in ORDER) + " |\n")
        if args.before and os.path.exists(args.before):
            before = json.load(open(args.before))
            cmp = compare(before, result)
            result["paired"] = dict(cmp, before=before.get("label", ""))
            json.dump(result, open(os.path.join(out, "classes.json"), "w"), indent=1)
            h.write(compare_md(cmp, before.get("label", ""), args.label))
    print(open(os.path.join(out, "classes.md")).read())


if __name__ == "__main__":
    main()
