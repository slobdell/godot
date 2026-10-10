#!/usr/bin/env python3
"""Round 25 pace: pass counts and rim crews per lab start tick from `make pace-sweep` output (tests/pace/start_sweep.sh).
The pooled bridge line (C25.3, pre-registered 2026-10-10 before 870e3fe7's results): at every start tick in PREREG, both
sides, all 4 crews across and rim_crews 0."""
PREREG = [1, 3, 6, 8, 11, 16]  # t = 1 + 5k mod 18, k = 0..5
import re,sys
for path in sys.argv[1:]:
    rows={}
    for l in open(path):
        m=re.match(r"tick (\d+) (green|rust): jam/rim_crews/crossed/crossed_s (\S+) (\S+) (\S+) (\S+)",l)
        if m: rows.setdefault(int(m[1]),{})[m[2]]=(m[3],int(m[4]),int(m[5]))
        m=re.match(r"tick (\d+)\s+(PASS|FAIL)\s+test_tactics_bridge::(\S+)",l)
        if m: rows.setdefault(int(m[1]),{})["his" if "his_squad" in m[3] else "cpu"]=m[2]
    g=[t for t in rows if rows[t].get("his")=="PASS"]; r=[t for t in rows if rows[t].get("cpu")=="PASS"]
    strict=lambda t,s: rows[t][s][1]==0 and rows[t][s][2]==4
    print(f"{path.split('/')[-1]}: his PASS {len(g)}/{len(rows)} {sorted(g)}; CPU PASS {len(r)}/{len(rows)}; both {len(set(g)&set(r))}; strict (all 4 across, rim 0, both sides) {sum(strict(t,'green') and strict(t,'rust') for t in rows)}/{len(rows)}")
    ok=[t for t in PREREG if t in rows and strict(t,"green") and strict(t,"rust")]
    print(f"  pre-registered set {PREREG}: line met at {len(ok)}/{len(PREREG)} {ok}")
    print("  tick: green jam/rim/crossed | rust jam/rim/crossed")
    for t in sorted(rows): print(f"  {t:2d}: {rows[t]['green']} {rows[t].get('his')} | {rows[t]['rust']} {rows[t].get('cpu')}")
