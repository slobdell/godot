class_name TacticsFormation
extends RefCounted
## THE formation system (round 6, N2): every formation in the game — a player's group move, a squad, an element's
## leader, the CPU — is laid out, seated and paced here. Round 5 had three (`GroupFormation` for plain moves,
## `Formations` + `Squad` for squads, this file for elements), with three shape tables, three assignment rules and
## three pacing rules; the lead read the result as *"I don't think we have any coherent formations working"*.
## `Formations` and `GroupFormation` are now thin adapters over this file and own no geometry of their own.
##
## Pure math, no engine state, no randomness: the same inputs always give the same slots, on every peer.
##
## A slot is Vector2(right, back) meters in the element's frame: x > 0 is to the element's right, y > 0 is
## BEHIND it. Slot 0 is the leader's (the point of the wedge, the head of the column).
## Shapes and their purpose come from US Army movement formations for a platoon (ATP 3-20.15 *Tank Platoon*
## ch. 2; ATP 3-21.8 *Infantry Platoon and Squad* ch. 2); the citations and the "what it's for" line per shape
## are in _agents/doctrine.md.
##
##   N2  slots(element, anchor, heading, count) -> [{"unit", "to", "facing", "role", ...}]   the contract
##       place(members, formation, anchor, heading, spacing, opts) -> the same, from plain member data
##       seat(members, offsets, ...) -> {unit: slot index}     who stands where (see seat() for the rule)
##   offsets(formation, count, spacing) -> Array[Vector2]   raw slots, leader at the origin (any size)
##   X1  pitch(members, spacing) -> Vector2(across, along)  the spacing the slots are really laid at: the doctrine's
##                                                          number, floored by the members' own hulls, per axis
##       offsets_at(formation, count, pitch) -> the shape at that per-axis pitch
##       closest_boxes(members, formation, spacing) -> clear ground between the two closest hulls
##   centered(offsets) -> Array[Vector2]                    the same shape around its own middle (movement anchor)
##   auto(count, verb, requested, all_fast) -> String       the shape a group uses when nobody named one
##   sectors(formation, count) -> Array[float]              each slot's sector of fire, degrees from the heading
##                                                          (0 = ahead, + = right), so the element covers itself
##   frontage/depth(formation, count, spacing) -> float     how wide and how deep the shape is (meters)
##   to_world(anchor, heading, offset) -> Vector3           slot -> world, and facing_of() for halts
##   pace(remaining, top_speed, group_eta) -> float         arrive together: the speed fraction for one member
##
## The herringbone is the halt formation that alternates vehicles 45-90 degrees left and right of the axis;
## `rows` is the block a big group (more than a platoon) moves in.

## Formation ids. The L1 contract names column, wedge, line, echelon_left/right and herringbone; vee and coil
## are the two other shapes real platoons use (a V of scouts, and the 360-degree halt in the open).
const NAMES := ["column", "wedge", "vee", "line", "echelon_left", "echelon_right", "herringbone", "coil",
		"swarm", "ring"]
## Shapes that are not doctrine formations but still lay out a group: `rows` (a block, front row first, for groups
## bigger than a platoon) and `single` (one vehicle: its slot is the destination).
const GROUP_SHAPES := ["rows", "single", "block"]
const DEFAULT := "wedge"
## Meters between neighbors when the doctrine table doesn't say.
const DEFAULT_SPACING := 12.0
## Wedge and echelon slots sit this fraction of the spacing out to the side (a 45-degree-ish diagonal).
const DIAGONAL_SIDE := 0.9
## Herringbone: lateral offset as a fraction of spacing, and how far its middle vehicles turn off the axis
## (degrees) — they point their hulls and guns at the flanks instead of traversing turrets later.
const HERRINGBONE_SIDE := 0.55
const HERRINGBONE_FACING := 90.0
## Sector of fire a single vehicle is responsible for (degrees). Overlap between neighbors is deliberate:
## interlocking fires are the point of assigning sectors at all.
const SECTOR_WIDTH := 90.0
## The swarm: how much wider than a line it spreads, and how far vehicles stagger fore and aft. It is not a
## formation any manual would recognise, which is the point — a pack that has never drilled doesn't hold a
## line, it comes at you loose and all at once, and being spread means one shell is one vehicle.
const SWARM_SPREAD := 1.9
const SWARM_STAGGER := 0.8
## The ring (encircle): how far out the pack orbits a target, as a multiple of spacing.
const RING_RADIUS := 2.4

# ---- The hull floor under the doctrine's spacing (round 9, X1) ------------------------------------------
#
# A doctrine's spacing (open 14 / lanes 11 / dense 8 m) is a TACTICAL number: how dispersed the element wants to
# be. It says nothing about how big its vehicles are, so a 14 m War Rig at 8 m "dense" spacing stands inside the
# rig in front of it, and the scale stream's resize (CP2) puts the whole mid-roster in the same position. The floor
# below sits UNDER the doctrine number — it never reduces it — and it is ANISOTROPIC, because side by side a
# vehicle needs its WIDTH clear and nose to tail its LENGTH: a column of rigs needs length between slots and a line
# of rigs needs width. That is the same rule `ArmyLayout._shape_of` applies at deploy, hoisted to where slots are
# laid so every formation in the game gets it (ArmyLayout now calls it rather than keeping its own copy).

## Clear ground between two hulls standing in neighbouring slots (meters).
const HULL_CLEAR_M := 2.0
## A member whose unit id is not in the catalogue (a test's bare name) contributes no hull.
const NO_HULL := Vector2.ZERO


## The biggest hull among `members` ({"unit"?: id}), as Vector2(width, length). Vector2.ZERO when no member names a
## unit the catalogue knows, so a caller with bare names gets today's behaviour unchanged.
## `hull_size` is [width, height, length]; min/max rather than [0]/[2] so a box authored the other way round still
## floors the right axis (the same defensive read `ArmyLayout` has always used).
static func hull_extent(members: Array) -> Vector2:
	var widest := 0.0
	var longest := 0.0
	for member: Dictionary in members:
		var unit := String(member.get("unit", ""))
		if not Units.exists(unit):
			continue
		var hull: Array = Units.stat(unit, "hull_size", [0.0, 0.0, 0.0])
		if hull.size() < 3:
			continue
		widest = maxf(widest, minf(float(hull[0]), float(hull[2])))
		longest = maxf(longest, maxf(float(hull[0]), float(hull[2])))
	return NO_HULL if longest <= 0.0 else Vector2(widest, longest)


## The smallest slot pitch `members` physically fit in, as Vector2(across the heading, along it): the widest hull's
## width and the longest hull's length, each plus HULL_CLEAR_M. Vector2.ZERO for members with no known hull.
static func hull_floor(members: Array) -> Vector2:
	var extent := hull_extent(members)
	return NO_HULL if extent == NO_HULL else extent + Vector2(HULL_CLEAR_M, HULL_CLEAR_M)


## The pitch a formation of `members` is actually laid out at: the doctrine's tactical `spacing`, raised per axis to
## the hull floor where that spacing would put hulls inside each other. Vector2(across, along).
static func pitch(members: Array, spacing := DEFAULT_SPACING) -> Vector2:
	var s := maxf(spacing, 1.0)
	var floor_v := hull_floor(members)
	return Vector2(maxf(s, floor_v.x), maxf(s, floor_v.y))


