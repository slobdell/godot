class_name ArmyLayout
extends RefCounted
## Round 6 (the lead, after playing): *"It seems like squads are not scoped together at the start; the units should start
## out like an army where there actually is a starting formation where each squad is separated."*
##
## Units spawn on the arena's spawn slots in load order, a grid shared by every squad, so a match opened as one mass. This
## lays the army out ONCE, at the start: the squads side by side across the team's spawn zone, each in its own formation
## (TacticsFormation, N2), every vehicle facing the enemy, every slot on standable ground (SlotGround). It moves the units
## there before the first frame anyone sees, so there is no "forming up" for a click to interrupt; a player's unit then
## holds that place as the post it was left at (TankBrain's hold rule), which is exactly "a squad given no order".
## It forms no ELEMENT: an element with no task runs its SOP and fights the player for the wheel (L1's sharp edge).
##
##   ArmyLayout.plan(squads, zone, frame) -> {unit: {"position": Vector3, "facing": Vector3, "squad": String}}   pure
##   ArmyLayout.deploy(game_match, team)       at the end of Match.load_doctrine, right after the army spawns

## Room left between neighbouring squads, in the squads' own (packed) spacings: at least this, so the gap between two
## squads always reads as wider than the gaps inside one. And the tightest a squad is packed to fit the zone (hulls are
## 2.6 x 4 m).
const GAP_SPACINGS := 2.5
const MIN_SPACING_M := 5.0
## The front rank stands this far inside the zone's front edge, and the last rank this far inside its back edge (and
## nothing past the drivable limit: a layout's zone may reach beyond it).
const FRONT_MARGIN_M := 4.0
const BACK_MARGIN_M := 4.0
## An army waiting for orders stands in an ASSEMBLY area, tighter than it moves: a squad starts at most this far between
## vehicles (hulls are ~4 m long), and opens out to its own spacing when it is ordered to move. The start view frames it.
const ASSEMBLY_SPACING_M := 6.5
## ...but never less than the squad's longest hull plus clear ground (vehicle sizes vary 3x between factions: a gang
## War Rig is far longer than a scout), and the same for the packing floor. Round 9 (X1): that floor is
## `TacticsFormation.hull_floor` — one derivation for the assembly and for every moving formation.
## A widened rank keeps this far off the drivable floor's side edges.
const SIDE_MARGIN_M := 6.0
## Clear ground between one rank of squads and the next (a hull is ~4 m long).
const RANK_GAP_M := 6.0
## A squad with no formation of its own starts in this one; a squad bigger than BLOCK_OVER waits in a compact block
## (TacticsFormation "block", ~3 x 2 for six), so a full faction army stands in one rank of clearly separate clusters
## (seen at 34 a side: five wedges of seven needed two ranks, and the second rank merged into the first's gaps).
const DEFAULT_FORMATION := "wedge"
const BLOCK_OVER := 4
## Only at the very start of a match: never re-lays an army that is already moving.
const DEPLOY_BY_TICK := 2


