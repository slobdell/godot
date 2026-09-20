extends TestCase
## S6, the arena light show (`_agents/lighting.md`): the channel engine. These tests hold the four properties the
## whole architecture rests on, and each one exists because losing it silently is the failure mode:
##
##   1. a channel is a PURE function of frame time (no per-frame state, no clock read in a decision);
##   2. the CPU's waveform and the shader's are the SAME line (the contract between two implementations);
##   3. the per-frame cost is O(patch entries), never O(instances) -- the guard against this becoming per-instance
##      writes in a year's time;
##   4. a fixture nobody patches looks exactly as it does today.

const SHADER_INCLUDE := "res://game/theme/fx/shaders/show.gdshaderinc"
const CHANNELS_SOURCE := "res://game/theme/show/channels.gd"
const SHOW_DIR := "res://game/theme/show"


func _show(patch: Variant, arena := "test") -> Array:
	var show := Show.new()
	add_to_tree(show)
	return [show, show.load_patch(patch, arena)]


func _breathing_patch() -> Dictionary:
	return {
		"channels": {
			# The verified set: pairwise incommensurate (no p/q with p, q <= 4 within 2%), phases on the golden
			# angle. 17.3 / 21.7 / 13.1 was the first draft and this file's own validator refused it -- 17.3 : 13.1
			# is 4:3 to within 1%, which is exactly the ensemble-loops failure the rule exists to catch.
			"rim": {"programme": "breathe", "period": 24.0, "phase": 0.00, "floor": 0.55, "ceiling": 1.0},
			"edges": {"programme": "breathe", "period": 19.7, "phase": 3.88, "floor": 0.20, "ceiling": 1.0},
			"windows": {"programme": "breathe", "period": 22.2, "phase": 1.48, "floor": 0.85, "ceiling": 1.25},
		},
		"patch": [
			{"fixture": "rim", "parameter": "level", "channel": "rim", "spread": 1.0},
			{"fixture": "city_block", "parameter": "edge", "channel": "edges", "spread": 1.0},
			{"fixture": "city_block", "parameter": "window", "channel": "windows", "spread": 1.0},
		],
	}


# --- 1. purity -----------------------------------------------------------------------------------------------

func test_a_channel_is_a_pure_function_of_frame_time() -> void:
	var channel := ShowChannel.from_data(&"rim", {"period": 17.3, "phase": 0.4, "floor": 0.3, "ceiling": 1.0})
	var first := channel.level(3.0)
	for t in [9.0, 0.0, 41.5, 3.0000001, 120.0]:
		channel.level(float(t))
	assert_eq(channel.level(3.0), first, "the same t gives the same value, whatever was asked in between")
	assert_near(channel.level(3.0 + channel.period), first, 0.0001, "and it repeats exactly one period later")
	assert_near(channel.level(-4.0), channel.level(-4.0 + 2.0 * channel.period), 0.0001, "including before t = 0")


func test_a_channel_never_leaves_its_floor_and_ceiling() -> void:
	for programme in ShowChannel.PROGRAMMES:
		var channel := ShowChannel.from_data(&"c", {"programme": str(programme), "period": 11.0, "floor": 0.25, "ceiling": 0.8})
		var low := 999.0
		var high := -999.0
		for i in 400:
			var value := channel.level(float(i) * 0.137)
			low = minf(low, value)
			high = maxf(high, value)
		assert_true(low >= 0.25 - 0.0001, "%s never falls below its floor (%.4f)" % [programme, low])
		assert_true(high <= 0.8 + 0.0001, "%s never rises above its ceiling (%.4f)" % [programme, high])
	var held := ShowChannel.from_data(&"c", {"programme": "hold", "period": 11.0, "floor": 0.25, "ceiling": 0.8})
	assert_near(held.level(0.0), 0.8, 0.0001, "a hold sits at its ceiling")
	assert_near(held.level(7.3), 0.8, 0.0001, "and stays there")


func test_sharpness_is_what_separates_a_breathe_from_a_strobe() -> void:
	var breathe := ShowChannel.from_data(&"b", {"programme": "breathe", "period": 12.0, "floor": 0.0, "ceiling": 1.0})
	var strobe := ShowChannel.from_data(&"s", {"programme": "strobe", "period": 12.0, "floor": 0.0, "ceiling": 1.0})
	var breathe_lit := 0
	var strobe_lit := 0
	for i in 600:
		var t := float(i) * 0.02
		breathe_lit += 1 if breathe.level(t) > 0.5 else 0
		strobe_lit += 1 if strobe.level(t) > 0.5 else 0
	assert_true(breathe_lit > 250 and breathe_lit < 350, "a breathe is over half brightness about half the time (%d/600)" % breathe_lit)
	assert_true(strobe_lit > 0 and strobe_lit < 60, "a strobe is a short stab, not a square wave (%d/600)" % strobe_lit)


