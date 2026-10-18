#!/usr/bin/env python3
"""R33.26: P3's line (2c) re-scoped, drift paired BY FACE, over manoeuvre-hull-rest's layout (`make planner-judge-face`,
both arms called): base_* = --planner-face-keep=0, new_* = --planner-face-keep=1, per mode (drawn, clicked), the
`face_episodes` of every run's last PLANNER_SEAM_REPORT (planner_seam.gd: one episode per crew at one home, with the
seam's outcome and the hull's own furthest from home over the episode, whoever drove it).

Within a paired run (faction, task, seed), episodes pair by crew and home (within 1 m), in order. Each pair is one of:
  FACE_PAIRS_BOTH       both arms planned it
  FACE_PAIRS_CAND_ONLY  only the candidate planned it (the base refused or abandoned every ask of it)
  FACE_PAIRS_BASE_ONLY  only the base planned it: REPORTED
  unmatched             an episode in one arm only (the runs diverged): counted
Every class reads the HULL's own furthest from home (hull_far), like for like; each plan's furthest (plan_far) is
reported beside it. A plan's furthest understates a face today serves after an abandon: the executor drives the hull
out and a re-ask plans the short remainder (the yard stage, laptop: base plan_far 1.4 m, hull_far 12.1 m).
Line per judged class and mode: candidate median <= base median + 1.645 se AND candidate p90 <= base p90 + 1.645 se, each
se a paired bootstrap over the faces (4000 rounds, seed 33). BOTH needs >= 10 faces a mode, or that mode's (2c) is
INCONCLUSIVE, which cannot pass (R33.26 as filed: a small class must not decide by going unjudged). CAND_ONLY with fewer
than 2 faces: NOT JUDGED (none: nothing to judge, reported). --distinct: a run pair whose episodes repeat another seed's in the same (faction, task) is read once
(hull_distinct.py, R33.23's rule). Usage: face_pairs.py <hull-rest dir> [--seeds "96 97 ..."] [--distinct]
"""
import json
import math
import pathlib
import random
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import hull_distinct  # noqa: E402

K = 1.645
BOTH_AT_LEAST = 10
HOME_M = 1.0


def last_report(log):
    last = None
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("PLANNER_SEAM_REPORT "):
            last = line
    return json.loads(last.split(" ", 1)[1]) if last else None


def runs(root, name, seeds):
    out = {}
    for log in sorted(pathlib.Path(root, name).glob("*/*/run.log")):
        task, seed = log.parent.name.rsplit("-", 1)
        if seeds and seed not in seeds:
            continue
        rep = last_report(log)
        if rep is not None:
            out[(log.parent.parent.name, task, seed)] = rep.get("face_episodes", [])
    return out


def _near(a, b):
    return a["name"] == b["name"] and math.hypot(a["home"][0] - b["home"][0], a["home"][1] - b["home"][1]) <= HOME_M


def classify(base, cand):
    out = {"both": [], "candidate_only": [], "base_only": [], "neither": [], "unmatched_base": [], "unmatched_candidate": []}
    left = list(cand)
    for b in base:
        match = next((c for c in left if _near(b, c)), None)
        if match is None:
            out["unmatched_base"].append(b)
            continue
        left.remove(match)
        key = {(True, True): "both", (False, True): "candidate_only", (True, False): "base_only",
               (False, False): "neither"}[(bool(b["served"]), bool(match["served"]))]
        out[key].append((b, match))
    out["unmatched_candidate"] = left
    return out


def p90(xs):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(math.ceil(0.9 * len(xs))) - 1)] if xs else float("nan")


def boot_se(pairs, stat, rounds=4000):
    rng = random.Random(33)
    diffs = []
    for _ in range(rounds):
        draw = rng.choices(pairs, k=len(pairs))
        diffs.append(stat([c for _, c in draw]) - stat([b for b, _ in draw]))
    return statistics.pstdev(diffs)


