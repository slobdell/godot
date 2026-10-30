#!/usr/bin/env python3
"""Round 46 (camera C4): Bar C1's verdict from its series (~/camera-r46/barc1/<arm>-<workload>/, CameraPlaytest traces).

Every line as filed in workstreams.md *Bars (round 46)*, BASE (today's camera) v ARM (--camera-planner=on), each printed with
both numbers and PASS / FAIL; then `VERDICT Bar C1: PASS|FAIL`.

    python3 tests/camera/bar_c1.py ~/camera-r46/barc1 [--budget-ms MEAN P99]   (the laptop's G8 numbers, measured apart)
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camera_report as cr  # noqa: E402

ATTACK = ["attack-terminus", "attack-locks", "attack-crossing", "attack-gorge"]
SEL_NEVER_S = cr.SEL_NEVER_S


def runs(root, arm, workloads):
    out = []
    for wl in workloads:
        out += cr.load(os.path.join(root, f"{arm}-{wl}"))
    return out


def looks(rs):
    return [r["look"] for r in rs if "look" in r]


def c1(rs):
    ls = looks(rs)
    play = sum(l["play_s"] for l in ls) or 1e-6
    lat = [x if x is not None else SEL_NEVER_S for l in ls for x in l.get("sel_latencies", [])]
    lat = [min(x, SEL_NEVER_S) for x in lat]
    hits = sum(l.get("hits", 0) for l in ls)
    return {"play": play, "hidden": sum(l.get("sel_hidden_s", 0.0) for l in ls), "none": sum(l.get("sel_none_s", 0.0) for l in ls),
            "lat_mean": sum(lat) / len(lat) if lat else 0.0, "lat_p90": cr.quantile(lat, 0.9) if lat else 0.0, "n_sel": len(lat),
            "hits": hits, "hits_off_pct": 100.0 * sum(l.get("hits_off", 0) for l in ls) / max(hits, 1)}


def lane(rs, name):
    return [r for r in rs if r.get("lane") == name]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--budget-ms", nargs=2, type=float, default=None)
    a = ap.parse_args()
    lines = []

    def judge(name, base, arm, ok, fmt="%.2f"):
        lines.append(ok)
        print(f"{'PASS' if ok else 'FAIL'}  {name}: BASE {fmt % base} v ARM {fmt % arm}" if not isinstance(base, str)
              else f"{'PASS' if ok else 'FAIL'}  {name}: BASE {base} v ARM {arm}")

    b_att, a_att = runs(a.root, "base", ATTACK), runs(a.root, "planner", ATTACK)
    print(f"ATTACK runs: BASE {len(b_att)} v ARM {len(a_att)}")
    b, r = c1(b_att), c1(a_att)
    judge("D1 driving with half+ of his shown selection hidden by a building, s (ARM <= 0.6 x BASE)", b["hidden"], r["hidden"],
          r["hidden"] <= 0.6 * b["hidden"], "%.1f")
    judge("D2 none of his selection on screen, s (ARM <= BASE)", b["none"], r["none"], r["none"] <= b["none"], "%.1f")
    judge("D3a new selection -> half on screen, mean s (ARM <= BASE + 0.5)", b["lat_mean"], r["lat_mean"], r["lat_mean"] <= b["lat_mean"] + 0.5)
    judge("D3b new selection -> half on screen, ARM p90 <= 1.5 s", b["lat_p90"], r["lat_p90"], r["lat_p90"] <= 1.5)
    judge("D4 hits on his units off screen, % of hits (ARM <= BASE + 1)", b["hits_off_pct"], r["hits_off_pct"],
          r["hits_off_pct"] <= b["hits_off_pct"] + 1.0, "%.1f")

    tb, ta = cr.table(b_att), cr.table(a_att)
    allb, alla = tb["rows"]["all"], ta["rows"]["all"]
    judge("G1a jerks ('all') per min (ARM <= BASE + 1)", allb["per_min"], alla["per_min"], alla["per_min"] <= allb["per_min"] + 1.0)
    snaps_arm = sum(row["snaps"] for wl in ATTACK + ["ambush", "retreat"] for row in
                    [cr.table(runs(a.root, "planner", [wl]))["rows"]["all"]] if runs(a.root, "planner", [wl]))
    judge("G1b snaps ('all'), ARM every workload = 0", 0, snaps_arm, snaps_arm == 0, "%d")
    worst = max(((s, row["per_min"]) for s, row in ta["rows"].items() if s not in ("all", "player", "jump", "follow", "select")),
                key=lambda x: x[1], default=("-", 0.0))
    judge("G1c no automatic source over 1.5 jerks/min (ARM; 'select' reported)", "-", "%s %.2f (select %.2f)" % (
        worst[0], worst[1], ta["rows"].get("select", {}).get("per_min", 0.0)), worst[1] <= 1.5)
    hit_pct = lambda t: 100.0 * t["slip"]["hit"] / max(t["slip"]["attacks"], 1)
    judge("G2a clicks on the aimed unit % (ARM >= 70)", hit_pct(tb), hit_pct(ta), hit_pct(ta) >= 70.0, "%.1f")
    judge("G2b slip p95 px (ARM <= 40)", tb["slip"]["p95"], ta["slip"]["p95"], ta["slip"]["p95"] <= 40.0, "%.1f")
    judge("G2c held % (ARM <= 25)", tb["play"]["held_pct"], ta["play"]["held_pct"], ta["play"]["held_pct"] <= 25.0, "%.1f")
    judge("G3 action share % (ARM >= BASE - 10)", tb["play"]["action_pct"], ta["play"]["action_pct"],
          ta["play"]["action_pct"] >= tb["play"]["action_pct"] - 10.0, "%.1f")
    inside_b = sum(l.get("inside_s", 0.0) for l in looks(b_att)) / max(len(b_att), 1)
    inside_a = sum(l.get("inside_s", 0.0) for l in looks(a_att)) / max(len(a_att), 1)
    judge("G6 camera inside a solid, s per run (ARM <= BASE + 1)", inside_b, inside_a, inside_a <= inside_b + 1.0)
    for wl in ATTACK + ["ambush", "retreat"]:
        rb, ra = runs(a.root, "base", [wl]), runs(a.root, "planner", [wl])
        if not rb or not ra:
            judge(f"G9 {wl} runs present", "0", "0", False)
            continue
        lb, la = cr.look_table(rb)[0], cr.look_table(ra)[0]
        judge(f"G4 {wl} yaw reversals/min (ARM <= BASE + 1)", lb["reversals_per_min"], la["reversals_per_min"],
              la["reversals_per_min"] <= lb["reversals_per_min"] + 1.0)
        judge(f"G5 {wl} own on screen % (ARM >= BASE - 5)", lb["own_pct"], la["own_pct"], la["own_pct"] >= lb["own_pct"] - 5.0, "%.1f")
        staged = sum(1 for x in ra if x.get("staged", {}).get("ok", x.get("scenario") in ("", None, "attack")))
        judge(f"G9 {wl} ARM runs ok + staged", "%d" % len(rb), "%d (%d staged)" % (len(ra), staged), len(ra) == len(rb) and staged == len(ra))
    for wl, sub in (("ambush", "rear"), ("retreat", None)):
        rb, ra = runs(a.root, "base", [wl]), runs(a.root, "planner", [wl])
        if sub:
            rb, ra = lane(rb, sub), lane(ra, sub)
        if not rb or not ra:
            continue
        lb, la = cr.look_table(rb)[0], cr.look_table(ra)[0]
        name = f"{wl}{' ' + sub if sub else ''}"
        judge(f"G7 {name} first shot -> on screen mean s (never = 20; ARM <= BASE + 1)", lb["capped"][0], la["capped"][0],
              la["capped"][0] <= lb["capped"][0] + 1.0)
        judge(f"G7 {name} blind % of fire (ARM <= BASE + 2)", lb["blind_of_fire_pct"], la["blind_of_fire_pct"],
              la["blind_of_fire_pct"] <= lb["blind_of_fire_pct"] + 2.0, "%.1f")
        if wl == "retreat":
            judge("G7 retreat facing the wall % (ARM <= BASE + 5)", lb["wall_pct"], la["wall_pct"], la["wall_pct"] <= lb["wall_pct"] + 5.0, "%.1f")
    if a.budget_ms:
        judge("G8 laptop planner ms/frame mean <= 0.5 and step p99 <= 1.5", "-", "%.3f / %.2f" % tuple(a.budget_ms),
              a.budget_ms[0] <= 0.5 and a.budget_ms[1] <= 1.5)
    errors = 0
    for d in os.listdir(a.root):
        p = os.path.join(a.root, d)
        if os.path.isdir(p):
            for f in os.listdir(p):
                if f.startswith("run_") and "SCRIPT ERROR" in open(os.path.join(p, f), errors="replace").read():
                    errors += 1
    judge("G9 no SCRIPT ERROR in any run log", "-", "%d logs" % errors, errors == 0)
    print(f"VERDICT Bar C1: {'PASS' if all(lines) else 'FAIL'} ({sum(lines)} of {len(lines)} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
