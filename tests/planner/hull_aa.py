#!/usr/bin/env python3
"""Round 33 (planner P1, C33.6 (a)): the hull-rest gang arm's A/A, sized per class (judging.md S5 step 1).

Two arms of manoeuvre-hull-rest's layout that ran the SAME flags on the SAME seeds (`make planner-aa-queue`: base_* and
new_* both `--planner-queue=fifo`). hull-rest is not run-to-run deterministic, so every difference between them is the
probe's own noise: what a line written on new v base must clear when nothing changed.

Per run (arm, faction, task, seed) and hull class (and ALL), from screen.json and run.log:
  moving     crews not still when the screen judges (round 31 (d)'s line (3c))
  rest_med   median hull error (deg) of the crews at rest (line (3a)'s statistic, read per run)
  settle     settled_after_s, 75 when never (line (3b); runs whose squads hold a wheeled turreted hull)
  asks / abandoned   the seam's last PLANNER_SEAM_REPORT (line (1): abandoned share of asks)
Paired on (mode, faction, task, seed) where mode = drawn | clicked. Prints:
  HULL_AA_CELL   mode task class metric | n | base new | mean diff | sd a run | se of the sum | sd_boot of the median diff
  HULL_AA_POOLED mode class metric | the sd pooled over the six tasks (the row judging.md files) | n runs
  HULL_AA_NULL   round 32's lines read on the null: line (3a)'s crew-pooled permutation p per task x class (how many
                 cells a do-nothing change fails at p < 0.05), (3b)'s settle median paired diff v +6 s, (3c)'s moving
                 diff v round 32's base + 1.645 se, (1)'s abandoned share v 5 %
  HULL_AA_ROW {json} one per pooled row, for the orchestrator's tools/judge/probes.py at the close
  HULL_PAIR  (with --verdict) round 33 P2's pooled guard lines: per mode, the paired diff over every (task, seed) of
             rest_med (mean), settle (mean, drawn) and moving (sum), its own se, the line at +K se and PASS / FAIL;
             the abandoned share per mode with a one-sided Fisher p (candidate below base) and the <= 5 % line.
Optional --rows OUT.jsonl writes every per-run row. Usage: hull_aa.py DIR [--base base] [--new new] [--rows OUT]
Report only: exits 0 whenever it read something.
"""
import argparse
import json
import math
import pathlib
import random
import statistics
import sys

FOCUS = "wheels/turret"
WINDOW_S = 75.0


def last_report(log):
    found = None
    try:
        with open(log, errors="replace") as handle:
            for line in handle:
                if line.startswith("PLANNER_SEAM_REPORT "):
                    found = line[len("PLANNER_SEAM_REPORT "):]
    except OSError:
        return None
    if found is None:
        return None
    try:
        return json.loads(found)
    except json.JSONDecodeError:
        return None


def read_arm(root, prefix):
    """{(mode, faction, task, seed): {"classes": {class: {moving, rest[]}}, "settle", "asks", "abandoned"}}"""
    out = {}
    crews = {}  # (mode, task, class) -> [hull errors]: line (3a) pools crews
    for mode in ("drawn", "clicked"):
        arm = f"{prefix}_{mode}"
        for path in sorted(pathlib.Path(root, arm).glob("*/*/screen.json")):
            faction, case = path.parts[-3], path.parts[-2]
            seed = case.rsplit("-", 1)[-1]
            rep = last_report(path.parent / "run.log") or {}
            for row in json.loads(path.read_text()):
                if "squads" not in row:
                    continue
                task = row["scenario"]
                rec = {"classes": {}, "settle": None, "asks": int(rep.get("requests", 0)),
                       "abandoned": int(rep.get("abandoned", 0))}
                has_focus = False
                for squad in row["squads"]:
                    for crew in squad.get("each", []):
                        still = crew.get("still", True)
                        has_focus = has_focus or crew["class"] == FOCUS
                        for klass in (crew["class"], "ALL"):
                            c = rec["classes"].setdefault(klass, {"moving": 0, "rest": []})
                            if still:
                                c["rest"].append(crew["hull_error_deg"])
                            else:
                                c["moving"] += 1
                            crews.setdefault((mode, task, klass), []).append(crew["hull_error_deg"])
                if has_focus:
                    s = float(row.get("settled_after_s", -1.0))
                    rec["settle"] = WINDOW_S if s < 0 else s
                out[(mode, faction, task, seed)] = rec
    return out, crews


def perm_p(a, b, rounds=4000):
    if not a or not b:
        return float("nan")
    seen = abs(statistics.median(a) - statistics.median(b))
    pool = a + b
    rng = random.Random(28)
    hits = 0
    for _ in range(rounds):
        rng.shuffle(pool)
        if abs(statistics.median(pool[:len(a)]) - statistics.median(pool[len(a):])) >= seen - 1e-9:
            hits += 1
    return (hits + 1) / (rounds + 1)


