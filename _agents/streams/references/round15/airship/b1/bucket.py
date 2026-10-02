import sys, glob, os
sys.path.insert(0, "tools")
import airship_view_pool as p
root = sys.argv[1]
B = {}
rows_out = []
for path in sorted(glob.glob(os.path.join(root, "*", "*", "trace_*.csv"))):
    rows = list(p._rows(path))
    rest = min(r["cam_y"] for r in rows)
    first_arrive = next((r["tick"]/30 for r in rows if ((r["hull_x"]-r["action_x"])**2+(r["hull_z"]-r["action_z"])**2)**0.5 < 62*1.45), None)
    seed = os.path.basename(os.path.dirname(path)); arena = os.path.basename(path)[6:].rsplit("_",1)[0]
    for x in p.intrusions(path):
        lifted = x["cam_y"] > rest + 2.0
        climbing = x["alt"] > p.CRUISE + 1.0
        jump = x["since_order"] < 3.0 and x["cam_moved"] > 15
        b = ("lifted" if lifted else "rest") + "/" + ("climbing" if climbing else "cruise") + ("/jump" if jump else "")
        cl = 38 <= x["t"] <= 50
        B.setdefault(b, [0, 0, 0.0]); B[b][0] += 1; B[b][1] += cl; B[b][2] += x["dur"]
        rows_out.append((arena, seed, x["t"], x["dur"], b, first_arrive, rest))
print("bucket  n  in_39-49  total_s")
for b, v in sorted(B.items(), key=lambda kv: -kv[1][2]): print(b, v[0], v[1], round(v[2],1))
print("cluster rows (t 38-50): arena seed t dur bucket first_arrival_s rest_cam_y")
for r in rows_out:
    if 38 <= r[2] <= 50: print(*[round(v,1) if isinstance(v,float) else v for v in r])
import collections
print("first arrival at the orbit per run:", sorted(set((r[0], r[1], round(r[5] or -1,1)) for r in rows_out)))
