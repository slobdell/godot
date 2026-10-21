extends TestCase
## Round 37 (cover, K2 / C37.3): hull-down behind real low cover. A direct round arriving in a hull's FRONT arc may
## strike the low cover tight in front of it instead, with the probability of how much of the presented front the
## cover hides; flank, rear and lobbed rounds are never stopped; the switch OFF changes nothing.

const MATCH := preload("res://game/match/match.tscn")
## A jersey barricade (ArenaKit "barricade"): 6.0 x 0.9 x 0.8 m.
const BARRICADE := {"position": Vector2(0.0, -3.0), "size": [6.0, 0.9, 0.8], "rotation_deg": 0.0, "height": 0.9,
		"type": "barricade"}
## A scout-sized hull [width, height, length].
const SCOUT := Vector3(1.8, 1.5, 3.0)


func teardown() -> void:
	CoverMap.set_off("hulldown", true)
	Armor.no_damage = false
	super.teardown()


# ---- the screen's geometry (pure) ---------------------------------------------------------------------------------

func test_a_barricade_tight_in_front_hides_its_height_share_of_the_front() -> void:
	var map := CoverMap.from_features([BARRICADE])
	# The hull at the origin faces -z, the shooter is far off along -z: the barricade's near side is 1.1 m off its nose.
	var screen := map.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), SCOUT)
	assert_near(float(screen["fraction"]), 0.9 / 1.5, 0.001, "0.9 m of a 1.5 m front, its whole width")
	assert_near((screen["point"] as Vector2).y, -2.6, 0.001, "the round meets the barricade's near side")


func test_a_tall_hull_is_barely_hidden_and_a_low_one_mostly() -> void:
	var map := CoverMap.from_features([BARRICADE])
	var bus := map.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), Vector3(2.9, 4.08, 3.0))
	var rat_rod := map.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), Vector3(1.52, 1.24, 3.0))
	assert_near(float(bus["fraction"]), 0.9 / 4.08, 0.001, "a 4 m hull shows most of itself over a jersey barrier")
	assert_near(float(rat_rod["fraction"]), 0.9 / 1.24, 0.001, "a 1.24 m car is mostly behind it")


func test_cover_too_far_out_beside_or_behind_screens_nothing() -> void:
	var far := CoverMap.from_features([{"position": Vector2(0.0, -6.0), "size": [6.0, 0.9, 0.8], "rotation_deg": 0.0,
			"height": 0.9}])
	assert_eq(float(far.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), SCOUT)["fraction"]), 0.0,
			"5.6 m off the nose is not hull-down (reach 3 m past the face)")
	var map := CoverMap.from_features([BARRICADE])
	assert_eq(float(map.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, 1), SCOUT)["fraction"]), 0.0,
			"a shooter on the other side: the barricade is behind the hull")
	assert_eq(float(map.low_screen(Vector2(8.0, 0.0), Vector2(0, -1), Vector2(0, -1), SCOUT)["fraction"]), 0.0,
			"a hull beside the barricade's end is in the open")


func test_tall_cover_is_not_low_cover() -> void:
	var wall := CoverMap.from_features([{"position": Vector2(0.0, -3.0), "size": [6.0, 3.0, 0.8], "rotation_deg": 0.0,
			"height": 3.0}])
	assert_eq(float(wall.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), SCOUT)["fraction"]), 0.0,
			"a 3 m wall blocks the line of sight already (all-or-nothing cover), never a hull-down roll")


func test_a_barricade_narrower_than_the_hull_hides_only_its_width() -> void:
	var map := CoverMap.from_features([{"position": Vector2(0.0, -3.0), "size": [1.5, 0.9, 0.8], "rotation_deg": 0.0,
			"height": 0.9}])
	var screen := map.low_screen(Vector2.ZERO, Vector2(0, -1), Vector2(0, -1), Vector3(3.0, 1.5, 3.0))
	assert_near(float(screen["fraction"]), 0.5 * 0.9 / 1.5, 0.02, "half the 3 m width, 0.9 of 1.5 m of height")


func test_the_roll_is_uniform_and_deterministic() -> void:
	var below := 0
	for id in 20000:
		if Armor.cover_roll(id) < 0.6:
			below += 1
	assert_near(below / 20000.0, 0.6, 0.015, "share of ids under 0.6")
	assert_eq(Armor.cover_roll(12345), Armor.cover_roll(12345), "same id, same roll")


# ---- the rule in a real match: frontal hits fall by the stated fraction, flank hits unchanged --------------------

## `shooter` fires at `victim` for `seconds`; returns [rounds that hit the victim, rounds that struck cover].
func _volley(game_match: Match, shooter: Tank, victim: Tank, seconds: float) -> Array:
	var counts := [0, 0]
	var on_impact := func(event: Dictionary) -> void:
		if String(event.get("target", "")) == String(victim.name):
			counts[0] += 1
		elif not event.has("target") and Vector2(float(event["position"][0]) - victim.global_position.x,
				float(event["position"][2]) - victim.global_position.z).length() < 6.0:
			counts[1] += 1
	game_match.projectile_impact.connect(on_impact)
	for tick in SimClock.ticks(seconds):
		shooter.command = TankCommand.new(0.0, 0.0, victim.global_position + Vector3.UP, true)
		victim.command = TankCommand.new()
		await wait_physics_frames(1)
	game_match.projectile_impact.disconnect(on_impact)
	return counts