## `group_offsets()` with a per-axis pitch: the shape at the ALONG pitch with the across axis scaled by the ratio.
## Exact, because every shape here is homogeneous of degree 1 in its spacing (`ArmyLayout` has always relied on
## it), and with an isotropic pitch it IS group_offsets(), on the same code path, bit for bit — which is why a
## formation whose hull floor does not bind is laid out exactly as before.
## This is the degenerate DIAGONAL 2x2 transform that X2 (catalogue A8) generalises to a continuous affine one.
static func offsets_at(formation: String, count: int, pitch_v: Vector2) -> Array[Vector2]:
	var raw := group_offsets(formation, count, pitch_v.y)
	if pitch_v.y <= 0.0 or is_equal_approx(pitch_v.x, pitch_v.y):
		return raw
	var ratio := pitch_v.x / pitch_v.y
	var result: Array[Vector2] = []
	for slot in raw:
		result.append(Vector2(slot.x * ratio, slot.y))
	return result


# ---- A8: the affine deformation (round 9, X2) -----------------------------------------------------------
#
# A formation is a NOMINAL SHAPE plus a per-element transform. X1's per-axis pitch is the diagonal case of it; A8
# makes it continuous in the CORRIDOR WIDTH, so a wedge narrows to fit a defile and re-expands after it, without
# dissolving, without changing formation, and without re-seating anybody.
#
# WHY THIS IS A SHAPE MORPH PLUS A DIAGONAL MATRIX, AND NOT A 2x2 ALONE. A wedge has PAIRS OF SLOTS AT THE SAME
# DEPTH (slot 1 at -0.9s, slot 2 at +0.9s, both at y = s). No 2x2 can separate two points that differ only across
# the heading while squeezing that axis toward zero: at the limit they land on top of each other. So "a wedge
# becomes a column" is FALSE for an affine map alone, and a design that assumed otherwise would ship a formation
# that stands its own hulls inside each other in the narrowest corridors — the exact failure X1 exists to prevent.
# What IS continuous, closed-form and crossing-free is two terms applied in order:
#
#   1. FILE (`file`): the nominal shape is pulled toward single file. Depth first, then width — the ranks split
#      apart along the heading BEFORE the shape closes across it, because splitting is what makes closing safe.
#   2. PITCH: the result is scaled per axis, elongated along the heading as it is compressed across it (X1's
#      diagonal 2x2), and sheared by whatever the caller's heading change needs.
#
# Neither term can cross a path or invert a rank. The file's target order is the nominal shape's OWN DEPTH ORDER
# (`_depth_ranks`), not the slot index — a vee has slots AHEAD of its leader, and filing those to `(0, index)`
# would drive slot 1 from in front of the leader to behind it, which is a rank inversion and is precisely what
# A8's falsifier forbids. Filing to the shape's own depth order means every pair's depth difference keeps its sign
# at every value of `file`, so the order along the heading is preserved throughout the deformation.
#
# The clearance rule is X1's and it is a HARD post-condition, not an aspiration: `fit_to_corridor` will not return
# a deformation whose hull boxes are closer than HULL_CLEAR_M. Where the corridor is narrower than the tightest
# clear deformation, it says so (`fits: false`) rather than overlapping the hulls — a formation that does not fit a
# defile is information for the element, not a licence to stack vehicles.

## The narrowest a formation is squeezed across the heading, as a share of its natural frontage. Below this there is
## nothing left to squeeze and the shape is a file.
const MIN_SQUEEZE := 0.05
## A formation compressed across the heading lengthens along it — the dispersion it gives up sideways it takes back
## in depth — but NEVER PAST ITS OWN FOOTPRINT: the deformed shape may not be longer than the nominal one was at its
## widest. MEASURED, not chosen. With a flat 2.5x cap a five-vehicle wedge filing through the maze's 5 m corridor
## became ~80 m deep, its tail slot 80 m behind the anchor, and `ElementPlan._cohesive` — which gates the next leg on
## every member being within the doctrine's cohesion TIME of its slot — then never passed. The element paralysed
## itself: **1 of 5 arrived and it never got through the gap, against 4 of 5 with the deformation off** (maze, wheeled
## Condemned squad, seed 3, 70 s, laptop). That is lesson 17 in a new place — a gate above a behaviour that cancels it
## every tick — and the elongation was the thing feeding the gate. Bounding the deformed depth by the nominal shape's
## own largest extent keeps "deform, don't dissolve" literally true: the element ends up in a different shape, not in
## a longer place than it already occupied.
const MAX_ELONGATION := 2.5
## Clear ground kept between the outermost hull and each wall of the corridor.
const CORRIDOR_MARGIN_M := 1.0
## The guard: if the deformation the corridor asks for would put hulls inside each other (a shape whose geometry the
## two-phase policy does not cover), the squeeze is relaxed back toward the nominal shape through this many fixed
## steps and the first clear one is used. Fixed work, no tolerance loop, same answer on every machine.
const FIT_RELAX_STEPS := 8
## A8's A/B switch — and A8 SHIPS OFF, because the measurement it was built for says it makes the traverse worse.
##
## `make squad-defile`, the maze's 11 m gap (5.0 m of navmesh once the 2.0 m agent radius comes off each side), a
## five-vehicle wheeled Condemned squad in a forced wedge, 70 s, laptop, `DEFORM_ENABLED` the only thing changed:
##
##     deform=on    arrived 0/5   got through the gap: NO    crossings 6   inversions 21   file 1.0
##     deform=off   arrived 4/5   got through the gap: yes   crossings 1   inversions 20   file 0.0
##
## **The deformation is the difference between getting through and not getting through.** Filing the wedge to fit the
## corridor leaves the element unable to advance its leg at all, and it takes the crossings UP (6 against 1) rather
## than to the zero its falsifier promised. One configuration, not five seeds: the three seeds I ran returned
## byte-identical numbers, because this scenario has no enemies and hand-placed units, so the seed varies nothing
## (lesson 22 — repeating a measurement across a variant that does not vary is one sample, not three). It is a
## deterministic difference in a deterministic system, which is why one sample is enough to switch it off and not
## enough to explain it.
##
## **What the geometry still guarantees, and it is not nothing:** every invariant A8 pre-registered holds by
## construction and is asserted over a sweep in `tests/test_tactics_deform.gd` — hulls never overlap at any corridor
## width, the depth order never inverts, the frontage is monotone with no snap. The geometry is right. What is wrong
## is that a slot layout is the wrong place to express it.
##
## **The named follow-on, and nav reached the same structural conclusion independently the same night.** A8 deforms
## the SLOTS, and slots are consumed by `ElementPlan`'s leg machinery (`_advance` gates the next leg on `_cohesive`)
## and then by nav's `Movement`. nav measured that `CombatMotion` decides under a tenth of a hull's ticks in a fight
## and that `Movement` — which drives the other nine tenths — has no notion of a formation leash at all; its
## conclusion was that the region belongs in `Movement`'s goal selection. **The same is true of this deformation.**
## Both are formation-level intents that the layer actually moving the hull cannot see, and both need to land there
## rather than in the layer that publishes slots.
##
## Turning it on is one constant, and the A/B above is the thing to re-run after that seam exists.
static var DEFORM_ENABLED := false


