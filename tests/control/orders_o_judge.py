#!/usr/bin/env python3
"""Round 47 (orders O2): Bar O's verdict, as filed in workstreams.md *Bars (round 47)*.

    python3 tests/control/orders_o_judge.py <bar dir> <off arm> <on arm>

Reads <dir>/{merged,his_x,his_l,identity}/{runs,rows}.jsonl (tests/control/orders_o_bar.sh). Pairs runs by (map, squads,
route, seed). Prints one line per bar line, then VERDICT PASS / FAIL. `--self-test` stages the lines that must fail
(lesson 350: each deciding line fails once on a case it must catch) and exits non-zero if any does not.
"""
import json
import statistics
import sys


def load(path):
    try:
        return [json.loads(line) for line in open(path) if line.strip()]
    except FileNotFoundError:
        return []


def key(r):
    return (r["map"], r["squads"], r.get("route", "click"), r["seed"])


def paired(runs, off, on):
    a = {key(r): r for r in runs if r.get("arm") == off}
    b = {key(r): r for r in runs if r.get("arm") == on}
    return [(a[k], b[k]) for k in sorted(a) if k in b]


def wedged(rows, arm):
    out = {}
    for r in rows:
        if r.get("arm") == arm:
            out[key(r)] = out.get(key(r), 0.0) + float(r.get("wedged_s", 0.0))
    return out


def med(xs):
    return statistics.median(xs) if xs else float("nan")


def judge(parts, off, on, out=print, identity=True):
    ok = True

    def line(name, passed, text):
        nonlocal ok
        ok = ok and passed
        out("%-4s %-5s %s" % (name, "PASS" if passed else "FAIL", text))

    merged_runs, merged_rows = parts["merged"]
    pairs = paired(merged_runs, off, on)
    spread_off = [p[0]["spread_m"] for p in pairs if p[0]["spread_m"] >= 0 and p[1]["spread_m"] >= 0]
    spread_on = [p[1]["spread_m"] for p in pairs if p[0]["spread_m"] >= 0 and p[1]["spread_m"] >= 0]
    line("D1", bool(spread_on) and med(spread_on) <= 0.6 * med(spread_off),
         "spread between squads' spots, one merged click: median ON %.1f m v OFF %.1f m (<= 0.6 x OFF), n %d pairs" % (
             med(spread_on), med(spread_off), len(spread_on)))
    laid = [p for p in pairs if p[1].get("merged_laid", 0) > 0]
    near = [p for p in laid if 0 <= p[1]["spread_m"] <= 25.0]
    line("D1b", bool(laid) and len(near) >= 0.9 * len(laid),
         "clicks laid as files with spread <= 25 m: %d of %d (>= 90 %%); refused by the ground: %d of %d" % (
             len(near), len(laid), len(pairs) - len(laid), len(pairs)))
    both = [(a["all_in_s"], b["all_in_s"]) for a, b in pairs if a["all_in_s"] >= 0 and b["all_in_s"] >= 0]
    mean_d = statistics.mean([b - a for a, b in both]) if both else float("nan")
    line("D2", bool(both) and mean_d <= 0.5,
         "all-in sooner or same: paired mean ON - OFF %+.2f s (<= +0.5 s, a tie is not a loss), n %d" % (mean_d, len(both)))
    never_off = sum(1 for a, _ in pairs if a["all_in_s"] < 0)
    never_on = sum(1 for _, b in pairs if b["all_in_s"] < 0)
    line("D2b", never_on <= never_off, "never all in: ON %d v OFF %d (<= OFF)" % (never_on, never_off))
    c_off = statistics.mean([a.get("friend_contacts", 0) for a, _ in pairs]) if pairs else 0.0
    c_on = statistics.mean([b.get("friend_contacts", 0) for _, b in pairs]) if pairs else 0.0
    line("G1", c_on <= c_off * 1.25 + 5, "friendly contacts a run: ON %.1f v OFF %.1f (<= OFF x 1.25 + 5)" % (c_on, c_off))
    w_off, w_on = wedged(merged_rows, off), wedged(merged_rows, on)
    ks = [k for k in w_off if k in w_on]
    wo = statistics.mean([w_off[k] for k in ks]) if ks else 0.0
    wn = statistics.mean([w_on[k] for k in ks]) if ks else 0.0
    line("G2", wn <= wo * 1.25 + 5, "wedged crew-s a run: ON %.1f v OFF %.1f (<= OFF x 1.25 + 5)" % (wn, wo))
    across_off = sum(1 for r in merged_rows if r.get("arm") == off and (r.get("veto_across") or r.get("veto_fail")))
    across_on = sum(1 for r in merged_rows if r.get("arm") == on and (r.get("veto_across") or r.get("veto_fail")))
    crossed_off = sum(int(a.get("crossed", 0)) for a, _ in pairs)
    crossed_on = sum(int(b.get("crossed", 0)) for _, b in pairs)
    line("G3", across_on <= across_off and crossed_on <= crossed_off,
         "the veto's lines: places across a gap / sent back ON %d v OFF %d; squads over a deck ON %d v OFF %d (<= OFF)" % (
             across_on, across_off, crossed_on, crossed_off))
    id_runs, id_rows = parts["identity"]
    if not identity:
        id_rows = []
    places = {}
    for r in id_rows:
        places.setdefault(r.get("arm"), {})[key(r) + (r["squad"],)] = r.get("anchor")
    a, b = places.get(off, {}), places.get(on, {})
    common = [k for k in a if k in b]
    differ = [k for k in common if a[k] != b[k]]
    if identity:
        line("G4", bool(common) and not differ,
             "an unmerged click is byte-identical: %d of %d places differ (0); runs %d" % (len(differ), len(common), len(id_runs)))
    else:
        out("G4   n/a   the `all` arm changes unmerged clicks by design (R47.15)")
    off_far = [a["worst_offset_m"] for a, _ in pairs]
    on_far = [b["worst_offset_m"] for _, b in pairs]
    line("G5", med(on_far) <= med(off_far), "farthest spot from his click: median ON %.1f m v OFF %.1f m (<= OFF)" % (
        med(on_far), med(off_far)))
    for name in ("his_x", "his_l"):
        runs, _ = parts[name]
        hp = paired(runs, off, on)
        if hp:
            out("his  %-5s %s: spread median ON %.1f v OFF %.1f m; all-in median ON %.1f v OFF %.1f s; n %d" % (
                "READ", name, med([q["spread_m"] for _, q in hp]), med([p["spread_m"] for p, _ in hp]),
                med([q["all_in_s"] for _, q in hp]), med([p["all_in_s"] for p, _ in hp]), len(hp)))
    out("VERDICT %s" % ("PASS" if ok else "FAIL"))
    return ok


