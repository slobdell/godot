extends TestCase
## Engine sounds (art stretch; audio's since round 5): the vehicles nearest the camera get the pooled engine voices, a
## voice stays with its vehicle, revs follow how fast the visual moves, load follows how hard it accelerates, and the
## running gear clanks with speed. Visual/audio only.


func _vehicle(position: Vector3) -> Node3D:
	var node := Node3D.new()
	add_to_tree(node)
	node.global_position = position
	return node


func test_the_nearest_vehicles_get_the_engine_voices() -> void:
	var engines := EngineSystem.new()
	add_to_tree(engines)
	engines.use_streams({"engine_diesel": load("res://assets/audio/engine_diesel.wav"), "engine_v8": load("res://assets/audio/engine_v8.wav")})
	var near: Array[Node3D] = []
	for i in EngineSystem.VOICES:
		near.append(_vehicle(Vector3(i * 3.0, 0, 10)))
		engines.add(near[-1], "engine_diesel")
	var far := _vehicle(Vector3(0, 0, 60))
	engines.add(far, "engine_v8")
	var out_of_earshot := _vehicle(Vector3(0, 0, 500))
	engines.add(out_of_earshot, "engine_v8")
	engines.update(Vector3.ZERO, 0.016)
	assert_eq(engines.active_count(), EngineSystem.VOICES, "every voice is in use")
	assert_true(not engines._owner_of.has(far) and not engines._owner_of.has(out_of_earshot), "the farther vehicles wait")
	var voice_of_first: int = engines._owner_of.find(near[0])
	near[3].global_position = Vector3(0, 0, 400)  # one drives away
	engines.update(Vector3.ZERO, 0.016)
	assert_true(engines._owner_of.has(far), "the next nearest takes the freed voice")
	assert_eq(engines._owner_of.find(near[0]), voice_of_first, "a vehicle that stays near keeps its voice (no restart)")


func test_revs_follow_the_vehicle_speed() -> void:
	var engines := EngineSystem.new()
	add_to_tree(engines)
	engines.use_streams({"engine_diesel": load("res://assets/audio/engine_diesel.wav")})
	var tank := _vehicle(Vector3(0, 0, 10))
	engines.add(tank, "engine_diesel")
	engines.update(Vector3.ZERO, 0.1)
	var idle_pitch := engines._voices[engines._owner_of.find(tank)].pitch_scale
	for i in 30:
		tank.global_position += Vector3(1.2, 0, 0)  # 12 m/s
		engines.update(Vector3.ZERO, 0.1)
	var voice := engines._voices[engines._owner_of.find(tank)]
	assert_true(voice.pitch_scale > idle_pitch + 0.4, "driving fast revs the engine (%.2f → %.2f)" % [idle_pitch, voice.pitch_scale])
	engines.remove(tank)
	assert_eq(engines.active_count(), 0, "a removed vehicle falls silent")


func _streams() -> Dictionary:
	var names := ["engine_diesel", "engine_v8", "tread_loop", "tire_loop"]
	var streams := {}
	for sound in names:
		streams[sound] = load("res://assets/audio/%s.wav" % sound)
	return streams


func test_pulling_away_works_the_engine_harder_than_cruising() -> void:
	var engines := EngineSystem.new()
	add_to_tree(engines)
	engines.use_streams(_streams())
	var tank := _vehicle(Vector3(0, 0, 10))
	engines.add(tank, "engine_diesel")
	var speed := 0.0
	for i in 20:  # flooring it from a standstill
		speed += 0.5
		tank.global_position += Vector3(speed * 0.1, 0, 0)
		engines.update(Vector3.ZERO, 0.1)
	var pulling := engines.load_of(tank)
	var pulling_db := engines._voices[engines._owner_of.find(tank)].volume_db
	for i in 60:  # the same speed, held
		tank.global_position += Vector3(speed * 0.1, 0, 0)
		engines.update(Vector3.ZERO, 0.1)
	var cruising := engines.load_of(tank)
	assert_true(pulling > 0.3, "accelerating hard loads the engine (%.2f)" % pulling)
	assert_true(cruising < pulling * 0.3, "holding a speed doesn't (%.2f)" % cruising)
	assert_true(engines._voices[engines._owner_of.find(tank)].volume_db < pulling_db,
			"so it is quieter cruising than pulling away at a lower speed")


func test_tracks_clank_with_speed_and_fall_silent_at_rest() -> void:
	var engines := EngineSystem.new()
	add_to_tree(engines)
	engines.use_streams(_streams())
	var tank := _vehicle(Vector3(0, 0, 10))
	var buggy := _vehicle(Vector3(5, 0, 10))
	engines.add(tank, "engine_diesel")
	engines.add(buggy, "engine_v8")
	engines.update(Vector3.ZERO, 0.1)
	var tank_gear := engines._gear[engines._owner_of.find(tank)]
	var buggy_gear := engines._gear[engines._owner_of.find(buggy)]
	assert_eq(tank_gear.stream.resource_path, "", "the gear loop is a looping copy")
	assert_true((tank_gear.stream as AudioStreamWAV).data == (load("res://assets/audio/tread_loop.wav") as AudioStreamWAV).data,
			"a tank runs on tracks")
	assert_true((buggy_gear.stream as AudioStreamWAV).data == (load("res://assets/audio/tire_loop.wav") as AudioStreamWAV).data,
			"a V8 buggy on tyres")
	assert_true(tank_gear.volume_db <= EngineSystem.SILENT_DB + 0.1, "parked, the tracks are silent")
	for i in 30:
		tank.global_position += Vector3(1.2, 0, 0)
		engines.update(Vector3.ZERO, 0.1)
	assert_true(tank_gear.volume_db > EngineSystem.GEAR_DB.x, "moving, they clank (%.1f dB)" % tank_gear.volume_db)
	assert_true(tank_gear.pitch_scale > 1.0, "and faster the faster it goes (%.2f)" % tank_gear.pitch_scale)
	engines.remove(tank)
	assert_true(not tank_gear.playing, "a removed vehicle's tracks stop with its engine")


func test_sixty_vehicles_still_only_use_the_pooled_voices() -> void:
	var engines := EngineSystem.new()
	add_to_tree(engines)
	engines.use_streams(_streams())
	for i in 60:
		engines.add(_vehicle(Vector3(i % 10 * 6.0, 0, i / 10 * 6.0)), "engine_diesel")
	engines.update(Vector3.ZERO, 0.016)
	assert_eq(engines.active_count(), EngineSystem.VOICES, "four engines at once, however many vehicles")
	var nearest := 0
	for i in EngineSystem.VOICES:
		var owner: Node3D = engines._owner_of[i]
		nearest = maxi(nearest, int(owner.global_position.length()))
	assert_true(nearest <= 10, "and they are the nearest ones (farthest voiced %d m)" % nearest)
