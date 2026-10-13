extends TestCase
## Round 28 (native N6.3, perception only): who sees whom as one batched pass (NativePerception ->
## perception_native.cpp) against the LIVE GDScript. Match._update_intel itself runs both ways from one snapshot
## (intel, stats, SimProfile's ray count) on seeded poses of a fight on the Sumps (crates and walls decide the lines):
## hulls of every unit scattered in a cluster, some dead, sight radii and reloads varied, the tick on and off the
## gun-ready sample's cadence, intel carried pose to pose so forgetting is reached. Everything intel writes is compared
## bit for bit (var_to_bytes), and the lines cast.

const MATCH := preload("res://game/match/match.tscn")
const HULLS := 16
const POSES := 240


func _state(game_match: Match) -> Array:
	return [game_match.intel[0].duplicate(true), game_match.intel[1].duplicate(true), game_match.stats.duplicate(true)]


func _restore(game_match: Match, state: Array) -> void:
	game_match.intel[0] = (state[0] as Dictionary).duplicate(true)
	game_match.intel[1] = (state[1] as Dictionary).duplicate(true)
	game_match.stats = (state[2] as Dictionary).duplicate(true)


func _pass(game_match: Match, native: bool) -> Array:
	BrainSwitches.native_perception = native
	var before := int(SimProfile._counts.get("intel/los_queries", 0))
	game_match._update_intel()
	return [var_to_bytes(_state(game_match)), int(SimProfile._counts.get("intel/los_queries", 0)) - before]


func test_the_sight_pass_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the perception equality is not exercised in this run")
		return
	assert_true(NativePerception.configure(), "the native pass takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array = Units.PROFILES.keys()
	units.sort()
	var tanks: Array[Tank] = []
	for i in HULLS:
		var team := Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST
		tanks.append(game_match.spawn_tank("Sight%02d" % i, 0, team, String(units[i % units.size()])))
	await wait_physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2831
	var was := BrainSwitches.native_perception
	var was_profile := SimProfile.enabled
	SimProfile.enabled = true
	var mismatches := 0
	var first := ""
	var rays := 0
	var seen := 0
	var gun_passes := 0
	var cadence := Match.INTEL_EVERY_TICKS * Match.GUN_READY_EVERY_INTELS
	for n in POSES:
		var centre := Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0))
		for tank in tanks:
			tank.global_position = Vector3(centre.x + rng.randf_range(-80.0, 80.0), 0.0, centre.y + rng.randf_range(-80.0, 80.0))
			tank.rotation.y = rng.randf_range(-PI, PI)
			tank.alive = rng.randf() < 0.85
			tank.sight_radius = rng.randf_range(20.0, 140.0)
			tank._reload_ticks = 0 if rng.randf() < 0.6 else rng.randi_range(2, 30)
		game_match.tick = cadence * (n + 1) if n % 3 == 0 else Match.INTEL_EVERY_TICKS * (n * 7 + 1)
		gun_passes += 1 if n % 3 == 0 else 0
		var start := _state(game_match)
		var live := _pass(game_match, false)
		_restore(game_match, start)
		var native := _pass(game_match, true)
		rays += int(live[1])
		seen += game_match.intel[0].size() + game_match.intel[1].size()
		if live != native:
			mismatches += 1
			if first == "":
				first = "pose %d (tick %d): rays live %d native %d, state %s" % [n, game_match.tick, live[1], native[1],
						"equal" if live[0] == native[0] else "differs"]
	for tank in tanks:
		tank.alive = true
	BrainSwitches.native_perception = was
	SimProfile.enabled = was_profile
	print("native perception: %d poses (%d on the gun-ready cadence), %d lines cast, %d contacts held, %d mismatches" % [
			POSES, gun_passes, rays, seen, mismatches])
	assert_eq(mismatches, 0, "the native sight pass is the live GDScript: %s" % first)
	assert_true(rays >= 1000 and seen >= 200, "a real sample (%d lines, %d contacts)" % [rays, seen])
