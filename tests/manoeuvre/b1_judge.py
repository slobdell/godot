#!/usr/bin/env python3
"""Bar B1 (round 44, manoeuvre): the nose-on crews' time to clear, base v arm, from Bar S's workload logs (manoeuvre-bar-s).

A crew is NOSE-ON at its order when the START_RUN row's nose_room_m (the probe's navmesh run past the nose at its first traced tick,
the backout rule's own test) is under NOSED_ROOM_M; on a log without it, when the ray from its first pose along its heading meets a container's footprint
(ArenaKit container_20 / container_40, from arenas/<arena>.json: long axis x, rotated by rotation_deg) within NOSED_REACH_M, and its
squad's bound is a War Rig squad's (bound_m >= 30: the long hulls the rule is about). The same classifier, read from BASE's rows,
names the crews in both arms. Its time to clear = the first START_ROW tick at which it stands CLEAR_M or more from its first spot
(rows every 5 ticks; never within the trace = the trace's end). Deciding: the mean time to clear over the nose-on crews ARM < BASE
by >= 2 paired se (paired per crew, each cell's base v arm) AND pooled ARM < BASE. Floor: at least FLOOR nose-on crews in base,
else INCONCLUSIVE.
  python3 tests/manoeuvre/b1_judge.py <dir of locks-<arm>-s<seed>.log> --base=base --arm=bo [--project=<repo root>]
"""
import glob, json, math, os, re, sys

NOSED_ROOM_M = 4.0     # Movement.BACKOUT_NOSED_M: the START_RUN row's nose_room_m (the probe's own navmesh run past the nose)
NOSED_REACH_M = 11.0   # the fallback for logs without nose_room_m: 7 m (a War Rig's half length) + the rule's 4 m, a ray v containers
CLEAR_M = 8.0
FLOOR = 12
ROW = re.compile(r"START_ROW t=(\d+) n=(\S+) x=(\S+) z=(\S+) hdg=(\S+) spd=(\S+) ")
REVERSE_MPS = -0.3     # a row (every 5 ticks) with the hull's speed under this counts 5 ticks of reversing
WINDOW_TICKS = 450     # the first 15 s after the order (the workload's orders are at tick 0 / 56 / 141: read from order_tick)


def props(project, arena):
    data = json.load(open(os.path.join(project, "arenas", "%s.json" % arena)))
    out = []
    for p in data.get("props", []):
        if p["type"] == "container_20":
            out.append((p["position"][0], p["position"][1], 6.06, 2.44, p.get("rotation_deg", 0.0)))
        elif p["type"] == "container_40":
            out.append((p["position"][0], p["position"][1], 12.19, 2.44, p.get("rotation_deg", 0.0)))
    return out


def ray_hits(x, z, hdg_deg, boxes, reach):
    # heading 0 = -z (forward), positive = left (counter-clockwise from above): forward = (-sin h, -cos h)
    h = math.radians(hdg_deg)
    fx, fz = -math.sin(h), -math.cos(h)
    for (cx, cz, lx, lz, rot) in boxes:
        r = math.radians(rot)
        step = 0.25
        d = 0.0
        while d <= reach:
            px, pz = x + fx * d, z + fz * d
            rx, rz = px - cx, pz - cz
            lx_ = rx * math.cos(r) + rz * math.sin(r)
            lz_ = -rx * math.sin(r) + rz * math.cos(r)
            if abs(lx_) <= lx * 0.5 and abs(lz_) <= lz * 0.5:
                return True
            d += step
    return False


def read(path):
    poses, rows, run = {}, {}, None
    for line in open(path):
        if line.startswith("START_ROW"):
            m = ROW.match(line)
            if not m:
                continue
            t, n, x, z, hdg, spd = int(m.group(1)), m.group(2), float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6))
            if n not in poses and t <= 10:  # the first row (the workload traces every 5 ticks): the pose at the order
                poses[n] = (x, z, hdg)
            rows.setdefault(n, []).append((t, x, z, spd))
        elif line.startswith("START_RUN"):
            run = json.loads(line.split(" ", 1)[1])
    return poses, rows, run


def clear_tick(rows, pose, last):
    x0, z0 = pose[0], pose[1]
    for t, x, z, _ in rows:
        if math.hypot(x - x0, z - z0) >= CLEAR_M:
            return t
    return last


def reverse_ticks(rows, order_tick):
    return sum(5 for t, _, _, spd in rows if order_tick <= t < order_tick + WINDOW_TICKS and spd < REVERSE_MPS)


