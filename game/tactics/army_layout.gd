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
const GAP_SPACINGS := 2.0
const MIN_SPACING_M := 5.0
## The front rank stands this far inside the zone's front edge, and the last rank this far inside its back edge (and
## nothing past the drivable limit: a layout's zone may reach beyond it).
const FRONT_MARGIN_M := 4.0
const BACK_MARGIN_M := 4.0
## An army waiting for orders stands in an ASSEMBLY area, tighter than it moves: a squad starts at most this far between
## vehicles (hulls are ~4 m long), and opens out to its own spacing when it is ordered to move. The start view frames it.
const ASSEMBLY_SPACING_M := 8.0
## Clear ground between one rank of squads and the next (a hull is ~4 m long).
const RANK_GAP_M := 6.0
## A squad with no formation of its own starts in this one.
const DEFAULT_FORMATION := "wedge"
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
	var ranks := 1
	while ranks < 4 and not _fits(shapes, ranks, Vector2(size.x, _usable_depth(size))):
		ranks += 1
	var per_rank := ceili(float(count) / ranks)
	var rank_depth := _usable_depth(size) / float(ranks)
	for r in ranks:
		var row: Array = shapes.slice(r * per_rank, mini((r + 1) * per_rank, count))
		if row.is_empty():
			continue
		var scale := _scale_for(row, size.x, rank_depth)
		var widths: Array = []
		var total := 0.0
		for shape: Dictionary in row:
			var spacing := maxf(float(shape["spacing"]) * scale, MIN_SPACING_M)
			var width: float = (float(shape["across"]) + GAP_SPACINGS) * spacing
			widths.append([spacing, width])
			total += width
		# Every squad's front on the rank's line: rank 0 on the zone's front edge (nearest the enemy, where the old spawn
		# grid filled first), each rank behind the one before. A formation's anchor is its middle, so step back half its depth.
		var line := center + forward * (size.y * 0.5 - FRONT_MARGIN_M - r * rank_depth)
		var left := -total * 0.5
		for i in row.size():
			var shape: Dictionary = row[i]
			var spacing: float = widths[i][0]
			var anchor: Vector3 = line - forward * float(shape["deep"]) * spacing * 0.5 \
					+ right * (left + float(widths[i][1]) * 0.5)
			left += float(widths[i][1])
			for entry in TacticsFormation.place(shape["members"], shape["formation"], anchor, forward, spacing,
					{"policy": "front", "leader": shape["leader"]}):
				var at: Vector3 = entry["to"]
				var limit := Match.DRIVABLE_LIMIT - 2.0
				at = Vector3(clampf(at.x, -limit, limit), 0.0, clampf(at.z, -limit, limit))
				result[String(entry["unit"])] = {"position": at, "facing": forward, "squad": shape["name"],
						"anchor": anchor, "formation": shape["formation"]}
	return result


static func _usable_depth(size: Vector2) -> float:
	return maxf(size.y - FRONT_MARGIN_M - BACK_MARGIN_M, 8.0)


## A squad's formation and its width and depth per metre of spacing (formations scale linearly with spacing).
static func _shape_of(squad: Dictionary) -> Dictionary:
	var members: Array = squad["members"]
	var shape := String(squad.get("formation", ""))
	if not TacticsFormation.NAMES.has(shape):
		shape = DEFAULT_FORMATION
	shape = TacticsFormation.auto(members.size(), "move", shape)
	var raw := TacticsFormation.group_offsets(shape, maxi(members.size(), 1), 1.0)
	return {"name": String(squad["name"]), "members": members, "formation": shape,
			"leader": String(squad.get("leader", "")),
			"spacing": minf(float(squad.get("spacing", TacticsFormation.DEFAULT_SPACING)), ASSEMBLY_SPACING_M),
			"across": _extent(raw, true), "deep": _extent(raw, false)}


## Whether `shapes` fit the zone in `ranks` ranks at the tightest spacing.
static func _fits(shapes: Array, ranks: int, size: Vector2) -> bool:
	var per_rank := ceili(float(shapes.size()) / ranks)
	for r in ranks:
		var width := 0.0
		for shape: Dictionary in shapes.slice(r * per_rank, mini((r + 1) * per_rank, shapes.size())):
			width += (float(shape["across"]) + GAP_SPACINGS) * MIN_SPACING_M
			if float(shape["deep"]) * MIN_SPACING_M > size.y / ranks - RANK_GAP_M:
				return false
		if width > size.x:
			return false
	return true


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
	for unit_name: String in laid:
		var tank := by_name.get(unit_name) as Tank
		var spot: Vector3 = SlotGround.standable(tank, laid[unit_name]["position"])
		tank.global_position = Vector3(spot.x, tank.global_position.y, spot.z)
		tank.rotation.y = yaw
		tank.reset_physics_interpolation()
	# A doctrine squad that starts "in formation" holds at its commander's spawn point: move that hold with it.
	for squad: Squad in game_match.team_squads(team):
		if squad.is_commanded() and laid.has(squad.commander):
			squad.destination = laid[squad.commander]["anchor"]
			squad.heading = TacticsFormation.flat(frame["forward"])
			squad.facing_on_arrival = squad.heading


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