def boot_median_sd(diffs, rounds=2000):
    if len(diffs) < 2:
        return float("nan")
    rng = random.Random(33)
    meds = [statistics.median(rng.choices(diffs, k=len(diffs))) for _ in range(rounds)]
    return statistics.stdev(meds)


def metric(rec, klass, name):
    if name in ("settle", "asks", "abandoned"):
        return rec[name]
    c = rec["classes"].get(klass)
    if c is None:
        return None
    if name == "moving":
        return c["moving"]
    return statistics.median(c["rest"]) if c["rest"] else None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default="build/manoeuvre/hull-rest")
    ap.add_argument("--base", default="base")
    ap.add_argument("--new", default="new")
    ap.add_argument("--rows")
    ap.add_argument("--verdict", action="store_true", help="print P2's pooled lines (HULL_PAIR)")
    ap.add_argument("--k", type=float, default=1.645)
    args = ap.parse_args(argv)
    base, base_crews = read_arm(args.root, args.base)
    new, new_crews = read_arm(args.root, args.new)
    keys = sorted(set(base) & set(new))
    if not keys:
        print(f"HULL_AA no paired runs under {args.root} ({len(base)} base, {len(new)} new)")
        return 1
    print(f"HULL_AA paired runs {len(keys)} (base {len(base)}, new {len(new)}) under {args.root}")
    if args.rows:
        with open(args.rows, "w") as fh:
            for k in keys:
                for arm, recs in (("base", base), ("new", new)):
                    r = recs[k]
                    fh.write(json.dumps({"arm": arm, "mode": k[0], "faction": k[1], "task": k[2], "seed": int(k[3]),
                                         "settle": r["settle"], "asks": r["asks"], "abandoned": r["abandoned"],
                                         "classes": {c: {"moving": v["moving"], "rest": v["rest"]}
                                                     for c, v in r["classes"].items()}}) + "\n")
    classes = sorted({c for k in keys for c in base[k]["classes"]} | {"ALL"})
    tasks = sorted({k[2] for k in keys})
    pooled = {}  # (mode, class, metric) -> [(n, var)]
    print("HULL_AA_CELL mode task class metric | n | base new (median) | mean diff | sd a run | se sum | sd_boot med diff")
    for mode in ("drawn", "clicked"):
        for task in tasks:
            for klass in classes:
                for name in ("moving", "rest_med", "settle"):
                    if name == "settle" and klass != "ALL":
                        continue
                    pairs = []
                    for k in keys:
                        if k[0] != mode or k[2] != task:
                            continue
                        a, b = metric(base[k], klass, name), metric(new[k], klass, name)
                        if a is not None and b is not None:
                            pairs.append((a, b))
                    if len(pairs) < 2:
                        continue
                    diffs = [b - a for a, b in pairs]
                    sd = statistics.stdev(diffs)
                    pooled.setdefault((mode, klass, name), []).append((len(diffs), sd * sd, statistics.median(a for a, _ in pairs)))
                    print(f"HULL_AA_CELL {mode} {task} {klass} {name} | {len(diffs)} | "
                          f"{statistics.median(a for a, _ in pairs):.1f} {statistics.median(b for _, b in pairs):.1f} | "
                          f"{statistics.mean(diffs):+.2f} | {sd:.2f} | {sd * math.sqrt(len(diffs)):.1f} | "
                          f"{boot_median_sd(diffs):.2f}")
    print("HULL_AA_POOLED mode class metric | pooled sd a run | runs | se of a task's sum at 6 runs | MDE (2.49 se) at 6")
    for (mode, klass, name), cells in sorted(pooled.items()):
        dof = sum(n - 1 for n, _, _ in cells)
        var = sum((n - 1) * v for n, v, _ in cells) / dof if dof else float("nan")
        sd = math.sqrt(var)
        runs = sum(n for n, _, _ in cells)
        base_level = statistics.median(m for _, _, m in cells)
        print(f"HULL_AA_POOLED {mode} {klass} {name} | {sd:.2f} | {runs} | {sd * math.sqrt(6):.1f} | {2.49 * sd * math.sqrt(6):.1f}")
        print("HULL_AA_ROW " + json.dumps({"probe": "hull-rest gang arm (queue A/A)", "mode": mode, "class": klass,
                                           "metric": name, "sd_run": round(sd, 3), "base_task_median": base_level,
                                           "runs": runs, "tasks": len(cells)}, sort_keys=True))
    # Round 32's lines read on the null.
    print("HULL_AA_NULL (3a) crew-pooled permutation p, new v base, per mode x task x class (p < 0.05 = a null fails the line)")
    fails = total = 0
    for mode in ("drawn", "clicked"):
        for task in tasks:
            for klass in classes:
                a, b = base_crews.get((mode, task, klass), []), new_crews.get((mode, task, klass), [])
                if not a or not b:
                    continue
                p = perm_p(b, a)
                total += 1
                fails += p < 0.05
                print(f"HULL_AA_NULL 3a {mode} {task} {klass} | n {len(b)}/{len(a)} | medians {statistics.median(b):.1f} "
                      f"v {statistics.median(a):.1f} | p {p:.3f}{'  FAIL' if p < 0.05 else ''}")
    print(f"HULL_AA_NULL 3a cells failing at p < 0.05: {fails} of {total}")
    for task in tasks:
        d = [new[k]["settle"] - base[k]["settle"] for k in keys if k[0] == "drawn" and k[2] == task
             and new[k]["settle"] is not None and base[k]["settle"] is not None]
        if d:
            med = statistics.median(d)
            print(f"HULL_AA_NULL 3b settle {task} | n {len(d)} | median paired diff {med:+.1f} s{'  FAIL (> +6)' if med > 6 else ''}")
        for klass in classes:
            m = [(metric(base[k], klass, "moving"), metric(new[k], klass, "moving")) for k in keys
                 if k[0] == "drawn" and k[2] == task]
            m = [(a, b) for a, b in m if a is not None and b is not None]
            if len(m) >= 2:
                diffs = [b - a for a, b in m]
                se = statistics.stdev(diffs) * math.sqrt(len(diffs))
                print(f"HULL_AA_NULL 3c moving {task} {klass} | new {sum(b for _, b in m)} v base {sum(a for a, _ in m)} "
                      f"| diff {sum(diffs):+d} | own se {se:.1f}")
    for mode in ("drawn", "clicked"):
        for arm, recs in (("base", base), ("new", new)):
            asks = sum(recs[k]["asks"] for k in keys if k[0] == mode)
            ab = sum(recs[k]["abandoned"] for k in keys if k[0] == mode)
            print(f"HULL_AA_NULL 1 abandoned {mode} {arm} | {ab}/{asks} = {100.0 * ab / asks if asks else 0:.1f} %")
    if args.verdict:
        verdict(base, new, keys, args.k)
    return 0


