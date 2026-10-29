"""Pair orders-probe rows of two arms (arm names stripped) and report byte-identical / differing rows."""
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
pairs = [p.split("=") for p in sys.argv[2:]]  # on=off
arm_key = next(k for k in ("arm", "probe_arm") if k in rows[0])
for a, b in pairs:
    def keyed(name):
        out = {}
        for r in rows:
            if r.get(arm_key) != name:
                continue
            r = dict(r); r.pop(arm_key)
            k = json.dumps({x: r.get(x) for x in ("arena", "map", "seed", "squads", "route", "squad", "unit", "index") if x in r}, sort_keys=True)
            out.setdefault(k, []).append(json.dumps(r, sort_keys=True))
        return out
    A, B = keyed(a), keyed(b)
    same = sum(1 for k in A if k in B and A[k] == B[k])
    diff = [k for k in A if k not in B or A[k] != B[k]]
    print(f"{a} v {b}: {sum(len(v) for v in A.values())} v {sum(len(v) for v in B.values())} rows; keys {len(A)} v {len(B)}; identical {same}, differ {len(diff)}")
    for k in diff[:3]:
        print("  DIFF", k)
