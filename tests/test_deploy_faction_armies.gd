extends TestCase
## Round 14 A0 (the lead, playing the Locks with the Gangs, 2026-09-27): *"the trucks just became completely invisible
## when I was moving them around. Their graphic was gone and instead it was just a blue circle"*.
##
## The mechanism, measured by replaying his match (`make rig-vanish REPLAY=…`, builder0): his two War Rigs,
## Green_Guns_7 and Green_Guns_9, were DEPLOYED INSIDE the city block at (-30, 42) -- his recording's tick 0 has them at
## (-39.5, 57) and (-35, 57), inside a building whose footprint runs x -50..-10, z 22..62. On the second tick
## `move_and_slide` separated each 14 m hull from the 40 m block along its shortest way out, which is DOWN: 6.24 m under
## the floor, where a floating hull stays for the whole match, drawn beneath the opaque ground with only its selection
## ring on top. `test_arena_deploy_zone.gd` holds this invariant for a bus army on three maps; nothing held it for the
## armies he actually fields, on the maps with blocks near the zone. This does: every faction's skirmish army, on every
## map with a block, deploys with no hull inside a collider.

const MATCH := preload("res://game/match/match.tscn")
const DeployZone := preload("res://tests/test_arena_deploy_zone.gd")
const FACTIONS := ["gangs", "condemned", "law", "syndicate"]


## The Green army a skirmish fields for `faction` (the same call path as `SkirmishMode`), deployed on `layout_name`.
## `baked` false deploys the way a live skirmish does: before there is a navigation map to ask (`SlotGround.standable`
## then returns every slot unchecked), which is how his rigs were placed inside the block.
func _deploy(layout_name: String, faction: String, baked := true, seed_value := 76424) -> Array:
	var arena: Arena = await ArenaFixture.build(self, layout_name)
	var game_match: Match = add_to_tree(MATCH.instantiate())
	await wait_physics_frames(1)
	var plan := SkirmishMode.lineup_plan("player_default", "cpu", faction, "", 0)
	var loaded := Army.load_army(String(plan[Match.Team.GREEN]["lineup"]), seed_value, int(plan["budget"]), faction)
	assert_eq(String(loaded.get("error", "")), "", "setup: the %s army rolls" % faction)
	var was := Pathing.enabled
	Pathing.enabled = baked
	var error := game_match.load_doctrine(Match.Team.GREEN, loaded["doctrine"])
	Pathing.enabled = was
	assert_eq(error, "", "setup: the %s army loads on %s" % [faction, layout_name])
	return [game_match, game_match.sorted_team_tanks(Match.Team.GREEN), arena]


func _clear(deployed: Array) -> void:
	(deployed[0] as Node).queue_free()
	(deployed[2] as Node).queue_free()
	await wait_physics_frames(2)


func _inside(tanks: Array) -> PackedStringArray:
	return PackedStringArray(Array(DeployZone.problems(tanks, Arena.active)).filter(
			func(line: String) -> bool: return line.contains("inside")))


func test_his_gangs_army_on_the_locks_deploys_with_no_rig_inside_a_building() -> void:
	for baked: bool in [false, true]:
		var deployed: Array = await _deploy("locks", "gangs", baked)
		var tanks: Array = deployed[1]
		var found := _inside(tanks)
		print("MEASURE deploy_inside locks gangs baked=%s %s" % [baked, JSON.stringify({"vehicles": tanks.size(),
				"inside": found.size(), "front_z": tanks.map(func(t: Tank) -> float: return t.global_position.z).min()})])
		assert_true(found.is_empty(), "baked=%s: no hull deploys inside a collider on the Locks: %s" % [baked,
				"; ".join(found.slice(0, 5))])
		# The symptom, guarded too: after the first ticks every hull is still on the floor (his went 6.24 m under).
		var before := Tank.off_floor
		await wait_physics_frames(10)
		var sunk := tanks.filter(func(t: Tank) -> bool: return absf(t.global_position.y) > Tank.OFF_FLOOR_M)
		assert_true(sunk.is_empty() and Tank.off_floor == before, "baked=%s: every hull is still on the floor after 10 ticks: %s" % [
				baked, sunk.map(func(t: Tank) -> String: return "%s y=%.2f" % [t.name, t.global_position.y])])
		await _clear(deployed)


func test_every_faction_deploys_clear_on_the_maps_with_buildings_by_the_zone() -> void:
	## The same invariant for every army a skirmish fields, deployed the way a live skirmish does (no baked map yet).
	var failures := PackedStringArray()
	for layout_name: String in ["locks", "terminus", "crossing", "yard"]:
		for faction: String in FACTIONS:
			var deployed: Array = await _deploy(layout_name, faction, false)
			var tanks: Array = deployed[1]
			var found := _inside(tanks)
			var before := Tank.off_floor
			await wait_physics_frames(6)
			var sunk := tanks.filter(func(t: Tank) -> bool: return absf(t.global_position.y) > Tank.OFF_FLOOR_M)
			print("MEASURE deploy_inside %s %s %s" % [layout_name, faction, JSON.stringify({"vehicles": tanks.size(),
					"inside": found.size(), "off_floor": sunk.size()})])
			for line in found.slice(0, 2):
				failures.append("%s %s: %s" % [layout_name, faction, line])
			for t: Tank in sunk.slice(0, 2):
				failures.append("%s %s: %s off the floor y=%.2f at (%.1f, %.1f)" % [layout_name, faction, t.name,
						t.global_position.y, t.global_position.x, t.global_position.z])
			await _clear(deployed)
	assert_true(failures.is_empty(), "every faction deploys clear and on the floor: %s" % "; ".join(failures))
