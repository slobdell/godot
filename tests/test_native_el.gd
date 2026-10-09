extends TestCase
## Round 24 (native, C24.8): SlotGround's water rules natively (NativeEl -> el_native.cpp) are the live GDScript's.
## `on_anchor_side` and `pulled_dry` are asked both ways (native_el off: the live function; on: the native one) on every
## shipped arena with terrain (the crossing, the locks, the gorge, the pit, the Sumps, the docks, the canal Terminus),
## on points laid round every rectangle (both banks, the decks and their mouths, across the water) and at random, and
## on anchors and slots from real fights on the Locks and the Sumps. The answers must be equal bit for bit; a dry
## arena and the rules switched off (WET_ENABLED) answer the same way too.

const MATCH := preload("res://game/match/match.tscn")
## Hull envelopes (SlotGround.envelope_of over the catalogue) and a few made-up ones round the bake radius.
static var ENVELOPES: Array[float] = []
const WATER_ARENAS: Array[String] = ["crossing", "locks", "gorge", "pit", "sumps", "docks", "terminus_canal"]


static func _envelopes() -> Array[float]:
	if ENVELOPES.is_empty():
		for unit_id in Units.ids():
			var envelope := SlotGround.envelope_of(unit_id)
			if not ENVELOPES.has(envelope):
				ENVELOPES.append(envelope)
		ENVELOPES.append_array([0.0, 1.5, 2.0, 2.01, 3.3, 6.5])
	return ENVELOPES


## [live, native] SlotGround.standable_for.
func _ground_both(node: Node3D, point: Vector3, clearance: float) -> Array:
	var saved := BrainSwitches.native_el
	BrainSwitches.native_el = false
	var live := SlotGround.standable_for(node, point, clearance)
	BrainSwitches.native_el = true
	assert_true(NativeEl.grounds(node), "the native grounding answers here")
	var native := SlotGround.standable_for(node, point, clearance)
	BrainSwitches.native_el = saved
	return [live, native]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


## [live, native] for one rule.
func _both(rule: String, a: Vector3, b: Vector3, data: Dictionary) -> Array:
	var saved := BrainSwitches.native_el
	BrainSwitches.native_el = false
	var live: Vector3 = SlotGround.on_anchor_side(a, b, data) if rule == "anchor" else SlotGround.pulled_dry(a, b, data)
	BrainSwitches.native_el = true
	var native: Vector3 = SlotGround.on_anchor_side(a, b, data) if rule == "anchor" else SlotGround.pulled_dry(a, b, data)
	BrainSwitches.native_el = saved
	return [live, native]


## A point near a terrain rectangle: inside it, on either side, along its edges and its corners.
func _near(rng: RandomNumberGenerator, data: Dictionary) -> Vector3:
	var terrain: Array = data["terrain"]
	var box := ArenaTerrain.bounds(terrain[rng.randi_range(0, terrain.size() - 1)])
	var margin := rng.randf_range(0.0, 20.0)
	var x := rng.randf_range(box[0] - margin, box[2] + margin)
	var z := rng.randf_range(box[1] - margin, box[3] + margin)
	if rng.randf() < 0.2:  # exactly on an edge
		x = [box[0], box[2]][rng.randi_range(0, 1)]
	return Vector3(x, rng.randf_range(-0.5, 2.0), z)


func test_the_water_rules_are_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the water-rule equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2411
	var asked := 0
	var moved := 0
	var mismatches := 0
	var first := ""
	var saved_wet := SlotGround.WET_ENABLED
	for name in WATER_ARENAS + ["foundry"]:
		var loaded := Arena.load_layout(name)
		assert_true(loaded.has("layout"), "%s loads: %s" % [name, loaded.get("error", "")])
		var data: Dictionary = loaded.get("layout", {})
		var half := float(data.get("half_size", 120.0))
		for n in 1500:
			SlotGround.WET_ENABLED = rng.randf() >= 0.03
			var a: Vector3
			var b: Vector3
			if data.has("terrain") and rng.randf() < 0.8:
				a = _near(rng, data)
				b = _near(rng, data) if rng.randf() < 0.5 else a + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
			else:
				a = Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
				b = Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
			if rng.randf() < 0.02:
				b = a  # a zero-length leg
			for rule: String in ["anchor", "dry"]:
				var answers := _both(rule, a, b, data)
				asked += 1
				moved += 1 if answers[0] != a else 0
				if answers[0] != answers[1]:
					mismatches += 1
					if first == "":
						first = "%s %s(%s, %s): live %s, native %s" % [name, rule, a, b, answers[0], answers[1]]
	SlotGround.WET_ENABLED = saved_wet
	print("native el water: %d asked, %d moved, %d mismatches" % [asked, moved, mismatches])
	assert_eq(mismatches, 0, "the native water rules are the live GDScript's: %s" % first)
	assert_true(asked >= 20000 and moved >= 3000, "a real sample (%d asked, %d moved)" % [asked, moved])


