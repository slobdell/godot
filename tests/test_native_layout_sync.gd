extends TestCase
## Round 48 (native N5, R47.18): THE ARMY LAYOUT DOES NOT DEPEND ON WHEN THE FIRST NAVIGATION SYNC LANDS. A doctrine army loaded in the
## frame its arena bakes (a skirmish's start) and one loaded a few frames later (a start that let the navigation server sync) lay
## every crew on the same spot, and neither leaves a slot unchecked (ARMY_LAYOUT_UNCHECKED). `--layout-sync=off` (round 47's) is the
## arm that fails: the same-frame army is laid unchecked.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _doctrine() -> Dictionary:
	var units := []
	for unit: String in ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]:
		units.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": units.slice(0, 5)}, {"name": "Bravo", "units": units.slice(5)}]}


func _deploy(wait_frames: int, arena_name: String) -> Array:
	var arena := ARENA.instantiate() as Node3D
	arena.set("layout_name", arena_name)
	add_to_tree(arena)
	for i in wait_frames:
		await tree.physics_frame
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(13505, 0.0)
	var before := SlotGround.unchecked
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine()), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine()), "", "rust loads")
	var unchecked := SlotGround.unchecked - before
	var spots := {}
	for tank: Tank in game_match.tanks_by_name().values():
		spots[String(tank.name)] = tank.global_position
	free_owned()
	await drain_navigation()
	return [spots, unchecked]


func test_the_layout_is_the_same_whenever_the_navigation_syncs() -> void:
	for arena_name: String in ["crossing", "locks", "sumps"]:
		# What a headless / same-frame start lays now v round 47's (--layout-sync=off): how far each crew's spawn moves.
		var was := ArmyLayout.LAYOUT_SYNC
		ArmyLayout.LAYOUT_SYNC = false
		var old: Array = await _deploy(0, arena_name)
		ArmyLayout.LAYOUT_SYNC = was
		var same_frame: Array = await _deploy(0, arena_name)
		var moved := 0
		var worst := 0.0
		var total := 0.0
		for n: String in old[0]:
			var d := Vector2((old[0][n] as Vector3).x - (same_frame[0][n] as Vector3).x, (old[0][n] as Vector3).z - (same_frame[0][n] as Vector3).z).length()
			moved += 1 if d > 0.01 else 0
			worst = maxf(worst, d)
			total += d
		print("LAYOUT_MOVED %s old_unchecked %d crews_moved %d of %d worst_m %.2f mean_m %.2f" % [arena_name, old[1], moved,
				(old[0] as Dictionary).size(), worst, total / maxf(1.0, float((old[0] as Dictionary).size()))])
		var later: Array = await _deploy(3, arena_name)
		print("LAYOUT_SYNC %s unchecked same_frame %d later %d crews %d" % [arena_name, same_frame[1], later[1], (same_frame[0] as Dictionary).size()])
		assert_eq(int(same_frame[1]), 0, "%s: no slot laid unchecked in the bake's own frame" % arena_name)
		assert_eq(int(later[1]), 0, "%s: none after the sync either" % arena_name)
		assert_true((same_frame[0] as Dictionary).size() == 20, "%s: both armies laid" % arena_name)
		var parted := []
		for n: String in same_frame[0]:
			var a: Vector3 = same_frame[0][n]
			var b: Vector3 = (later[0] as Dictionary).get(n, Vector3.INF)
			if a != b:
				parted.append("%s %s v %s" % [n, a, b])
		assert_true(parted.is_empty(), "%s: every crew on the same spot either way (%s)" % [arena_name, parted.slice(0, 3)])