## `squads`: [{"name", "formation"?, "spacing"?, "leader"?, "members": [{"name", "unit"?, "role"?, "position"?}]}] in
## the order they stand left to right; `zone`: {"center": Vector3, "size": Vector2(width across, depth)}; `frame`:
## {"right": Vector3, "forward": Vector3} (Match.team_frame: forward points at the enemy).
static func plan(squads: Array, zone: Dictionary, frame: Dictionary) -> Dictionary:
	var result := {}
	var shapes: Array = []
	for squad: Dictionary in squads:
		shapes.append(_shape_of(squad))
	var count := shapes.size()
	if count == 0:
		return result
	var center: Vector3 = zone["center"]
	var size: Vector2 = zone["size"]
	var right: Vector3 = frame["right"]
	var forward: Vector3 = TacticsFormation.flat(frame["forward"])
	# As few ranks of squads as fit: each squad takes the width its own formation needs plus a gap, the rank is centred
	# (a small army stands together, not strung across the whole zone), spacing is compressed only if a rank will not
	# fit, and when even the tightest spacing will not, the squads stand in more ranks, the first nearest the enemy.
	# The zone is where the old spawn grid lived; when an army of big hulls will not fit it, a rank may widen out toward
	# the drivable floor's edges (the base is open there) rather than stack vehicles against a clamp.
	var widest := 2.0 * (Match.DRIVABLE_LIMIT - SIDE_MARGIN_M) - 2.0 * absf(center.dot(right))
	var ranks := 1
	while ranks < 4 and not _fits(shapes, ranks, Vector2(size.x, _usable_depth(size))):
		ranks += 1
	if not _fits(shapes, ranks, Vector2(size.x, _usable_depth(size))):
		ranks = 1
		while ranks < 4 and not _fits(shapes, ranks, Vector2(widest, _usable_depth(size))):
			ranks += 1
		size = Vector2(widest, size.y)
		if not _fits(shapes, ranks, Vector2(widest, _usable_depth(size))):
			# Nothing fits the zone's depth (round 8: a gang army with 14 m rigs): use the width, the fewest ranks whose
			# squads fit the drivable floor's breadth, and let pass 1's forward step find the depth.
			ranks = 1
			while ranks < count and not _fits(shapes, ranks, Vector2(widest, INF)):
				ranks += 1
	var per_rank := ceili(float(count) / ranks)
	var rank_depth := _usable_depth(size) / float(ranks)
	# Pass 1: each rank's squads, their pitches, and the rank's REAL depth. Slots are hull centres, so a rank overhangs
	# its slots by half its longest hull front and back (round 8: combat's 14 m War Rig stood its rank inside the next).
	# Across, vehicles stand side by side and need their WIDTH clear; front to back, their LENGTH: a squad of rigs pitches
	# 6.5 m across and 16 m deep, not 16 m both ways.
	var rows: Array = []
	var total_depth := 0.0
	for r in ranks:
		var row: Array = shapes.slice(r * per_rank, mini((r + 1) * per_rank, count))
		if row.is_empty():
			continue
		var scale := _scale_for(row, size.x, rank_depth)
		var placed: Array = []
		var width_sum := 0.0
		var slots_deep := 0.0
		var overhang := 0.0
		for shape: Dictionary in row:
			var spacing := maxf(float(shape["spacing"]) * scale, float(shape["floor"]))
			var deep_pitch := maxf(spacing, float(shape["deep_floor"]))
			var width: float = (float(shape["across"]) + GAP_SPACINGS) * spacing
			placed.append({"shape": shape, "spacing": spacing, "deep_pitch": deep_pitch, "width": width})
			width_sum += width
			slots_deep = maxf(slots_deep, float(shape["deep"]) * deep_pitch)
			overhang = maxf(overhang, float(shape["hull"]) * 0.5)
		rows.append({"placed": placed, "width": width_sum, "slots_deep": slots_deep, "overhang": overhang})
		total_depth += slots_deep + (overhang * 2.0 + RANK_GAP_M if rows.size() > 1 else 0.0)
	# Rank 0's slot fronts on the zone's front edge; if the ranks' real depth would run the last one past the drivable
	# floor's back edge, the whole army steps forward instead (a clamp there stacked vehicles on top of each other).
	var line := center + forward * (size.y * 0.5 - FRONT_MARGIN_M)
	var back_limit := -(Match.DRIVABLE_LIMIT - BACK_MARGIN_M)
	var last_back := line.dot(forward) - total_depth - float(rows[-1]["overhang"])
	if last_back < back_limit:
		line += forward * (back_limit - last_back)
	# Pass 2: place.
	for r in rows.size():
		var row: Dictionary = rows[r]
		if r > 0:
			line -= forward * float(row["overhang"])
		var left := -float(row["width"]) * 0.5
		for item: Dictionary in row["placed"]:
			var shape: Dictionary = item["shape"]
			var spacing: float = item["spacing"]
			# place() centres a shape on its centroid: step back from the line by how far its front slot is ahead of that.
			var anchor: Vector3 = line - forward * float(shape["front"]) * float(item["deep_pitch"]) \
					+ right * (left + float(item["width"]) * 0.5)
			left += float(item["width"])
			# The along-axis stretch this used to apply by hand IS place()'s X1 pitch: spacing across, the hull's
			# length floor along (item["deep_pitch"] is max(spacing, deep_floor), which is what pitch() resolves to).
			for entry in TacticsFormation.place(shape["members"], shape["formation"], anchor, forward, spacing,
					{"policy": "front", "leader": shape["leader"]}):
				var at: Vector3 = entry["to"]
				var limit := Match.DRIVABLE_LIMIT - 2.0
				at = Vector3(clampf(at.x, -limit, limit), 0.0, clampf(at.z, -limit, limit))
				result[String(entry["unit"])] = {"position": at, "facing": forward, "squad": shape["name"],
						"anchor": anchor, "formation": shape["formation"]}
		line -= forward * (float(row["slots_deep"]) + float(row["overhang"]) + RANK_GAP_M)
	return result


static func _usable_depth(size: Vector2) -> float:
	return maxf(size.y - FRONT_MARGIN_M - BACK_MARGIN_M, 8.0)