def judge(label, mode, pairs, note):
    """pairs: [(base value, candidate value)]. Prints one line; returns True / False / None (not judged)."""
    if len(pairs) < 2:
        print(f"{label} {mode} | faces {len(pairs)} | NOT JUDGED (fewer than 2){note}")
        return None if not pairs else False
    b, c = [x for x, _ in pairs], [y for _, y in pairs]
    se_med, se_p90 = boot_se(pairs, statistics.median), boot_se(pairs, p90)
    med_ok = statistics.median(c) <= statistics.median(b) + K * se_med
    p90_ok = p90(c) <= p90(b) + K * se_p90
    print(f"{label} {mode} | faces {len(pairs)} | median {statistics.median(c):.1f} v {statistics.median(b):.1f} m "
          f"(se {se_med:.2f}, line <= {statistics.median(b) + K * se_med:.1f}) {'ok' if med_ok else 'over'} | p90 "
          f"{p90(c):.1f} v {p90(b):.1f} (se {se_p90:.2f}, line <= {p90(b) + K * se_p90:.1f}) {'ok' if p90_ok else 'over'} | "
          f"max {max(c):.1f} v {max(b):.1f}{note} | {'PASS' if med_ok and p90_ok else 'FAIL'}")
    return med_ok and p90_ok


def main(argv):
    root = argv[0]
    seeds = set(argv[argv.index("--seeds") + 1].split()) if "--seeds" in argv else set()
    ok = True
    for mode in ("drawn", "clicked"):
        rb, rc = runs(root, f"base_{mode}", seeds), runs(root, f"new_{mode}", seeds)
        keys = sorted(set(rb) & set(rc))
        if not keys:
            print(f"FACE_PAIRS {mode} | NOT JUDGED: no paired runs (base {len(rb)}, candidate {len(rc)})")
            ok = False
            continue
        if "--distinct" in argv:
            keys, cells = hull_distinct.distinct_keys(rb, rc, keys)
            for line in hull_distinct.summary({(mode,) + c: v for c, v in cells.items()}, "FACE_PAIRS_DISTINCT"):
                print(line)
        totals = {k: [] for k in ("both", "candidate_only", "base_only", "neither", "unmatched_base", "unmatched_candidate")}
        for key in keys:
            for cls, items in classify(rb[key], rc[key]).items():
                totals[cls] += items
        both = [(b["hull_far"], c["hull_far"]) for b, c in totals["both"]]
        only = [(b["hull_far"], c["hull_far"]) for b, c in totals["candidate_only"]]
        kept_only = sum(1 for _, c in totals["candidate_only"] if c.get("kept"))
        plan = lambda cls, side: statistics.median([pair[side]["plan_far"] for pair in totals[cls]]) if totals[cls] else 0.0
        if len(both) < BOTH_AT_LEAST:
            print(f"FACE_PAIRS_BOTH {mode} | faces {len(both)} | INCONCLUSIVE (fewer than {BOTH_AT_LEAST} faces both planned):"
                  f" this mode's (2c) cannot pass")
            r_both = False
        else:
            r_both = judge("FACE_PAIRS_BOTH", mode, both,
                           f" | hull_far (plan_far median {plan('both', 1):.1f} v {plan('both', 0):.1f})")
        r_only = judge("FACE_PAIRS_CAND_ONLY", mode, only,
                       f" | hull_far (candidate plan_far median {plan('candidate_only', 1):.1f}; kept {kept_only})")
        ok = ok and r_both is not False and r_only is not False
        base_only = totals["base_only"]
        print(f"FACE_PAIRS_BASE_ONLY {mode} | faces {len(base_only)} | hull_far candidate {[c['hull_far'] for _, c in base_only]}"
              f" v base {[b['hull_far'] for b, _ in base_only]} (base plan_far {[b['plan_far'] for b, _ in base_only]}) | reported")
        print(f"FACE_PAIRS_OTHER {mode} | neither served {len(totals['neither'])} | unmatched base {len(totals['unmatched_base'])}"
              f" candidate {len(totals['unmatched_candidate'])} | reported")
    print(f"FACE_PAIRS line (2c): {'ALL PASS' if ok else 'NOT ALL PASS'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
