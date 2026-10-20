#!/usr/bin/env python3
"""X1(d): crews rocking in place with the stall clock running and no escape (hull-rest MANOEUVRE_STATE rows, --turn-states):
|throttle| > 0.5 on a move_to, net movement < 0.5 m over 10 one-second samples, stuck clock > 0.2 s seen, escape 0.
usage: rocking_census.py <hull-rest arm dir>   (e.g. .../hull-rest/base_drawn). Measurement only."""
import sys,glob,math,collections
root=sys.argv[1]
def parse(l):
    w=l.split(); i=lambda k:w.index(k)
    try:
        return dict(f=int(w[2]),name=w[3],unit=w[4],thr=abs(float(w[i("cmd")+1].split("/")[0])),stuck=float(w[i("stuck")+1]),esc=float(w[i("esc")+1]),real=float(w[i("real")+1]),x=float(w[i("at")+1]),z=float(w[i("at")+2]),order=w[i("order")+1])
    except Exception: return None
runs=crews=0; byunit=collections.Counter(); ex=[]
for log in glob.glob(root+"/*/*/run.log"):
    runs+=1; per=collections.defaultdict(list)
    for l in open(log,errors="replace"):
        if l.startswith("SCREEN {"): break
        if l.startswith("MANOEUVRE_STATE "):
            r=parse(l)
            if r: per[r["name"]].append(r)
    for n,rs in per.items():
        best=0; run=[]
        for r in rs:
            if r["thr"]>0.5 and r["esc"]==0 and r["order"]=="move_to":
                run.append(r)
                if len(run)>=10 and math.hypot(run[-1]["x"]-run[-10]["x"],run[-1]["z"]-run[-10]["z"])<0.5 and max(q["stuck"] for q in run[-10:])>0.2:
                    best=max(best,len(run))
            else: run=[]
        if best: crews+=1; byunit[rs[0]["unit"]]+=1; ex.append((best,log.split("/")[-3]+"/"+log.split("/")[-2],n))
print("runs",runs,"crews rocking >=10 s with the clock running, no escape:",crews, dict(byunit))
for e in sorted(ex,reverse=True)[:8]: print(e)
