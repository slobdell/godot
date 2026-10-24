extends TestCase
## Round 39 (feedback F2/F3, his "the top of the screen ... corresponds to units in the distance"): his pick, the phone
## map's "dock" layout, keeps the chips, orders and camera buttons out of the top third, on screen, off each other and
## off the HUD's score bug and radar. It is what a run gets; round 2's "top" stays behind --touch-layout=top.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SCREENS := {"phone 20:9": Vector2(2400, 1080), "small phone": Vector2(1800, 810), "portrait phone": Vector2(810, 1800)}


func teardown() -> void:
	CyberStyle.set_touch_boost(-1.0)
	super()


## TacticalMap's sizes for `squads` chips at button height `h` (CHIP_*, DRILL_*; six order buttons, three camera ones).
func _place(layout: String, screen: Vector2, squads: int) -> Dictionary:
	var h := clampf(screen.y * TacticalMap.BUTTON_HEIGHT_FRACTION * CyberStyle.touch_boost(),
			TacticalMap.BUTTON_MIN_PX * CyberStyle.touch_boost(), TacticalMap.BUTTON_MAX_PX * CyberStyle.touch_boost())
	var chip := Vector2(h * TacticalMap.CHIP_WIDTH, h * TacticalMap.CHIP_HEIGHT)
	var tool := Vector2(h * 2.4, h)
	var drill := Vector2(h * TacticalMap.DRILL_WIDTH, h * TacticalMap.DRILL_HEIGHT)
	return TouchLayout.place(layout, screen, [Vector2(drill.x * 6 + 20.0, drill.y), Vector2(drill.x, drill.y * 6 + 20.0)],
			[Vector2(chip.x * squads + 4.0 * (squads - 1), chip.y), Vector2(chip.x, chip.y * squads + 4.0 * (squads - 1))],
			[Vector2(tool.x * 3 + 8.0, tool.y), Vector2(tool.x, tool.y * 3 + 8.0)], HudLayout.bug_rect(screen), HudLayout.radar_rect(screen))


func test_dock_leaves_the_top_third_free_and_overlaps_nothing() -> void:
	for boost in [1.0, 1.5]:
		CyberStyle.set_touch_boost(boost)
		for layout in ["dock"]:
			for name: String in SCREENS:
				var screen: Vector2 = SCREENS[name]
				for squads in [2, 5]:
					var rects := _place(layout, screen, squads)
					var where := "%s %s x%.1f, %d squads" % [layout, name, boost, squads]
					var bug := HudLayout.bug_rect(screen)
					var hud := {"bug": Rect2(bug.position, Vector2(bug.size.x, screen.y - bug.position.y)),
							"radar": HudLayout.radar_rect(screen)}
					var keys := ["orders", "squads", "tools"]
					for key: String in keys:
						var r: Rect2 = rects[key]
						assert_true(r.position.y >= screen.y / 3.0, "%s: the %s are below the top third (%s)" % [where, key, r])
						assert_true(Rect2(Vector2.ZERO, screen).encloses(r), "%s: the %s are on screen (%s)" % [where, key, r])
						for part: String in hud:
							assert_true(not r.grow(-1.0).intersects(hud[part]), "%s: the %s clear the %s (%s v %s)" % [where, key, part, r, hud[part]])
					for i in keys.size():
						for j in range(i + 1, keys.size()):
							assert_true(not (rects[keys[i]] as Rect2).intersects(rects[keys[j]]),
									"%s: the %s and the %s apart" % [where, keys[i], keys[j]])
					assert_true(float(rects["text_floor"]) >= screen.y / 3.0, "%s: toasts sit below the top third" % where)


func test_dock_is_the_default_and_top_is_round_twos_layout() -> void:
	assert_true(TouchLayout.place("top", SCREENS["phone 20:9"], [Vector2(400, 80), Vector2(80, 400)], [Vector2(400, 80),
			Vector2(200, 400)], [Vector2(300, 60), Vector2(100, 200)], Rect2(), Rect2()).is_empty(), "top: TacticalMap keeps its own layout")
	assert_eq(TouchLayout.from_flags(), "dock", "his pick is what a run without --touch-layout gets")


## His default path: the phone map opens on the overview, which draws his own end of the arena at the bottom of the screen,
## where dock sits (test_tactical_map's input test found his crews under dock's chips at 1280x720). The overview fits the
## whole arena above the bars instead (TacticalMap.overview_fit), and a followed crew is framed in the clear.
func test_dock_keeps_his_crews_clear_of_the_bars() -> void:
	var before := tree.root.size
	for screen: Vector2i in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(810, 1800)]:
		tree.root.size = screen
		var arena: Node = add_to_tree(ARENA.instantiate())
		var game_match: Match = MATCH.instantiate()
		add_to_tree(game_match)
		game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"])
		var camera := FollowCamera.new()
		add_to_tree(camera)
		camera.make_current()
		var map := TacticalMap.new()
		map.game_match = game_match
		map.camera = camera
		add_to_tree(map)
		await wait_physics_frames(2)
		assert_eq(map.touch_layout, "dock", "his pick is the layout a run gets")
		assert_true(map.tactical_view, "setup: the map opens on the overview")
		var floor_y := float(map.touch_rects["text_floor"])
		for tank: Tank in game_match.team_tanks(0) + game_match.team_tanks(1):
			var at := camera.unproject_position(tank.global_position)
			assert_true(at.y >= 0.0 and at.y < floor_y, "%s overview: %s at %s is above the bars (y < %.0f)" % [screen, tank.name, at, floor_y])
		for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, 1)]:
			var edge := camera.unproject_position(corner * Match.ARENA_HALF_SIZE)
			assert_true(edge.y >= 0.0 and edge.y <= floor_y, "%s overview: the arena's %s end is on screen above the bars (%s)" %
					[screen, "far" if corner.z < 0.0 else "near", edge])
		map.select_squad("Bravo")
		map.set_tactical_view(false)
		await wait_physics_frames(2)
		var lead := game_match.tanks.get_node(NodePath(game_match.squads["0/Bravo"].commander)) as Tank
		var at := camera.unproject_position(lead.global_position)
		for key: String in ["orders", "squads", "tools"]:
			assert_true(not (map.touch_rects[key] as Rect2).has_point(at), "%s follow: the followed crew at %s is clear of the %s" % [screen, at, key])
		assert_true(at.y < floor_y, "%s follow: and above the bars (%s)" % [screen, at])
		assert_true(absf(camera.v_offset) < 0.001, "%s follow: the follow view is not lifted (%f)" % [screen, camera.v_offset])
		for node: Node in [map, camera, game_match, arena]:
			node.queue_free()
		await tree.process_frame
	tree.root.size = before