def paired(diffs):
    n = len(diffs)
    mean = sum(diffs) / n if n else 0.0
    sd = math.sqrt(sum((x - mean) ** 2 for x in diffs) / (n - 1)) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n > 1 else float("inf")
    return n, mean, se, (mean / se if se > 0 else 0.0)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    base, arm = opt.get("base", "base"), opt.get("arm", "bo")
    project = opt.get("project", os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    d = args[0]
    diffs, named, pooled_b, pooled_a, errors = [], 0, 0.0, 0.0, 0
    # The unneeded-back-up guards (R44, the orchestrator): among crews NOT nose-on, per arena, paired per cell: reversing ticks in the
    # first 15 s ARM <= BASE + 2 se, and crews seated within the bound by 15 s ARM >= BASE - 2 se.
    other_rev, other_seated = {}, {}
    for bf in sorted(glob.glob(os.path.join(d, "*-%s-s*.log" % base))):
        m = re.match(r"(\w+)-%s-s(\d+)\.log" % base, os.path.basename(bf))
        if not m:
            continue
        arena, seed = m.groups()
        af = os.path.join(d, "%s-%s-s%s.log" % (arena, arm, seed))
        if not os.path.exists(af):
            continue
        bp, br, brun = read(bf)
        ap, ar, arun = read(af)
        for f in (bf, af):
            if "SCRIPT ERROR" in open(f).read():
                errors += 1
        if brun is None or arun is None:
            continue
        bounds = {c["name"]: c.get("bound_m", 0.0) for c in brun["per_crew"]}
        rooms = {c["name"]: float(c.get("nose_room_m", -1.0)) for c in brun["per_crew"]}  # the probe's own nose test (-1: an older log)
        orders = {c["name"]: int(c.get("order_tick", 0)) for c in brun["per_crew"]}
        seated_b = {c["name"]: 1 if c.get("within_bound_15s") else 0 for c in brun["per_crew"]}
        seated_a = {c["name"]: 1 if c.get("within_bound_15s") else 0 for c in arun["per_crew"]}
        nosed = set()
        last = max((r[0] for rs in br.values() for r in rs), default=0)
        boxes = props(project, arena)
        for n, pose in bp.items():
            if bounds.get(n, 0.0) < 30.0 or n not in ap:
                continue
            room = rooms.get(n, -1.0)
            if room >= 0.0:
                if room >= NOSED_ROOM_M:  # the rule's test, read from the base log: the straight run past the nose
                    continue
            elif not ray_hits(pose[0], pose[1], pose[2], boxes, NOSED_REACH_M):
                continue
            nosed.add(n)
            named += 1
            tb = clear_tick(br.get(n, []), pose, last)
            ta = clear_tick(ar.get(n, []), ap[n], last)
            pooled_b += tb
            pooled_a += ta
            diffs.append(ta - tb)
            print("  %s %s %s: base clear t%d -> arm t%d" % (arena, seed, n, tb, ta))
        rb = sum(reverse_ticks(br.get(n, []), orders.get(n, 0)) for n in bp if n not in nosed and n in ap)
        ra = sum(reverse_ticks(ar.get(n, []), orders.get(n, 0)) for n in bp if n not in nosed and n in ap)
        sb = sum(seated_b.get(n, 0) for n in bp if n not in nosed and n in ap)
        sa = sum(seated_a.get(n, 0) for n in bp if n not in nosed and n in ap)
        other_rev.setdefault(arena, []).append(ra - rb)
        other_seated.setdefault(arena, []).append(sa - sb)
    print("Bar B1 judge: %s v %s, nose-on crews %d (floor %d), files with SCRIPT ERROR %d" % (base, arm, named, FLOOR, errors))
    guards_ok = True
    for arena in sorted(other_rev):
        n, mean, se, z = paired(other_rev[arena])
        ok = z <= 2.0
        guards_ok &= ok
        print("G %-9s other crews' reversing ticks (15 s): paired mean %+.1f a run, se %.1f (%+.1f se); line <= +2 se: %s" % (arena, mean, se, z, "PASS" if ok else "FAIL"))
        n, mean, se, z = paired(other_seated[arena])
        ok = z >= -2.0
        guards_ok &= ok
        print("G %-9s other crews seated by 15 s: paired mean %+.2f a run, se %.2f (%+.1f se); line >= -2 se: %s" % (arena, mean, se, z, "PASS" if ok else "FAIL"))
    if named < FLOOR:
        print("VERDICT: INCONCLUSIVE (under the floor)")
        return
    n, mean, se, z = paired(diffs)
    ok = z <= -2.0 and pooled_a < pooled_b and errors == 0 and guards_ok
    print("D2 nose-on time to clear %.1f m (ticks): pooled %.0f -> %.0f (mean a crew %.1f -> %.1f); paired mean %+.2f, se %.2f (%+.1f se); line <= -2 se and ARM < BASE: %s"
          % (CLEAR_M, pooled_b, pooled_a, pooled_b / n, pooled_a / n, mean, se, z, "PASS" if ok else "FAIL"))
    print("VERDICT: %s" % ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main()