def read(bar):
    return {name: (load("%s/%s/runs.jsonl" % (bar, name)), load("%s/%s/rows.jsonl" % (bar, name)))
            for name in ("merged", "his_x", "his_l", "identity")}


def self_test():
    """Each deciding line FAILS on a staged case (lesson 350)."""
    def run(map_, arm, spread, all_in, laid=1):
        return {"map": map_, "squads": 2, "route": "click", "seed": 1, "arm": arm, "spread_m": spread, "all_in_s": all_in,
                "merged_laid": laid, "friend_contacts": 0, "crossed": 0, "worst_offset_m": 10.0}

    def row(arm, anchor):
        return {"map": "locks", "squads": 2, "route": "click", "seed": 1, "arm": arm, "squad": 1, "anchor": anchor, "wedged_s": 0}

    good = {"merged": ([run("locks", "off", 40, 20), run("locks", "on", 15, 20)], [row("off", [0, 0]), row("on", [0, 0])]),
            "identity": ([run("locks", "off", 0, 1)], [row("off", [1, 1]), row("on", [1, 1])]), "his_x": ([], []), "his_l": ([], [])}
    failures = []
    quiet = lambda *_: None
    if not judge(good, "off", "on", quiet):
        failures.append("the staged good case fails")
    staged = {
        "D1 (no closer)": {**good, "merged": ([run("locks", "off", 40, 20), run("locks", "on", 39, 20)], good["merged"][1])},
        "D2 (later)": {**good, "merged": ([run("locks", "off", 40, 20), run("locks", "on", 15, 22)], good["merged"][1])},
        "D2b (never in)": {**good, "merged": ([run("locks", "off", 40, 20), run("locks", "on", 15, -1)], good["merged"][1])},
        "G4 (a place moved)": {**good, "identity": (good["identity"][0], [row("off", [1, 1]), row("on", [1, 2])])},
    }
    for name, parts in staged.items():
        if judge(parts, "off", "on", quiet):
            failures.append("%s passed a case it must fail" % name)
    print("SELF_TEST %s%s" % ("PASS" if not failures else "FAIL: ", "; ".join(failures)))
    return not failures


if __name__ == "__main__":
    if sys.argv[1] == "--all":
        # R47.15: the `all` arm, deciding on D1-D2b and G1-G3, G5 (G4 is the merged arm's: `all` changes unmerged clicks).
        bar = sys.argv[2]
        parts = {"merged": (load("%s/all/runs.jsonl" % bar), load("%s/all/rows.jsonl" % bar)),
                 "identity": ([], []), "his_x": ([], []),
                 "his_l": (load("%s/his_l_all/runs.jsonl" % bar), load("%s/his_l_all/rows.jsonl" % bar))}
        sys.exit(0 if judge(parts, sys.argv[3], sys.argv[4], identity=False) else 1)
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(0 if self_test() else 1)
    sys.exit(0 if judge(read(sys.argv[1]), sys.argv[2], sys.argv[3]) else 1)