func _setup(gun: String) -> Dictionary:
	var arena := await ArenaFixture.build(self, "yard")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.elimination = true
	Armor.no_damage = true  # the victim must outlive the volley: hits are counted, not their damage
	var barricade := {}
	for feature: Dictionary in arena.cover_features():
		if feature["type"] == "barricade":
			barricade = feature
			break
	var shooter := game_match.spawn_tank("Gun", 0, Match.Team.GREEN, gun)
	var victim := game_match.spawn_tank("Hulldown", 0, Match.Team.RUST, "gang_scout")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	return {"match": game_match, "barricade": barricade, "shooter": shooter, "victim": victim}


## The victim tight behind the barricade's long face (its nose 1 m off it); the shooter 30 m out on the far side.
## `turn_deg` turns the victim's hull from facing the shooter (0: front arc; 90: its side to the gun).
func _place(setup: Dictionary, turn_deg: float) -> void:
	var feature: Dictionary = setup["barricade"]
	var basis := Basis(Vector3.UP, float(feature["rotation"]))
	var middle: Vector3 = feature["position"]
	# The barricade's open side: toward the arena's centre line (its other side is toward the base wall).
	var across := basis.z if middle.dot(basis.z) < 0.0 else -basis.z
	var victim: Tank = setup["victim"]
	var shooter: Tank = setup["shooter"]
	var length := float((Units.stat(victim.unit_id, "hull_size") as Array)[2])
	victim.global_position = middle - across * (0.4 + 1.0 + length * 0.5)
	shooter.global_position = middle + across * 30.0
	victim.look_at(shooter.global_position, Vector3.UP)
	victim.rotate_y(deg_to_rad(turn_deg))
	shooter.look_at(victim.global_position, Vector3.UP)
	victim.reset_physics_interpolation()
	shooter.reset_physics_interpolation()
	await wait_physics_frames(2)


## Shells (the IFV's autocannon, a PROJECTILE) through Match._shell_hit.
func test_frontal_shells_fall_by_the_hidden_fraction_and_flank_shells_do_not() -> void:
	await _frontal_and_flank("ifv", 20.0)


## Beams (the scout's machine gun, hitscan) through Match._fire_beam.
func test_frontal_beams_fall_by_the_hidden_fraction_and_flank_beams_do_not() -> void:
	await _frontal_and_flank("scout", 8.0)


func _frontal_and_flank(gun: String, seconds: float) -> void:
	var setup := await _setup(gun)
	assert_true(not (setup["barricade"] as Dictionary).is_empty(), "setup: yard has a barricade")
	if (setup["barricade"] as Dictionary).is_empty():
		return
	var game_match: Match = setup["match"]
	var victim: Tank = setup["victim"]
	var hull: Array = Units.stat(victim.unit_id, "hull_size")
	var hidden := minf(1.0, 0.9 / float(hull[1]))
	CoverMap.set_off("hulldown", true)
	await _place(setup, 0.0)
	var front_off := await _volley(game_match, setup["shooter"], victim, seconds)
	CoverMap.set_off("hulldown", false)
	await _place(setup, 0.0)
	var front_on := await _volley(game_match, setup["shooter"], victim, seconds)
	CoverMap.set_off("hulldown", true)
	await _place(setup, 90.0)
	var flank_off := await _volley(game_match, setup["shooter"], victim, seconds)
	CoverMap.set_off("hulldown", false)
	await _place(setup, 90.0)
	var flank_on := await _volley(game_match, setup["shooter"], victim, seconds)
	print("MEASURE hulldown %s v %s (hides %.2f): front hits off %d, on %d (+%d on the cover); flank off %d, on %d (+%d)" % [
			gun, victim.unit_id, hidden, front_off[0], front_on[0], front_on[1], flank_off[0], flank_on[0], flank_on[1]])
	assert_true(front_off[0] >= 15, "setup: the gun hits a hull it can see (%d)" % front_off[0])
	assert_eq(front_off[1], 0, "switch OFF: nothing strikes the cover")
	var kept := float(front_on[0]) / maxf(1.0, float(front_on[0] + front_on[1]))
	assert_near(kept, 1.0 - hidden, 0.2, "ON: the share of frontal rounds reaching the hull is 1 - hidden")
	assert_true(front_on[1] > 0, "ON: some rounds strike the barricade")
	assert_eq(flank_on[1], 0, "a flank shot is never stopped by the cover")
	assert_true(absi(flank_on[0] - flank_off[0]) <= maxi(2, flank_off[0] / 5),
			"flank hits unchanged (%d v %d)" % [flank_on[0], flank_off[0]])
