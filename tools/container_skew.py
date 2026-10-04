"""Containers placed by people (yard, round 17, Y3): every ground-level container turns a few seeded degrees off the
angle its layout authored, IN THE LAYOUT (`rotation_deg`), so the collider turns with the picture.

The lead (2026-10-03): *"For all cases of containers on maps, I think we should rotate them just slightly so that it
doesn't look synthetic."* The amount is `ContainerProp.GROUND_SKEW_DEG` (game/theme/arena_kit/containers/
container_prop.gd), READ from there so the frames page's "too much" is a one-line change in one file.

`skew(half_props, fixed)` runs inside `write_v2` on the authored HALF, before `mirrored_props` writes its 180 degree
twin, so a turned container's mirror is turned the same way about the centre and the map stays fair by construction.
It is deterministic: the turn is seeded by the container's kind and authored position (crc32, not Python's salted
`hash`), so the same layout source always writes the same JSON, and a map and its dry twin turn identically.

**The traps, enforced here rather than hoped for** (each pair is judged against the SAME pair in the square layout):
- *A wall stays a wall.* Two colliders that touched or overlapped before (a joint) still overlap after, by at least
  `min(before, JOINT_M)`. Two convex boxes that overlap form a connected set, so no straight ray -- a sight line or a
  shell -- crosses a run between its far ends without hitting one of them.
- *No street lost, no poking through.* A container that sat flush against a city block keeps the block's angle (pushed
  against a wall, a box sits parallel to it; turned, it either sinks into the wall or takes street width). One flush
  against anything else (a wall, a wreck) is slid away along the contact's normal until it is flush again.
- *No new joint and no lost gap.* Two colliders apart before stay apart (a slit a ray used to see through stays open).
- *Spawn clearance* holds (`Arena.SPAWN_CLEARANCE`).
- *Deep overlaps turn together.* Two containers overlapping by more than a joint (the Pit's gate pillars, a box laid
  across a run's end) are one placement: the later one takes the earlier one's turn.
A prop authored with `_square=True` is held at its authored angle (the key is removed here; it never reaches the JSON).
When a candidate turn breaks any of these it is halved, then halved again, then zero (the authored angle, which
passes by definition). What was given up is printed (`CONTAINER_SKEW`), so nothing is reduced silently.
"""
import math
import zlib

import gdscript_source

KINDS = {"container_20": 6.06, "container_40": 12.19}
WIDTH = 2.44
## A joint must keep at least this much overlap (or what it had, if less): enough that a physics ray at a joint meets
## steel, which a 0 cm kiss does not promise.
JOINT_M = 0.03
## A container slid off something flush keeps this much contact with it (invisible; closes the joint to a ray).
FLUSH_M = 0.005
## Buildings (`ArenaKit` "block"): a container flush against one keeps its angle (see `skew`).
SOLID_KINDS = ("block",)
## Pairs closer than this were touching (a joint); further apart, a gap that must stay a gap.
TOUCH_M = 0.01
## Overlap past which two containers are one placement (more than any run's end overlap, 0.19 m).
DEEP_M = 1.0
## A turned box's magnitude never drops under this share of the maximum, so almost nothing is left square.
MIN_SHARE = 0.35

PROP_GD = gdscript_source.GAME / "theme" / "arena_kit" / "containers" / "container_prop.gd"


def amounts():
    """(GROUND_SKEW_DEG, GROUND_SKEW_20_SCALE), read from ContainerProp."""
    return (gdscript_source.const_float(PROP_GD, "GROUND_SKEW_DEG"),
            gdscript_source.const_float(PROP_GD, "GROUND_SKEW_20_SCALE"))


