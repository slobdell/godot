"""Round 32 (traffic): squad B's pace / phase each second from a traffic-trace log (TRAFFIC_TRACK lines): K k-turn, H hold,
phase initial (d driving, a arrived, y yielding, b blocked), b:<last 3 chars of blocked_by>.

    python3 tests/traffic/squad_pace_table.py build/traffic-trace.log
"""
import json,sys,collections
rows=collections.defaultdict(dict)
for l in open(sys.argv[1]):
    if not l.startswith('TRAFFIC_TRACK'): continue
    d=json.loads(l[len('TRAFFIC_TRACK '):])
    if not d['n'].startswith('Green_B'): continue
    rows[d['t']][d['n']]=d
names=sorted({n for t in rows for n in rows[t]})
print('t    '+'  '.join('%-18s'%n[-3:] for n in names))
for t in sorted(rows):
    if t>22: break
    if abs(t*2-round(t*2))>0.01 or int(t*2)%2: continue
    out=[]
    for n in names:
        d=rows[t].get(n)
        if not d: out.append('%-18s'%'-'); continue
        flag=('K' if d['kturn'] else '')+('H' if d['hold'] else '')+(d['phase'][0])+(' b:'+d['blocked'][-3:] if d['blocked'] else '')
        out.append('%-18s'%('%.2f %s'%(d['pace'],flag)))
    print('%4.1f '%t+'  '.join(out))
