extends TestCase
## Engine sounds (art stretch): the vehicles nearest the camera get the pooled engine voices, a voice stays with its
## vehicle, and revs follow how fast the visual moves. Visual/audio only.


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
