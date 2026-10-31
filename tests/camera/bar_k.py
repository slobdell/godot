#!/usr/bin/env python3
"""Round 47 (camera K4): Bar K's verdict from its series (<root>/<arm>-<workload>/, CameraPlaytest traces).

Every line as filed in workstreams.md *Bars (round 47)*: BASE (`--camera-select-pan=off`, round 46's planner as on main) v
ARM (the default, select_pan ON), each printed with both numbers and PASS / FAIL; then `VERDICT Bar K: PASS|FAIL`.

    python3 tests/camera/bar_k.py <root> [--budget-ms MEAN P99]   (the laptop's frame cost, measured apart)
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camera_report as cr  # noqa: E402

SPLIT = ["split-terminus", "split-locks", "split-crossing", "split-gorge"]
ATTACK = ["attack-terminus", "attack-crossing"]
DECIDING = SPLIT + ATTACK
NEVER_S = 10.0
ARMS = ("base", "pan")


def runs(root, arm, workloads):
    out = []
    for wl in workloads:
        out += cr.load(os.path.join(root, f"{arm}-{wl}"))
    return out


def looks(rs):
    return [r["look"] for r in rs if "look" in r]


def k(rs):
    ls = looks(rs)
    play = sum(l["play_s"] for l in ls) or 1e-6
    frames = [e for l in ls for e in l.get("sel_frames", [])]
    lat = [min(e["latency_s"], NEVER_S) if e["latency_s"] is not None else NEVER_S for e in frames]
    hits = sum(l.get("hits", 0) for l in ls)
    return {"play": play, "far_pct": 100.0 * sum(l.get("sel_far_s", 0.0) for l in ls) / play, "n": len(lat),
            "lat_mean": sum(lat) / len(lat) if lat else 0.0, "lat_p90": cr.quantile(lat, 0.9) if lat else 0.0,
            "never": sum(1 for e in frames if e["latency_s"] is None),
            "hidden": sum(l.get("sel_hidden_s", 0.0) for l in ls), "none": sum(l.get("sel_none_s", 0.0) for l in ls),
            "hits_off_pct": 100.0 * sum(l.get("hits_off", 0) for l in ls) / max(hits, 1), "hits": hits}


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
        if isinstance(base, str):
            print(f"{'PASS' if ok else 'FAIL'}  {name}: BASE {base} v ARM {arm}")
        else:
            print(f"{'PASS' if ok else 'FAIL'}  {name}: BASE {fmt % base} v ARM {fmt % arm}")

    b_dec, a_dec = runs(a.root, "base", DECIDING), runs(a.root, "pan", DECIDING)
    print(f"DECIDING runs (SPLIT + ATTACK): BASE {len(b_dec)} v ARM {len(a_dec)}")
    b, r = k(b_dec), k(a_dec)
    print(f"  new selections > 20 m off when picked: BASE {b['n']} v ARM {r['n']}; hits on his units BASE {b['hits']} v ARM {r['hits']}")
    judge("D1 his selection > 30 m from the look point, % of play (ARM <= BASE and ARM <= 10; the ratio reported)", b["far_pct"],
          r["far_pct"], r["far_pct"] <= b["far_pct"] and r["far_pct"] <= 10.0, "%.1f")
    print(f"  (reported) D1 ratio ARM / BASE {r['far_pct'] / max(b['far_pct'], 1e-6):.2f}")
    judge("D2a a far new selection -> within 20 m, mean s (never = 10; ARM <= 1.0 and ARM <= BASE)", b["lat_mean"], r["lat_mean"],
          r["lat_mean"] <= 1.0 and r["lat_mean"] <= b["lat_mean"])
    judge("D2b the same, ARM p90 <= 1.5 s", b["lat_p90"], r["lat_p90"], r["lat_p90"] <= 1.5)
    judge("D3 far new selections never framed (ARM <= BASE)", b["never"], r["never"], r["never"] <= b["never"], "%d")
    for wl in SPLIT:
        bs, rs = k(runs(a.root, "base", [wl])), k(runs(a.root, "pan", [wl]))
        print(f"  (reported) {wl}: far % {bs['far_pct']:.1f} v {rs['far_pct']:.1f}; frame mean {bs['lat_mean']:.2f} v "
              f"{rs['lat_mean']:.2f} s (n {bs['n']} v {rs['n']}); never {bs['never']} v {rs['never']}")

    judge("G1 driving with half+ of his selection hidden by a building, s (ARM <= 1.1 x BASE + 5)", b["hidden"], r["hidden"],
          r["hidden"] <= 1.1 * b["hidden"] + 5.0, "%.1f")
    judge("G2 none of his selection on screen, s (ARM <= BASE)", b["none"], r["none"], r["none"] <= b["none"], "%.1f")
    judge("G3 hits on his units off screen, % of hits (ARM <= BASE + 1)", b["hits_off_pct"], r["hits_off_pct"],
          r["hits_off_pct"] <= b["hits_off_pct"] + 1.0, "%.1f")

    tb, ta = cr.table(b_dec), cr.table(a_dec)
    others = lambda t: max(((s, row["per_min"]) for s, row in t["rows"].items()
                            if s not in ("all", "player", "jump", "follow", "select")), key=lambda x: x[1], default=("-", 0.0))
    wb, wa = others(tb), others(ta)
    judge("G4a no automatic source but 'select' over BASE's worst + 0.5 jerks/min", "%s %.2f" % wb, "%s %.2f" % wa,
          wa[1] <= wb[1] + 0.5)
    snaps_other = sum(row["snaps"] for s, row in ta["rows"].items() if s not in ("all", "select", "player", "jump", "follow"))
    print(f"  (reported) the selection pan ('select'): jerks/min {tb['rows'].get('select', {}).get('per_min', 0.0):.2f} v "
          f"{ta['rows'].get('select', {}).get('per_min', 0.0):.2f}; snaps {tb['rows'].get('select', {}).get('snaps', 0)} v "
          f"{ta['rows'].get('select', {}).get('snaps', 0)}")
    peak = lambda rs: max((l.get("pan_peak_hps", 0.0) for l in looks(rs)), default=0.0)
    cut = lambda rs: sum(l.get("pan_cut_s", 0.0) for l in looks(rs))
    judge("G4c a pan, not a cut: the view's own fastest move, heights/s (ARM peak <= 4.5) and seconds over 4.5 (ARM <= BASE + 1)",
          "%.2f / %.1f s" % (peak(b_dec), cut(b_dec)), "%.2f / %.1f s" % (peak(a_dec), cut(a_dec)),
          peak(a_dec) <= 4.5 and cut(a_dec) <= cut(b_dec) + 1.0)
    judge("G4b snaps from any automatic source but 'select', ARM = 0", 0, snaps_other, snaps_other == 0, "%d")
    hit_pct = lambda t: 100.0 * t["slip"]["hit"] / max(t["slip"]["attacks"], 1)
    judge("G5a clicks on the aimed unit % (ARM >= 70: Bar C1's G2a)", hit_pct(tb), hit_pct(ta), hit_pct(ta) >= 70.0, "%.1f")
    judge("G5b slip p95 px (ARM <= 40)", tb["slip"]["p95"], ta["slip"]["p95"], ta["slip"]["p95"] <= 40.0, "%.1f")
    judge("G5c held % (ARM <= BASE + 2)", tb["play"]["held_pct"], ta["play"]["held_pct"], ta["play"]["held_pct"] <= tb["play"]["held_pct"] + 2.0, "%.1f")
    panned = lambda rs: [c for r in rs for c in r["clicks"] if c.get("panned")]
    pb, pa = panned(b_dec), panned(a_dec)
    print(f"  (reported) clicks aimed while the selection's pan ran: BASE {len(pb)} v ARM {len(pa)}; their slip p95 "
          f"{cr.quantile([c['slip_px'] for c in pb], 0.95):.1f} v {cr.quantile([c['slip_px'] for c in pa], 0.95):.1f} px")
    judge("G6 action share % (ARM >= BASE - 5)", tb["play"]["action_pct"], ta["play"]["action_pct"],
          ta["play"]["action_pct"] >= tb["play"]["action_pct"] - 5.0, "%.1f")
    inside = lambda rs: sum(l.get("inside_s", 0.0) for l in looks(rs)) / max(len(rs), 1)
    judge("G7 camera inside a solid, s per run (ARM <= BASE + 1)", inside(b_dec), inside(a_dec), inside(a_dec) <= inside(b_dec) + 1.0)
    for wl, sub in (("ambush", "rear"), ("ambush", None), ("retreat", None)):
        rb, ra = runs(a.root, "base", [wl]), runs(a.root, "pan", [wl])
        if sub:
            rb, ra = lane(rb, sub), lane(ra, sub)
        if not rb or not ra:
            judge(f"G9 {wl} {sub or ''} runs present", "0", "0", False)
            continue
        lb, la = cr.look_table(rb)[0], cr.look_table(ra)[0]
        name = f"{wl}{' ' + sub if sub else ' all lanes'}"
        judge(f"G8 {name} first shot -> on screen mean s (never = 20; ARM <= BASE + 1)", lb["capped"][0], la["capped"][0],
              la["capped"][0] <= lb["capped"][0] + 1.0)
        judge(f"G8 {name} blind % of fire (ARM <= BASE + 2)", lb["blind_of_fire_pct"], la["blind_of_fire_pct"],
              la["blind_of_fire_pct"] <= lb["blind_of_fire_pct"] + 2.0, "%.1f")
        if wl == "retreat":
            judge("G8 retreat facing the wall % (ARM <= BASE + 5)", lb["wall_pct"], la["wall_pct"], la["wall_pct"] <= lb["wall_pct"] + 5.0, "%.1f")
    for wl in DECIDING + ["ambush", "retreat"]:
        rb, ra = runs(a.root, "base", [wl]), runs(a.root, "pan", [wl])
        staged = sum(1 for x in ra if x.get("staged", {}).get("ok", x.get("scenario") in ("", None, "attack")))
        judge(f"G9 {wl} runs ok + staged", "%d" % len(rb), "%d (%d staged)" % (len(ra), staged),
              len(ra) == len(rb) and len(ra) > 0 and staged == len(ra))
    if a.budget_ms:
        judge("G10 laptop rig ms/frame mean <= 0.5 and planner step p99 <= 1.5", "-", "%.3f / %.2f" % tuple(a.budget_ms),
              a.budget_ms[0] <= 0.5 and a.budget_ms[1] <= 1.5)
    errors = 0
    for d in os.listdir(a.root):
        p = os.path.join(a.root, d)
        if os.path.isdir(p):
            for f in os.listdir(p):
                if f.startswith("run_") and "SCRIPT ERROR" in open(os.path.join(p, f), errors="replace").read():
                    errors += 1
    judge("G9 no SCRIPT ERROR in any run log", "-", "%d logs" % errors, errors == 0)
    print(f"VERDICT Bar K: {'PASS' if all(lines) else 'FAIL'} ({sum(lines)} of {len(lines)} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