## R39.5: the real skirmish's Overview button is the RTS rig's (perspective, 77 degrees). The rig keeps the bars' height
## clear in its overview (overview_inset_px, from TacticalMap): everything the old overview showed on screen now shows above
## dock's bars, the far end included; desktop and round 2's layout get exactly the old pose; the follow view is never inset.
## (The phone map hands the rig no vision region, so its overview centres on the arena: his crews at their start were off
## the bottom of the screen before dock too; that is the old framing, kept.)
func test_the_rigs_overview_shows_above_the_bars_what_it_showed() -> void:
	var before := tree.root.size
	var lens := RtsCamera.fov
	RtsCamera.fov = RtsCamera.FOV_DEG  # his lens
	var h := Match.ARENA_HALF_SIZE
	var marks: Array = []
	for i in range(-6, 7):
		for j in range(-6, 7):
			marks.append(Vector3(i * h / 6.0, 0.0, j * h / 6.0))
	for screen: Vector2i in [Vector2i(2400, 1080), Vector2i(1800, 810), Vector2i(810, 1800)]:
		tree.root.size = screen
		var arena: Node = add_to_tree(ARENA.instantiate())
		var game_match: Match = MATCH.instantiate()
		add_to_tree(game_match)
		game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"])
		var camera := Camera3D.new()
		add_to_tree(camera)
		camera.make_current()
		var rig := RtsCamera.new()
		rig.camera = camera
		rig.edge_pan = false
		add_to_tree(rig)
		var map := TacticalMap.new()
		map.game_match = game_match
		map.camera = camera
		map.rig = rig
		map.touch_layout = "top"  # first the old overview, round 2's layout (what desktop gets too: nothing sets the inset)
		add_to_tree(map)
		await wait_physics_frames(2)
		(map._buttons["overview"] as Button).pressed.emit()
		await wait_physics_frames(3)
		await tree.process_frame
		assert_true(rig.is_overview(), "%s: the Overview button opens the rig's overview" % screen)
		assert_eq(rig.overview_inset_px, 0.0, "%s: round 2's layout hands the rig no inset" % screen)
		assert_true(is_equal_approx(camera.fov, RtsCamera.fov), "%s: and the old lens (%.2f)" % [screen, camera.fov])
		var old_at := marks.map(func(mark: Vector3) -> Vector2: return camera.unproject_position(mark))
		map.touch_layout = "dock"
		map._layout_panels()
		await wait_physics_frames(2)
		await tree.process_frame
		var floor_y := float(map.touch_rects["text_floor"])
		assert_true(rig.overview_inset_px > 0.0, "%s: dock hands the rig its bars' height (%.0f px)" % [screen, rig.overview_inset_px])
		var shown := 0
		for i in marks.size():
			var was: Vector2 = old_at[i]
			if was.y < 0.0 or was.y > screen.y or was.x < 0.0 or was.x > screen.x:
				continue
			shown += 1
			var now := camera.unproject_position(marks[i])
			assert_true(now.y >= -1.0 and now.y < floor_y, "%s: %s shown at %s is now at %s, above the bars (y < %.0f)" %
					[screen, marks[i], was, now, floor_y])
		assert_true(shown >= 10, "%s: setup: the old overview showed a good part of the arena (%d marks)" % [screen, shown])
		print("FEEDBACK_OVERVIEW %s marks shown %d, bars from y %.0f, inset %.0f px, lens %.1f -> %.1f" % [screen, shown, floor_y,
				rig.overview_inset_px, RtsCamera.fov, camera.fov])
		(map._buttons["overview"] as Button).pressed.emit()  # back to the follow view
		await wait_physics_frames(2)
		await tree.process_frame
		assert_true(not rig.is_overview() and is_equal_approx(camera.fov, RtsCamera.fov), "%s: the follow view keeps the rig's own lens" % screen)
		# Desktop and round 2's layout: with no inset, the same state gives exactly the old pose and lens.
		(map._buttons["overview"] as Button).pressed.emit()
		map.set_process(false)
		rig.set_process(false)
		rig.overview_inset_px = 0.0
		rig._apply()
		var plain := [camera.global_transform, camera.fov]
		rig.overview_inset_px = 178.0
		rig._apply()
		assert_true(not camera.global_transform.is_equal_approx(plain[0]), "%s: setup: an inset moves the overview" % screen)
		rig.overview_inset_px = 0.0
		rig._apply()
		assert_true(camera.global_transform == plain[0] and camera.fov == plain[1], "%s: no inset: the old overview exactly" % screen)
		for node: Node in [map, rig, camera, game_match, arena]:
			node.queue_free()
		await tree.process_frame
	RtsCamera.fov = lens
	tree.root.size = before
