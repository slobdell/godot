import sys, glob, os, json
sys.path.insert(0, "tools")
import airship_view_pool as p
root, base, fix = sys.argv[1], sys.argv[2], sys.argv[3]
def pooled(arm):
    out = {}
    for path in glob.glob(os.path.join(root, arm, "*", "airship_view_*.json")):
        r = json.load(open(path)); m = out.setdefault(r["arena"], {"t":0,"f":0,"h":0,"long":0,"n":0})
        m["t"] += r["ticks"]; m["f"] += r["frame_pct"]*r["ticks"]; m["h"] += r["between_pct"]*r["ticks"]
        m["long"] = max(m["long"], r["longest_s"]); m["n"] += r["intrusions"]
    return {k: {"frame": v["f"]/v["t"], "hides": v["h"]/v["t"], "clean": (v["f"]-v["h"])/v["t"], "longest": v["long"], "n": v["n"]} for k, v in out.items()}
def cluster(arm):
    c = 0; tot = 0
    for path in glob.glob(os.path.join(root, arm, "*", "trace_*.csv")):
        for x in p.intrusions(path):
            tot += 1; c += 38 <= x["t"] <= 50
    return c, tot
B, F = pooled(base), pooled(fix)
cb, tb = cluster(base); cf, tf = cluster(fix)
print("(1) cluster 38-50 s: %s %d of %d -> %s %d of %d: %s (<= 0.5x)" % (base, cb, tb, fix, cf, tf, "PASS" if cf <= 0.5*cb else "FAIL"))
ok2 = ok3 = True
for m in sorted(B):
    b, f = B[m], F.get(m)
    h_ok = f["hides"] <= b["hides"] + 0.5; l_ok = f["longest"] <= b["longest"] + 1.0
    scored = b["clean"] >= 1.0; c_ok = (not scored) or f["clean"] >= 0.9*b["clean"]
    ok2 &= h_ok and l_ok; ok3 &= c_ok
    print("%-9s hides %.2f -> %.2f %s | longest %.1f -> %.1f %s | intrusions %d -> %d | frame %.1f -> %.1f | seen-clean %.2f -> %.2f %s" % (
        m, b["hides"], f["hides"], "ok" if h_ok else "UP", b["longest"], f["longest"], "ok" if l_ok else "UP", b["n"], f["n"],
        b["frame"], f["frame"], b["clean"], f["clean"], ("ok" if c_ok else "DOWN") if scored else "(not scored)"))
print("(2) the rest unchanged:", "PASS" if ok2 else "FAIL"); print("(3) seen-share not down:", "PASS" if ok3 else "FAIL")