## A8: how a formation of `members` fits a corridor `corridor_m` wide across its heading.
## Returns {"pitch": Vector2, "file": float, "shear": float, "corridor_m": float, "squeeze": float, "fits": bool}.
## Continuous and monotone in `corridor_m`; `fits` is false when even the tightest CLEAR deformation is wider than
## the corridor. With an unknown corridor (INF or <= 0) the answer is the IDENTITY — X1's pitch, no morph — because
## a formation must never be worse than today for the lack of a number.
static func fit_to_corridor(members: Array, formation: String, count: int, spacing: float, corridor_m: float,
		shear := 0.0) -> Dictionary:
	var pitch_v := pitch(members, spacing)
	var slots := maxi(count, members.size())
	var hull := hull_extent(members)
	var nominal := group_offsets(formation, slots, 1.0)
	var natural := _extent(nominal, true)
	var open := {"pitch": pitch_v, "file": 0.0, "shear": shear, "corridor_m": corridor_m, "squeeze": 1.0,
			"fits": true}
	if not DEFORM_ENABLED or not is_finite(corridor_m) or corridor_m <= 0.0 or natural <= 0.0 or slots < 2 \
			or hull == NO_HULL:
		return open
	# The share of its natural frontage that fits between the walls, hulls and margins included.
	var room := corridor_m - hull.x - 2.0 * CORRIDOR_MARGIN_M
	var want := clampf(room / (natural * pitch_v.x), MIN_SQUEEZE, 1.0)
	if want >= 1.0:
		return open
	# The tightest squeeze the NOMINAL shape survives: a pair of slots that no depth difference separates has to be
	# held apart across the heading, and that is one division per pair. Closed form, one pass.
	var split := _split_share(nominal, hull, pitch_v)
	# The footprint cap, as an ALONG-AXIS PITCH: the deformed shape's depth may reach the nominal shape's largest
	# extent (its frontage for a wide shape, its depth for a deep one) and no further. `slots - 1` is how many pitches
	# deep a full file is.
	var largest := maxf(_extent(nominal, true) * pitch_v.x, _extent(nominal, false) * pitch_v.y)
	var depth_cap := largest / float(maxi(slots - 1, 1))
	var best := open
	for step in FIT_RELAX_STEPS + 1:
		# Relax from what the corridor asked for back toward the nominal shape, and take the first CLEAR answer.
		var share := clampf(want + (1.0 - want) * float(step) / float(FIT_RELAX_STEPS), MIN_SQUEEZE, 1.0)
		var fit := _deformation(share, split, pitch_v, shear, corridor_m, depth_cap)
		best = fit
		if _clear_enough(offsets_deformed(formation, slots, fit), hull):
			break  # the tightest CLEAR deformation; the last step is the nominal shape, which X1 guarantees is clear
	var frontage_m := _extent(offsets_deformed(formation, slots, best), true) + hull.x \
			+ 2.0 * CORRIDOR_MARGIN_M
	best["fits"] = frontage_m <= corridor_m + 0.001
	return best


## The deformation for a frontage `share` (0..1 of the shape's natural frontage): squeeze across, elongate along,
## and file the ranks apart as it goes. `split` is the share below which the nominal shape's own width can no longer
## hold its hulls apart, so the file is COMPLETE exactly there — which is what makes `file` continuous, 0 in the
## open, and 1 by the time the squeeze would otherwise start stacking vehicles side by side.
## The frontage is `natural x pitch.x x share` at every value of `share` (filing moves depth, not width), so it is
## strictly monotone in the corridor width: narrower is always narrower, with no snap anywhere.
static func _deformation(share: float, split: float, pitch_v: Vector2, shear: float, corridor_m: float,
		depth_cap: float = INF) -> Dictionary:
	var squeeze := maxf(share, split)
	# Elongate along the heading as the shape is squeezed across it, but never past the footprint cap, and never
	# below X1's hull floor (which `pitch_v.y` already is): a deformation may change an element's shape, not put it
	# in a longer place than it started.
	var along := pitch_v.y * clampf(1.0 / squeeze, 1.0, MAX_ELONGATION)
	return {"pitch": Vector2(pitch_v.x * share, clampf(along, pitch_v.y, maxf(depth_cap, pitch_v.y))),
			"file": clampf((1.0 - share) / maxf(1.0 - split, 1e-6), 0.0, 1.0),
			"shear": shear, "corridor_m": corridor_m, "squeeze": share, "fits": true}


## The frontage share below which the nominal shape can no longer keep its hulls clear by width alone: the largest,
## over every pair of slots that no depth difference separates, of the share that pair needs across the heading.
## Pairs the shape already separates along the heading never bind, whatever the squeeze.
static func _split_share(nominal: Array[Vector2], hull: Vector2, pitch_v: Vector2) -> float:
	var need := hull.x + HULL_CLEAR_M
	var worst := 0.0
	for i in nominal.size():
		for j in range(i + 1, nominal.size()):
			var apart: Vector2 = (nominal[i] - nominal[j]).abs()
			if apart.y * pitch_v.y - hull.y >= HULL_CLEAR_M:
				continue  # separated along the heading: the squeeze cannot bring these two together
			if apart.x <= 1e-6:
				return 1.0  # two slots at the same place in the nominal shape: only the file can part them
			worst = maxf(worst, need / (apart.x * pitch_v.x))
	return clampf(worst, MIN_SQUEEZE, 1.0)


## Whether every pair of hull boxes in `slots` is at least HULL_CLEAR_M apart (the separating-axis rule).
static func _clear_enough(slots: Array[Vector2], hull: Vector2) -> bool:
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var apart: Vector2 = (slots[i] - slots[j]).abs()
			if maxf(apart.x - hull.x, apart.y - hull.y) < HULL_CLEAR_M - 0.001:
				return false
	return true


## The nominal shape's own depth order: slot index -> its place from front to back (ties by index). The file's
## target order, so filing never reorders the element along its heading.
static func _depth_ranks(nominal: Array[Vector2]) -> PackedInt32Array:
	var order: Array = range(nominal.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ya: float = nominal[a].y
		var yb: float = nominal[b].y
		return ya < yb if absf(ya - yb) > 1e-9 else a < b)
	var ranks := PackedInt32Array()
	ranks.resize(nominal.size())
	for place in order.size():
		ranks[int(order[place])] = place
	return ranks


## The nominal shape pulled `file` of the way toward single file, DEPTH FIRST: the ranks split apart along the
## heading over the first half of the morph, and the shape closes across it over the second. Slot i keeps its index
## and ends at (0, its depth rank), so nobody changes slot and nobody overtakes anybody.
static func _filed(nominal: Array[Vector2], file: float) -> Array[Vector2]:
	if file <= 0.0:
		return nominal
	var ranks := _depth_ranks(nominal)
	var deep := clampf(file, 0.0, 1.0)
	var result: Array[Vector2] = []
	for i in nominal.size():
		result.append(Vector2(nominal[i].x, lerpf(nominal[i].y, float(ranks[i]), deep)))
	return result


