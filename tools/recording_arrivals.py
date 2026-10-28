#!/usr/bin/env python3
"""Per order in a match recording: how close each ordered unit got, when it first arrived, and the largest drive AWAY from the
click inside the window to the next order on it (the lead's 2026-10-27 playtest: a War Rig under attack-move drove 82 m away).
    python3 tools/recording_arrivals.py build/recordings/X.jsonl [more...]   (gzipped files under references read in place)
per_order(rows) gives the same numbers as data (tests/replay/playtest_report.py's one-screen summary, round 44).
"""
import gzip, json, math, sys
def rows_of(f):
    opener = gzip.open if f.endswith(".gz") else open
    with opener(f, "rt") as handle:
        return [json.loads(l) for l in handle if l.strip()]
def split(rows):
    return [r for r in rows if r['t']=='order' and r.get('to')], [r for r in rows if r['t']=='census']
def load(f):
    return split(rows_of(f))
def per_order(rows):
    """[(order row, [{name, best, arrived, away}], window end tick)] for every order with a ground point; arrived is seconds
    or None, best -1 when the unit was never in a census of the window."""
    orders,cens=split(rows)
    out=[]
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
            res.append({'name':n.replace('Green_',''),'best':best if best is not None else -1,'arrived':arrived,'away':away})
        out.append((o,res,tend))
    return out
def report(f):
    print('===',f)
    for o,res,tend in per_order(rows_of(f)):
        tx,ty=o['to']; t0=o['tick']
        print(f" t{t0:5d} {o['verb']:11s} to ({tx:6.1f},{ty:6.1f}) window {int((tend-t0)/30)} s:", ' '.join(f"{u['name']}:best{round(u['best'] or -1)}m{'/arr%.0fs'%u['arrived'] if u['arrived'] else '/no-arr'}{'/AWAY%dm'%round(u['away']) if round(u['away'])>=30 else ''}" for u in res))
if __name__ == "__main__":
    for f in sys.argv[1:]: report(f)