# --- 2. the CPU and the shader run the same line -------------------------------------------------------------

func test_the_gdscript_waveform_is_character_for_character_the_shaders() -> void:
	# If these two ever drift, the headless tests stop describing what the player sees. Normalising language
	# differences (maxf/max, := /=, the constant's name) is deliberate: anything else must match.
	var shader := FileAccess.get_file_as_string(SHADER_INCLUDE)
	var script := FileAccess.get_file_as_string(CHANNELS_SOURCE)
	assert_true(shader != "" and script != "", "both sources are readable")
	var shader_body := _normalise(_body_after(shader, "float show_value(vec4 chan, float phase) {"))
	var script_body := _normalise(_body_after(script, "static func level_at(chan: Vector4, instance_phase: float) -> float:"))
	assert_true(shader_body != "", "show.gdshaderinc still defines show_value()")
	assert_true(script_body != "", "channels.gd still defines level_at()")
	assert_eq(script_body, shader_body, "ShowChannel.level_at() and show_level() are the same waveform")


func test_the_shader_clamps_the_pow_base_so_a_trough_is_not_undefined() -> void:
	# pow() is undefined for a negative base and for pow(0, 0); 0.5 + 0.5*sin() touches exactly 0 and can land a
	# hair under it in float. Mesa, Adreno and ANGLE disagree about what undefined means (feel, 2026-09-20).
	var shader := FileAccess.get_file_as_string(SHADER_INCLUDE)
	assert_true(shader.contains("SHOW_BASE_MIN"), "the shader clamps the base")
	var trough := ShowChannel.from_data(&"c", {"programme": "strobe", "period": 10.0, "phase": 0.0, "floor": 0.0, "ceiling": 1.0})
	# The exact trough: clock + phase = -PI/2 puts sin() at -1 and the base at 0.
	var t := trough.period * (-0.25)
	var value := trough.level(t)
	assert_true(is_finite(value) and value >= 0.0, "the trough is finite and not negative (%s)" % value)


func _body_after(source: String, signature: String) -> String:
	var at := source.find(signature)
	if at < 0:
		return ""
	var rest := source.substr(at + signature.length())
	var kept := PackedStringArray()
	for line in rest.split("\n"):
		# The body ends at the shader's closing brace, or -- in GDScript, which has none -- at the first line that
		# is not indented, i.e. the next top-level declaration.
		if line.begins_with("}"):
			break
		var text := line.strip_edges()
		if text == "" or text.begins_with("//") or text.begins_with("#"):
			continue
		if not (line.begins_with("\t") or line.begins_with(" ")):
			break
		kept.append(text)
	return "\n".join(kept)


func _normalise(body: String) -> String:
	var text := body
	for pair in [["maxf(", "max("], ["var ", ""], [":=", "="], ["instance_phase", "phase"],
			["BASE_MIN", "SHOW_BASE_MIN"], ["SHOW_SHOW_BASE_MIN", "SHOW_BASE_MIN"], ["float ", ""], [";", ""], [" ", ""]]:
		text = text.replace(pair[0], pair[1])
	return text


# --- 3. the cost is O(patch entries), never O(instances) ------------------------------------------------------

func test_one_frame_costs_one_write_per_patch_entry_however_many_instances_there_are() -> void:
	var result := _show(_breathing_patch())
	var show: Show = result[0]
	assert_eq(result[1], "", "the patch loads")
	var rim := ShaderMaterial.new()
	var facade := ShaderMaterial.new()
	show.add_fixture(&"rim", rim)
	# Eight city blocks, each registering the ONE material they share. The show must not learn there are eight.
	for i in 8:
		show.add_fixture(&"city_block", facade)
	assert_eq(show.fixtures_for(&"city_block").size(), 1, "eight blocks register one driven material between them")
	assert_eq(show.apply(4.0), 3, "three patch entries, three writes")
	assert_eq(show.writes_last_frame, show.writes_for(4.0), "the predicted cost is the cost paid")
	# Doubling the blocks must not double the cost.
	for i in 24:
		show.add_fixture(&"city_block", facade)
	assert_eq(show.apply(5.0), 3, "thirty-two blocks still cost three writes")


func test_a_colour_cue_costs_its_two_extra_writes_and_says_so() -> void:
	var patch := _breathing_patch()
	patch["channels"]["rim"]["color"] = "#ff0099"
	var result := _show(patch)
	var show: Show = result[0]
	assert_eq(result[1], "", "a colour channel loads")
	show.add_fixture(&"rim", ShaderMaterial.new())
	show.add_fixture(&"city_block", ShaderMaterial.new())
	assert_eq(show.apply(1.0), 5, "the colour channel writes its level, colour and mix; the other two write once each")
	assert_eq(show.report()["writes_per_frame"], 5, "and the report says the same number")


