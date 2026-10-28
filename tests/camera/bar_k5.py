#!/usr/bin/env python3
"""Round 43 (camera K5.4): Bar K5's verdict, line by line, from the series' trace directories.

    python3 tests/camera/bar_k5.py <series dir> [--v2] (holds <workload>-off/ and <workload>-on/, as ~/camera-r43/bar_k5.sh
                                                      writes them; workloads corner-locks, corner-terminus, empty-locks,
                                                      empty-terminus, ambush, retreat, attack)
Each line: ARM, BASE, se where it has one, n, PASS/FAIL; the last line the bar's verdict. `--v2` = Bar K5 v2 (R43.27):
D1's per-arena clause is ARM >= BASE - 2 se of the difference (per-run shares), not ARM > BASE. The lines are the ones FILED in
_agents/streams/camera.md *Bar K5* (before any 10501-10536 number); do not edit them after a number is seen.
"""
import glob
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camera_report as cr  # noqa: E402

HAND = {"player", "jump", "follow", "all"}
V2 = "--v2" in sys.argv


def shares(rs):
    """Per-run share (%) of the corner seconds within 45 deg of the hidden side (runs with corner seconds)."""
    return [100.0 * r["corner"]["toward_s"] / r["corner"]["corner_s"] for r in rs
            if r.get("corner") and r["corner"].get("corner_s", 0.0) > 0.0]
lines = []


def line(name, arm, base, ok, note=""):
    lines.append((name, arm, base, ok, note))


def runs(d):
    return cr.load(d)


def corner_all(rs):
    rows = cr.corner_table(rs)
    return next((r for r in rows if r["lane"] == "all"), None)


def look_all(rs):
    rows = cr.look_table(rs)
    for r in rows:
        if r["lane"] in ("", "all"):
            return r
    return rows[0] if rows else None


def look_lane(rs, lane):
    return next((r for r in cr.look_table(rs) if r["lane"] == lane), None)


def capped(rs):
    looks = [r["look"] for r in rs if "look" in r]
    lat = [x for l in looks for x in l["latencies"]] + [cr.NEVER_S] * sum(l["never"] for l in looks)
    m, se = cr.mean_se([min(x, cr.NEVER_S) for x in lat])
    return m, se, len(lat)


