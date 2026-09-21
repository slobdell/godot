extends TestCase
## S6, the arena light show: the CUES — what makes it an entertainment event rather than random breathing
## (`_agents/lighting.md` section 6). The lead: *"rather than just randomly having breathing lights ... imagine light
## shows in Las Vegas."*
##
## Idle is the slow breathe; the cues are the show. What these tests hold is that the cues can never break the two
## rules the idle guarantees — a core fixture never goes fully dark, and nothing goes to full blast — and that a cue
## change is a change of RATE, never a jump.

const BOOK := "res://game/theme/show/cues.json"


func _patched_show() -> Show:
	var show := Show.new()
	add_to_tree(show)
	show.cues = ShowCues.load_book(BOOK)
	assert_eq(show.cues.problem, "", "the cue book loads: %s" % show.cues.problem)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://arenas/terminus.json"))
	assert_eq(show.load_patch(data["show"], "terminus"), "", "the Terminus patch loads")
	return show


# --- the book itself -------------------------------------------------------------------------------------------

func test_the_shipped_cue_book_loads_and_every_state_is_one_the_match_can_reach() -> void:
	var cues := ShowCues.load_book(BOOK)
	assert_eq(cues.problem, "", cues.problem)
	for state: Variant in cues.states:
		assert_true(MatchMood.STATES.has(str(state)) or state == ShowCues.FIGHT_STATE,
				"'%s' is a state a match actually reaches" % state)
	for state in MatchMood.STATES:
		assert_true(cues.states.has(StringName(state)), "every mood the match can be in has a cue ('%s')" % state)
	assert_true(cues.events.has(&"kill"), "the kill ripple is in the book")


func test_a_typo_in_the_book_is_an_error_rather_than_a_cue_that_never_fires() -> void:
	var cues := ShowCues.new()
	assert_true(cues.load_data({"states": {"batttle": {"set": {}}}}).contains("not a mood state"),
			"a misspelled state is refused, not silently ignored")
	assert_true(cues.load_data({"states": {"battle": {"set": {"rim": {"programme": "wobble"}}}}}).contains("wobble"),
			"an unknown programme is named")
	assert_true(cues.load_data({"states": {"battle": {"set": {"rim": {"period": 0.05}}}}}).contains("read as a fault"),
			"a 0.05 s period is refused even in a cue")


func test_only_the_victory_cue_carries_a_team_colour() -> void:
	# art_direction.md: venue lighting must not read as a team. The victory sweep is the one deliberate exception,
	# and it is a cue rather than a fixture default, which is the whole reason that exception is safe.
	var cues := ShowCues.load_book(BOOK)
	for state: Variant in cues.states:
		for channel: Variant in cues.states[state]["set"]:
			var override: Dictionary = cues.states[state]["set"][channel]
			if not override.has("color"):
				continue
			assert_eq(str(state), "victory", "only victory colours a fixture (found one on '%s')" % state)
			assert_eq(str(override["color"]), "winner", "and it is the WINNER's colour, not a hard-coded hue")


# --- a cue can never break the idle's guarantees -----------------------------------------------------------------

func test_no_cue_can_take_a_lit_fixture_dark_or_past_the_patch_ceiling() -> void:
	# The clamp in ShowCues.blend is what makes this true by construction rather than by everyone being careful.
	var show := _patched_show()
	for state: Variant in show.cues.states:
		show.settle_into(StringName(str(state)), 0.0)
		for key: Variant in show.channels:
			var base: ShowChannel = show.channels[key]
			var live: ShowChannel = show.live_channel(key)
			if Show.CORE_PARAMETERS.has(&"level") and base.level_floor > 0.0:
				assert_true(live.level_floor > 0.0,
						"%s under '%s' keeps a floor above zero (%.3f)" % [key, state, live.level_floor])
			assert_true(live.level_ceiling <= base.level_ceiling + 0.0001,
					"%s under '%s' stays under the patch ceiling (%.3f vs %.3f)"
					% [key, state, live.level_ceiling, base.level_ceiling])
			assert_true(live.level_floor >= base.level_floor - 0.0001,
					"%s under '%s' stays above the patch floor (%.3f vs %.3f)"
					% [key, state, live.level_floor, base.level_floor])


