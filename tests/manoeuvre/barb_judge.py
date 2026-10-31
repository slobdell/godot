#!/usr/bin/env python3
"""Round 48 (manoeuvre M3): Bar B's judge. Pairs the spotter feature-probe fights of two arms (same arena x seed) and prints each
line's own statistic (lesson 331): per fight, summed over every crew of both teams,

  jam_s        crew-seconds `yielding`, or `blocked` by a FRIENDLY crew (class B's own signal)        -> D1 (deciding)
  heldwait_s   crew-seconds blocked / yielding with blocked_by naming a crew whose order that second is hold
               (the asker waiting on a held crew: the rule's own risk)                                    -> G1
  friendtouch_s crew-seconds touching a friendly hull                                                      -> G2
  noprog_s     crew-seconds on a move order, > FAR_M from its goal, gaining < 1 m in 5 s                  -> G3
  alive        crews alive at the fight's last second, per team                                           -> G4

  python3 tests/manoeuvre/barb_judge.py BASE_DIR NEW_DIR   (each holds <arena>-<seed>.jsonl[.gz])
  python3 tests/manoeuvre/barb_judge.py --selftest         (the mutation check: each line FAILS on a staged pair, lesson 350)
Measurement only."""
import gzip, json, math, os, sys

FAR_M = 15.0


def _open(path):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path)


def fight_rows(path):
    return [r for r in (json.loads(l) for l in _open(path) if l.strip()) if r.get("t") == "crew"]


def metrics(rows):
    by_s = {}
    for r in rows:
        by_s.setdefault(r["s"], {})[r["crew"]] = r
    team_of = {r["crew"]: r["team"] for r in rows}
    m = {"jam_s": 0, "heldwait_s": 0, "friendtouch_s": 0, "noprog_s": 0}
    hist = {}
    for s in sorted(by_s):
        crews = by_s[s]
        for name, r in crews.items():
            blk = r.get("blocked", "") or ""
            phase = r.get("phase", "")
            friendly = blk in team_of and team_of[blk] == r["team"]
            if phase == "yielding" or (phase == "blocked" and friendly):
                m["jam_s"] += 1
            if phase in ("yielding", "blocked") and friendly and (crews.get(blk) or {}).get("order") == "hold":
                m["heldwait_s"] += 1
            what = r.get("touch_what", "") or ""
            if r.get("touch") and what in team_of and team_of[what] == r["team"]:
                m["friendtouch_s"] += 1
            to_go = r.get("to_go")
            h = hist.setdefault(name, [])
            h.append((s, to_go))
            if r.get("move") == "move_to" and to_go is not None and to_go > FAR_M:
                back = [g for (t, g) in h if t == s - 5 and g is not None]
                if back and back[0] - to_go < 1.0:
                    m["noprog_s"] += 1
    last = max(by_s) if by_s else 0
    for team in (0, 1):
        m["alive_%d" % team] = sum(1 for r in by_s.get(last, {}).values() if r["team"] == team)
    return m


def load(folder):
    out = {}
    for f in sorted(os.listdir(folder)):
        if f.endswith(".jsonl") or f.endswith(".jsonl.gz"):
            out[f.replace(".gz", "")] = metrics(fight_rows(os.path.join(folder, f)))
    return out


def paired(base, new, key):
    d = [new[k][key] - base[k][key] for k in sorted(base) if k in new]
    n = len(d)
    if n == 0:
        return {"n": 0, "mean": 0.0, "se": 0.0, "z": 0.0, "lower_or_same": 0}
    mean = sum(d) / n
    var = sum((x - mean) ** 2 for x in d) / (n - 1) if n > 1 else 0.0
    se = math.sqrt(var / n)
    z = mean / se if se > 0 else (0.0 if mean == 0 else math.copysign(99.0, mean))
    return {"n": n, "mean": round(mean, 2), "se": round(se, 2), "z": round(z, 2),
            "lower_or_same": sum(1 for x in d if x <= 0), "base_mean": round(sum(base[k][key] for k in base if k in new) / n, 2)}


