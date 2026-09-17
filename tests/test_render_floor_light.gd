extends TestCase
## Render (round 5): the floor's painted light is baked in color, and a layout's own floodlight towers light it.

const DRESSING := preload("res://game/theme/cyberpunk/arena_dressing.gd")


func test_a_warm_lamp_bakes_warm_light_and_nothing_far_away() -> void:
	var map := DRESSING.flood_map([[Vector4(0, 0, 40, 1.0), Color(1.0, 0.7, 0.4)]])
	var image := map.get_image()
	var center := image.get_pixel(DRESSING.FLOOD_MAP_SIZE / 2, DRESSING.FLOOD_MAP_SIZE / 2)
	assert_true(center.r > 0.2 and center.r > center.b * 1.5, "warm at the lamp (%s)" % center)
	assert_eq(image.get_pixel(0, 0).r, 0.0, "dark far from it")


func test_plain_lamps_still_bake_white() -> void:
	var image := DRESSING.flood_map([Vector4(0, 0, 40, 1.0)]).get_image()
	var center := image.get_pixel(DRESSING.FLOOD_MAP_SIZE / 2, DRESSING.FLOOD_MAP_SIZE / 2)
	assert_true(center.r > 0.2 and absf(center.r - center.b) < 0.02, "white (%s)" % center)


func test_a_layouts_floodlight_towers_throw_pools_ahead_of_them() -> void:
	var layout := {"props": [{"type": "floodlight", "position": [40.0, 82.0], "rotation_deg": 0.0},
			{"type": "container_20", "position": [0.0, 0.0]}]}
	var lamps := DRESSING.layout_lamps(layout)
	assert_eq(lamps.size(), 1, "one pool per floodlight tower, none for containers")
	var pool: Vector4 = lamps[0][0]
	assert_true(pool.y < 82.0, "thrown toward -Z, the way the tower's lamps face (%s)" % pool)
	assert_true((lamps[0][1] as Color).r > (lamps[0][1] as Color).b, "sodium warm")