## A squad's formation and its width and depth per metre of spacing (formations scale linearly with spacing).
static func _shape_of(squad: Dictionary) -> Dictionary:
	var members: Array = squad["members"]
	var shape := String(squad.get("formation", ""))
	if not TacticsFormation.NAMES.has(shape):
		shape = DEFAULT_FORMATION
	shape = "block" if members.size() > BLOCK_OVER else TacticsFormation.auto(members.size(), "move", shape)
	var raw := TacticsFormation.centered(TacticsFormation.group_offsets(shape, maxi(members.size(), 1), 1.0))
	var ahead := 0.0
	for slot in raw:
		ahead = maxf(ahead, -slot.y)
	# Side by side a vehicle needs its width clear, nose to tail its length (everyone faces the enemy at the start).
	# ONE derivation, two callers (round 9, X1): the floor itself is TacticsFormation's, so the assembly and the
	# moving formation can never disagree about what a hull needs. This file keeps only its own assembly policy
	# (MIN_SPACING_M and ASSEMBLY_SPACING_M) on top of it.
	var hull_floor := TacticsFormation.hull_floor(members)
	var longest := TacticsFormation.hull_extent(members).y
	var floor_m := maxf(MIN_SPACING_M, hull_floor.x)
	return {"front": ahead, "floor": floor_m, "deep_floor": hull_floor.y, "hull": longest,
			"name": String(squad["name"]), "members": members, "formation": shape,
			"leader": String(squad.get("leader", "")),
			"spacing": maxf(minf(float(squad.get("spacing", TacticsFormation.DEFAULT_SPACING)), ASSEMBLY_SPACING_M), floor_m),
			"across": _extent(raw, true), "deep": _extent(raw, false)}


## Whether `shapes` fit in `ranks` ranks at their tightest spacing: every rank no wider than size.x, and the ranks'
## real depths plus the gaps between them no deeper than size.y (the placement stacks them the same way).
static func _fits(shapes: Array, ranks: int, size: Vector2) -> bool:
	var per_rank := ceili(float(shapes.size()) / ranks)
	var depth := 0.0
	for r in ranks:
		var row: Array = shapes.slice(r * per_rank, mini((r + 1) * per_rank, shapes.size()))
		if row.is_empty():
			continue
		var width := 0.0
		var deepest := 0.0
		var hull := 0.0
		for shape: Dictionary in row:
			width += (float(shape["across"]) + GAP_SPACINGS) * float(shape["floor"])
			deepest = maxf(deepest, float(shape["deep"]) * maxf(float(shape["floor"]), float(shape["deep_floor"])))
			hull = maxf(hull, float(shape.get("hull", 0.0)))
		if width > size.x:
			return false
		# Interior rank boundaries carry both hulls' overhangs (the placement stacks them the same way).
		depth += deepest + (RANK_GAP_M + hull if r > 0 else 0.0)
	return depth <= size.y


## How much a rank's squads must be packed (<= 1) to fit its width and depth.
static func _scale_for(row: Array, width: float, depth: float) -> float:
	var natural := 0.0
	var scale := 1.0
	for shape: Dictionary in row:
		natural += (float(shape["across"]) + GAP_SPACINGS) * float(shape["spacing"])
		if float(shape["deep"]) > 0.0:
			scale = minf(scale, maxf(depth - RANK_GAP_M, 1.0) / (float(shape["deep"]) * float(shape["spacing"])))
	if natural > 0.0:
		scale = minf(scale, width / natural)
	return scale


