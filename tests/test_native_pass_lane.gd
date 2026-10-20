extends TestCase
## Round 35 (native, R35.8's follow-up; T7 shipped at R35.44): `Movement._pass_lane` natively (drive_native.cpp's pass_lane,
## pass_wheels_ok, pass_clear and pass_swept over NavNative::outline_ok) is the live GDScript's, asked both ways from one
## pose. A refuser stands on yard_open (open ground: lanes found) and in the Sumps beside the pit (walls: the sweep refuses
## some); a passer of each hull kind comes at it from 3 distances x 12 bearings, nose on and turned away (a wheeled passer's
## turning circles), and every third pose a third hull stands 7 m off the refuser's side (_pass_clear). The side answered
## must be equal, and both answers (a lane, none) must be reached.

const MATCH := preload("res://game/match/match.tscn")
const PASSERS: Array[String] = ["tank", "ifv", "gang_tank", "scout"]


func test_the_pass_lane_is_the_gdscripts_on_open_ground() -> void:
	await _sweep("yard_open", Vector3(0.0, 0.0, 15.0))


func test_the_pass_lane_is_the_gdscripts_beside_walls() -> void:
	await _sweep("sumps", Vector3(-40.0, 0.0, 40.0))


func _sweep(arena: String, centre: Vector3) -> void:
	if NativeExpect.absent(self):
		print("native: absent, the pass lane is not exercised in this run")
		return
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var refuser := game_match.spawn_tank("LaneRefuser", 0, Match.Team.GREEN, "tank")
	var blocker := game_match.spawn_tank("LaneBlocker", 0, Match.Team.GREEN, "tank")
	var passers: Array[Tank] = []
	for unit in PASSERS:
		passers.append(game_match.spawn_tank("LanePasser_%s" % unit, 0, Match.Team.GREEN, unit))
	var controllers: Array[OrderController] = []
	for tank: Tank in [refuser, blocker] + passers:
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	refuser.place(centre, 0.0)
	await wait_physics_frames(2)
	for orders in controllers:
		orders.set_physics_process(false)
	var mover := Movement.of(refuser)
	var asked := 0
	var lanes := 0
	var none := 0
	var mismatches := 0
	var first := ""
	var parked := centre + Vector3(0.0, 0.0, 300.0)  # off the stage
	for p in passers.size():
		var passer := passers[p]
		for distance: float in [8.0, 12.0, 16.0]:
			for bearing in 12:
				for turned in 2:
					var angle := bearing * TAU / 12.0
					var at := centre + Vector3(sin(angle), 0.0, cos(angle)) * distance
					var toward := Vector2(centre.x - at.x, centre.z - at.z).normalized()
					var yaw := atan2(-toward.x, -toward.y) + (PI * 0.75 if turned == 1 else 0.0)
					for other in passers:
						other.place(parked + Vector3(float(passers.find(other)) * 12.0, 0.0, 0.0), 0.0)
					passer.place(at, yaw)
					var with_blocker := (bearing + p) % 3 == 0
					var across := Vector3(-toward.y, 0.0, toward.x)
					blocker.place(centre + across * 7.0 if with_blocker else parked + Vector3(-12.0, 0.0, 0.0), 0.0)
					refuser.place(centre, angle)
					await wait_physics_frames(1)
					var live := mover._pass_lane(String(passer.name), passer.global_position, toward)
					var native := NativeDrive.pass_lane(mover, String(passer.name), passer.global_position, toward)
					asked += 1
					if live != native:
						mismatches += 1
						if first == "":
							first = "%s %s at %s yaw %.2f blocker %s: live %s native %s" % [arena, passer.unit_id, at, yaw,
									with_blocker, live, native]
					elif live != 0.0:
						lanes += 1
					else:
						none += 1
	print("native pass lane %s: %d poses asked, %d lanes, %d none, %d mismatches" % [arena, asked, lanes, none, mismatches])
	assert_eq(mismatches, 0, "the native pass lane is the live GDScript's: %s" % first)
	assert_true(lanes >= 10, "%s: a lane found (%d)" % [arena, lanes])
	assert_true(none >= 10, "%s: no lane (%d)" % [arena, none])