class Box:
    """A collider's footprint: centre, half extents along its local x (length) and z (width), and yaw (Basis(UP, a):
    local x -> world (cos a, -sin a), local z -> (sin a, cos a))."""

    def __init__(self, x, z, rot_deg, hx, hz, kind=""):
        self.x, self.z, self.rot, self.hx, self.hz, self.kind = x, z, rot_deg, hx, hz, kind
        a = math.radians(rot_deg)
        self.ax = (math.cos(a), -math.sin(a))
        self.az = (math.sin(a), math.cos(a))

    def corners(self):
        return [(self.x + sx * self.hx * self.ax[0] + sz * self.hz * self.az[0],
                 self.z + sx * self.hx * self.ax[1] + sz * self.hz * self.az[1])
                for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def penetration(a, b):
    """Separating-axis overlap of two boxes: (depth, axis). depth > 0 overlap along the shallowest axis; < 0 the
    boxes are apart (by at least -depth along that axis). axis points from b towards a."""
    best, best_axis = math.inf, (1.0, 0.0)
    ca, cb = a.corners(), b.corners()
    for axis in (a.ax, a.az, b.ax, b.az):
        pa = [x * axis[0] + z * axis[1] for x, z in ca]
        pb = [x * axis[0] + z * axis[1] for x, z in cb]
        depth = min(max(pa), max(pb)) - max(min(pa), min(pb))
        if depth < best:
            best, best_axis = depth, axis
    if (a.x - b.x) * best_axis[0] + (a.z - b.z) * best_axis[1] < 0:
        best_axis = (-best_axis[0], -best_axis[1])
    return best, best_axis


def turn_for(kind, x, z, max_deg, scale_20):
    """The seeded turn, in degrees, for a container of `kind` authored at (x, z)."""
    h = zlib.crc32(("%s:%.2f:%.2f" % (kind, x, z)).encode())
    share = MIN_SHARE + (1.0 - MIN_SHARE) * ((h & 0xFFFF) / 65535.0)
    sign = 1.0 if (h >> 16) & 1 else -1.0
    most = max_deg * (scale_20 if kind == "container_20" else 1.0)
    return sign * share * most


def _box(kind_sizes, p, x=None, z=None, rot=None):
    hx, hz = kind_sizes[p["type"]]
    return Box(p["position"][0] if x is None else x, p["position"][1] if z is None else z,
               float(p.get("rotation_deg", 0.0)) if rot is None else rot, hx, hz, p["type"])


def _mirror(box):
    return Box(-box.x, -box.z, (box.rot + 180.0) % 360.0, box.hx, box.hz, box.kind)


def skew(half_props, fixed=(), spawns=(), clearance=0.0, kit=None, label="", log=print):
    """Turn every container of `half_props` (the authored half, list of prop dicts) by its seeded amount, keeping the
    traps above. `fixed`: dicts of every other collider in the WHOLE layout that is not a half prop (obstacles and
    their mirrors) as {"type", "position", "rotation_deg", "size": [x, y, z]}. `kit`: type -> (size, cover, collides)
    (arena_report.KIT). Returns new prop dicts; the input is not changed."""
    max_deg, scale_20 = amounts()
    sizes = {t: (s[0] / 2.0, s[2] / 2.0) for t, (s, _, collides) in kit.items() if collides}
    props = [dict(p) for p in half_props]
    colliding = [i for i, p in enumerate(props) if p["type"] in sizes]
    original = {i: _box(sizes, props[i]) for i in colliding}
    fixed_boxes = [Box(o["position"][0], o["position"][1], float(o.get("rotation_deg", 0.0)), o["size"][0] / 2.0, o["size"][2] / 2.0,
                       o["type"]) for o in fixed]
    containers = [i for i in colliding if props[i]["type"] in KINDS]
    current = dict(original)  # every collider's box: containers as turned once decided, everything else as authored
    decided = set(colliding) - set(containers)
    reduced = 0
    for i in containers:
        p = props[i]
        here = original[i]
        reach = here.hx + here.hz + 1.0
        # Each pair is judged once, when its second member is placed: against containers already decided (and their
        # mirrors), everything that is not a container, and this container's own mirror (which turns with it).
        before = []  # (resolve(candidate) -> the neighbour's box now, the neighbour as authored, is_container, ref)
        for j in colliding:
            for mirror in (False, True):
                if j == i and not mirror:
                    continue
                if j != i and j not in decided:
                    continue
                then = _mirror(original[j]) if mirror else original[j]
                if math.hypot(then.x - here.x, then.z - here.z) > reach + then.hx + then.hz:
                    continue
                if j == i:
                    resolve = _mirror
                else:
                    fixed_now = _mirror(current[j]) if mirror else current[j]
                    resolve = (lambda box: (lambda _cand: box))(fixed_now)
                before.append((resolve, then, props[j]["type"] in KINDS, j))
        for b in fixed_boxes:
            if math.hypot(b.x - here.x, b.z - here.z) <= reach + b.hx + b.hz:
                before.append(((lambda box: (lambda _cand: box))(b), b, False, None))
        judged = []
        for resolve, then, is_container, ref in before:
            depth, axis = penetration(here, _mirror(here) if ref == i else then)
            judged.append((resolve, is_container, ref, depth, axis))
        wanted = 0.0 if p.pop("_square", False) else turn_for(p["type"], here.x, here.z, max_deg, scale_20)
        # Pushed against a building, a container sits parallel to its wall: a turn would either sink its far corner
        # into the wall (~0.4 m on a 40 ft box: it reads as embedded) or swing it into the street (the Terminus kerb
        # boxes: a lost turning pocket, round 17). So a box flush against a city block keeps the block's angle.
        against_wall = any(resolve(here).kind in SOLID_KINDS and -TOUCH_M <= depth <= DEEP_M
                           for resolve, is_container, ref, depth, axis in judged if not is_container)
        if against_wall:
            wanted = 0.0
            # Tell the visual which side the wall is on (look key `wall`, in the box's own frame: x along its length,
            # z across), so its stacked levels slide off the building instead of into it (container_prop.gd).
            for resolve, is_container, ref, depth, axis in judged:
                if not is_container and resolve(here).kind in SOLID_KINDS and -TOUCH_M <= depth <= DEEP_M:
                    toward = (-axis[0], -axis[1])
                    p["wall"] = [round(toward[0] * here.ax[0] + toward[1] * here.ax[1]),
                                 round(toward[0] * here.az[0] + toward[1] * here.az[1])]
                    break
        for resolve, is_container, ref, depth, axis in judged:
            if is_container and depth > DEEP_M and ref is not None and ref != i:
                wanted = current[ref].rot - original[ref].rot  # one placement: a mirror's turn is the same turn
                break
        accepted = None
        for share in (1.0, 0.5, 0.25, 0.0):
            cand = Box(here.x, here.z, here.rot + wanted * share, here.hx, here.hz)
            # Slide off anything that is not a container and that it sat flush against (a wreck, a wall), along the
            # square layout's contact normal, until it is as flush as it was.
            for resolve, is_container, ref, depth, axis in judged:
                if is_container or depth > DEEP_M or depth < -TOUCH_M:
                    continue
                other = resolve(cand)
                pa = [x * axis[0] + z * axis[1] for x, z in cand.corners()]
                pb = [x * axis[0] + z * axis[1] for x, z in other.corners()]
                along = max(pb) - min(pa)
                # Leave FLUSH_M of contact: rounding to the millimetre must not open a hairline a ray slips through.
                if along > max(depth, 0.0) + FLUSH_M + 0.002:
                    push = along - max(depth, 0.0) - FLUSH_M
                    cand = Box(cand.x + axis[0] * push, cand.z + axis[1] * push, cand.rot, cand.hx, cand.hz, cand.kind)
            if _passes(cand, judged, spawns, clearance):
                accepted = (share, cand)
                break
        share, cand = accepted
        if share < 1.0:
            reduced += 1
            log("CONTAINER_SKEW %s: %s at [%g, %g] turned %.2f deg of the seeded %.2f (a joint, a contact or a spawn)"
                % (label, p["type"], here.x, here.z, wanted * share, wanted))
        current[i] = cand
        decided.add(i)
        p["rotation_deg"] = round(cand.rot % 360.0, 3)
        p["position"] = [round(cand.x, 3), round(cand.z, 3)]
    if containers:
        moved = sum(1 for i in containers if math.hypot(current[i].x - original[i].x, current[i].z - original[i].z) > 1e-6)
        turned = sum(1 for i in containers if abs(current[i].rot - original[i].rot) > 1e-6)
        log("CONTAINER_SKEW %s: %d of %d containers in the half turned (the rest against a building), %d less than "
            "seeded, %d slid off a contact" % (label, turned, len(containers), reduced, moved))
    return props


def _passes(cand, judged, spawns, clearance):
    for resolve, is_container, ref, depth, axis in judged:
        after, _ = penetration(cand, resolve(cand))
        if depth >= -TOUCH_M:
            # A joint stays closed; nothing flush gets buried.
            if after < min(depth, JOINT_M) - 1e-4:
                return False
            # Nothing flush gets buried.
            if not is_container and depth < DEEP_M and after > max(depth, 0.0) + 0.01:
                return False
        elif after >= -0.005:
            return False  # a gap that was a gap closes: a slit somebody saw through is gone
    for x, z in spawns:
        if _distance(cand, x, z) < clearance:
            return False
    return True


def _distance(box, px, pz):
    dx, dz = px - box.x, pz - box.z
    lx = dx * box.ax[0] + dz * box.ax[1]
    lz = dx * box.az[0] + dz * box.az[1]
    return math.hypot(max(abs(lx) - box.hx, 0.0), max(abs(lz) - box.hz, 0.0))
