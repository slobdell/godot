extends TestCase
## Round 34 (C34.4 (2), the seam agreed with brains): an arrival is not declared while a planned leg is still driving.
## `TankBrain._act`'s arrived branch asks `Manoeuvre.leg_holds_arrival` (through brains' adapter): true under the
## `arriveleg` switch for a `move_to` whose k-turn leg (or planner-held plan) is being driven, for at most
## ARRIVE_LEG_HOLD_S of leg time on one order; once the leg ends (or the bound runs out) the crew arrives as before.
## Counters: arrivals_held once per order, arrivals_held_ticks per held think.


func _switch(on: bool) -> void:
	Movement._off = PackedStringArray(["arriveleg"]) if on != Manoeuvre.ARRIVE_LEG_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true


func test_a_move_mid_leg_is_not_arrived_until_the_leg_ends_or_the_bound() -> void:
	var was_off := Movement._off
	var s := AiScenario.create(self, 4)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, "gang_tank")
	var brain := s.brain_of(me)
	await s.start()
	var held0 := Manoeuvre.arrivals_held
	var ticks0 := Manoeuvre.arrivals_held_ticks
	brain.move_order = {"type": "move_to", "x": 0.0, "z": -3.0}
	brain.movement.new_order()
	brain.movement._kturn_left_m = 6.0  # a reverse leg still driving
	_switch(true)
	assert_true(Manoeuvre.leg_holds_arrival(brain), "switch on, mid-leg: the arrival is held")
	assert_true(Manoeuvre.leg_holds_arrival(brain), "...and on the next think")
	assert_eq(Manoeuvre.arrivals_held - held0, 1, "arrivals_held counts the ORDER once")
	assert_eq(Manoeuvre.arrivals_held_ticks - ticks0, 2, "arrivals_held_ticks counts each held think")
	brain.movement._kturn_left_m = 0.0
	assert_true(not Manoeuvre.leg_holds_arrival(brain), "switch on, the leg ended: arrives as before")
	brain.movement._kturn_left_m = 6.0
	brain.move_order = {"type": "face", "x": 0.0, "z": -20.0}
	assert_true(not Manoeuvre.leg_holds_arrival(brain), "only a move_to is held")
	brain.move_order = {"type": "move_to", "x": 0.0, "z": -3.0}
	# The bound: a leg that never ends cannot deny the arrival past ARRIVE_LEG_HOLD_S of this order.
	brain.movement.arrive_hold_until = Engine.get_physics_frames() - 1
	assert_true(not Manoeuvre.leg_holds_arrival(brain), "past the bound the arrival goes through")
	brain.movement.new_order()
	assert_true(Manoeuvre.leg_holds_arrival(brain), "a new order starts a new hold")
	_switch(false)
	assert_true(not Manoeuvre.leg_holds_arrival(brain), "switch off: today's arrival")
	brain.movement._kturn_left_m = 0.0
	s.dispose()
	Movement._off = was_off
	Movement._off_parsed = true


## The whole seam, end to end (the orchestrator's condition on brains' adapter, lesson 181): with the switch ON a brain
## mid-leg inside its goal's radius keeps its move_to through `_act`, the held-post rule refuses nothing, and the hold
## is COUNTED (so a renamed function could not ship inert with this green); OFF, today's arrival turns it into its face.
func test_the_brains_adapter_really_calls_the_hold() -> void:
	var adapter := false
	for m: Dictionary in (TankBrain as GDScript).get_script_method_list():
		adapter = adapter or String(m["name"]) == "_leg_holds_arrival"
	assert_true(adapter, "brains' _leg_holds_arrival adapter is on this tree (main 9c0f4dfce)")
	var was_off := Movement._off
	for on: bool in [false, true]:
		var s := AiScenario.create(self, 4)
		var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, "gang_tank")
		var brain := s.brain_of(me)
		await s.start()
		_switch(on)
		var situation := brain.build_situation()
		situation["order"] = {"verb": "move", "goal": Vector3(0, 0, -2.0), "speed": 1.0}
		brain.choice = {"option": "MOVE", "target": ""}
		brain.move_order = {"type": "move_to", "x": 0.0, "z": -2.0}
		brain.movement.new_order()
		brain.movement._kturn_left_m = 6.0
		var held0 := Manoeuvre.arrivals_held
		var refused0 := brain.held_moves_refused
		brain._act(situation)
		if on:
			assert_eq(String(brain.move_order.get("type", "")), "move_to", "ON, mid-leg: the move stands")
			assert_eq(Manoeuvre.arrivals_held - held0, 1, "ON: the hold was counted, so the adapter called it")
			assert_eq(brain.held_moves_refused - refused0, 0, "ON: the held-post rule refused nothing")
		else:
			assert_true(String(brain.move_order.get("type", "")) != "move_to", "OFF: today's arrival (%s)" % brain.move_order.get("type", ""))
		brain.movement._kturn_left_m = 0.0
		s.dispose()
	Movement._off = was_off
	Movement._off_parsed = true
