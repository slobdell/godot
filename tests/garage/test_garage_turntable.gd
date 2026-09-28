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
		var camera := turntable.find_children("*", "Camera3D", true, false)[0] as Camera3D
		var view := Rect2(Vector2.ZERO, Vector2(camera.get_viewport().size))
		var box: Array = Units.stat(unit_id, "hull_size")
		var aabb := AABB(Vector3(-float(box[0]) / 2.0, 0.0, -float(box[2]) / 2.0), Vector3(box[0], box[1], box[2]))
		var widest := 0.0
		for spin in [0.0, 90.0, 45.0]:
			var outside := turntable.corners_outside_view(deg_to_rad(spin))
			assert_eq(outside, 0, "%s at %d deg: %d of the hull box's 8 corners are off the turntable's view" % [unit_id, spin, outside])
			# The same, by the real camera's own projection into its viewport (independent of the turntable's maths).
			var left := INF
			var right := -INF
			for i in 8:
				var corner := Basis(Vector3.UP, deg_to_rad(spin)) * aabb.get_endpoint(i)
				var at := camera.unproject_position(corner)
				assert_true(not camera.is_position_behind(corner) and view.grow(1.0).has_point(at),
						"%s at %d deg: corner %d at %s is inside the %s view" % [unit_id, spin, i, at, view.size])
				left = minf(left, at.x)
				right = maxf(right, at.x)
			widest = maxf(widest, right - left)
		# 0.35: a 480 x 220 panel is 2.2:1, so the box's height under the camera's 23-degree look-down binds first (~40 %).
		assert_true(widest > view.size.x * 0.35, "%s is framed, not lost in the panel: %d of %d px wide at its widest"
				% [unit_id, widest, view.size.x])
