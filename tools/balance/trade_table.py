"""B5 (round 41, balance): the orchestrator's IFV split, read from a face-probed mono series (no new runs): (b) the mixed army's damage on tanks per unit-second alive, by
    tools/balance/trade_table.py ROOT [--match -mono-base-]   (ROOT holds <commit>-<tag>mono-<faction>-<team>/ folders)
role and (for IFVs) by face; (c) the static per-credit trade IFV v tank from the catalog's numbers (armor.gd's penetration)."""
import json, math, re, sys
from collections import defaultdict
from pathlib import Path
import argparse
ap = argparse.ArgumentParser(); ap.add_argument("root", type=Path); ap.add_argument("--match", default="-mono-base-"); args = ap.parse_args()
root = args.root
cat = json.load(open(Path.home() / "balance-runs/catalog.json"))
U, W = cat["units"], cat["weapons"]
DIR = re.compile(r"mono-" + re.escape(args.match.strip("-").split("mono-")[-1]) + r"-(?P<faction>condemned|gangs|law|syndicate)-(?P<team>player|enemy)$")
acc = defaultdict(lambda: defaultdict(float))   # (faction, role) -> n, cost, dealt, alive_s, faces
for d in sorted(p for p in root.iterdir() if p.is_dir()):
    m = DIR.search(d.name)
    if not m: continue
    mono = "green" if m["team"] == "player" else "rust"
    mixed = "rust" if mono == "green" else "green"
    for log in (d / "none").glob("*-green.log"):
        res = face = None
        for line in log.read_text(errors="replace").splitlines():
            if line.startswith("GUARD_RESULT "): res = json.loads(line[13:])
            elif line.startswith("FACE "): face = json.loads(line[5:])
        if not res or not face: continue
        secs = float(res["seconds"])
        for u in res["units"][mixed]:
            a = acc[(m["faction"], U[u["type"]]["role"])]
            a["n"] += 1; a["cost"] += u["cost"]; a["dealt"] += u["dealt"]
            a["alive_s"] += (u["death"] / 30.0) if u["death"] >= 0 else secs
            a["dead"] += 0 if u["death"] < 0 else 1
        for role, by in face["teams"][mixed]["to_tanks_by_role"].items():
            a = acc[(m["faction"], role)]
            for f in ("front", "side", "rear"): a[f] += by[f]
print("(b) the MIXED army v the tank blob, base arm, per role: dealt is hull+shield points on enemies (tanks: every enemy here is one)")
print("faction    role       units  cost/u  dealt/unit  dealt/credit  alive s/unit  dealt/alive-s  lived  | faced: front  side  rear (per alive-s)")
for (f, role), a in sorted(acc.items()):
    n = a["n"] or 1
    faced = a["front"] + a["side"] + a["rear"]
    print(f"{f:10} {role:10} {int(a['n']):5} {a['cost']/n:7.0f} {a['dealt']/n:11.0f} {a['dealt']/max(a['cost'],1):13.2f} {a['alive_s']/n:13.0f} "
          f"{a['dealt']/max(a['alive_s'],1):14.2f} {100*(1-a['dead']/n):5.0f} % | "
          f"{a['front']/max(a['alive_s'],1):6.2f} {a['side']/max(a['alive_s'],1):6.2f} {a['rear']/max(a['alive_s'],1):6.2f}")

def pen(p, t):
    if t <= 0: return 1.5
    if p <= 0: return 0.05
    return min(1.5, max(0.05, 0.5 * math.log(1.6 * p / t) / math.log(2)))
SF = {"front": 0.7, "side": 1.0, "rear": 1.4}
def raw_dps(w):
    reload = float(w.get("reload", 1.0)) or 1.0
    rounds = float(w.get("burst_count", 1) or 1) if w.get("fire_model") == "burst" else 1.0
    return float(w["damage"]) * rounds / reload
print("\n(c) the static trade (no aim, no range, no cover; the catalog's numbers through armor.gd): seconds for ONE shooter to kill a TANK of its faction"
      "\n    at each face, and the same per 1000 credits of shooter (hp = shield then hull; shield takes dmg x shield_multiplier x SHIELD_FACING[face])")
print("faction    shooter        cost  raw dps |  front s   side s   rear s | per 1000 CR: front  side  rear | the tank kills the shooter in (front/side/rear) s")
for f in ("condemned", "gangs", "law", "syndicate"):
    tank = next(u for u, r in U.items() if r["faction"] == f and r["role"] == "tank")
    T, TW = U[tank], W[U[tank]["weapon"]]
    for u, r in sorted(U.items(), key=lambda kv: kv[1]["cost"]):
        if r["faction"] != f or r["role"] not in ("ifv", "scout", "lancer", "tank", "artillery"): continue
        w = W[r["weapon"]]
        dps = raw_dps(w)
        ttk = {}
        for face in ("front", "side", "rear"):
            thick = T["armor"][face] if w.get("fire_model") != "arc" else T["armor"]["side"]
            sdps = dps * float(w.get("shield_multiplier", 1.0)) * SF[face]
            hdps = dps * pen(float(w["penetration"]), float(thick))
            ttk[face] = float(T["max_shield"]) / sdps + float(T["max_health"]) / hdps
        # the tank shooting back at this unit's front/side/rear
        tdps = raw_dps(TW); back = {}
        for face in ("front", "side", "rear"):
            sdps = tdps * float(TW.get("shield_multiplier", 1.0)) * SF[face]
            hdps = tdps * pen(float(TW["penetration"]), float(r["armor"][face]))
            back[face] = float(r["max_shield"]) / sdps + float(r["max_health"]) / hdps
        k = 1000 / r["cost"]
        print(f"{f:10} {u:14} {r['cost']:5} {dps:8.1f} | {ttk['front']:8.0f} {ttk['side']:8.0f} {ttk['rear']:8.0f} | "
              f"{ttk['front']/k:13.0f} {ttk['side']/k:5.0f} {ttk['rear']/k:5.0f} | {back['front']:.0f} / {back['side']:.0f} / {back['rear']:.0f}")
