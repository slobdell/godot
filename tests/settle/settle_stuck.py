import sys,re,math,collections
path,squad=sys.argv[1],sys.argv[2]
every=float(sys.argv[3]) if len(sys.argv)>3 else 5
mem=re.compile(r'(\w+) at \((-?[\d.]+),(-?[\d.]+)\)(?: slot \((-?[\d.]+),(-?[\d.]+)\) ([\d.]+) m off)?')
frames=collections.OrderedDict()
arrived={}
for l in open(path,errors='ignore'):
    if not l.startswith('ELEMENT_TRACE'): continue
    t=float(re.search(r't=([\d.]+)',l).group(1)); el=re.search(r'\[(\w+)\]',l).group(1)
    arr='arrived true' in l
    task=re.search(r'task (\w+)',l).group(1)
    for m in mem.finditer(l.split(' | ',1)[1] if ' | ' in l else ''):
        n=m.group(1); fr=frames.setdefault(round(t),{})
        fr[n]=dict(el=el,at=(float(m.group(2)),float(m.group(3))),slot=(float(m.group(4)),float(m.group(5))) if m.group(4) else None,off=float(m.group(6)) if m.group(6) else -1,arr=arr,task=task)
ts=list(frames); last={}
for t in ts:
    if t % every: continue
    fr=frames[t]
    for n,c in sorted(fr.items()):
        if c['el']!=squad: continue
        near=sorted(((math.dist(c['at'],o['at']),m,o) for m,o in fr.items() if o['el']!=c['el'] and m.startswith('Green')),key=lambda x:x[0])[:2]
        sp=math.dist(c['at'],last.get(n,c['at']))/every; last[n]=c['at']
        ns='; '.join('%s %.1fm%s%s'%(m.replace('Green_',''),d,' ARR' if o['arr'] else '',' slot %.1f off'%o['off'] if o['off']>=0 else '') for d,m,o in near)
        print('t=%3d %-16s at (%.1f,%.1f) off %5.1f v %.1f m/s %s | near: %s'%(t,n.replace('Green_',''),c['at'][0],c['at'][1],c['off'],sp,'ARR' if c['arr'] else '',ns))
