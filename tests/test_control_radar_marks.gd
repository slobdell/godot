extends TestCase
## Round 16 (hud H4): the desktop radar draws its blips from one pass over the units and the intel (`Radar._marks`)
## instead of building blips()'s Dictionary per blip and unpacking it. The marks must be exactly the ones the old path
## drew (`_marks_from_blips(blips())`): the same shapes, positions, sizes, colours and order, while a fight moves them.

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_the_one_pass_marks_are_the_blips_marks() -> void:
	var f := Fixture.new(self)
	await f.build_scale(15)
	var radar := Radar.new()
	radar.game_match = f.game_match
	radar.controls = f.controls
	f.controls.add_child(radar)
	await wait_physics_frames(2)
	await f.select(Array(f.controls.groups.members(1)) + Array(f.controls.groups.members(2)))
	assert_eq(f.controls.order_selection("move", {"to": [0.0, -10.0]}), "", "half the force is sent forward")
	var compared := 0
	var contacts := 0
	for flipped in [false, true]:
		var before := Match.swap_bases
		Match.swap_bases = flipped  # the other base: the radar turns 180 degrees
		for step in 12:
			await wait_physics_frames(4)
			var fast := radar._marks()
			var reference := radar._marks_from_blips(radar.blips())
			assert_eq(fast, reference, "flipped=%s step %d" % [flipped, step])
			contacts += (fast["by_shape"]["diamond"] as Array).size() + (fast["by_shape"]["diamond_outline"] as Array).size()
			compared += 1
		Match.swap_bases = before
	assert_true(contacts > 0, "enemies were on the radar while it was compared (%d marks)" % contacts)
	print("MEASURE control_radar_marks compared=%d passes, %d contact marks" % [compared, contacts])
