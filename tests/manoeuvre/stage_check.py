import json, math, sys
HULLS={'gang_tank':(3.32,14.0),'gang_ifv':(1.59,3.44),'gang_support':(3.18,6.58)}
MATES=[((-8.0,1.0),'gang_tank'),((5.0,1.0),'gang_tank'),((-5.0,15.0),'gang_ifv'),((1.5,15.0),'gang_support')]
SIZES={'container_20':(6.06,2.44),'container_40':(12.19,2.44),'block':(40.0,40.0)}
def hex_margin(x,z,r=140.0):
    # hexagon vertices at angles 30+60k: (r sin a, r cos a); min distance to its edges (inside positive)
    vs=[(r*math.sin(math.radians(30+60*k)), r*math.cos(math.radians(30+60*k))) for k in range(6)]
    best=1e9
    for i in range(6):
        ax,az=vs[i]; bx,bz=vs[(i+1)%6]
        ex,ez=bx-ax,bz-az; L=math.hypot(ex,ez)
        # signed distance: inside = toward the centre
        d=((x-ax)*ez-(z-az)*ex)/L
        # orientation: check centre
        dc=((0-ax)*ez-(0-az)*ex)/L
        d = d if dc>0 else -d
        best=min(best,d)
    return best
def rect_pts(cx,cz,w,d,rot_deg):
    r=math.radians(rot_deg); c,s=math.cos(r),math.sin(r)
    out=[]
    for sx,sz in ((-1,-1),(1,-1),(1,1),(-1,1)):
        lx,lz=sx*w/2,sz*d/2
        out.append((cx+lx*c-lz*s, cz+lx*s+lz*c))
    return out
def sat_overlap(A,B,margin=0.0):
    # separating axis for two convex quads (expand by margin along axes)
    for poly in (A,B):
        for i in range(4):
            ax,az=poly[i]; bx,bz=poly[(i+1)%4]
            nx,nz=-(bz-az),(bx-ax); L=math.hypot(nx,nz); nx/=L; nz/=L
            pa=[px*nx+pz*nz for px,pz in A]; pb=[px*nx+pz*nz for px,pz in B]
            if max(pa)+margin<min(pb) or max(pb)+margin<min(pa): return False
    return True
def check(arena, centre, rot, side, shape, label):
    a=json.load(open(f'arenas/{arena}.json'))
    props=[p for p in a['props'] if p['type'] in SIZES]
    water=[]
    for t in a.get('terrain',[]):
        if t['kind']=='water':
            cx,cz,w,d=t['rect']; water.append((cx-w/2,cz-d/2,cx+w/2,cz+d/2))
    r=math.radians(rot)
    axis=(-math.sin(r)*side, math.cos(r)*side); along=(math.cos(r),math.sin(r))
    spot=(centre[0]+axis[0]*(1.22+2.0+7.0), centre[1]+axis[1]*(1.22+2.0+7.0))
    fwd=(-axis[0],-axis[1]); right=(-fwd[1],fwd[0])
    hdg=math.degrees(math.atan2(fwd[1],fwd[0]))  # rect rotation: long axis is z for a hull; use rot of x-axis = right
    units=[(spot,'gang_tank')]
    if shape=='crawl':
        for (ox,oz),h in MATES:
            units.append(((spot[0]+right[0]*ox-fwd[0]*oz, spot[1]+right[1]*ox-fwd[1]*oz),h))
    issues=[]
    for (ux,uz),h in units:
        w,l=HULLS[h]
        # hull rect: width along right, length along fwd: rotation = angle of right axis
        rot_h=math.degrees(math.atan2(right[1],right[0]))
        poly=rect_pts(ux,uz,w,l,rot_h)
        hm=min(hex_margin(px,pz) for px,pz in poly)
        if hm<2.5: issues.append(f'{h} hex margin {hm:.1f}')
        for (x0,z0,x1,z1) in water:
            if any(x0-1<px<x1+1 and z0-1<pz<z1+1 for px,pz in poly): issues.append(f'{h} in water')
        for p in props:
            pw,pd=SIZES[p['type']]
            pp=rect_pts(p['position'][0],p['position'][1],pw,pd,p.get('rotation_deg',0.0))
            own = (h=='gang_tank' and (ux,uz)==spot and tuple(p['position'])==tuple(centre))
            if sat_overlap(poly,pp,0.0 if own else 1.0): issues.append(f'{h} overlaps {p["type"]} at {p["position"]}')
    print(f'{label}: {arena} box {centre} rot {rot} side {side} {shape} -> spot ({spot[0]:.1f}, {spot[1]:.1f}) fwd ({fwd[0]:.2f},{fwd[1]:.2f}) :: ' + ('; '.join(issues) if issues else 'CLEAN'))
if __name__=='__main__':
    for line in sys.stdin:
        if not line.strip() or line.startswith('#'): continue
        arena,cx,cz,rot,side,shape=line.split()[:6]
        check(arena,(float(cx),float(cz)),float(rot),int(side),shape,line.strip())
