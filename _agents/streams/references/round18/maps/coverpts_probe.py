"""Mirror of CoverMap's static tactical points (game/ai/cover_map.gd: rings at 3.5 and 7.5 m from each feature's faces,
every 3 m, standable >= 2.6 m from every feature): how many lie within the idle covering reach (45 m) of the middle
(the box |x| <= 18, |z| <= 24 a line crosses), and how many of those SEE some of it at eye level."""
import json, math, sys
sys.path.insert(0, "tools")
import arena_report as ar, arena_room as R
RINGS, SPACING, STAND, REACH = (3.5, 7.5), 3.0, 2.6, 45.0
mid = [(x, z) for x in range(-18, 19, 6) for z in range(-24, 25, 6)]
def dist_mid(x, z):
    return math.hypot(max(abs(x) - 18, 0), max(abs(z) - 24, 0))
for name in sys.argv[1:]:
    L = json.load(open("arenas/%s.json" % name))
    boxes, blocked, n = R.ground(L)
    tall = [b for b in boxes if b.h >= ar.EYE_HEIGHT]
    grid, gn = ar.sight_grid(boxes)
    pts = []
    for b in tall:
        for c in RINGS:
            hw, hd = b.w / 2 + c, b.d / 2 + c
            per = 4 * (hw + hd)
            k = max(4, int(per / SPACING))
            for i in range(k):
                t = per * i / k
                if t < 2 * hw: lx, lz = -hw + t, -hd
                elif t < 2 * hw + 2 * hd: lx, lz = hw, -hd + (t - 2 * hw)
                elif t < 4 * hw + 2 * hd: lx, lz = hw - (t - 2 * hw - 2 * hd), hd
                else: lx, lz = -hw, hd - (t - 4 * hw - 2 * hd)
                x = b.x + lx * b.c + lz * b.s; z = b.z - lx * b.s + lz * b.c
                if not R.free_at(blocked, n, x, z) or any(o.distance(x, z) < STAND for o in boxes):
                    continue
                pts.append((x, z))
    near = [p for p in pts if dist_mid(*p) <= REACH]
    seeing = [p for p in near if any(ar.sees(grid, gn, p[0], p[1], mx, mz) for mx, mz in mid if math.hypot(p[0]-mx, p[1]-mz) <= REACH)]
    flank = [p for p in seeing if abs(p[0]) > 40]
    print("COVERPTS %-12s tall features %3d | cover points %5d | within 45 m of the middle %4d | seeing it %4d | of those out on a flank (|x|>40) %4d"
          % (name, len(tall), len(pts), len(near), len(seeing), len(flank)), flush=True)
