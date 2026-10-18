extends TestCase
## Round 24 (brains R2, C24.5): squads ordered together keep with the army unless a split really pays. His recording
## (the Locks, 26.8 s): three squads moved west together, the Sirens took the middle way alone toward the canal.
## tests/tactics/body_stage.gd stands them where his census put them. Before (Element.BODY_ENABLED off, builder0, seeds
## 1-3, both sides): 50-84 squad-seconds alone; on: 11-18, the Sirens with the army, arriving no later.

const SECONDS := 60.0


func teardown() -> void:
	Element.BODY_ENABLED = true
	super.teardown()


## Round 33 (R33.14): each arm runs in a FRESH process (tests/tactics/body_probe.gd), so no test before it in the shard
## can reach it. In one process the stage read differently by what ran first, after R32.6's spawn fix, on traffic's ghost-ON
## pair (bbb4d2db, laptop): alone 37.0 v 16.0, with test_rts_camera first 28.5 v 15.5 (builder0: 38.0 v 18.5), the halving
## line failed. Not the start: with the navmesh awaited before the spawn every match began on the same frames (1, then
## tick 2) and still read 29.5 first in the process v 38.5 after the camera test, seed 2's on arm 22.0 v 15.0 as the 4th
## match of each. What a match leaves behind (the physics server's bodies, statics a new match does not clear) moved one
## crew's yield at tick ~56 by 0.1 m and the run branched (Sirens_1 stood ~35 ticks in one order, drove on in the other).
const CHILD_TIMEOUT_S := "300"


func _arm(body: String) -> Dictionary:
	var out: Array = []
	var code := OS.execute("timeout", [CHILD_TIMEOUT_S, OS.get_executable_path(), "--headless", "--fixed-fps",
			str(SimClock.TICK_RATE), "--path", ProjectSettings.globalize_path("res://"), "--script",
			"res://tests/tactics/body_probe.gd", "--", "--seed=1", "--body=%s" % body, "--seconds=%d" % int(SECONDS)], out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code == 0, "the body=%s child finished inside %ss (exit %d)" % [body, CHILD_TIMEOUT_S, code])
	for line in text.split("\n"):
		if line.begins_with("BODY_PROBE "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("BODY_PROBE "))
			if parsed is Dictionary:
				return parsed
	assert_true(false, "the body=%s child printed its line: %s" % [body, text.substr(0, 400)])
	return {"alone_s": INF, "arrived_s": -1.0, "Sirens": {"choice": {}}}


func test_his_three_squads_keep_together() -> void:
	var off := _arm("off")
	var on := _arm("on")
	print("MEASURE body locks seed 1: off %s | on %s" % [off, on])
	assert_eq(String((on["Sirens"]["choice"] as Dictionary).get("chosen", "")), "body", "the Sirens take the army's route")
	assert_true(float(on["alone_s"]) < float(off["alone_s"]) * 0.5,
			"squad-seconds alone at least halved: off %s, on %s" % [off["alone_s"], on["alone_s"]])
	assert_true(float(on["arrived_s"]) > 0.0 and float(on["arrived_s"]) <= float(off["arrived_s"]) + 5.0,
			"and the army is not much later for it: off %s s, on %s s" % [off["arrived_s"], on["arrived_s"]])


## Round 32 (R32.6): the stage's hulls never spawn overlapping. They did (Sirens 2 and 3, 3.8 m apart, seed 1), and the
## physics separated them on the first frame of the FIRST match in a process only, so the test above read alone_s 12.0 run
## first and 24.5 run after any other match (builder0): it passed or failed by the order of its shard.
func test_the_stage_spawns_no_two_hulls_overlapping() -> void:
	for seed_value: int in [1, 2, 3]:
		for specs: Array in [BodyStage.SQUADS, BodyStage.SPLIT]:
			var points: Array = BodyStage.spawns(seed_value, specs)
			for i in points.size():
				for j in range(i + 1, points.size()):
					var a: Array = points[i]
					var b: Array = points[j]
					var gap := Vector2((a[0] as Vector3).x - (b[0] as Vector3).x, (a[0] as Vector3).z - (b[0] as Vector3).z).length()
					assert_true(gap >= float(a[1]) + float(b[1]) - 0.01,
							"seed %d: spawns %d and %d are %.1f m apart, envelopes %.1f + %.1f" % [seed_value, i, j, gap, a[1], b[1]])


func test_a_split_that_saves_real_driving_still_happens() -> void:
	var report: Dictionary = await BodyStage.run(self, 1, SECONDS, false, false, BodyStage.SPLIT)
	print("MEASURE body split seed 1: %s" % report)
	for squad: String in ["West", "East"]:
		var choice: Dictionary = report[squad]["choice"]
		assert_eq(String(choice.get("chosen", "")), "own", "%s keeps its own bridge: %s" % [squad, choice])
		assert_true(float(report[squad]["arrived_s"]) > 0.0, "%s arrived" % squad)


func test_a_route_inside_the_corridor_is_not_alone_and_one_outside_is() -> void:
	var body: Array = [Vector3(0, 0, 0), Vector3(-100, 0, 0)]
	assert_near(Element._detached_m([Vector3(0, 0, 10), Vector3(-100, 0, 10)], body), 0.0, 0.01, "10 m off: with the army")
	assert_near(Element._detached_m([Vector3(0, 0, 40), Vector3(-100, 0, 40)], body), 100.0, 0.5, "40 m off: 100 m alone")
	var at := Element._closest_along(body, Vector3(-30, 0, 20))
	assert_near(float(at["s"]), 30.0, 0.01, "joins the body 30 m along")
	var slice := Element._slice(body, 10.0, 60.0)
	assert_near((slice[0] as Vector3).x, -10.0, 0.01, "the slice starts 10 m along")
	assert_near((slice[slice.size() - 1] as Vector3).x, -60.0, 0.01, "and ends 60 m along")
