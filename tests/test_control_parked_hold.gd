extends TestCase
## Round 37 (orders O2, R37.9; his answer: "Stay put and shoot"). Under TankBrain.PARKED_HOLD a crew of his at its post
## (the spot his order left it on) refuses a move of its own option that ends more than PARKED_HOLD_M from the post (it
## holds and shoots instead), keeps RETREAT, and drives back onto the post when it is off it with nothing else to do.
## The seam (TankBrain._parked_move) on a real brain tank in a lab; the post and the option are set by hand.

var _lab: TacticsLab
var _brain: TankBrain


func _setup() -> void:
	TankBrain.PARKED_HOLD = true
	_lab = TacticsLab.create(self, 7)
	var tank := _lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(0, 0, 0), 0.0)
	await _lab.start()
	_brain = _lab.game_match.brains.get_node("Brain_Green_P_1") as TankBrain
	_brain._player_post = Vector3(0, 0, 0)
	_brain._held_face = {"type": "face", "x": 0.0, "z": -20.0}
	assert_true(tank != null and _brain != null, "setup: a brain tank")


func _teardown() -> void:
	TankBrain.PARKED_HOLD = TankBrain._parked_flag()
	_lab.dispose()


func test_a_move_of_its_own_beyond_the_post_is_refused_and_it_holds() -> void:
	await _setup()
	_brain.choice = {"option": "SPOT", "target": ""}
	var out := _brain._parked_move(TankBrain._move_to(Vector3(0, 0, 25)))
	assert_eq(String(out["type"]), "face", "the scout's stand-off move is refused: it holds and faces the threat")
	var near := _brain._parked_move(TankBrain._move_to(Vector3(2, 0, 2)))
	assert_eq(String(near["type"]), "move_to", "a shuffle inside PARKED_HOLD_M stands")


func test_retreat_is_kept() -> void:
	await _setup()
	_brain.choice = {"option": "RETREAT", "target": ""}
	var out := _brain._parked_move(TankBrain._move_to(Vector3(0, 0, 40), false, 1.0, 3.0, false, true))
	assert_eq(String(out["type"]), "move_to", "a crew about to be destroyed may still pull back")


func test_off_its_post_with_nothing_to_do_it_drives_all_the_way_back() -> void:
	await _setup()
	_brain.choice = {"option": "HOLD", "target": ""}
	_lab.tank_of("Green_P_1").place(Vector3(8, 0, 0), 0.0)
	var out := _brain._parked_move({"type": "face", "x": 0.0, "z": -20.0})
	assert_eq(String(out["type"]), "move_to", "8 m off its spot: back onto it")
	assert_true(Vector2(float(out["x"]), float(out["z"])).length() < 0.01, "to the post itself")
	assert_eq(float(out["arrive"]), TankBrain.PARKED_ARRIVE_M, "all the way (not within 5 m)")
	_lab.tank_of("Green_P_1").place(Vector3(2, 0, 0), 0.0)
	var on := _brain._parked_move({"type": "face", "x": 0.0, "z": -20.0})
	assert_eq(String(on["type"]), "face", "on its spot it just faces")
