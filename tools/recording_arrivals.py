#!/usr/bin/env python3
"""Per order in a match recording: how close each ordered unit got, when it first arrived, and the largest drive AWAY from the
click inside the window to the next order on it (the lead's 2026-10-27 playtest: a War Rig under attack-move drove 82 m away).
    python3 tools/recording_arrivals.py build/recordings/X.jsonl [more...]   (gzipped files under references read in place)
"""
import gzip, json, math, sys
def load(f):
    opener = gzip.open if f.endswith(".gz") else open
    with opener(f, "rt") as handle:
        rows = [json.loads(l) for l in handle if l.strip()]
    return [r for r in rows if r['t']=='order' and r.get('to')], [r for r in rows if r['t']=='census']
def report(f):
    orders,cens=load(f)
    print('===',f)
    for o in orders:
        tx,ty=o['to']; t0=o['tick']
        # window until the next order touching these units
        later=[q['tick'] for q in orders if q['tick']>t0 and set(q['units'])&set(o['units'])]
        tend=min(later) if later else cens[-1]['tick']
        res=[]
        for n in o['units']:
            best=None; arrived=None; away=0; last=None
            for c in cens:
                if c['tick']<t0 or c['tick']>tend: continue
                u=[x for x in c['units'] if x['n']==n]
                if not u: break
                u=u[0]; d=math.hypot(u['pos'][0]-tx,u['pos'][1]-ty)
                if last is not None: away=max(away,d-last)
                last=d if last is None else min(last,d)
                if best is None or d<best: best=d
                if arrived is None and u['phase']=='arrived' and c['tick']>t0: arrived=(c['tick']-t0)/30
            res.append((n.replace('Green_',''),round(best or -1),arrived,round(away)))
        print(f" t{t0:5d} {o['verb']:11s} to ({tx:6.1f},{ty:6.1f}) window {int((tend-t0)/30)} s:", ' '.join(f"{n}:best{b}m{'/arr%.0fs'%a if a else '/no-arr'}{'/AWAY%dm'%w if w>=30 else ''}" for n,b,a,w in res))
if __name__ == "__main__":
    for f in sys.argv[1:]: report(f)