func test_the_show_writes_the_value_the_shader_would_compute() -> void:
	var result := _show(_breathing_patch())
	var show: Show = result[0]
	var rim := ShaderMaterial.new()
	show.add_fixture(&"rim", rim)
	show.apply(6.25)
	var packed: Vector4 = rim.get_shader_parameter("show_level")
	var channel: ShowChannel = show.channels[&"rim"]
	assert_near(ShowChannel.level_at(packed, 0.0), channel.level(6.25), 0.0001, "the packed vec4 is the channel")
	assert_near(packed.x, 0.55, 0.0001, "floor rides in .x")
	assert_near(packed.y, 0.45, 0.0001, "span in .y")
	assert_near(packed.w, 1.0, 0.0001, "sharpness in .w")
	var early := ShowChannel.level_at(packed, 0.0)
	var offset := ShowChannel.level_at(packed, 1.7)
	assert_true(absf(early - offset) > 0.001, "a per-instance phase moves the value: this is how eight blocks desync")


func test_spread_is_written_once_at_registration_and_never_per_frame() -> void:
	var result := _show(_breathing_patch())
	var show: Show = result[0]
	var facade := ShaderMaterial.new()
	show.add_fixture(&"city_block", facade)
	assert_near(float(facade.get_shader_parameter("show_spread")), 1.0, 0.0001, "the patch's spread reached the material")
	facade.set_shader_parameter("show_spread", 0.5)
	show.apply(2.0)
	assert_near(float(facade.get_shader_parameter("show_spread")), 0.5, 0.0001,
			"a frame does not rewrite it: spread is constant per arena and costs nothing per frame")


# --- 4. an unpatched fixture looks exactly as it does today ---------------------------------------------------

func test_no_show_key_is_todays_static_look() -> void:
	var result := _show(null)
	var show: Show = result[0]
	assert_eq(result[1], "", "a layout with no 'show' key is not an error")
	var facade := ShaderMaterial.new()
	show.add_fixture(&"city_block", facade)
	assert_eq(show.apply(3.0), 0, "nothing is driven")
	assert_eq(facade.get_shader_parameter("show_level"), Show.identity_for(&"level"), "level is a constant 1.0")
	assert_eq(facade.get_shader_parameter("show_window"), Show.identity_for(&"window"), "windows are a constant 1.0")
	assert_eq(facade.get_shader_parameter("show_edge"), Show.identity_for(&"edge"), "the edge emission stays off")
	assert_near(float(facade.get_shader_parameter("show_color_mix")), 0.0, 0.0001, "no colour override")


func test_identity_values_reproduce_a_multiplier_of_one_and_an_emission_of_zero() -> void:
	assert_near(ShowChannel.level_at(Show.identity_for(&"level"), 0.0), 1.0, 0.0001, "a multiplier of exactly 1.0")
	assert_near(ShowChannel.level_at(Show.identity_for(&"level"), 2.2), 1.0, 0.0001, "at every instance phase")
	assert_near(ShowChannel.level_at(Show.identity_for(&"edge"), 1.1), 0.0, 0.0001, "and an edge emission of exactly 0")


func test_a_parameter_a_patch_drops_goes_back_to_its_identity() -> void:
	var result := _show(_breathing_patch())
	var show: Show = result[0]
	var facade := ShaderMaterial.new()
	show.add_fixture(&"city_block", facade)
	show.apply(2.0)
	assert_true(facade.get_shader_parameter("show_edge") != Show.identity_for(&"edge"), "the edge is driven")
	# A second arena with no show key must not inherit the first arena's cue on a shared, cached material.
	var plain := Show.new()
	add_to_tree(plain)
	assert_eq(plain.load_patch({}, "plain"), "", "an empty show key loads")
	plain.add_fixture(&"city_block", facade)
	assert_eq(facade.get_shader_parameter("show_edge"), Show.identity_for(&"edge"),
			"registering with an unpatched show puts the shared material back to today's look")


# --- the patch validator says what is wrong, in words a reader can act on -------------------------------------

func test_the_validator_refuses_an_ensemble_that_would_visibly_loop() -> void:
	var patch := _breathing_patch()
	patch["channels"]["edges"]["period"] = 24.0 / 1.25  # 5:4 against the rim -- the ratio that slipped through at 4
	var result := _show(patch)
	assert_true(String(result[1]).contains("visibly loop"), "a 5:4 pair is refused: %s" % result[1])
	assert_true(String(result[1]).contains("5:4") or String(result[1]).contains("4:5"), "and it names the ratio: %s" % result[1])