func _fight(arena: String, rng: RandomNumberGenerator, counts: Dictionary) -> String:
	await ArenaFixture.build(self, arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	await wait_physics_frames(TacticsFlags.SETTLE_TICKS)
	_envelopes()
	TacticsFlags.install(game_match, ["", ""], false)  # both sides led by elements (--green-elements --rust-elements)
	var first := ""
	for frame in 360:
		await wait_physics_frames(1)
		if frame % 6 != 5:
			continue
		var elements := Elements.of_match(game_match)
		if elements == null:
			continue
		for element: Element in elements.all():
			if not (element.anchor is Vector3):
				continue
			var anchor: Vector3 = element.anchor
			var points: Array = (element.slots as Dictionary).values() + (element.slots_asked as Dictionary).values()
			for point: Vector3 in points:
				for jitter in 2:
					var p: Vector3 = point if jitter == 0 else point + Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(-8.0, 8.0))
					for rule: String in ["anchor", "dry"]:
						var answers := _both(rule, p, anchor, Arena.active)
						counts["asked"] += 1
						counts["moved"] += 1 if answers[0] != p else 0
						if answers[0] != answers[1]:
							counts["mismatches"] += 1
							if first == "":
								first = "%s frame %d %s(%s, %s): live %s, native %s" % [arena, frame, rule, p, anchor, answers[0], answers[1]]
					var clearance: float = ENVELOPES[rng.randi_range(0, ENVELOPES.size() - 1)]
					var grounded := _ground_both(game_match.tanks, p, clearance)
					counts["grounded"] += 1
					counts["pushed"] += 1 if grounded[0] != p else 0
					if grounded[0] != grounded[1]:
						counts["mismatches"] += 1
						if first == "":
							first = "%s frame %d standable_for(%s, %.3f): live %s, native %s" % [arena, frame, p, clearance, grounded[0], grounded[1]]
	return first


func _fight_test(arena: String, seed: int) -> void:
	if not NativeBridge.available:
		print("native: absent, the water-rule equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := {"asked": 0, "moved": 0, "mismatches": 0, "grounded": 0, "pushed": 0}
	var first: String = await _fight(arena, rng, counts)
	print("native el (%s fight): water %d asked, %d moved; standable_for %d asked, %d pushed; %d mismatches" % [arena,
			counts["asked"], counts["moved"], counts["grounded"], counts["pushed"], counts["mismatches"]])
	assert_eq(counts["mismatches"], 0, "the native water rules are the live GDScript's in a fight: %s" % first)
	assert_true(counts["asked"] >= 1000 and counts["grounded"] >= 500 and counts["pushed"] >= 50,
			"a real sample (%s)" % counts)


func test_the_water_rules_in_a_locks_fight_are_the_live_gdscript() -> void:
	await _fight_test("locks", 2412)


func test_the_water_rules_in_a_sumps_fight_are_the_live_gdscript() -> void:
	await _fight_test("sumps", 2413)


## standable_for on a built arena (its baked navmesh): random points everywhere, points round every obstacle, each
## hull's envelope, every point asked twice (the memo's answer is the computed one).
func _ground_test(arena: String, seed: int) -> void:
	if not NativeBridge.available:
		print("native: absent, the grounding equality is not exercised in this run")
		return
	var built := await ArenaFixture.build(self, arena)
	var node: Node3D = built
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var half := float(Arena.active.get("half_size", 120.0))
	var obstacles: Array = Arena.active.get("obstacles", []) + Arena.active.get("props", [])
	_envelopes()
	var asked := 0
	var pushed := 0
	var mismatches := 0
	var first := ""
	for n in 1500:
		var point := Vector3(rng.randf_range(-half, half), rng.randf_range(0.0, 1.0), rng.randf_range(-half, half))
		if not obstacles.is_empty() and rng.randf() < 0.6:
			var obstacle: Dictionary = obstacles[rng.randi_range(0, obstacles.size() - 1)]
			var at: Array = obstacle.get("position", [0.0, 0.0])
			point = Vector3(float(at[0]) + rng.randf_range(-12.0, 12.0), 0.0, float(at[1]) + rng.randf_range(-12.0, 12.0))
		var clearance: float = ENVELOPES[rng.randi_range(0, ENVELOPES.size() - 1)]
		for again in 2:
			var answers := _ground_both(node, point, clearance)
			asked += 1
			pushed += 1 if answers[0] != point else 0
			if answers[0] != answers[1]:
				mismatches += 1
				if first == "":
					first = "%s standable_for(%s, %.3f): live %s, native %s" % [arena, point, clearance, answers[0], answers[1]]
	print("native el ground (%s): %d asked, %d pushed, %d mismatches" % [arena, asked, pushed, mismatches])
	assert_eq(mismatches, 0, "the native standable_for is the live GDScript's: %s" % first)
	assert_true(asked >= 3000 and pushed >= 300, "a real sample (%d asked, %d pushed)" % [asked, pushed])


func test_grounding_on_the_sumps_is_the_live_gdscript() -> void:
	await _ground_test("sumps", 2414)


func test_grounding_on_the_locks_is_the_live_gdscript() -> void:
	await _ground_test("locks", 2415)


func test_grounding_on_the_terminus_canal_is_the_live_gdscript() -> void:
	await _ground_test("terminus_canal", 2416)


func test_grounding_on_the_yard_is_the_live_gdscript() -> void:
	await _ground_test("yard", 2417)
