extends TestCase
## control's animated button help reads ElementPlan.preview: the planner's own answer for a task, on a synthetic element.


func test_the_preview_is_the_planners_posture() -> void:
	var from := Vector3(0, 0, 60)
	var point := Vector3(0, 0, -20)
	var sbf := ElementPlan.preview("support_by_fire", 4, point, from)
	assert_eq((sbf["slots"] as Array).size(), 4, "a place for each vehicle")
	var band := TankBrain.fire_band(Weapons.profile(String(Units.stat("tank", "weapon"))))
	for spot: Vector3 in sbf["slots"]:
		assert_true(spot.distance_to(point) <= band + ElementPlan.FACE_LEAD, "a firing position in reach (%.0f m)" % spot.distance_to(point))
		assert_true(spot.distance_to(point) >= band * ElementPlan.SBF_STANDOFF - ElementPlan.FACE_LEAD - 1.0, "at the standoff")
	for f: Vector3 in sbf["facing"]:
		assert_true(f.dot(Vector3.FORWARD) > 0.8, "facing the point")
	assert_eq(sbf["fires"], "always", "a base of fire fires")
	assert_true(not bool(sbf["advances"]), "and holds")
	var ambush := ElementPlan.preview("ambush", 4, point, from)
	assert_true(not bool(ambush["advances"]), "an ambush holds")
	for spot: Vector3 in ambush["slots"]:
		assert_true(spot.distance_to(point) < (sbf["slots"][0] as Vector3).distance_to(point), "closer in than a base of fire")
	var screen := ElementPlan.preview("screen", 4, point, from)
	var xs: Array = (screen["slots"] as Array).map(func(p: Vector3) -> float: return p.x)
	assert_true(xs.max() - xs.min() > 30.0, "a screen is a wide line across the point")
	assert_true(bool(ElementPlan.preview("attack_move", 4, point, from)["advances"]), "attack-move advances")