def main():
    root = [a for a in sys.argv[1:] if not a.startswith("--")][0]
    W = {}
    for name in ["corner-locks", "corner-terminus", "empty-locks", "empty-terminus", "ambush", "retreat", "attack"]:
        W[name] = {arm: runs(os.path.join(root, f"{name}-{arm}")) for arm in ("off", "on")}
    # D1 toward the hidden side
    pool = {arm: corner_all(W["corner-locks"][arm] + W["corner-terminus"][arm]) for arm in ("off", "on")}
    a, b = pool["on"]["toward_pct"], pool["off"]["toward_pct"]
    line("D1 toward the hidden side, CORNER pooled (% of corner s)", a, b, a >= b + 10.0, f"n {pool['on']['runs']} v {pool['off']['runs']}")
    for arena in ("locks", "terminus"):
        ra, rb = corner_all(W[f"corner-{arena}"]["on"]), corner_all(W[f"corner-{arena}"]["off"])
        if V2:
            sa = cr.mean_se(shares(W[f"corner-{arena}"]["on"]))
            sb = cr.mean_se(shares(W[f"corner-{arena}"]["off"]))
            se = (sa[1] ** 2 + sb[1] ** 2) ** 0.5
            line(f"D1 toward the hidden side, {arena} (per-run mean +- se)", f"{sa[0]:.1f} +- {sa[1]:.1f}",
                 f"{sb[0]:.1f} +- {sb[1]:.1f}", sa[0] >= sb[0] - 2.0 * se, f"line: ARM >= BASE - 2 se ({2 * se:.1f}); pooled {ra['toward_pct']:.1f} v {rb['toward_pct']:.1f}")
        else:
            line(f"D1 toward the hidden side, {arena}", ra["toward_pct"], rb["toward_pct"], ra["toward_pct"] > rb["toward_pct"])
    # D2 facing the building after the opening, EMPTY pooled
    ep = {arm: corner_all(W["empty-locks"][arm] + W["empty-terminus"][arm]) for arm in ("off", "on")}
    key = "facing_free_pct" if V2 else "facing_open_pct"
    a, b = ep["on"][key], ep["off"][key]
    line("D2 facing the building after the opening, EMPTY pooled (%)" + (" (R43.29: frames K4's war pull wins left out)" if V2 else ""),
         a, b, a <= 0.75 * b, "line: ARM <= 0.75 x BASE")
    # D3 seen -> on screen
    a, b = pool["on"]["seen_screen"], pool["off"]["seen_screen"]
    line("D3 seen -> on screen, CORNER pooled (s, mean +- se)", f"{a[0]:.2f} +- {a[1]:.2f}", f"{b[0]:.2f} +- {b[1]:.2f}", a[0] <= b[0])
    # G0 no fog cheat
    for arena in ("locks", "terminus"):
        p = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "corner_nocheat.py"),
                            os.path.join(root, f"corner-{arena}-on"), os.path.join(root, f"empty-{arena}-on")],
                           capture_output=True, text=True)
        last = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "no output"
        line(f"G0 no fog cheat, {arena}", last, "-", p.returncode == 0)
    # G1 the empty corner
    for arena in ("locks", "terminus"):
        on, off = W[f"empty-{arena}"]["on"], W[f"empty-{arena}"]["off"]
        la, lb = look_all(on), look_all(off)
        line(f"G1 EMPTY {arena} reversals/min", la["reversals_per_min"], lb["reversals_per_min"], la["reversals_per_min"] <= lb["reversals_per_min"] + 1.0)
        ca, cb = corner_all(on), corner_all(off)
        line(f"G1 EMPTY {arena} > 135 deg off the travel (%)", ca["back_pct"], cb["back_pct"], ca["back_pct"] <= cb["back_pct"] + 3.0)
        t = cr.table(on)["rows"]
        line(f"G1 EMPTY {arena} jerks/min all / corner", f"{t['all']['per_min']:.2f} / {t['corner']['per_min']:.2f}", "-",
             t["all"]["per_min"] <= 3.0 and t["corner"]["per_min"] <= 1.5)
    # G2 Bar K4 v2's lines held
    a = capped(W["ambush"]["on"] + W["retreat"]["on"])
    b = capped(W["ambush"]["off"] + W["retreat"]["off"])
    line("G2 latency ambush+retreat pooled (s)", f"{a[0]:.2f} +- {a[1]:.2f} ({a[2]})", f"{b[0]:.2f} +- {b[1]:.2f} ({b[2]})",
         a[0] <= b[0] + 2.0 * (a[1] ** 2 + b[1] ** 2) ** 0.5)
    for label, ra, rb in (("rear lane", [r for r in W["ambush"]["on"] if r.get("lane") == "rear"], [r for r in W["ambush"]["off"] if r.get("lane") == "rear"]),
                          ("retreat", W["retreat"]["on"], W["retreat"]["off"])):
        a, b = capped(ra), capped(rb)
        line(f"G2 latency {label} (s)", f"{a[0]:.2f} +- {a[1]:.2f} ({a[2]})", f"{b[0]:.2f} +- {b[1]:.2f} ({b[2]})",
             a[0] <= b[0] + 2.0 * (a[1] ** 2 + b[1] ** 2) ** 0.5)
    wa = look_all(W["ambush"]["on"] + W["retreat"]["on"]); wb = look_all(W["ambush"]["off"] + W["retreat"]["off"])
    sa = sum(r["look"]["wall_s"] for r in W["ambush"]["on"] + W["retreat"]["on"]) / max(1e-6, sum(r["look"]["play_s"] for r in W["ambush"]["on"] + W["retreat"]["on"])) * 100
    sb = sum(r["look"]["wall_s"] for r in W["ambush"]["off"] + W["retreat"]["off"]) / max(1e-6, sum(r["look"]["play_s"] for r in W["ambush"]["off"] + W["retreat"]["off"])) * 100
    line("G2 facing the wall ambush+retreat pooled (%)", sa, sb, sa <= sb + 5.0)
    # G3 Bar K3 v2's lines, ATTACK, ARM
    t = cr.table(W["attack"]["on"])
    s = t["slip"]
    hit = 100.0 * s["hit"] / max(1, s["attacks"])
    line("G3 attack clicks on the aimed unit (%)", f"{hit:.1f} ({s['hit']}/{s['attacks']})", "-", hit >= 70.0)
    line("G3 slip p95 (px)", s["p95"], "-", s["p95"] <= 40.0)
    auto = max((row["per_min"], src) for src, row in t["rows"].items() if src not in HAND)
    line("G3 jerks/min all / top automatic source", f"{t['rows']['all']['per_min']:.2f} / {auto[1]} {auto[0]:.2f}", "-",
         t["rows"]["all"]["per_min"] <= 3.0 and auto[0] <= 1.5)
    snaps = {}
    for name in W:
        rows = cr.table(W[name]["on"])["rows"]
        snaps[name] = sum(row["snaps"] for src, row in rows.items() if src not in HAND)
    line("G3 automatic snaps, ARM, every workload", " ".join(f"{k} {v}" for k, v in snaps.items()), "-", sum(snaps.values()) == 0)
    # G4 reversals, G5 own on screen
    for name in ["corner-locks", "corner-terminus", "ambush", "retreat", "attack"]:
        la, lb = look_all(W[name]["on"]), look_all(W[name]["off"])
        line(f"G4 reversals/min {name}", la["reversals_per_min"], lb["reversals_per_min"], la["reversals_per_min"] <= lb["reversals_per_min"] + 1.0)
    for name in W:
        la, lb = look_all(W[name]["on"]), look_all(W[name]["off"])
        line(f"G5 own on screen {name} (%)", la["own_pct"], lb["own_pct"], la["own_pct"] >= lb["own_pct"] - 5.0)
    # G6
    bad = []
    for name in W:
        for arm in ("off", "on"):
            d = os.path.join(root, f"{name}-{arm}")
            logs = glob.glob(os.path.join(d, "run_*.log"))
            done = sum(1 for p in logs if "CAMERA_TRACE_DONE ok=true" in open(p, errors="replace").read())
            err = sum(1 for p in logs if "SCRIPT ERROR" in open(p, errors="replace").read())
            rs = W[name][arm]
            staged = sum(1 for r in rs if r.get("staged", {}).get("ok", name == "attack"))
            if done != 36 or err or staged != 36 or len(rs) != 36:
                bad.append(f"{name}-{arm} done {done} err {err} staged {staged}/{len(rs)}")
            if name.startswith(("corner", "empty")):
                opened = sum(1 for r in rs if r.get("corner", {}).get("opened"))
                if opened < 0.8 * 36:
                    bad.append(f"{name}-{arm} opened {opened}/36")
    line("G6 every run done, no SCRIPT ERROR, staged, opened >= 80 %", "; ".join(bad) or "all", "-", not bad)
    print("| line | ARM (on) | BASE (off) | verdict | note |")
    print("|---|---|---|---|---|")
    for name, arm, base, ok, note in lines:
        f = lambda v: f"{v:.2f}" if isinstance(v, float) else str(v)
        print(f"| {name} | {f(arm)} | {f(base)} | {'PASS' if ok else 'FAIL'} | {note} |")
    verdict = all(ok for *_, ok, _ in lines)
    print(f"BAR_K5 {'PASS' if verdict else 'FAIL'} ({sum(1 for *_, ok, _ in lines if not ok)} failing lines)")
    return 0 if verdict else 1


if __name__ == "__main__":
    sys.exit(main())