## The slots of a deformed formation: the nominal shape, filed, then scaled per axis and sheared.
## `fit` is fit_to_corridor()'s answer; with `file` 0 and no shear this IS offsets_at(), on the same code path.
static func offsets_deformed(formation: String, count: int, fit: Dictionary) -> Array[Vector2]:
	var pitch_v: Vector2 = fit.get("pitch", Vector2(DEFAULT_SPACING, DEFAULT_SPACING))
	var file := float(fit.get("file", 0.0))
	var shear := float(fit.get("shear", 0.0))
	if file <= 0.0 and is_zero_approx(shear):
		return offsets_at(formation, count, pitch_v)
	var shaped := _filed(group_offsets(formation, count, 1.0), file)
	var result: Array[Vector2] = []
	for slot in shaped:
		result.append(Vector2(slot.x * pitch_v.x + slot.y * shear, slot.y * pitch_v.y))
	return result


## Clear ground between the two closest HULL BOXES of a formation of `members` (meters; negative = overlapping).
## Every slot holds the biggest hull in the squad, so the answer is the conservative bound and does not depend on
## who is seated where. Boxes are axis-aligned with the heading, so a pair is clear when EITHER axis separates it —
## side by side needs width, nose to tail needs length — and the pair's clearance is that separating axis's gap.
## INF for a single vehicle or members with no known hull (nothing to keep clear of).
static func closest_boxes(members: Array, formation: String, spacing := DEFAULT_SPACING) -> float:
	var hull := hull_extent(members)
	if hull == NO_HULL or members.size() < 2:
		return INF
	var slots := offsets_at(formation, members.size(), pitch(members, spacing))
	var closest := INF
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var apart: Vector2 = (slots[i] - slots[j]).abs()
			closest = minf(closest, maxf(apart.x - hull.x, apart.y - hull.y))
	return closest


## Slots for `count` units in `formation`, leader first, at the origin.
static func offsets(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> Array[Vector2]:
	if formation == "rows":
		return rows(count, 0, spacing)
	var result: Array[Vector2] = []
	for i in maxi(count, 0):
		result.append(offset(formation, i, count, spacing))
	return result


static func offset(formation: String, i: int, count: int, spacing: float) -> Vector2:
	var s := maxf(spacing, 1.0)
	# Followers alternate sides: 1 left, 2 right, 3 further left, 4 further right.
	var side := -1.0 if i % 2 == 1 else 1.0
	var rank := float((i + 1) / 2)
	match formation:
		"column":
			return Vector2(0.0, i * s)
		"wedge":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s * DIAGONAL_SIDE, rank * s)
		"vee":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s * DIAGONAL_SIDE, -rank * s)
		"line":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s, 0.0)
		"echelon_right":
			return Vector2(i * s * DIAGONAL_SIDE, i * s)
		"echelon_left":
			return Vector2(-i * s * DIAGONAL_SIDE, i * s)
		"herringbone":
			# Still in column, but each vehicle pulls off the axis to the side it will cover.
			return Vector2(side * s * HERRINGBONE_SIDE, i * s * 0.8)
		"coil":
			var angle := TAU * i / maxi(count, 1)
			var radius := s * (0.7 if count <= 3 else 0.9) * sqrt(maxf(count, 1.0) / 4.0)
			return Vector2(sin(angle) * radius, -cos(angle) * radius)
		"swarm":
			# Wide and ragged: alternating sides, spreading as it goes out, each vehicle staggered fore or
			# aft so the pack has no line to shoot along. Deterministic, despite looking unruly.
			var rank_out := float((i + 1) / 2)
			var stagger := ((i * 7) % 5) - 2.0
			return Vector2(side * rank_out * s * SWARM_SPREAD, stagger * s * SWARM_STAGGER)
		"ring":
			# Around the enemy, not around a heading: the anchor of a ring is the thing being encircled.
			var step := TAU * i / maxi(count, 1)
			return Vector2(sin(step) * s * RING_RADIUS, -cos(step) * s * RING_RADIUS)
	return Vector2(0.0, 0.0)


## The same shape moved so its middle is the origin: what a movement anchor (the element's destination) uses,
## so "go there" puts the element's centre there, not its leader.
static func centered(raw: Array[Vector2]) -> Array[Vector2]:
	if raw.is_empty():
		return raw
	var middle := Vector2.ZERO
	for slot in raw:
		middle += slot
	middle /= float(raw.size())
	var result: Array[Vector2] = []
	for slot in raw:
		result.append(slot - middle)
	return result


## Each slot's sector of fire: the azimuth (degrees, 0 = the direction of travel, + = right) its crew watches.
## Together they cover the element: the front in the direction of travel, the flanks and rear where the shape
## is blind. SECTOR_WIDTH degrees wide each, so neighbours interlock.
static func sectors(formation: String, count: int) -> Array[float]:
	var result: Array[float] = []
	if count <= 0:
		return result
	match formation:
		"column":
			# Everyone but the lead (front) and the rear vehicle (rear) watches alternate flanks.
			for i in count:
				if i == 0:
					result.append(0.0)
				elif i == count - 1 and count > 2:
					result.append(180.0)
				else:
					result.append(90.0 if i % 2 == 0 else -90.0)
		"wedge", "vee":
			for i in count:
				if i == 0:
					result.append(0.0)
				else:
					var side := -1.0 if i % 2 == 1 else 1.0
					var rank := float((i + 1) / 2)
					result.append(side * minf(45.0 + 45.0 * (rank - 1.0), 135.0))
		"line":
			# Maximum fire forward: the frontage is split so the element's fires interlock across it.
			for i in count:
				var spread: float = 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 60.0
				result.append(spread)
		"echelon_right":
			for i in count:
				result.append(0.0 if i == 0 else minf(45.0 + 45.0 * (i - 1), 135.0))
		"echelon_left":
			for i in count:
				result.append(0.0 if i == 0 else -minf(45.0 + 45.0 * (i - 1), 135.0))
		"herringbone":
			# Lead watches ahead, the middle vehicles turn out to alternate flanks, the tail watches behind:
			# a halted column with every direction covered.
			for i in count:
				if i == 0:
					result.append(0.0)
				elif i == count - 1 and count > 2:
					result.append(180.0)
				else:
					result.append(HERRINGBONE_FACING if i % 2 == 0 else -HERRINGBONE_FACING)
		"coil", "ring":
			for i in count:
				result.append(rad_to_deg(TAU * i / count) - (360.0 if TAU * i / count > PI else 0.0))
		"swarm":
			# Everyone watches roughly forward, fanned wide: no sectors, no discipline, all eyes on the prey.
			for i in count:
				var spread: float = 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 120.0
				result.append(spread)
		_:
			for i in count:
				result.append(0.0)
	return result


## How much of the full circle the element's sectors watch, 0..1 (SECTOR_WIDTH each, overlap counted once).
## The measurement behind "why formations pay off": a column watching both flanks sees more than a clump.
static func coverage(formation: String, count: int) -> float:
	var watched := {}
	for azimuth in sectors(formation, count):
		for degree in range(int(round(azimuth - SECTOR_WIDTH * 0.5)), int(round(azimuth + SECTOR_WIDTH * 0.5))):
			watched[(degree + 720) % 360] = true
	return watched.size() / 360.0


