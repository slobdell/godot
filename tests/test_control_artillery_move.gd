extends TestCase
## Round 37 (orders, the lead's playtest 2026-10-21, archipelago s44214): "My last 2 surviving units are artillery
## vehicles. By the end, I was directing them to move to target locations, and they did not move." An element of only
## Gas Rocket Trucks (law_artillery) given a plain move task must drive to it.

var _lab: TacticsLab


func teardown() -> void:
	ElementPlan.BATTERY_SEAT = not OS.get_cmdline_user_args().has("--battery-seat=off")
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _run(names: Array, prior: Variant, seconds: float) -> Dictionary:
	_lab = TacticsLab.create(self, 7)
	var x := 0.0
	for n: String in names:
		_lab.unit(Match.Team.GREEN, n, Vector3(x, 0, 0), 0.0, "law_artillery")
		x += 8.0
	await _lab.start()
	var element := _lab.element(names, "Guns")
	if prior is Dictionary:
		element.assign(prior)
		for i in int(10.0 * SimClock.TICK_RATE):
			await _lab.step()
		for n: String in names:
			assert_true(_lab.tank_of(n).deploy_ratio >= 1.0, "setup: %s parked and set up (%.2f)" % [n, _lab.tank_of(n).deploy_ratio])
	var before := _lab.center_of(names)
	assert_eq(element.assign({"verb": "move", "to": [before.x + 40.0, before.z - 40.0]}), "", "the move is taken")
	for i in int(seconds * SimClock.TICK_RATE):
		await _lab.step()
	var after := _lab.center_of(names)
	var orders := TacticsLab._orders_for(_lab.game_match)
	print("ARTY_MOVE %s prior=%s moved %.1f m, goal %s, why %s" % [names, prior, before.distance_to(after),
			orders.goal_position(String(names[0])), element.why if "why" in element else "-"])
	return {"moved": before.distance_to(after)}


func test_a_lone_rocket_truck_drives_to_its_move() -> void:
	var out := await _run(["Green_Guns_5"], null, 15.0)
	assert_true(float(out["moved"]) > 30.0, "it drove (%.1f m)" % float(out["moved"]))


func test_two_rocket_trucks_drive_to_their_move() -> void:
	var out := await _run(["Green_Eyes_4", "Green_Eyes_5"], null, 15.0)
	assert_true(float(out["moved"]) > 30.0, "they drove (%.1f m)" % float(out["moved"]))


## His case: the trucks were parked (a move done, standing long enough to set up) when he sent them on.
func test_a_parked_set_up_rocket_truck_drives_to_its_next_move() -> void:
	var out := await _run(["Green_Guns_5"], {"verb": "move", "to": [0.0, -10.0], "drills": false}, 15.0)
	assert_true(float(out["moved"]) > 30.0, "it drove (%.1f m)" % float(out["moved"]))


func test_two_parked_set_up_rocket_trucks_drive_to_their_next_move() -> void:
	var out := await _run(["Green_Eyes_4", "Green_Eyes_5"], {"verb": "move", "to": [4.0, -10.0], "drills": false}, 15.0)
	assert_true(float(out["moved"]) > 30.0, "they drove (%.1f m)" % float(out["moved"]))


## The cause (round 33's battery seat, `--battery-seat=off`): with it off the parked truck drives.
func test_with_the_battery_seat_off_the_parked_truck_drives() -> void:
	ElementPlan.BATTERY_SEAT = false
	var out := await _run(["Green_Guns_5"], {"verb": "move", "to": [0.0, -10.0], "drills": false}, 15.0)
	ElementPlan.BATTERY_SEAT = true
	assert_true(float(out["moved"]) > 30.0, "it drove (%.1f m)" % float(out["moved"]))