func test_a_cue_that_asks_for_more_than_the_patch_allows_is_clamped_not_obeyed() -> void:
	var base := ShowChannel.from_data(&"rim", {"period": 24.0, "floor": 0.6, "ceiling": 1.25})
	var greedy := ShowCues.blend(base, {"floor": 0.0, "ceiling": 9.0}, 1.0)
	assert_near(greedy.level_floor, 0.6, 0.0001, "the floor cannot be lowered past the patch's")
	assert_near(greedy.level_ceiling, 1.25, 0.0001, "and the ceiling cannot be raised past it")


# --- attack and release: cues never pop --------------------------------------------------------------------------

func test_a_cue_ramps_in_over_its_attack_instead_of_snapping() -> void:
	var show := _patched_show()
	show.mood_state = &"battle"
	var attack := float(show.cues.for_state(&"battle")["attack"])
	var before: ShowChannel = show.channels[&"rim"]
	show.apply(0.0, 0.0)
	assert_near(show.live_channel(&"rim").period, before.period, 0.01, "nothing has moved on the first frame")
	var steps := 0
	var t := 0.0
	while steps < 600 and absf(show.live_channel(&"rim").period - 5.5) > 0.1:
		t += 0.02
		show.apply(t, 0.02)
		steps += 1
	assert_true(steps > 10, "the rim took more than a frame or two to reach the battle period (%d frames)" % steps)
	assert_near(float(steps) * 0.02, attack, 0.15, "and it took about the cue's attack (%.2f s)" % (steps * 0.02))


func test_a_programme_swap_changes_the_rate_and_never_jumps_the_clock() -> void:
	# The rim going from a 24 s breathe to a 1.6 s strobe is the worst case in the book. If the clock were
	# recomputed from t rather than retuned, the fixture would tear on the frame the period changed.
	var show := _patched_show()
	show.mood_state = &"last_stand"
	var t := 40.0
	show.apply(t, 0.0)
	var previous := show.live_channel(&"rim").clock(t)
	var worst := 0.0
	for i in 400:
		t += 1.0 / 60.0
		show.apply(t, 1.0 / 60.0)
		var here := show.live_channel(&"rim").clock(t)
		worst = maxf(worst, absf(here - previous))
		previous = here
	# One frame of a 1.6 s period is TAU/1.6/60 = 0.065 rad. Anything near a radian is a jump.
	assert_true(worst < 0.2, "the clock never jumped: worst single-frame step %.4f rad" % worst)


func test_the_fight_cue_is_armed_before_the_first_fixture_registers() -> void:
	# The venue is built while the Show is still a deferred add_child, so a cue book loaded in _ready() arrives
	# AFTER the arena has been patched -- and the FIGHT cue, the one the loading screen drops into, would never
	# fire. Loading it lazily on the first registration is the fix, and this is the test that holds it.
	# Deliberately NOT in the tree: that is the real situation, because the running show mounts itself with a
	# DEFERRED add_child and the venue is built before it lands, so _ready() has not run when a block registers.
	var show := Show.new()
	show.follows_active_arena = true
	assert_true(show.cues == null, "_ready() has not run, so the book is not loaded yet")
	show.add_fixture(&"rim", ShaderMaterial.new())
	assert_true(show.cues != null, "registering a fixture loads it anyway")
	assert_eq(show.cues.problem, "", "and the shipped book is valid: %s" % show.cues.problem)
	show.free()


func test_the_fight_cue_holds_then_hands_over_to_the_mood() -> void:
	var cues := ShowCues.load_book(BOOK)
	var fight: Dictionary = cues.states[ShowCues.FIGHT_STATE]
	assert_true(float(fight["hold"]) > 0.0, "the FIGHT cue declares how long it holds")
	assert_true(fight["set"].has("rim"), "it lifts the rim")
	# control: cutaway_near() can clip the near wall away entirely when the camera is outside the perimeter, which
	# is every spawn at the lead's low pitch. So the rim must not be the ONLY thing carrying match start.
	var lifts_something_inside: bool = fight["set"].has("edges") or fight["set"].has("beams") or fight["set"].has("signs")
	assert_true(lifts_something_inside,
			"and something inside the perimeter too: the rim can be clipped away at spawn (control, 2026-09-20)")