def judge(base, new):
    lines = []
    d1 = paired(base, new, "jam_s")
    lines.append(("D1 jam_s a fight (deciding: mean < 0 and z <= -2)", d1, d1["n"] > 0 and d1["mean"] < 0 and d1["z"] <= -2.0))
    g1 = paired(base, new, "heldwait_s")
    lines.append(("G1 heldwait_s a fight (mean <= +5 and z < +2)", g1, g1["mean"] <= 5.0 and g1["z"] < 2.0))
    g2 = paired(base, new, "friendtouch_s")
    lines.append(("G2 friendtouch_s a fight (z < +2)", g2, g2["z"] < 2.0))
    g3 = paired(base, new, "noprog_s")
    lines.append(("G3 noprog_s a fight (z < +2)", g3, g3["z"] < 2.0))
    for team in (0, 1):
        g4 = paired(base, new, "alive_%d" % team)
        lines.append(("G4 alive team %d at the end (|mean| <= 0.5 and |z| < 2)" % team, g4,
                      abs(g4["mean"]) <= 0.5 and abs(g4["z"]) < 2.0))
    return lines


def report(lines, base, new):
    print("BARB_JUDGE fights paired %d (base %d, new %d)" % (len([k for k in base if k in new]), len(base), len(new)))
    ok = True
    for label, stat, passed in lines:
        ok = ok and passed
        print("  %-60s %s  %s" % (label, json.dumps(stat), "PASS" if passed else "FAIL"))
    by_map = {}
    for k in base:
        if k in new:
            by_map.setdefault(k.split("-")[0], []).append(new[k]["jam_s"] - base[k]["jam_s"])
    print("  per map jam_s ON-OFF a fight: " + ", ".join("%s %+.1f (n %d)" % (a, sum(v) / len(v), len(v)) for a, v in sorted(by_map.items())))
    print("BARB_VERDICT %s" % ("PASS" if ok else "FAIL"))
    return ok


def selftest():
    # Each line must FAIL on a staged pair built to violate it (lesson 350), and D1 pass on a staged improvement.
    def fights(f):
        return {"m-%d.jsonl" % i: dict(f(i)) for i in range(12)}
    base = fights(lambda i: {"jam_s": 40 + i, "heldwait_s": 5, "friendtouch_s": 3, "noprog_s": 10, "alive_0": 5, "alive_1": 5})
    better = fights(lambda i: {"jam_s": 20 + i % 3, "heldwait_s": 5, "friendtouch_s": 3, "noprog_s": 10, "alive_0": 5, "alive_1": 5})
    worse_wait = fights(lambda i: {"jam_s": 20 + i % 3, "heldwait_s": 15 + i % 2, "friendtouch_s": 3, "noprog_s": 10, "alive_0": 5, "alive_1": 5})
    worse_all = fights(lambda i: {"jam_s": 60 + i, "heldwait_s": 5, "friendtouch_s": 9 + i % 2, "noprog_s": 30 + i % 2, "alive_0": 3, "alive_1": 5})
    r = {lbl[:2] + str(i): p for i, (lbl, _, p) in enumerate(judge(base, better))}
    assert all(r.values()), r
    assert [p for (_, _, p) in judge(base, worse_wait)][1] is False, "G1 must fail on a staged longer wait"
    fails = [p for (_, _, p) in judge(base, worse_all)]
    assert fails[0] is False and fails[2] is False and fails[3] is False and fails[4] is False, fails
    assert [p for (_, _, p) in judge(base, base)][0] is False, "D1 must fail on no change"
    # metrics() on staged rows: a crew yielding to a held friend for 3 s, touching it 2 s.
    rows = []
    for s in range(1, 5):
        rows.append({"t": "crew", "s": s, "crew": "G_A", "team": 0, "order": "move", "move": "move_to", "phase": "yielding" if s < 4 else "driving",
                     "blocked": "G_H" if s < 4 else "", "touch": s < 3, "touch_what": "G_H", "to_go": 30})
        rows.append({"t": "crew", "s": s, "crew": "G_H", "team": 0, "order": "hold", "move": "face", "phase": "arrived", "blocked": "",
                     "touch": False, "touch_what": "", "to_go": None})
    m = metrics(rows)
    assert m["jam_s"] == 3 and m["heldwait_s"] == 3 and m["friendtouch_s"] == 2 and m["alive_0"] == 2, m
    print("BARB_SELFTEST ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        selftest()
        sys.exit(0)
    base, new = load(sys.argv[1]), load(sys.argv[2])
    sys.exit(0 if report(judge(base, new), base, new) else 1)