def fisher_less(a_hit, a_n, b_hit, b_n):
    """One-sided Fisher exact p that the first arm's rate is below the second's (hypergeometric lower tail)."""
    total, hits = a_n + b_n, a_hit + b_hit
    def pmf(k):
        return math.comb(hits, k) * math.comb(total - hits, a_n - k) / math.comb(total, a_n)
    lo = max(0, a_n - (total - hits))
    return min(1.0, sum(pmf(k) for k in range(lo, a_hit + 1)))


def verdict(base, new, keys, k):
    print(f"HULL_PAIR the pooled lines (round 33 P2's bar), k {k}: candidate = new, base = base")
    ok = True
    for mode in ("drawn", "clicked"):
        mk = [x for x in keys if x[0] == mode]
        for name, form in (("rest_med", "mean"), ("settle", "mean"), ("moving", "sum")):
            if name == "settle" and mode != "drawn":
                continue
            diffs = []
            for x in mk:
                a, b = metric(base[x], "ALL", name), metric(new[x], "ALL", name)
                if a is not None and b is not None:
                    diffs.append(b - a)
            if len(diffs) < 2:
                print(f"HULL_PAIR {mode} {name}: too few pairs ({len(diffs)})")
                ok = False
                continue
            sd = statistics.stdev(diffs)
            if form == "sum":
                stat, se = sum(diffs), sd * math.sqrt(len(diffs))
            else:
                stat, se = statistics.mean(diffs), sd / math.sqrt(len(diffs))
            line = k * se
            passed = stat <= line
            ok = ok and passed
            extra = ""
            if name == "settle":
                extra = f" | never settled new {sum(1 for x in mk if new[x]['settle'] == WINDOW_S)} v base {sum(1 for x in mk if base[x]['settle'] == WINDOW_S)}"
            print(f"HULL_PAIR {mode} {name} ({form}) | n {len(diffs)} | diff {stat:+.2f} | se {se:.2f} | line <= {line:+.2f} | "
                  f"MDE {2.49 * se:.2f} | {'PASS' if passed else 'FAIL'}{extra}")
        ab_n = sum(new[x]["asks"] for x in mk)
        ab = sum(new[x]["abandoned"] for x in mk)
        bb_n = sum(base[x]["asks"] for x in mk)
        bb = sum(base[x]["abandoned"] for x in mk)
        share = ab / ab_n if ab_n else 0.0
        p = fisher_less(ab, ab_n, bb, bb_n) if ab_n and bb_n else float("nan")
        passed = share <= 0.05 and p <= 0.05
        ok = ok and passed
        print(f"HULL_PAIR {mode} abandoned | new {ab}/{ab_n} = {100 * share:.1f} % v base {bb}/{bb_n} = "
              f"{100 * bb / bb_n if bb_n else 0:.1f} % | Fisher one-sided p {p:.4f} | line <= 5 % and p <= 0.05 | {'PASS' if passed else 'FAIL'}")
    print(f"HULL_PAIR lines (1) and (3): {'ALL PASS' if ok else 'NOT ALL PASS'} (line (2), the hold, is queue_table.py's)")


if __name__ == "__main__":
    sys.exit(main())
