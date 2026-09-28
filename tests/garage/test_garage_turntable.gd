extends TestCase
## Round 14 (G2, the lead's son: "the tank in the garage isn't the tank I fought with"): the turntable draws every unit
## at the size the match draws it -- the catalogue's hull_size -- and frames it whole, from a bus to a scout.


func _turntable() -> GarageTurntable:
	var holder := Control.new()
	holder.size = Vector2(480, 220)
	add_to_tree(holder)
	var turntable := GarageTurntable.new()
	turntable.size = Vector2(480, 220)
	holder.add_child(turntable)
	return turntable


func test_every_garage_unit_is_drawn_at_its_hull_size() -> void:
	var turntable := _turntable()
	var catalog := ArmyCatalog.from_game()
	for unit_id in catalog.unit_ids():
		turntable.show_unit({"unit": unit_id}, Color.CYAN, catalog.weapon_id(unit_id))
		await wait_physics_frames(2)  # the art's fit is deferred (DozerPart._fit_to_hull)
		var box: Array = Units.stat(unit_id, "hull_size")
		var drawn := turntable.drawn_hull_size()
		assert_true(absf(drawn.z - float(box[2])) <= 0.05 * float(box[2]),
				"%s: drawn %.2f m long, hull_size says %.2f m" % [unit_id, drawn.z, float(box[2])])


func test_the_longest_and_the_shortest_unit_are_framed_whole() -> void:
	var turntable := _turntable()
	var catalog := ArmyCatalog.from_game()
	var by_length := catalog.unit_ids()
	by_length.sort_custom(func(a: String, b: String) -> bool:
		return float(Units.stat(a, "hull_size")[2]) < float(Units.stat(b, "hull_size")[2]))
	for unit_id: String in [by_length[0], by_length[-1]]:
		turntable.show_unit({"unit": unit_id}, Color.CYAN, catalog.weapon_id(unit_id))
		await wait_physics_frames(2)
		for spin in [0.0, 90.0, 45.0]:
			var outside := turntable.corners_outside_view(deg_to_rad(spin))
			assert_eq(outside, 0, "%s at %d deg: %d of the hull box's 8 corners are off the turntable's view" % [unit_id, spin, outside])
