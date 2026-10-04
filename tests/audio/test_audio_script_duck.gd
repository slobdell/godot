extends TestCase
## Round 17 (guns; built on the orchestrator's decision): in the browser (Sample playback) bus effects do not run, so
## the booth's sidechain does not exist there and the caller would sit ~12.7 dB lower against the battle than natively.
## The SCRIPT duck reproduces it: while a booth line plays, SfxSystem lowers the World bus's VOLUME by the depth the
## chosen booth duck has natively (measured on his match: launch 18.2, mid 12.7, light 6.8 dB), ~50 ms down, ~300 ms
## up. Only where bus effects do not run; never natively, where it would be a second duck on top of the sidechain.


func _sfx() -> SfxSystem:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	return sfx


func _world_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SfxSystem.WORLD_BUS))


func test_it_is_off_natively() -> void:
	assert_true(not SfxSystem.script_duck_wanted(), "a native build never script-ducks: the sidechain does it there")


func test_the_depth_follows_the_chosen_booth_duck() -> void:
	assert_near(SfxSystem.script_duck_depth_db(SfxSystem.BOOTH_DUCKS["mid"]), 12.7, 0.01, "MID: 12.7 dB, measured")
	assert_near(SfxSystem.script_duck_depth_db(SfxSystem.BOOTH_DUCKS["launch"]), 18.2, 0.01, "launch: 18.2 dB")
	assert_near(SfxSystem.script_duck_depth_db(SfxSystem.BOOTH_DUCKS["new"]), 6.8, 0.01, "light: 6.8 dB")


func test_world_dips_while_the_caller_speaks_and_comes_back() -> void:
	var sfx := _sfx()
	var speaking := [false]
	sfx.script_duck_on = true
	sfx.booth_speaking = func() -> bool: return speaking[0]
	var rest := _world_db()
	speaking[0] = true
	for i in 30:  # 0.5 s at 60 fps
		sfx.step_script_duck(1.0 / 60.0)
	var depth := SfxSystem.script_duck_depth_db(SfxSystem.booth_duck())
	assert_near(_world_db(), rest - depth, 0.5, "half a second into a line the battle is down by the duck's depth")
	speaking[0] = false
	for i in 120:  # 2 s
		sfx.step_script_duck(1.0 / 60.0)
	assert_near(_world_db(), rest, 0.1, "and back up after it")
	sfx.script_duck_on = false


func test_the_attack_is_fast_and_the_release_slow() -> void:
	var sfx := _sfx()
	var speaking := [true]
	sfx.script_duck_on = true
	sfx.booth_speaking = func() -> bool: return speaking[0]
	var rest := _world_db()
	var depth := SfxSystem.script_duck_depth_db(SfxSystem.booth_duck())
	for i in 6:  # 100 ms
		sfx.step_script_duck(1.0 / 60.0)
	assert_true(rest - _world_db() > depth * 0.8, "most of the dip within 100 ms (%.1f of %.1f dB)" % [rest - _world_db(), depth])
	for i in 60:
		sfx.step_script_duck(1.0 / 60.0)
	speaking[0] = false
	for i in 6:
		sfx.step_script_duck(1.0 / 60.0)
	assert_true(rest - _world_db() > depth * 0.5, "100 ms after the line the battle is still mostly down: no pumping")
	for i in 180:
		sfx.step_script_duck(1.0 / 60.0)
	sfx.script_duck_on = false


func test_back_to_back_lines_never_stack() -> void:
	# The duck chases ONE target (rest - depth), it never subtracts from where it is: a second line starting in the
	# release of the first lowers World back to the same floor, not a second depth below it (orchestrator, 17:5x).
	var sfx := _sfx()
	var speaking := [false]
	sfx.script_duck_on = true
	sfx.booth_speaking = func() -> bool: return speaking[0]
	var rest := _world_db()
	var depth := SfxSystem.script_duck_depth_db(SfxSystem.booth_duck())
	var lowest := rest
	for line in 4:
		speaking[0] = true
		for i in 60:  # a 1 s line
			sfx.step_script_duck(1.0 / 60.0)
			lowest = minf(lowest, _world_db())
		speaking[0] = false
		for i in 30:  # 0.5 s gap: the next line starts mid-release
			sfx.step_script_duck(1.0 / 60.0)
			lowest = minf(lowest, _world_db())
	assert_true(rest - lowest <= depth + 0.05, "four lines 1.5 s apart dip %.1f dB at most (depth %.1f)" % [rest - lowest, depth])
	for i in 180:
		sfx.step_script_duck(1.0 / 60.0)
	assert_near(_world_db(), rest, 0.1, "and the battle comes back")
	sfx.script_duck_on = false


func test_a_real_booth_line_is_seen() -> void:
	var sfx := _sfx()
	var voice := AnnouncerVoice.new()
	add_to_tree(voice)
	sfx._booth_scan_s = 0.0
	assert_true(not sfx._booth_speaking(), "a booth that is not speaking")
	var line := AudioStreamPlayer.new()
	var tone := AudioStreamWAV.new()
	tone.data = PackedByteArray()
	tone.data.resize(44100 * 2)
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_end = 44100
	line.stream = tone
	voice.add_child(line)
	line.play()
	sfx._booth_scan_s = 0.0
	assert_true(sfx._booth_speaking(), "a line playing under an AnnouncerVoice is the booth speaking")
	line.stop()


func test_the_web_master_trim_never_touches_native() -> void:
	SfxSystem.ensure_master_limiter()
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), 0.0, 0.001,
			"natively Master stays at 0 dB under its limiter (the web's %.0f dB trim is Sample-mode only)" % SfxSystem.WEB_MASTER_TRIM_DB)
	assert_true(not SfxSystem.web_sample_mix(), "this native run is not the web's Sample mix")
