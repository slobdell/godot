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
const GROUP_SHAPES := ["rows", "single"]
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


## Width of the shape across the direction of travel (meters).
static func frontage(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(offsets(formation, count, spacing), true)


## Length of the shape along the direction of travel (meters).
static func depth(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(offsets(formation, count, spacing), false)


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
## A seating is kept from one update to the next unless a new one saves at least this fraction of the spacing, in
## total meters driven: the N2 guarantee that a unit does not swap slots with its neighbour every tick.
const STABLE_MARGIN := 0.5
const _PINNED := 1.0e9


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
##   4. `previous` ({name: index}, the last seating) is kept unless the new one saves STABLE_MARGIN × spacing of
##      driving: no slot swapping from one tick to the next.
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
	var pin := false
	for member: Dictionary in members:
		pin = pin or (leader != "" and String(member.get("name", "")) == leader)
	var world: Array[Vector3] = []
	for slot in offsets:
		world.append(to_world(anchor, heading, slot))
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
				value = Vector2(at.x - world[j].x, at.z - world[j].z).length()
			# Fragile vehicles (a high tier) are paid for standing anywhere but the most sheltered slots.
			value += TIER_COST * float(member_tier[i]) * float(deepest - int(slot_tier[j]))
			if pin:
				var is_leader := String(member.get("name", "")) == leader
				if is_leader != (j == 0):
					value += _PINNED
			row[j] = value
		cost.append(row)
	var best := _hungarian(cost)
	var chosen := {}
	var best_cost := 0.0
	for i in count:
		chosen[String(members[i]["name"])] = best[i]
		best_cost += (cost[i] as PackedFloat64Array)[best[i]]
	var previous: Dictionary = opts.get("previous", {})
	if _valid_seating(previous, members, offsets.size()):
		var previous_cost := 0.0
		for i in count:
			previous_cost += (cost[i] as PackedFloat64Array)[int(previous[String(members[i]["name"])])]
		if previous_cost <= best_cost + STABLE_MARGIN * spacing:
			for i in count:
				result[String(members[i]["name"])] = int(previous[String(members[i]["name"])])
			return result
	return chosen


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


## Minimum-cost assignment on a square matrix (the Hungarian method, O(n³); n is a group, at most an army).
## Returns row -> column. Deterministic: only + and −, ties go to the lower index.
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
## Returns one entry per member, in slot order: {"unit", "to", "facing", "role", "index", "offset", "sector"}.
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
	var raw := group_offsets(formation, count, spacing)
	var shape: Array[Vector2] = centered(raw) if bool(opts.get("centered", true)) else raw
	var sector_list := sectors(formation if NAMES.has(formation) else "line", count)
	var seat_opts := opts.duplicate()
	seat_opts["spacing"] = spacing
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
				"index": index, "offset": shape[index], "sector": sector})
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
