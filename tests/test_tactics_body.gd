extends TestCase
## Round 24 (brains R2, C24.5): squads ordered together keep with the army unless a split really pays. His recording
## (the Locks, 26.8 s): three squads moved west together, the Sirens took the middle way alone toward the canal.
## tests/tactics/body_stage.gd stands them where his census put them. Before (Element.BODY_ENABLED off, builder0, seeds
## 1-3, both sides): 50-84 squad-seconds alone; on: 11-18, the Sirens with the army, arriving no later.

const SECONDS := 60.0


func teardown() -> void:
	Element.BODY_ENABLED = true
	super.teardown()


func test_his_three_squads_keep_together() -> void:
	Element.BODY_ENABLED = false
	var off: Dictionary = await BodyStage.run(self, 1, SECONDS)
	Element.BODY_ENABLED = true
	var on: Dictionary = await BodyStage.run(self, 1, SECONDS)
	print("MEASURE body locks seed 1: off %s | on %s" % [off, on])
	assert_eq(String((on["Sirens"]["choice"] as Dictionary).get("chosen", "")), "body", "the Sirens take the army's route")
	assert_true(float(on["alone_s"]) < float(off["alone_s"]) * 0.5,
			"squad-seconds alone at least halved: off %s, on %s" % [off["alone_s"], on["alone_s"]])
	assert_true(float(on["arrived_s"]) > 0.0 and float(on["arrived_s"]) <= float(off["arrived_s"]) + 5.0,
			"and the army is not much later for it: off %s s, on %s s" % [off["arrived_s"], on["arrived_s"]])


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
