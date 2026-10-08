class_name LayoutCheck
extends RefCounted
## Round 22 (brains B2): ten squads of five, and whether they stand apart at the start. Shared by
## tests/tactics/layout_probe.gd, tests/tactics/army_probe.gd and tests/test_tactics_army_layout10.gd.

const SQUADS := 10
const SQUAD_SIZE := 5
## Two squads' footprints closer than this (meters, either axis) count as touching: a box is the hulls' own outline.
const CLEAR_M := 0.0


## Ten squads of five, every one full: the faction's roster cycled from a seeded start (the garage's 2000 CR buys this
## many only of the gangs' Rat Rods; it is the stress case for the layout and the commander).
static func full_army(faction: String, seed_value: int) -> Dictionary:
	var roster := Units.roster(faction)
	var squads: Array = []
	var start := seed_value % roster.size()
	for k in SQUADS:
		var units: Array = []
		for i in SQUAD_SIZE:
			units.append({"unit": String(roster[(start + k * SQUAD_SIZE + i) % roster.size()])})
		squads.append({"name": "Squad%d" % (k + 1), "directive": {"role": "assault"}, "units": units})
	var doctrine := {"name": "Full %s" % faction, "faction": faction, "squads": squads}
	var parsed := Doctrine.parse(doctrine)
	return parsed if parsed.has("error") else {"doctrine": doctrine}


## Every squad's footprint in `team`'s own frame (across = right, along = forward, metres), the hull boxes of its living
## vehicles; and the pairs of squads whose footprints overlap: {"team", "squads", "overlaps": [[a, b, across, along]],
## "boxes": {squad: [min_across, max_across, min_along, max_along]}}. Overlap depths are how far the boxes interpenetrate.
static func footprints(game_match: Match, team: int) -> Dictionary:
	var frame := Match.team_frame(team)
	var right: Vector3 = TacticsFormation.flat(frame["right"])
	var forward: Vector3 = TacticsFormation.flat(frame["forward"])
	var boxes := {}
	for squad: Squad in game_match.team_squads(team):
		var box := [INF, -INF, INF, -INF]
		for unit_name in squad.roster:
			var tank := game_match.tanks.get_node_or_null(NodePath(String(unit_name))) as Tank
			if tank == null or not tank.is_alive():
				continue
			var hull := TacticsFormation.hull_extent([{"unit": tank.unit_id}])
			var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			var across := at.dot(right)
			var along := at.dot(forward)
			box[0] = minf(box[0], across - hull.x * 0.5)
			box[1] = maxf(box[1], across + hull.x * 0.5)
			box[2] = minf(box[2], along - hull.y * 0.5)
			box[3] = maxf(box[3], along + hull.y * 0.5)
		if box[0] < INF:
			boxes[String(squad.squad_name)] = box
	var names: Array = boxes.keys()
	names.sort()
	var overlaps: Array = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Array = boxes[names[i]]
			var b: Array = boxes[names[j]]
			var across := minf(a[1], b[1]) - maxf(a[0], b[0])
			var along := minf(a[3], b[3]) - maxf(a[2], b[2])
			if across > -CLEAR_M and along > -CLEAR_M:
				overlaps.append([names[i], names[j], snappedf(across, 0.1), snappedf(along, 0.1)])
	return {"team": team, "squads": names.size(), "overlaps": overlaps, "boxes": boxes}


## Pairs of living vehicles of `team` whose hull boxes overlap (everyone faces the enemy at the start, so the boxes are
## aligned with the team's frame): [[a, b, across_m, along_m]] interpenetration. ArmyLayout._clear_spot keeps
## STAND_CLEAR_M between every two hulls; this is what a player would see as two vehicles on top of each other.
static func hull_overlaps(game_match: Match, team: int) -> Array:
	var frame := Match.team_frame(team)
	var right: Vector3 = TacticsFormation.flat(frame["right"])
	var forward: Vector3 = TacticsFormation.flat(frame["forward"])
	var hulls: Array = []
	for tank: Tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive():
			continue
		var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		hulls.append([String(tank.name), at.dot(right), at.dot(forward), TacticsFormation.hull_extent([{"unit": tank.unit_id}])])
	var found: Array = []
	for i in hulls.size():
		for j in range(i + 1, hulls.size()):
			var a: Array = hulls[i]
			var b: Array = hulls[j]
			var across := ((a[3] as Vector2).x + (b[3] as Vector2).x) * 0.5 - absf(float(a[1]) - float(b[1]))
			var along := ((a[3] as Vector2).y + (b[3] as Vector2).y) * 0.5 - absf(float(a[2]) - float(b[2]))
			if across > 0.0 and along > 0.0:
				found.append([a[0], b[0], snappedf(across, 0.1), snappedf(along, 0.1)])
	return found
