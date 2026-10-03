extends TestCase
## Round 17 G5: where a round lands is audible as what it hit. The impact event carries a position and a normal and,
## on a vehicle, the target; what a MISS struck is read from the arena's own layout (Arena.active: obstacle types,
## footprints, water) by SfxSurfaces - presentation only, the event contract unchanged.

const LAYOUT := {
	"half_size": 100.0,
	"obstacles": [
		{"type": "container_40", "position": [10.0, 0.0], "rotation_deg": 0.0, "size": [12.19, 2.6, 2.44]},
		{"type": "block", "position": [-30.0, 0.0], "rotation_deg": 0.0, "size": [20.0, 18.0, 20.0]},
		{"type": "barricade", "position": [0.0, 30.0], "rotation_deg": 90.0, "size": [4.0, 1.2, 0.8]},
		{"type": "wreck", "position": [40.0, 40.0], "rotation_deg": 0.0, "size": [6.0, 2.0, 3.0]},
		{"type": "container_40", "position": [60.0, 60.0], "rotation_deg": 30.0, "size": [12.19, 2.6, 2.44]},
	],
	"terrain": [{"kind": "water", "name": "canal", "rect": [0.0, -50.0, 40.0, 10.0]}],
}


func test_a_miss_knows_what_it_struck() -> void:
	assert_eq(SfxSurfaces.surface_at(Vector3(10.0, 1.2, 1.3), Vector3(0, 0, 1), LAYOUT), "steel", "a container's flank")
	assert_eq(SfxSurfaces.surface_at(Vector3(-20.0, 3.0, 0.0), Vector3(1, 0, 0), LAYOUT), "concrete", "a tower block's face")
	assert_eq(SfxSurfaces.surface_at(Vector3(0.4, 0.6, 30.0), Vector3(1, 0, 0), LAYOUT), "concrete",
			"a barricade, turned 90°: its footprint turns with it")
	assert_eq(SfxSurfaces.surface_at(Vector3(40.0, 1.0, 41.4), Vector3(0, 0, 1), LAYOUT), "steel", "a wreck")
	assert_eq(SfxSurfaces.surface_at(Vector3(5.0, 0.0, -50.0), Vector3.UP, LAYOUT), "water", "the canal")
	assert_eq(SfxSurfaces.surface_at(Vector3(60.0, 0.0, -10.0), Vector3.UP, LAYOUT), "ground", "open ground")
	assert_eq(SfxSurfaces.surface_at(Vector3(99.8, 1.5, 0.0), Vector3(-1, 0, 0), LAYOUT), "concrete", "the arena's wall")
	# Yard's CP1 turns ground-level containers for real: the turned box's end, which a square box would miss by metres.
	var corner := Vector2(60.0, 60.0) + Vector2(5.9, 0.0).rotated(-deg_to_rad(30.0))
	assert_eq(SfxSurfaces.surface_at(Vector3(corner.x, 1.0, corner.y), Vector3(1, 0, 0), LAYOUT), "steel",
			"the end of a container turned 30° is steel")
	assert_eq(SfxSurfaces.surface_at(Vector3(65.9, 1.0, 60.0), Vector3(1, 0, 0), LAYOUT), "ground",
			"and where its square twin's end would have been is open ground")
	assert_eq(SfxSurfaces.surface_at(Vector3(10.0, 0.05, 4.5), Vector3.UP, LAYOUT), "ground",
			"the ground beside a container is still ground")


func test_every_surface_and_calibre_asks_for_its_own_sound() -> void:
	var heard := {}
	for calibre in SfxSurfaces.CALIBRES:
		for surface in SfxSurfaces.SURFACES:
			var sound := SfxSurfaces.miss_sound(String(calibre), String(surface))
			assert_true(sound != "", "%s into %s makes a sound" % [calibre, surface])
			heard[sound] = true
		assert_true(SfxSurfaces.hit_sound(String(calibre)) != "", "%s on armour makes a sound" % calibre)
	assert_true(heard.size() >= 10, "the table is not one sound renamed (%d distinct)" % heard.size())
	assert_true(SfxSurfaces.hit_sound("heavy") != SfxSurfaces.hit_sound("light"), "a 120 mm on armour is not a bullet")
	assert_true(SfxSurfaces.hit_sound("medium") != SfxSurfaces.hit_sound("light"), "nor is a 25 mm")


