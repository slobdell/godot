extends TestCase
## Round 39 (feedback F2/F3, his "the top of the screen ... corresponds to units in the distance"): his pick, the phone
## map's "dock" layout, keeps the chips, orders and camera buttons out of the top third, on screen, off each other and
## off the HUD's score bug and radar. It is what a run gets; round 2's "top" stays behind --touch-layout=top.

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
