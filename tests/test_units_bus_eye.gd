extends TestCase
## Contract R6 (round 10, feel): THE BUS IS HIS EYE. The lead, on the Terminus at main `de31eeea`:
## *"I can see that the condemned bus is too small still. It should be longer than the garbage truck and heightened
## proportionally."*
##
## The garbage truck is the Condemned `ifv` (the armored-garbage-truck art, 7.54 m); the bus is `tank`, which has no
## mesh of its own and wears the shared dozer stretched to its box, so S1's `box_at_length` cannot derive it and the
## lead's ruling is the source. These assert his two sentences as RATIOS against the ifv's live box, so they keep
## meaning the same thing if the garbage truck is ever resized: a bus that stops being longer than the truck, or grows
## longer without growing taller in proportion, goes red here.
##
## The before, on `2ee65f94`'s numbers (lesson 147: the treatment must be distinguishable): the bus was 8.62 / 7.54 =
## 1.14x the truck's length (under the 1.25 floor) and 2.40 / 3.70 = 0.65x its height (under the 1.14 its length
## ratio asked for). Both assertions failed on it.

## "Longer than the garbage truck", as a floor that reads at his telephoto pose. 1.25 is the brief's starting point
## (R6): at 49 m and FOV 35 a 10% difference in length between two boxes parked apart does not read, a quarter does.
const LONGER_BY := 1.25
## Rounding slack on a ratio of two catalog numbers typed to the centimetre.
const RATIO_SLACK := 0.01


func _box(unit_id: String) -> Vector3:
	var size: Array = Units.PROFILES[unit_id]["hull_size"]
	return Vector3(float(size[0]), float(size[1]), float(size[2]))


func test_the_bus_is_longer_than_the_garbage_truck() -> void:
	var bus := _box("tank")
	var truck := _box("ifv")
	assert_true(bus.z / truck.z >= LONGER_BY - RATIO_SLACK,
			"the bus (%.2f m) is at least %.2fx the garbage truck's length (%.2f m): it is %.2fx"
			% [bus.z, LONGER_BY, truck.z, bus.z / truck.z])


func test_the_bus_is_heightened_in_proportion() -> void:
	var bus := _box("tank")
	var truck := _box("ifv")
	var length_ratio := bus.z / truck.z
	assert_true(bus.y / truck.y >= length_ratio - RATIO_SLACK,
			"the bus is %.2fx the truck's length, so it is at least %.2fx its height (%.2f m): it is %.2f m, %.2fx"
			% [length_ratio, length_ratio, truck.y, bus.y, bus.y / truck.y])


## The number came from his eye, but the reference it lands on is still written down beside the box (R6: "record the
## reference you settle on"), and it is one S1's rule accepts: the length is that vehicle's times SCALE_K, so the
## roster-wide `test_every_hull_is_its_reference_length_times_k` keeps holding for the bus too.
func test_the_bus_records_the_reference_it_settled_on() -> void:
	var reference: Dictionary = Units.PROFILES["tank"]["scale_reference"]
	assert_true(reference.has("ruled"), "the bus's reference says it was ruled by the lead's eye, and on what")
	assert_near(_box("tank").z, Units.target_length_m("tank"), 0.011,
			"the bus's length is its recorded reference times K")


## The second half of "too small", found by R5's turret probe (2026-09-22): the bus was not even DRAWN at its box.
## `Tank.shared_hull_size()` measured the shared dozer by instantiating its scene out of the tree, where the
## `dozer_part` wrapper has not built its model yet (it does that in `_ready`), found no meshes and fell back to
## (2.4, 1.6, 3.6) without a word -- so the stretch was computed against the wrong size and the 2.40 x 2.40 x 8.62
## bus drew 1.60 wide and 7.36 long. Asserted on what is DRAWN, in the tank's frame, for both units that wear it.
func test_the_units_wearing_the_shared_dozer_are_drawn_at_their_box() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for unit_id: String in ["tank", "burner"]:
		var tank: Tank = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
		tank.set("unit_id", unit_id)
		tank.set("simulate", false)
		add_to_tree(tank)
		await wait_physics_frames(1)
		var drawn := _drawn_size(tank, tank.get_node("HullVisual"))
		var box := _box(unit_id)
		for axis in 3:
			assert_near(drawn[axis] / box[axis], 1.0, 0.05,
					"%s axis %d: drawn %.2f m against its box's %.2f m" % [unit_id, axis, drawn[axis], box[axis]])
	GameTheme.use(previous)


func _drawn_size(tank: Node3D, node: Node) -> Vector3:
	var to_tank := tank.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		# The shield bubble is a mesh too, sized to the hull plus a margin and hidden until hit: not the hull.
		if mesh.mesh == null or mesh is ShieldEffect:
			continue
		var box := (to_tank * mesh.global_transform) * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result.size
