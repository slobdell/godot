extends TestCase
## The agent bridge declares where an order can send a unit ON THIS MAP. ARENA_HALF_SIZE is only the largest any layout
## may be; declaring it told an agent it could drive to places Orders then clamped silently (round 7, arena).


func test_the_bridge_declares_the_active_maps_reach_not_the_largest_possible() -> void:
	var saved := Arena.active
	Arena.active = {"half_size": 100.0}
	var bridge := AgentBridge.new()
	var bounds: Dictionary = bridge.describe_map()["bounds"]
	var margin := Match.ARENA_HALF_SIZE - Match.DRIVABLE_LIMIT
	assert_near(float(bounds["x"][1]), 100.0 - margin, 0.01, "a 100 m layout: its own reach, less the wall margin")
	assert_near(float(bounds["z"][0]), -(100.0 - margin), 0.01, "on both axes")
	Arena.active = {}
	bounds = bridge.describe_map()["bounds"]
	assert_true(float(bounds["x"][1]) <= Match.DRIVABLE_LIMIT, "never past where Orders clamps a destination")
	bridge.free()
	Arena.active = saved