func test_the_validator_refuses_phases_that_would_pulse_together() -> void:
	var patch := _breathing_patch()
	patch["channels"]["edges"]["phase"] = 0.02  # a hair from the rim's 0.00
	var result := _show(patch)
	assert_true(String(result[1]).contains("pulse together"), "bunched phases are refused: %s" % result[1])


func test_the_validator_refuses_a_period_outside_the_ten_to_twentyfive_second_band() -> void:
	var patch := _breathing_patch()
	patch["channels"]["rim"]["period"] = 1.5
	assert_true(String(_show(patch)[1]).contains("alarm-blinking"), "a 1.5 s patch period is refused")
	patch["channels"]["rim"]["period"] = 90.0
	assert_true(String(_show(patch)[1]).contains("static"), "a 90 s patch period is refused")


func test_the_validator_refuses_a_core_fixture_that_would_go_fully_dark() -> void:
	var patch := _breathing_patch()
	patch["channels"]["rim"]["floor"] = 0.0
	var result := _show(patch)
	assert_true(String(result[1]).contains("reads as broken"), "a rim that goes dark is refused: %s" % result[1])
	# But the blocks' edge emission, which does not exist today, is allowed to start at zero.
	var edges := _breathing_patch()
	edges["channels"]["edges"]["floor"] = 0.0
	assert_eq(_show(edges)[1], "", "an additive edge emission may have a floor of zero")


func test_the_validator_refuses_two_writers_to_one_uniform() -> void:
	var patch := _breathing_patch()
	patch["patch"].append({"fixture": "rim", "parameter": "level", "channel": "edges"})
	assert_true(String(_show(patch)[1]).contains("patched twice"), "two channels on one uniform are refused")


func test_the_validator_names_the_arena_the_key_and_what_it_expected() -> void:
	var unknown := _breathing_patch()
	unknown["patch"][0]["channel"] = "nope"
	var message := String(_show(unknown, "terminus")[1])
	assert_true(message.contains("terminus"), "the arena is named: %s" % message)
	assert_true(message.contains("nope"), "the bad value is quoted: %s" % message)
	assert_true(message.contains("rim") and message.contains("edges"), "and the valid choices are listed: %s" % message)
	var bad_parameter := _breathing_patch()
	bad_parameter["patch"][0]["parameter"] = "brightness"
	assert_true(String(_show(bad_parameter)[1]).contains("brightness"), "an unknown parameter is named")
	assert_true(String(_show({"channels": []}, "yard")[1]).contains("channels"), "a channels list instead of an object is refused")


func test_a_fixture_nothing_registers_costs_nothing_and_is_not_an_error() -> void:
	var result := _show(_breathing_patch())
	var show: Show = result[0]
	assert_eq(show.apply(1.0), 0, "a patch whose fixtures are not in this arena writes nothing")
	assert_eq(show.report()["bound_patch_entries"], 3, "the patch is still reported, so a typo is visible")


# --- the show is visual only, and this test is what keeps it that way -----------------------------------------

func test_nothing_in_the_show_reaches_the_simulation() -> void:
	# S6: the show reads the match only through MatchMood and K5 events, runs on frame time, and never on the tick.
	# Pre-registered with the sim baseline: this is the code-level half of that claim.
	var forbidden := ["_physics_process", "Time.get_ticks", "game_match", "Tank", "TankBrain", "Elements",
			"OrderController", "get_tree().physics_frame", "randf", "randi"]
	var dir := DirAccess.open(SHOW_DIR)
	assert_true(dir != null, "game/theme/show/ exists")
	var checked := 0
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		checked += 1
		var source := FileAccess.get_file_as_string(SHOW_DIR.path_join(file))
		# Comments are prose, and this guard is about code: the first version of this test failed on show.gd's own
		# line saying "never Time.get_ticks_*", which is the documentation of the rule it was checking.
		var masked := _code_only(source).replace("MatchMood", "~mood~")
		for needle in forbidden:
			assert_true(not masked.contains(needle),
					"%s must not mention '%s': the show is visual only (S6)" % [file, needle])
		assert_true(not masked.contains("Match."), "%s must not read Match state (S6)" % file)
	assert_true(checked >= 3, "the guard actually read the show's files (%d)" % checked)


## `source` with every comment and string literal removed, so a rule can be documented in the file it governs.
func _code_only(source: String) -> String:
	var out := PackedStringArray()
	for line in source.split("\n"):
		var text: String = line
		var hash_at := text.find("#")
		if hash_at >= 0:
			text = text.substr(0, hash_at)
		while true:
			var open_quote := text.find("\"")
			if open_quote < 0:
				break
			var close_quote := text.find("\"", open_quote + 1)
			if close_quote < 0:
				text = text.substr(0, open_quote)
				break
			text = text.substr(0, open_quote) + text.substr(close_quote + 1)
		out.append(text)
	return "\n".join(out)
