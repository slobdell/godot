extends TestCase
## Fleet round 15, F2 (garage's tour: *"My tanks and IFVs look the same in the fight."*). `make class-look` measured the
## two pairs that do: the Condemned bus and garbage truck (silhouette IoU 0.89 from behind, how he follows his squad)
## and Law's Assault Gun and Retired APC (0.87, and the same dark blue: mean colours 6.9 apart). The free fix is a
## CLASS LAMP: amber beacons on those IFVs' roofs (ClassMark), the tanks unmarked. These hold it: the marked units carry
## lamps and the tanks do not, the lamps stand ON the drawn roof (not floating, not buried), and it is art only -- the
## collider is the catalog's box, untouched.

const SEAT_SLACK_M := 0.12


func _spawn(unit_id: String) -> Node3D:
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	add_to_tree(tank)
	return tank


func _beacons(tank: Node3D) -> Array:
	return tank.find_children("ClassBeacon*", "Node3D", true, false)


func test_the_confused_ifvs_carry_beacons_and_their_tanks_do_not() -> void:
	GameTheme.use("cyberpunk")
	for unit_id: String in ["ifv", "law_ifv"]:
		var tank := _spawn(unit_id)
		await wait_physics_frames(2)
		assert_true(_beacons(tank).size() >= 1, "%s carries its class lamp" % unit_id)
	for unit_id: String in ["tank", "law_tank", "gang_ifv", "syn_ifv"]:
		var tank := _spawn(unit_id)
		await wait_physics_frames(2)
		assert_eq(_beacons(tank).size(), 0, "%s is unmarked (only the pairs class-look found alike are)" % unit_id)


func test_every_beacon_stands_on_the_drawn_roof() -> void:
	GameTheme.use("cyberpunk")
	for unit_id: String in ClassMark.MARKS.keys():
		var tank := _spawn(unit_id)
		await wait_physics_frames(2)
		var to_tank := tank.global_transform.affine_inverse()
		for beacon: Node3D in _beacons(tank):
			var base := to_tank * beacon.global_position
			var roof: float = ClassMark.roof_height(tank.get_node("HullVisual"), Vector2(base.x, base.z))
			assert_true(is_finite(roof), "%s %s has roof under it" % [unit_id, beacon.name])
			assert_near(base.y, roof, SEAT_SLACK_M, "%s %s seated on the roof (base %.2f, roof %.2f)" % [unit_id,
					beacon.name, base.y, roof])


func test_the_lamp_is_art_only() -> void:
	GameTheme.use("cyberpunk")
	for unit_id: String in ClassMark.MARKS.keys():
		var tank := _spawn(unit_id)
		await wait_physics_frames(2)
		var shape := (tank.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
		var box: Array = Units.stat(unit_id, "hull_size")
		assert_near(shape.size.x, float(box[0]), 0.001, "%s collider width is the catalog's" % unit_id)
		assert_near(shape.size.z, float(box[2]), 0.001, "%s collider length is the catalog's" % unit_id)
		for beacon: Node3D in _beacons(tank):
			assert_eq(beacon.find_children("*", "CollisionObject3D", true, false).size(), 0, "no physics in a lamp")