## Lay out `team`'s squads, at the start of the match only (a doctrine loaded later, mid-match, is left where it spawns).
## Called by Match.load_doctrine right after the army spawns, so a test that places its tanks afterwards still can.
static func deploy(game_match: Match, team: int) -> void:
	if game_match.tick > DEPLOY_BY_TICK:
		return
	var by_name := game_match.tanks_by_name()
	var squads: Array = []
	for squad: Squad in game_match.team_squads(team):
		var members: Array = []
		for unit_name in squad.roster:
			var tank := by_name.get(unit_name) as Tank
			if tank != null and tank.is_alive():
				members.append({"name": unit_name, "unit": tank.unit_id, "role": Units.role_of(tank.unit_id),
						"position": tank.global_position})
		squads.append({"name": squad.squad_name, "formation": squad.formation, "spacing": squad.spacing,
				"leader": squad.commander, "members": members})
	if squads.is_empty():
		return
	var south := (team == Match.Team.GREEN) != Match.swap_bases
	var frame := Match.team_frame(team)
	var laid := plan(squads, zone_of(south), frame)
	var yaw := Match.spawn_yaw(team)
	var taken: Array = []  # [position, hull width, hull length] of every vehicle placed so far (and the other team's)
	var forward: Vector3 = TacticsFormation.flat(frame["forward"])
	for other in game_match.sorted_team_tanks(1 - team):
		if other.is_alive():
			taken.append([other.global_position, _hull(other.unit_id).x, _hull(other.unit_id).y])
	var names: Array = laid.keys()
	names.sort()
	for unit_name: String in names:
		var tank := by_name.get(unit_name) as Tank
		var hull := _hull(tank.unit_id)
		var spot := _clear_spot(tank, laid[unit_name]["position"], hull, forward, taken)
		taken.append([spot, hull.x, hull.y])
		tank.global_position = Vector3(spot.x, tank.global_position.y, spot.z)
		tank.rotation.y = yaw
		tank.reset_physics_interpolation()
	# A doctrine squad that starts "in formation" holds at its commander's spawn point: move that hold with it.
	for squad: Squad in game_match.team_squads(team):
		if squad.is_commanded() and laid.has(squad.commander):
			squad.destination = laid[squad.commander]["anchor"]
			squad.heading = TacticsFormation.flat(frame["forward"])
			squad.facing_on_arrival = squad.heading


## Round 8: a slot is pushed off an obstacle to the nearest standable ground (SlotGround), which can push it toward a
## neighbour (measured: a law tank moved 2 m, leaving two 2.6 m hulls 3.0 m apart; two slots on one crate could land on
## the same edge, and physics would shove them apart: shuffling "trying to get unstuck" from tick 0). So a vehicle
## takes the nearest standable spot whose hull box (everyone faces `forward` at the start) keeps STAND_CLEAR_M from every
## vehicle already placed — across by the widths, or along by the lengths — searching outward in rings from its slot.
const STAND_CLEAR_M := 1.0
const SEARCH_STEP_M := 2.0
const SEARCH_RINGS := 12


static func _clear_spot(tank: Tank, wanted: Vector3, hull: Vector2, forward: Vector3, taken: Array) -> Vector3:
	var first: Vector3 = SlotGround.standable(tank, wanted)
	if _is_clear(first, hull, forward, taken):
		return first
	for ring in range(1, SEARCH_RINGS + 1):
		var radius := ring * SEARCH_STEP_M
		var steps := 8 + ring * 4
		for k in steps:
			var angle := TAU * float(k) / float(steps)
			var probe := wanted + Vector3(cos(angle), 0.0, sin(angle)) * radius
			var limit := Match.DRIVABLE_LIMIT - 2.0
			probe = Vector3(clampf(probe.x, -limit, limit), 0.0, clampf(probe.z, -limit, limit))
			var spot: Vector3 = SlotGround.standable(tank, probe)
			if _is_clear(spot, hull, forward, taken):
				return spot
	return first  # nowhere clear within reach: the slot as planned (a loud MEASURE in the footprint test, not a silent fix)


static func _is_clear(spot: Vector3, hull: Vector2, forward: Vector3, taken: Array) -> bool:
	var right := Vector3(-forward.z, 0.0, forward.x)
	for entry: Array in taken:
		var d: Vector3 = spot - (entry[0] as Vector3)
		var across := absf(d.dot(right)) - (hull.x + float(entry[1])) * 0.5
		var along := absf(d.dot(forward)) - (hull.y + float(entry[2])) * 0.5
		if maxf(across, along) < STAND_CLEAR_M:
			return false
	return true


## (width, length) of a unit's hull box.
static func _hull(unit_id: String) -> Vector2:
	if not Units.exists(unit_id):
		return Vector2(2.6, 4.0)
	var hull: Array = Units.stat(unit_id, "hull_size", [2.6, 1.8, 4.0])
	return Vector2(minf(float(hull[0]), float(hull[2])), maxf(float(hull[0]), float(hull[2])))


## The team's spawn zone: the layout's (M2 v2), else the box round its spawn spots, else round the default slots.
static func zone_of(south: bool) -> Dictionary:
	var declared := Arena.spawn_zone_of(Arena.active, south)
	if not declared.is_empty():
		return declared
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for slot in 52:
		var spot: Variant = Arena.spawn_spot(south, slot)
		var at: Vector3 = spot if spot != null else Match.spawn_position(Match.Team.GREEN if south != Match.swap_bases \
				else Match.Team.RUST, slot)
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
		high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
	var middle := (low + high) * 0.5
	return {"center": Vector3(middle.x, 0.0, middle.y), "size": Vector2(high.x - low.x + 8.0, high.y - low.y + 8.0)}


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
