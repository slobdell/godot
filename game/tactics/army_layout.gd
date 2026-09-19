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
## A squad with no formation of its own starts in this one.
const DEFAULT_FORMATION := "wedge"
## Only at the very start of a match: never re-lays an army that is already moving.
const DEPLOY_BY_TICK := 2


## `squads`: [{"name", "formation"?, "spacing"?, "leader"?, "members": [{"name", "unit"?, "role"?, "position"?}]}] in
## the order they stand left to right; `zone`: {"center": Vector3, "size": Vector2(width across, depth)}; `frame`:
## {"right": Vector3, "forward": Vector3} (Match.team_frame: forward points at the enemy).
static func plan(squads: Array, zone: Dictionary, frame: Dictionary) -> Dictionary:
	var result := {}
	var count := squads.size()
	if count == 0:
		return result
	var center: Vector3 = zone["center"]
	var size: Vector2 = zone["size"]
	var right: Vector3 = frame["right"]
	var forward: Vector3 = TacticsFormation.flat(frame["forward"])
	var lane := size.x / float(count)
	for i in count:
		var squad: Dictionary = squads[i]
		var members: Array = squad["members"]
		if members.is_empty():
			continue
		var shape := String(squad.get("formation", ""))
		if not TacticsFormation.NAMES.has(shape):
			shape = DEFAULT_FORMATION
		shape = TacticsFormation.auto(members.size(), "move", shape)
		# Pack the squad into its lane of the zone: as its own spacing allows, tighter if it must, never below the floor.
		var spacing := float(squad.get("spacing", TacticsFormation.DEFAULT_SPACING))
		var frontage := TacticsFormation.frontage(shape, members.size(), spacing) if shape != "rows" \
				else _extent(TacticsFormation.rows(members.size(), 0, spacing), true)
		var depth := TacticsFormation.depth(shape, members.size(), spacing) if shape != "rows" \
				else _extent(TacticsFormation.rows(members.size(), 0, spacing), false)
		# Fit frontage + the gap to the next squad (both in spacings) into the lane, and the depth into the zone.
		var fit := spacing
		if frontage > 0.0:
			fit = minf(fit, lane / (frontage / spacing + GAP_SPACINGS))
		if depth > 0.0:
			fit = minf(fit, size.y * 0.9 / (depth / spacing))
		spacing = maxf(fit, MIN_SPACING_M)
		var anchor := center + right * (float(i) - (count - 1) * 0.5) * lane
		for entry in TacticsFormation.place(members, shape, anchor, forward, spacing,
				{"policy": "front", "leader": String(squad.get("leader", ""))}):
			result[String(entry["unit"])] = {"position": entry["to"], "facing": forward, "squad": String(squad["name"]),
					"anchor": anchor, "formation": shape}
	return result


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