func test_softening_the_strobes_changes_only_the_strobes() -> void:
	# `--no-strobe` is the comparison arm for the lead's call on whether the last_stand strobe survives. It is only
	# a fair comparison if the two arms differ in the strobe and in NOTHING ELSE -- which is why it edits the
	# loaded book rather than shipping a second one that could drift.
	var before := ShowCues.load_book(BOOK)
	var after := ShowCues.load_book(BOOK)
	after.soften_strobes(6.0)
	var softened := 0
	var untouched := 0
	for state: Variant in before.states:
		var a: Dictionary = before.states[state]["set"]
		var b: Dictionary = after.states[state]["set"]
		assert_eq(b.keys(), a.keys(), "'%s' overrides the same channels in both arms" % state)
		for channel: Variant in a:
			var was: Dictionary = a[channel]
			var now: Dictionary = b[channel]
			if str(was.get("programme", "")) == "strobe":
				softened += 1
				assert_eq(str(now["programme"]), "breathe", "%s/%s is a breathe now" % [state, channel])
				assert_near(float(now["period"]), 6.0, 0.001, "%s/%s took the new period" % [state, channel])
				assert_near(float(now.get("floor", -1.0)), float(was.get("floor", -1.0)), 0.0001,
						"%s/%s keeps its floor: the arms differ in the PROGRAMME, not the band" % [state, channel])
				assert_near(float(now.get("ceiling", -1.0)), float(was.get("ceiling", -1.0)), 0.0001,
						"%s/%s keeps its ceiling" % [state, channel])
			else:
				untouched += 1
				assert_eq(str(now.get("programme", "")), str(was.get("programme", "")),
						"%s/%s is not a strobe and must not move" % [state, channel])
				assert_eq(now.get("period", null), was.get("period", null),
						"%s/%s keeps its period" % [state, channel])
	assert_true(softened >= 2, "the book really does contain strobes to soften (%d)" % softened)
	assert_true(untouched > softened, "and most of the book is left alone (%d untouched)" % untouched)
	for state: Variant in after.states:
		assert_eq(float(after.states[state]["attack"]), float(before.states[state]["attack"]),
				"'%s' keeps its attack: only the programme changes" % state)


# --- the kill ripple ---------------------------------------------------------------------------------------------

func test_the_ripple_fires_on_a_kill_and_on_nothing_quieter() -> void:
	# FxWorld.spectacle is NOT a kill signal: fx_world.gd:319 emits 0.15 for a near miss, weapon_fx.gd:278 emits
	# 0.3 for a plain hit and :378 emits 0.5 for a weak spot. Only a kill is 1.0. Wiring a venue-wide effect to
	# that bus without reading `weight` fires it several times a second in a 30-a-side fight (feel, 2026-09-20).
	var show := _patched_show()
	var material := ShaderMaterial.new()
	show.add_fixture(&"city_block", material)
	for weight in [0.15, 0.3, 0.5]:
		show.fire_event(Vector3(10, 0, 20), float(weight))
		show.apply(1.0, 0.1)
		var quiet: Vector4 = material.get_shader_parameter("show_event")
		assert_near(quiet.w, 0.0, 0.0001, "weight %s is a hit, not a kill: no ripple" % weight)
	show.fire_event(Vector3(10, 0, 20), 1.0)
	show.apply(1.0, 0.1)
	var loud: Vector4 = material.get_shader_parameter("show_event")
	assert_true(loud.w > 0.0, "a kill ripples")
	assert_near(loud.x, 10.0, 0.0001, "from where it happened")
	assert_near(loud.y, 20.0, 0.0001, "in world x and z")
	assert_true(loud.z > 0.0, "with a wavefront that has started travelling")


func test_the_ripple_travels_outward_and_then_puts_every_fixture_back() -> void:
	var show := _patched_show()
	var material := ShaderMaterial.new()
	show.add_fixture(&"city_block", material)
	show.fire_event(Vector3.ZERO, 1.0)
	var radius := 0.0
	var gain := 999.0
	for i in 10:
		show.apply(1.0, 0.1)
		var value: Vector4 = material.get_shader_parameter("show_event")
		assert_true(value.z > radius, "the wavefront keeps moving outward (%.1f m)" % value.z)
		assert_true(value.w < gain, "and keeps fading (%.3f)" % value.w)
		radius = value.z
		gain = value.w
	for i in 40:
		show.apply(1.0, 0.1)
	assert_eq(material.get_shader_parameter("show_event"), Vector4.ZERO,
			"when it has run its life every fixture is back exactly where it was")
	assert_eq(show.apply(1.0, 0.1), show.writes_for(1.0), "and the ripple stops costing anything")
