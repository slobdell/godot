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