func test_every_sound_in_the_table_can_play() -> void:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	for sound in SfxSurfaces.all_sounds():
		assert_true(sfx.streams.has(sound) or SfxSystem.ALIAS.has(sound), "%s is a sound SfxSystem can play" % sound)


func test_the_fire_models_map_to_calibres() -> void:
	assert_eq(SfxSurfaces.calibre_of("shell"), "heavy", "a tank shell is heavy")
	assert_eq(SfxSurfaces.calibre_of("arc"), "heavy", "so is a mortar round")
	assert_eq(SfxSurfaces.calibre_of("burst"), "medium", "the 25 mm is medium")
	assert_eq(SfxSurfaces.calibre_of("stream"), "light", "a machine gun is light")


func test_a_stream_stitching_a_wall_is_a_texture_not_fourteen_voices() -> void:
	## 14 rounds a second into one spot for a second: a handful of impacts, not one per round.
	var limiter := SfxSurfaces.RateLimit.new()
	var played := 0
	for i in 14:
		if limiter.allow("light", Vector3(10.0, 1.0, 1.3), i / 14.0):
			played += 1
	assert_true(played >= 3 and played <= 6, "a 14-round stream plays %d impacts in a second" % played)
	var heavy := 0
	for i in 3:
		if limiter.allow("heavy", Vector3(0.0, 0.0, 0.0), 2.0 + i * 0.05):
			heavy += 1
	assert_eq(heavy, 3, "three shells landing together are three impacts")


func _fire(fx: FxWorld, model: String, id: int, direction := Vector3.FORWARD) -> void:
	var weapon: String = {"shell": "cannon", "burst": "autocannon", "stream": "machine_gun", "arc": "mortar"}[model]
	var event := K2Events.fired_event(10, "", weapon, Weapons.profile(weapon), Vector3(0, 1.3, 20), direction, id)
	event["fire_model"] = model
	fx.weapons.fired(event)


func _land(fx: FxWorld, id: int, position: Vector3, normal: Vector3, target := "") -> PackedStringArray:
	fx.weapons.impact(K2Events.impact_event(12, id, position, normal, target, false))
	return fx.weapons.last_pieces


func test_weapon_fx_plays_what_the_round_struck() -> void:
	var saved := Arena.active
	Arena.active = LAYOUT
	var fx: FxWorld = add_to_tree(FxWorld.new())
	_fire(fx, "burst", 1)
	assert_true(_land(fx, 1, Vector3(10.0, 1.2, 1.3), Vector3(0, 0, 1)).has("sound:impact_steel_medium"),
			"a 25 mm round into a container rings steel")
	_fire(fx, "shell", 2)
	assert_true(_land(fx, 2, Vector3(-20.0, 3.0, 0.0), Vector3(1, 0, 0)).has("sound:impact_concrete_heavy"),
			"a tank shell into a tower block is concrete, not dirt")
	_fire(fx, "shell", 3)
	assert_true(_land(fx, 3, Vector3(5.0, 0.0, -50.0), Vector3.UP).has("sound:impact_water_heavy"), "into the canal")
	_fire(fx, "shell", 4)
	assert_true(_land(fx, 4, Vector3(60.0, 0.0, -10.0), Vector3.UP).has("sound:dirt_impact"), "open ground is still dirt")
	_fire(fx, "stream", 5)
	assert_true(_land(fx, 5, Vector3(-20.0, 1.0, 0.0), Vector3(1, 0, 0)).has("sound:impact_concrete_light"),
			"a machine-gun miss is no longer silent")
	Arena.active = saved


func test_a_25mm_hit_on_a_vehicle_is_not_a_bullet() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	_fire(fx, "burst", 7)
	assert_true(_land(fx, 7, Vector3(0, 1.2, -25), Vector3.BACK, "Target").has("sound:impact_armor_medium"),
			"a 25 mm round on armour is its own sound")
