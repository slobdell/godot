extends TestCase
## C34.4 (2) (brains B2; the seam agreed with manoeuvre): TankBrain._act's arrived branch asks
## Manoeuvre.leg_holds_arrival (manoeuvre's, with its `arriveleg` switch) before it turns a move into its arrival face.
## The flicker it fixes (planner's s69 trace): a crew reversing on a k-turn leg crossed inside its goal's arrival radius,
## the move became a face mid-leg, the k-turn was dropped, and the held-post rule refused the next move_tos for 36 ticks.
## Held, a crew mid-leg inside its radius keeps its move_to and is never refused (manoeuvre's side landed in round 34).


func _held_ticks_mid_leg(on: bool) -> Dictionary:
	var was_off := Movement._off
	var s := AiScenario.create(self, 4)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, "gang_tank")
	var brain := s.brain_of(me)
	await s.start()
	var default_on := bool((Manoeuvre as GDScript).get_script_constant_map().get("ARRIVE_LEG_DEFAULT", false))
	Movement._off = PackedStringArray(["arriveleg"]) if on != default_on else PackedStringArray([])
	Movement._off_parsed = true
	var situation := brain.build_situation()
	situation["order"] = {"verb": "move", "goal": Vector3(0, 0, -2.0), "speed": 1.0}
	brain.choice = {"option": "MOVE", "target": ""}
	brain.move_order = {"type": "move_to", "x": 0.0, "z": -2.0}
	brain.movement._kturn_left_m = 6.0  # a reverse leg still driving, the crew already inside the goal's radius
	var refused0 := brain.held_moves_refused
	brain._act(situation)
	var out := {"type": String(brain.move_order.get("type", "")), "refused": brain.held_moves_refused - refused0}
	brain.movement._kturn_left_m = 0.0
	s.dispose()
	Movement._off = was_off
	Movement._off_parsed = true
	return out


func test_a_crew_mid_leg_inside_its_radius_keeps_its_move_and_is_never_refused() -> void:
	# Manoeuvre's side is on main (round 34): the adapter must find it; a rename would otherwise read as today's arrival.
	var known := false
	for m: Dictionary in (Manoeuvre as GDScript).get_script_method_list():
		known = known or String(m["name"]) == "leg_holds_arrival"
	assert_true(known, "Manoeuvre.leg_holds_arrival is on the tree")
	var off: Dictionary = await _held_ticks_mid_leg(false)
	assert_true(off["type"] != "move_to", "switch off: today's arrival turns the move into its face/stop (%s)" % off["type"])
	var on: Dictionary = await _held_ticks_mid_leg(true)
	assert_eq(on["type"], "move_to", "switch on, mid-leg: the move stands until the leg ends")
	assert_eq(on["refused"], 0, "and the held-post rule refuses nothing")
