extends TestCase
## Round 17 G2: the mix lets a gun be the loudest thing in the room. The weapon sheet (make weapon-sheet) and the
## fight taps (audio-pass --audio-taps) found what took it away: a World limiter that lifted everything 3 dB and then
## clamped every loud sound to the same -6.5 dBTP, a distance filter Godot scales by the voice's own level (so a quiet
## gun was dulled even close), a 9 dB level swing across the 40-120 m he watches, and the booth's duck taking ~16 dB
## off the battle for the 70 % of a match it speaks. What can be checked headless is checked here; how it sounds is
## the audition page.


func test_nothing_on_the_world_bus_adds_gain_before_it_limits() -> void:
	var world := SfxSystem.ensure_world_bus()
	for i in AudioServer.get_bus_effect_count(world):
		var effect := AudioServer.get_bus_effect(world, i)
		assert_true(not (effect is AudioEffectLimiter),
				"no AudioEffectLimiter on World: it lifts everything by ceiling - threshold and then soft-clips the crack")
	var limiter := _world_limiter()
	assert_true(limiter != null, "the battle is still limited on its own bus, so its peaks never pump the booth")
	if limiter != null:
		assert_near(limiter.pre_gain_db, 0.0, 0.001, "with no make-up gain")


func test_the_booth_duck_is_tuned_here_and_gentle_whichever_bus_came_first() -> void:
	AnnouncerVoice.ensure_bus()
	SfxSystem.ensure_world_bus()
	var world := AudioServer.get_bus_index(SfxSystem.WORLD_BUS)
	var ducks: Array[AudioEffectCompressor] = []
	for i in AudioServer.get_bus_effect_count(world):
		var effect := AudioServer.get_bus_effect(world, i) as AudioEffectCompressor
		if effect != null and effect.sidechain == AnnouncerVoice.BUS:
			ducks.append(effect)
	assert_eq(ducks.size(), 1, "one duck under the booth")
	if ducks.size() == 1:
		assert_near(ducks[0].ratio, SfxSystem.BOOTH_DUCK["ratio"], 0.001, "tuned by SfxSystem, not left at 6:1")
		assert_true(ducks[0].ratio <= 3.0 and ducks[0].threshold >= -22.0,
				"the booth stays on top without the battle losing 16 dB whenever it talks")


func test_the_distance_filter_follows_distance_not_the_mix_level() -> void:
	## Godot dulls a voice by (1 - its linear gain) * filter_db, and that gain includes volume_db: a gun mixed at
	## -13 dB was filtered 9 dB at the camera's focus. SfxSystem compensates, so two guns at one distance are dulled
	## alike whatever their mix level.
	for distance in [30.0, 49.0, 80.0, 120.0, 300.0]:
		var loud := SfxSystem.effective_filter_db(0.0, distance, SfxSystem.filter_db_for(0.0, distance, -12.0))
		var quiet := SfxSystem.effective_filter_db(-13.0, distance, SfxSystem.filter_db_for(-13.0, distance, -12.0))
		assert_near(quiet, loud, 0.05, "at %d m a -13 dB gun is dulled like a 0 dB one" % int(distance))
	assert_true(absf(SfxSystem.effective_filter_db(0.0, 40.0, SfxSystem.filter_db_for(0.0, 40.0, -12.0))) < 1.0,
			"inside the unit size almost nothing is dulled (Godot's linear fade to max_distance leaves a fraction of a dB)")
	assert_true(SfxSystem.effective_filter_db(0.0, 300.0, SfxSystem.filter_db_for(0.0, 300.0, -12.0)) < -6.0,
			"across the arena it is")


func test_the_effective_filter_matches_what_the_probe_measured() -> void:
	## The model of Godot's filter, checked against the round-17 probe: mg_round (MIX -13, filter -12 dB) lost 10.1 dB
	## above 2 kHz at 49 m with the old UNIT_SIZE 55 / MAX_DISTANCE 600 (the shelf sits at 3 kHz, so a little less
	## than the full amount reaches 2-6 kHz).
	var db := SfxSystem.effective_filter_db(-13.0, 49.0, -12.0, 55.0, 600.0)
	assert_true(db < -8.5 and db > -10.5, "the model says %.1f dB" % db)


func test_the_fight_he_watches_keeps_its_weight() -> void:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	sfx.listener = Vector3.ZERO
	var near := sfx.heard_level_db(0.0, Vector3(40.0, 0, 0))
	var far := sfx.heard_level_db(0.0, Vector3(120.0, 0, 0))
	assert_true(near - far <= 6.0, "40 m to 120 m loses at most 6 dB (%.1f): distance is told by tail and brightness" % (near - far))
	assert_true(near <= 0.0 and near > -1.0, "and inside the unit size a sound plays at about its own level (%.2f)" % near)


func test_the_heavy_guns_and_the_kill_lead_the_mix() -> void:
	var level := func(sound: String) -> float: return float(SfxSystem.MIX[sound][0])
	assert_true(level.call("explosion_big") >= level.call("tank_boom"), "the kill is the biggest event in the game")
	assert_true(level.call("tank_boom") >= level.call("autocannon_shot") + 2.0, "a tank shot over a 25 mm round")
	assert_true(level.call("mg_round") >= level.call("autocannon_shot") - 6.0,
			"a machine-gun round is a gun, not a tick (it was 7 dB under the 25 mm and 20 dB under a tank at the master)")


func _world_limiter() -> AudioEffectHardLimiter:
	var world := AudioServer.get_bus_index(SfxSystem.WORLD_BUS)
	for i in AudioServer.get_bus_effect_count(world):
		if AudioServer.get_bus_effect(world, i) is AudioEffectHardLimiter:
			return AudioServer.get_bus_effect(world, i)
	return null


func test_the_launch_mix_is_kept_whole_for_the_before_and_after() -> void:
	## --mix=launch rebuilds the pre-round-17 mix in this build (one tree, one match for the comparison); with no flag
	## the game plays the new one. The launch numbers are 3713fdaa's, copied, not re-derived.
	assert_true(not SfxSystem.launch_mix(), "no flag: the new mix")
	assert_eq(SfxSystem.booth_duck(), SfxSystem.BOOTH_DUCK, "and the new booth duck")
	var old: Dictionary = SfxSystem.BOOTH_DUCKS["launch"]
	assert_near(float(old["threshold"]), -28.0, 0.001, "the launch duck: -28 dB")
	assert_near(float(old["ratio"]), 6.0, 0.001, "at 6:1")
	assert_near(float(SfxSystem.LAUNCH_MIX["world_trim_db"]), -6.0, 0.001, "the launch trim")
	assert_near(float(SfxSystem.LAUNCH_MIX["filter"]["tank_boom"][0]), 1400.0, 0.001, "the launch tank filter shelf")
	assert_eq(SfxSystem.BOOTH_DUCKS["new"], SfxSystem.BOOTH_DUCK, "the page's 'new' is the shipped default")
