extends TestCase
## Round 28, brains B2 (his call 3: "a drag means the same thing for every unit"): ARTILLERY SHELLS FROM THE DRAWN SIDE.
## An artillery element (every crew's role "artillery") with a drawn approach takes its firing position on that side:
##   - the nearest point within APPROACH_ARTILLERY_EDGE_DEG of the side, at its standoff (ARTILLERY_SAFE_DISTANCE, or wider
##     of the target squad's guns, inside the weapon's preferred band), straight there when the line clears the target
##     squad's reach, else the next notch round at the standoff;
##   - once round, its places are at that standoff on the side;
##   - a mixed element is not a battery (B1's rule).

const TARGET := Vector3.ZERO


func teardown() -> void:
	ElementPlan.APPROACH_CARRY = true
	DoctrineTable.clear_cache()
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	return DoctrineTable.load_table("standard").get("table")


## Three mortar carriers round `center`; the target a Law IFV (60 m) at TARGET. `mixed` makes the first a tank.
func _situation(center: Vector3, mixed := false) -> Dictionary:
	var members: Array = []
	for i in 3:
		var unit := "tank" if mixed and i == 0 else "artillery"
		var weapon := Weapons.profile(String(Units.stat(unit, "weapon", "")))
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 8.0 - 8.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": Units.role_of(unit), "unit": unit, "speed": 6.5,
				"range": float(weapon["range"]), "effective_range": float(weapon.get("effective_range", weapon["range"])),
				"sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed := [{"name": "Rust_1", "position": TARGET, "role": "ifv", "unit": "law_ifv", "visible": true, "age": 200,
			"distance": TARGET.distance_to(center), "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0}]
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "support", "strength": 600.0,
			"enemy_strength": 200.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


## In from the EAST: approach [-1, 0] (the run in drives west), the side is the target's east.
func _attack() -> Dictionary:
	return {"verb": "attack", "target": "Rust_1", "approach": [-1.0, 0.0]}


## `degrees` round from the east side (positive toward +z), `metres` out.
func _round(degrees: float, metres := 100.0) -> Vector3:
	return Vector3(cos(deg_to_rad(degrees)), 0.0, sin(deg_to_rad(degrees))) * metres


func test_a_battery_is_every_crew_artillery() -> void:
	assert_true(ElementPlan.is_battery(_situation(_round(90.0))), "three mortar carriers are a battery")
	assert_true(not ElementPlan.is_battery(_situation(_round(90.0), true)), "a tank among them: not a battery")


func test_its_standoff_is_safe_and_inside_its_band() -> void:
	var standoff := ElementPlan.battery_standoff(_situation(_round(90.0)), "Rust_1", TARGET)
	assert_near(standoff, maxf(TankBrain.ARTILLERY_SAFE_DISTANCE, 60.0 + ElementPlan.APPROACH_STANDOFF_MARGIN_M), 0.5,
			"the safe distance (or wide of a 60 m IFV): %.1f" % standoff)
	var mortar := Weapons.profile("mortar")
	assert_true(standoff >= float(mortar["min_range"]) and standoff <= float(mortar["preferred_max"]),
			"inside the mortar's band")


func test_from_the_south_it_drives_straight_to_the_near_edge_of_the_side() -> void:
	var table := _table()
	var plan := ElementPlan.build(_situation(_round(90.0)), _state(_attack()), table)
	var anchor: Vector3 = plan["anchor"]
	var standoff := ElementPlan.battery_standoff(_situation(_round(90.0)), "Rust_1", TARGET)
	assert_near(anchor.distance_to(TARGET), standoff, 0.5, "at its standoff (%.1f m)" % anchor.distance_to(TARGET))
	var off := ElementPlan.approach_off_deg(anchor, TARGET, Vector3(-1.0, 0.0, 0.0))
	assert_near(off, ElementPlan.APPROACH_ARTILLERY_EDGE_DEG, 0.5, "the near edge of the side, its own way (%.1f deg)" % off)
	assert_eq(String(plan["formation"]), "column", "in a column")
	for unit_name: String in plan["orders"]:
		assert_eq(String(plan["orders"][unit_name]["verb"]), "move", "%s drives there" % unit_name)
		assert_eq(String(plan["orders"][unit_name]["target"]), "Rust_1", "%s keeps its gun on the target" % unit_name)


func test_from_the_far_side_it_goes_round_at_its_standoff() -> void:
	var table := _table()
	var plan := ElementPlan.build(_situation(_round(170.0)), _state(_attack()), table)
	var anchor: Vector3 = plan["anchor"]
	var standoff := ElementPlan.battery_standoff(_situation(_round(170.0)), "Rust_1", TARGET)
	assert_near(anchor.distance_to(TARGET), standoff, 0.5, "round at its standoff, not 160 m (%.1f m)" % anchor.distance_to(TARGET))
	var off := ElementPlan.approach_off_deg(anchor, TARGET, Vector3(-1.0, 0.0, 0.0))
	assert_near(off, 135.0, 0.5, "the next notch (the straight line would cross the IFV's guns): %.1f deg" % off)


func test_once_round_its_places_are_at_its_standoff() -> void:
	var table := _table()
	var plan := ElementPlan.build(_situation(_round(15.0, 90.0)), _state(_attack(), {"approach_round": {"in": true,
			"side": 1}}), table)
	var standoff := ElementPlan.battery_standoff(_situation(_round(15.0, 90.0)), "Rust_1", TARGET)
	assert_near((plan["anchor"] as Vector3).distance_to(TARGET), standoff, 0.5, "its places at its standoff")
	ElementPlan.APPROACH_CARRY = false
	var b0 := ElementPlan.build(_situation(_round(170.0)), _state(_attack()), table)
	assert_near((b0["anchor"] as Vector3).distance_to(TARGET), 160.0, 25.0, "control (B0): round at its 160 m range")