## Width of the shape across the direction of travel (meters). Through group_offsets, so `rows`, `block` and
## `single` answer for the shape they actually lay out rather than reading 0 (round 9: `offsets()` has no case for
## them, so `frontage("block", ...)` was 0 for every count and every spacing).
static func frontage(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(group_offsets(formation, count, spacing), true)


## Length of the shape along the direction of travel (meters).
static func depth(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(group_offsets(formation, count, spacing), false)


## The closest two slots in the shape (meters): how much one splash or one burst can reach at once.
static func closest_pair(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	var slots := offsets(formation, count, spacing)
	var closest := INF
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			closest = minf(closest, slots[i].distance_to(slots[j]))
	return closest if is_finite(closest) else 0.0


## World position of a slot, given the element's anchor and its heading (a flat forward vector).
static func to_world(anchor: Vector3, heading: Vector3, slot: Vector2) -> Vector3:
	var forward := flat(heading)
	var right := Vector3(-forward.z, 0.0, forward.x)
	return Vector3(anchor.x, 0.0, anchor.z) + right * slot.x - forward * slot.y


## Which way a slot's crew faces at a halt: its sector of fire, turned into a world direction.
static func facing_of(formation: String, i: int, count: int, heading: Vector3) -> Vector3:
	var list := sectors(formation, count)
	if i < 0 or i >= list.size():
		return flat(heading)
	return rotate(flat(heading), deg_to_rad(list[i]))


## `heading` turned `radians` to the right (positive = clockwise seen from above, i.e. to the element's right).
static func rotate(heading: Vector3, radians: float) -> Vector3:
	var forward := flat(heading)
	# Turning right means turning toward the element's own right vector, (-forward.z, 0, forward.x).
	return (forward * cos(radians) + Vector3(-forward.z, 0.0, forward.x) * sin(radians)).normalized()


## A horizontal unit vector; Vector3.FORWARD when there's nothing to normalize.
static func flat(direction: Vector3) -> Vector3:
	var forward := Vector3(direction.x, 0.0, direction.z)
	return Vector3.FORWARD if forward.length_squared() < 1e-6 else forward.normalized()


static func _extent(slots: Array[Vector2], across: bool) -> float:
	if slots.is_empty():
		return 0.0
	var low := INF
	var high := -INF
	for slot in slots:
		var value := slot.x if across else slot.y
		low = minf(low, value)
		high = maxf(high, value)
	return high - low


# ---- Group shapes (from GroupFormation, round 5) --------------------------------------------------------

## Most units abreast in an automatic row, and in a holding line before it adds a second row.
const ROW_WIDTH := 5
const LINE_WIDTH := 8
## Most vehicles a doctrine shape is used for when nobody named one: a wedge of thirty is thirteen ranks deep, so
## a group bigger than a platoon moves as a block of rows instead.
const PLATOON := 5


## Rows abreast, front row first, each row centred on the line of travel. `width` 0 = automatic.
static func rows(count: int, width := 0, spacing := DEFAULT_SPACING) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	if width <= 0:
		width = mini(ROW_WIDTH, count) if count <= ROW_WIDTH * 2 else ceili(sqrt(count * 2.0))
	for i in count:
		var row := i / width
		var in_row := mini(width, count - row * width)
		var column := i - row * width
		result.append(Vector2((column - (in_row - 1) * 0.5) * spacing, row * spacing))
	return result


## The shape a group uses when nobody named one (`requested` is "auto" or a shape): one vehicle is "single"; a
## holding group forms a line (a block of rows past LINE_WIDTH); a platoon or less moves in a wedge; more, in rows.
## A named shape is honoured up to PLATOON vehicles, and becomes rows beyond, except a line, which stays a line.
static func auto(count: int, verb: String, requested := "auto") -> String:
	if count <= 1:
		return "single"
	if requested != "auto" and (NAMES.has(requested) or requested == "rows"):
		if requested == "line" or requested == "rows" or count <= PLATOON:
			return requested
		return "rows"
	if verb == "hold":
		return "line"
	return "wedge" if count <= PLATOON else "rows"


## Raw slots for a group shape (auto()'s answer): a line past LINE_WIDTH wraps into rows of that width.
static func group_offsets(formation: String, count: int, spacing: float) -> Array[Vector2]:
	if formation == "single" or count <= 1:
		return [Vector2.ZERO] as Array[Vector2]
	if formation == "line" and count > LINE_WIDTH:
		return rows(count, LINE_WIDTH, spacing)
	if formation == "block":
		# A compact assembly block: about as wide as it is deep (3 x 2 for six), so a squad reads as one cluster.
		return rows(count, ceili(sqrt(float(count))), spacing)
	return offsets(formation, count, spacing)


# ---- Seating: who stands in which slot -----------------------------------------------------------------

## Front to back when nothing better is known: armour in front, fragile and indirect-fire vehicles behind.
const ROLE_RANK := {"tank": 0, "burner": 1, "ifv": 2, "scout": 3, "lancer": 4, "artillery": 5}
## How much being at the FRONT of the shape counts toward a slot's exposure, next to being on its edge.
## Both matter: the point of a wedge and the outside of a line are where the fire comes from.
const FRONT_EXPOSURE := 1.5
## Hull points are worth this much armour thickness when ranking what a vehicle can take.
const HULL_PER_ARMOUR := 25.0
## Indirect fire and lasers go in the middle whatever their armour says. Artillery is better protected than a
## scout on paper, but it is the thing the element exists to protect, and a gun that is being shot at is not
## shooting (game_design.md: "protecting fragile units (artillery, Lancers)").
const PROTECTED_ROLES := ["artillery", "lancer"]
const PROTECTED_PENALTY := 100.0
## Two slots (or two vehicles) this close in exposure (or toughness) count as the same tier.
const TIER_TOLERANCE := 0.5
## The role rule outranks travel: breaking it once costs more than any amount of driving could.
const TIER_COST := 100000.0
const _PINNED := 1.0e9

# ---- A10: the seating solver (round 9, X4) --------------------------------------------------------------
#
# Rounds 6-8 seated an element with the Hungarian method plus TWO hysteresis patches bolted on afterwards:
# `STABLE_MARGIN` (keep last update's seating unless a new one saves half a spacing of driving, summed over the whole
# element) and round 8's `fixed` flag (keep it whatever it costs — added because a CPU crew fighting inside its slot's
# leash drifts ~10 m and the seating re-shuffled around the drift, re-ordering idle units). Both were symptoms of one
# thing: the solver had no notion that **the seat a unit already holds is worth something to it**. A10 puts that in
# the utilities where it belongs, and both patches are DELETED rather than layered under it.
#
# Why an auction rather than Hungarian with a regularisation term — four determinism properties we need, and which
# float-tolerance Hungarian variants do not have: pure integer arithmetic (no float reduction order, no tolerance
# test); a hard bid cap, so the work is fixed and never a convergence test; a bid order by unit name, so ties break
# the same way on every peer; and the previous seating entering as a first-class term rather than as a patch.
#
# **Lesson 153 is why nothing in the utility is clamped.** nav's `PENALTY_LEASH` saturated 10 m past its radius:
# harmless as one addend in a weighted sum, fatal as a priority level, because every far candidate tied at the
# ceiling and nothing ranked. An auction utility is exactly that kind of load-bearing number — a clamped driving term
# would tie two slots for a far unit and the bid queue's tie order (unit name) would silently decide the formation.
# So the driving term is monotone over the whole range it can see.

## Costs become integers at this scale: 10^4 per metre is 0.1 mm of resolution, and an arena-sized cost with the tier
## term stays far inside 64-bit.
const UTILITY_SCALE := 10000
## The auction's epsilon: how much a bid must beat the runner-up by, in the same integer units. 5 cm of driving —
## small enough that the assignment is within `members x epsilon` (a quarter of a metre) of optimal, large enough to
## bound the bidding.
const AUCTION_EPSILON := 500
## The hard cap: this many bids per member, then the rest are seated greedily by name. Fixed work, never a
## convergence test (determinism.md). MEASURED, not guessed: at 8 the auction hit the cap and fell to the greedy
## completion often enough to produce 6 spurious re-assignments in 512 under a half-metre nudge, where the Hungarian
## solver it replaces produced 0 — an approximation artefact, not a property of the incumbent bonus, which at half a
## spacing per unit is far too strong for a nudge to overcome. The work is trivial (this many bids x n slots of
## integer arithmetic, for an element of 3-8), so the cap is set where the approximation stops showing.
const AUCTION_BIDS_PER_UNIT := 64
## What the seat a unit already holds is worth to it, in spacings. This is the PRINCIPLED form of both patches it
## replaces: a re-solve cannot swap two units for a marginal gain, because each would have to give up this much, which
## is why round 8's "hold this seating whatever it costs" flag is no longer needed.
##
## ONE FULL SPACING, AND THE SIZE IS MEASURED RATHER THAN INHERITED. It started at 0.5 — the same magnitude as the
## `STABLE_MARGIN` it replaces — and that was the wrong number for a reason that was already written down: round 7
## added the `fixed` flag because **a CPU crew fighting inside its slot's leash drifts ~10 m off it**, and
## `test_tactics_scenarios`' five-squad CPU fight measures that drift at a **9.3 m mean** on this tree. Half a spacing
## is 7 m at the open spacing, so the drift could outbid the bonus, and the idle-order count the flag was added to
## zero came back as **1** (from round 7's 4-6 → 0). A hysteresis term has to exceed the noise it exists to resist, and
## the noise here was measured a round ago: one full spacing is 14 m against a 9.3 m drift.
##
## It is bounded the other way by the thing it must NOT resist: a formation transition, which moves slots by tens of
## metres AND clears the incumbency outright (`ElementPlan._previous_seating` returns {} when the shape or the count
## changes), so no bonus of any size can make a shape change sticky.
const INCUMBENT_SPACINGS := 0.5
## A unit this far (in spacings) from the slot it already holds counts as STANDING IN IT for costing purposes.
##
## This is the drift deadband, and it is what the incumbent bonus was doing badly. A vehicle holding station wanders --
## the measured CPU error is 9.3 m -- and that wander changes its distance to every slot, so the cheapest seating
## flickers and every flicker re-issues an order. A bonus big enough to outbid 9.3 m of flicker (1.0 spacing, 14 m) is
## also big enough to hold a seating that sends two units across each other, which is A10's own falsifier: that is the
## trade `test_formation_slots::test_nobody_swaps_slots_tick_to_tick` failed on. Treating a unit inside its leash as
## being AT its slot removes the flicker at its source instead of outbidding it, which leaves the bonus free to be
## small enough that no crossing can survive it. Same abstraction as `TankBrain.slot_leash`.
## Bracketed by measurement, not chosen: a crew that has drifted as far as a NEIGHBOURING slot is 1.34 spacings from
## its own (wedge of four, adjacent slots 18.8 m apart at 14 m spacing) and must keep its seating -- that is round 7's
## "sent once means seated once", and `test_tactics_tasks::test_a_plain_move_standing_on_its_spot_keeps_its_seating`
## drifts two crews onto each other's slots to say so. A seating that is genuinely wrong puts a unit 3.8 spacings from
## the slot it holds (46 m at 12 m spacing in `test_formation_slots::test_nobody_swaps_slots_tick_to_tick`) and must be
## dropped. 1.5 sits between them with room on both sides.
const ON_STATION_SPACINGS := 1.5


## Who stands where. `members` are {"name", "position"?: Vector3, "unit"?, "role"?}; `offsets` the slots (in the
## element's frame, placed at `anchor` along `heading`). Returns {name: slot index}.
##
## The rule, in order of precedence:
##   1. `leader` (a name, optional) keeps slot 0, the shape's own point: a leader that cannot see its element
##      cannot lead it.
##   2. Whatever can take a hit goes where the fire comes from. `policy` says where that is: "front" (the front
##      ranks first: a group on the move; game_design.md "heavies in front, fragile units behind") or "exposure"
##      (the outside of the shape and its point: a halted element; the lead, 2026-09-16, *"heavy armor on the
##      outside of a column, light armor on the inside"*). Vehicles of the same toughness are one tier, and so
##      are slots of the same exposure, so this rule only ever separates vehicles that really differ.
##   3. Within that, the least total driving. A minimum-total-distance matching never has two paths crossing (if
##      two did, swapping their ends would be shorter), so a unit keeps its relative place: the vehicle on the
##      left takes a slot on the left.
##   4. `previous` ({name: index}, the last seating) is worth INCUMBENT_SPACINGS × spacing of driving to the unit
##      holding it (A10's incumbent bonus), so no unit swaps slots with its neighbour for a marginal gain. It is a
##      term in the utility, not a rule applied afterwards: there is no separate "keep it whatever it costs" flag.
static func seat(members: Array, offsets: Array[Vector2], anchor := Vector3.ZERO, heading := Vector3.FORWARD,
		opts := {}) -> Dictionary:
	var count := members.size()
	var result := {}
	if count == 0 or offsets.is_empty():
		return result
	var slot_count := maxi(offsets.size(), count)
	var policy := String(opts.get("policy", "front"))
	var leader := String(opts.get("leader", ""))
	var spacing := float(opts.get("spacing", DEFAULT_SPACING))
	# Tiers: 0 = toughest vehicle / most exposed slot.
	var tough: Array = members.map(func(member: Dictionary) -> float: return toughness_of(member))
	var member_tier := _dense_rank(tough, true)
	var exposure: Array = []
	for slot in offsets:
		exposure.append(exposure_of(slot) if policy == "exposure" else -slot.y)
	var slot_tier := _dense_rank(exposure, true)
	var deepest := 0
	for tier: int in slot_tier:
		deepest = maxi(deepest, tier)
	var most_fragile := 0
	for tier: int in member_tier:
		most_fragile = maxi(most_fragile, tier)
	var pin := false
	for member: Dictionary in members:
		pin = pin or (leader != "" and String(member.get("name", "")) == leader)
	var world: Array[Vector3] = []
	for slot in offsets:
		world.append(to_world(anchor, heading, slot))
	# The seating we are already holding, resolved BEFORE the costs, because being on station changes them.
	var previous: Dictionary = opts.get("previous", {})
	var held := previous if _valid_seating(previous, members, offsets.size()) else {}
	var on_station := ON_STATION_SPACINGS * spacing
	# Square cost matrix: members (padded with empty seats) by slots (padded with nowhere).
	var cost: Array = []
	for i in slot_count:
		var row := PackedFloat64Array()
		row.resize(slot_count)
		for j in slot_count:
			if i >= count or j >= offsets.size():
				row[j] = 0.0 if i >= count else _PINNED
				continue
			var member: Dictionary = members[i]
			var value := 0.0
			if member.has("position"):
				var at: Vector3 = member["position"]
				var seat_held: int = int(held.get(String(member.get("name", "")), -1))
				# On station in the slot it already holds: cost it from the slot, not from where it has drifted to.
				if seat_held >= 0 and seat_held < world.size() \
						and Vector2(at.x - world[seat_held].x, at.z - world[seat_held].z).length() <= on_station:
					at = world[seat_held]
				value = Vector2(at.x - world[j].x, at.z - world[j].z).length()
			# THE ROLE RULE: stand in the slot whose exposure rank matches your toughness rank. Tiers are normalised
			# to 0..1 on both sides and the cost is the MISMATCH, so it is minimised exactly when the tiers line up
			# -- toughest in the most exposed slot, most fragile in the most sheltered -- and it is strictly
			# increasing in how far out of order a vehicle stands.
			#
			# Two earlier forms of this term both had a tier that the cost could not see, and each one let doctrine's
			# ordering survive only as an accident of the solver's tie-breaking:
			#   `m * (D - s)` alone charges a fragile vehicle for standing forward, but it is identically ZERO for
			#   the toughest vehicle (m = 0), so nothing pulls a heavy to the point. That is what shipped, and
			#   `test_control_group_moves`'s role tests went red the moment A10 changed how ties break.
			#   `m * (D - s) + (M - m) * s` adds the other half, but its s-coefficient is (M - 2m), which is zero at
			#   m = M/2: the MIDDLE tier goes indifferent instead of the top one. With tank/ifv/scout/lancer/artillery
			#   that is exactly the scout, which then shared the rear rank with the artillery and failed
			#   "the artillery stays behind the scout" on an equality.
			# A mismatch has no such tier: the coefficient of s never vanishes, because the quantity IS the distance
			# between the two ranks.
			# And it says NOTHING when there is no ordering to express. An element of one toughness tier (every
			# scattered-tanks test in the suite, and any single-vehicle-type squad in the game) has no heavies and no
			# fragiles, so the mismatch must vanish and leave the seating to driving distance. Normalising a single
			# tier to 0 while the slots still rank 0..1 would instead send every identical vehicle after the most
			# exposed slot, with a cost ten thousand times any distance -- which broke `paths_never_cross`,
			# `the_seating_is_the_least_driving` and four more the first time I wrote this.
			if most_fragile > 0 and deepest > 0:
				var member_rank := float(member_tier[i]) / float(most_fragile)
				var slot_rank := float(slot_tier[j]) / float(deepest)
				value += TIER_COST * absf(member_rank - slot_rank)
			if pin:
				var is_leader := String(member.get("name", "")) == leader
				if is_leader != (j == 0):
					value += _PINNED
			row[j] = value
		cost.append(row)
	# A10: costs become integer utilities (bigger is better), with the incumbent bonus as a term rather than a patch.
	var incumbent := INCUMBENT_SPACINGS * spacing
	var utility: Array = []
	for i in slot_count:
		var row := PackedInt64Array()
		row.resize(slot_count)
		var mine: int = int(held.get(String(members[i]["name"]), -1)) if i < count else -1
		for j in slot_count:
			var value := -(cost[i] as PackedFloat64Array)[j]
			if j == mine:
				value += incumbent
			row[j] = int(round(value * UTILITY_SCALE))
		utility.append(row)
	var best := _auction(utility)
	for i in count:
		result[String(members[i]["name"])] = best[i]
	return result


## How exposed a slot is: how far out of the middle of the shape it sits, and how far toward the front.
static func exposure_of(slot: Vector2) -> float:
	return slot.length() + FRONT_EXPOSURE * maxf(-slot.y, 0.0)


## What a vehicle can take, and whether it should have to: front and side armour plus hull, minus a heavy
## penalty for the roles an element is built to keep alive. A member is {"unit"?, "role"?}.
static func toughness_of(member: Dictionary) -> float:
	var unit := String(member.get("unit", ""))
	var role := String(member.get("role", Units.role_of(unit) if unit != "" else "scout"))
	var protected_penalty := PROTECTED_PENALTY if PROTECTED_ROLES.has(role) else 0.0
	if not Units.exists(unit):
		return -float(ROLE_RANK.get(role, 3)) - protected_penalty
	return Units.armor(unit, "front") + Units.armor(unit, "side") \
			+ float(Units.stat(unit, "max_health")) / HULL_PER_ARMOUR - protected_penalty


static func _valid_seating(previous: Dictionary, members: Array, slot_count: int) -> bool:
	if previous.size() < members.size():
		return false
	var taken := {}
	for member: Dictionary in members:
		var index: int = int(previous.get(String(member["name"]), -1))
		if index < 0 or index >= slot_count or taken.has(index):
			return false
		taken[index] = true
	return true


## Dense tiers of `values`: equal (within TIER_TOLERANCE) values share a tier; tier 0 is the highest value when
## `descending`.
static func _dense_rank(values: Array, descending: bool) -> Array:
	var order: Array = range(values.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var va := float(values[a])
		var vb := float(values[b])
		if absf(va - vb) > 1e-9:
			return va > vb if descending else va < vb
		return a < b)
	var tiers: Array = []
	tiers.resize(values.size())
	var tier := 0
	var last := 0.0
	for k in order.size():
		var value := float(values[order[k]])
		if k > 0 and absf(value - last) > TIER_TOLERANCE:
			tier += 1
			last = value
		elif k == 0:
			last = value
		tiers[order[k]] = tier
	return tiers


## A10: maximum-utility assignment by integer auction (Bertsekas 1988). `utility[i][j]` is what slot j is worth to
## bidder i, as an integer. Returns bidder -> slot.
##
## Each round the lowest-numbered unassigned bidder takes the slot with the best net value (utility minus the slot's
## current price) and raises that price by how much it beat the runner-up, plus AUCTION_EPSILON; whoever held the
## slot is displaced and bids again. Ties go to the LOWER slot index, and bidders are taken in index order — which is
## members' order, which `slot_order`/`place` keep by unit name — so two peers reach the same seating from the same
## inputs. Only integer + and − are used, so no float reduction order can differ between them.
##
## Bounded: at most AUCTION_BIDS_PER_UNIT bids per bidder, and whatever is still unassigned when the cap is reached is
## seated greedily (best remaining slot, bidders in index order). A cap that is reached is not a failure — it is a
## slightly worse assignment, deterministically arrived at — and with epsilon-complementary slackness the completed
## answer is within `n x AUCTION_EPSILON` of optimal, a quarter of a metre of driving for a five-vehicle element.
static func _auction(utility: Array) -> PackedInt32Array:
	var n := utility.size()
	var seat_of := PackedInt32Array()
	var owner := PackedInt32Array()
	var price := PackedInt64Array()
	seat_of.resize(n)
	owner.resize(n)
	price.resize(n)
	seat_of.fill(-1)
	owner.fill(-1)
	price.fill(0)
	if n == 0:
		return seat_of
	var bids := 0
	var cap := n * AUCTION_BIDS_PER_UNIT
	while bids < cap:
		var bidder := -1
		for i in n:
			if seat_of[i] < 0:
				bidder = i
				break
		if bidder < 0:
			return seat_of
		var row: PackedInt64Array = utility[bidder]
		var best := 0
		for j in range(1, n):
			if row[j] - price[j] > row[best] - price[best]:
				best = j
		var best_net: int = row[best] - price[best]
		var second_net: int = best_net
		if n > 1:
			var found := false
			for j in n:
				if j == best:
					continue
				var net: int = row[j] - price[j]
				if not found or net > second_net:
					second_net = net
					found = true
		price[best] += (best_net - second_net) + AUCTION_EPSILON
		var displaced := owner[best]
		if displaced >= 0:
			seat_of[displaced] = -1
		owner[best] = bidder
		seat_of[bidder] = best
		bids += 1
	# The cap was reached: finish deterministically rather than leave anybody without a slot.
	for i in n:
		if seat_of[i] >= 0:
			continue
		var row: PackedInt64Array = utility[i]
		var pick := -1
		for j in n:
			if owner[j] >= 0:
				continue
			if pick < 0 or row[j] > row[pick]:
				pick = j
		if pick < 0:
			continue
		owner[pick] = i
		seat_of[i] = pick
	return seat_of


## Minimum-cost assignment on a square matrix (the Hungarian method, O(n³); n is a group, at most an army).
## Returns row -> column. Deterministic: only + and −, ties go to the lower index.
## Kept as the REFERENCE the auction is tested against (`test_tactics_seating`), and called by nothing in the game.
static func _hungarian(cost: Array) -> PackedInt32Array:
	var n := cost.size()
	var u := PackedFloat64Array()
	var v := PackedFloat64Array()
	var p := PackedInt32Array()
	var way := PackedInt32Array()
	u.resize(n + 1)
	v.resize(n + 1)
	p.resize(n + 1)
	way.resize(n + 1)
	u.fill(0.0)
	v.fill(0.0)
	p.fill(0)
	way.fill(0)
	for i in range(1, n + 1):
		p[0] = i
		var j0 := 0
		var minv := PackedFloat64Array()
		minv.resize(n + 1)
		minv.fill(INF)
		var used := PackedByteArray()
		used.resize(n + 1)
		used.fill(0)
		while true:
			used[j0] = 1
			var i0 := p[j0]
			var delta := INF
			var j1 := 0
			var row: PackedFloat64Array = cost[i0 - 1]
			for j in range(1, n + 1):
				if used[j] == 0:
					var cur := row[j - 1] - u[i0] - v[j]
					if cur < minv[j]:
						minv[j] = cur
						way[j] = j0
					if minv[j] < delta:
						delta = minv[j]
						j1 = j
			for j in range(0, n + 1):
				if used[j] == 1:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while true:
			var j1 := way[j0]
			p[j0] = p[j1]
			j0 = j1
			if j0 == 0:
				break
	var result := PackedInt32Array()
	result.resize(n)
	for j in range(1, n + 1):
		if p[j] > 0:
			result[p[j] - 1] = j - 1
	return result


# ---- Placing a formation (N2) --------------------------------------------------------------------------

## N2: the slots for `element` with its formation's centre at `anchor`, travelling along `heading`.
## `element` is anything with `formation_group() -> Dictionary` (an Element), or that Dictionary itself:
##   {"members": [{"name", "position", "unit"?, "role"?}], "formation", "spacing"?, "leader"?, "previous"?,
##    "policy"?, "halt"?}
## `count` is how many slots the shape has (default: one per member; more leaves places free for stragglers).
## Returns one entry per member, in slot order: {"unit", "to", "facing", "role", "index", "offset", "sector",
## "pitch", "file", "fits"} — "pitch" being the per-axis spacing X1 resolved the slots to (Vector2(across, along)),
## "file" how far X2 (A8) pulled the shape toward single file for its corridor, and "fits" whether it fits at all.
## opts may carry "corridor_m" (the drivable width across the heading; absent = open) and "shear".
## Recompute it as the anchor moves, passing the last seating as "previous": the seating is stable.
static func slots(element: Variant, anchor: Vector3, heading: Vector3, count := -1) -> Array[Dictionary]:
	var group: Dictionary = element.call("formation_group") if element is Object else element
	var members: Array = group.get("members", [])
	var opts := group.duplicate()
	opts["count"] = count
	return place(members, String(group.get("formation", DEFAULT)), anchor, heading,
			float(group.get("spacing", DEFAULT_SPACING)), opts)


## The slots for `members` in `formation` around `anchor` (see slots()). opts: "leader", "previous", "policy"
## ("front" | "exposure"), "halt" (face each slot's sector of fire rather than the heading), "count", "centered"
## (default true: the anchor is the shape's middle; false: the anchor is the leader's slot).
static func place(members: Array, formation: String, anchor: Vector3, heading: Vector3, spacing := DEFAULT_SPACING,
		opts := {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if members.is_empty():
		return result
	var count := maxi(int(opts.get("count", -1)), members.size())
	# X1: the doctrine's spacing, raised per axis to what these hulls physically fit in. X2 (A8): and deformed to
	# fit the corridor the element is driving through, when one was measured ("corridor_m"; absent = the open field,
	# and the identity). "shear" is the caller's heading change, if it has one.
	var fit := fit_to_corridor(members, formation, count, spacing,
			float(opts.get("corridor_m", INF)), float(opts.get("shear", 0.0)))
	var pitch_v: Vector2 = fit["pitch"]
	var raw := offsets_deformed(formation, count, fit)
	var shape: Array[Vector2] = centered(raw) if bool(opts.get("centered", true)) else raw
	var sector_list := sectors(formation if NAMES.has(formation) else "line", count)
	var seat_opts := opts.duplicate()
	# The hysteresis margin is a fraction of the biggest step between neighbouring slots, which is the larger axis.
	seat_opts["spacing"] = maxf(pitch_v.x, pitch_v.y)
	var seats := seat(members, shape, anchor, heading, seat_opts)
	var forward := flat(heading)
	var by_index := {}
	for member: Dictionary in members:
		by_index[int(seats[String(member["name"])])] = member
	var indices: Array = by_index.keys()
	indices.sort()
	for index: int in indices:
		var member: Dictionary = by_index[index]
		var sector: float = sector_list[index] if index < sector_list.size() else 0.0
		var facing := rotate(forward, deg_to_rad(sector)) if bool(opts.get("halt", false)) else forward
		var unit := String(member.get("unit", ""))
		result.append({"unit": String(member["name"]), "to": to_world(anchor, forward, shape[index]),
				"facing": facing, "role": String(member.get("role", Units.role_of(unit) if unit != "" else "")),
				"index": index, "offset": shape[index], "sector": sector, "pitch": pitch_v,
				"file": float(fit["file"]), "fits": bool(fit["fits"])})
	return result


## {name: slot index} from place()'s output: what to pass back as "previous" next time.
static func seating_of(placed: Array[Dictionary]) -> Dictionary:
	var result := {}
	for entry in placed:
		result[String(entry["unit"])] = int(entry["index"])
	return result


# ---- Pacing: arrive together --------------------------------------------------------------------------

## Within this distance of its slot a unit stops pacing itself to the group (meters).
const PACE_NEAR := 8.0
## The slowest a unit paces itself for its group (fraction of its top speed).
const PACE_FLOOR := 0.35


## Arrive together: the speed fraction (of its own top speed) for a unit `remaining` meters from its slot, when the
## slowest-to-arrive member of its group needs `group_eta` seconds. Units near their slot, and the laggard itself,
## drive flat out; the rest slow to arrive at the same moment, never below PACE_FLOOR.
static func pace(remaining: float, top_speed: float, group_eta: float) -> float:
	if remaining <= PACE_NEAR or top_speed <= 0.0 or group_eta <= 0.0:
		return 1.0
	return clampf(remaining / group_eta / top_speed, PACE_FLOOR, 1.0)
