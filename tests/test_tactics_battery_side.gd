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
	ElementPlan.APPROACH_BATTERY = true
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
	assert_true(ElementPlan.carries(_situation(_round(90.0))), "a battery carries its approach (B2)")
	assert_true(ElementPlan.carries(_situation(_round(90.0), true)), "a mixed element carries it too (round 29's B2: on)")
	ElementPlan.APPROACH_CARRY = false
	assert_true(ElementPlan.carries(_situation(_round(90.0))), "--approach-carry=off: a battery still carries it")
	assert_true(not ElementPlan.carries(_situation(_round(90.0), true)), "...a mixed element does not (B0's rule)")


func test_its_standoff_is_safe_and_inside_its_band() -> void:
	var standoff := ElementPlan.battery_standoff(_situation(_round(90.0)), "Rust_1", TARGET)
	assert_near(standoff, TankBrain.ARTILLERY_SAFE_DISTANCE + ElementPlan.APPROACH_STANDOFF_MARGIN_M, 0.5,
			"the safe distance and a margin (a truck stopping short of exactly 80 m backed off and packed up): %.1f" % standoff)
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
	assert_eq(String(plan["formation"]), "line", "abreast (filing into a column cost ~9 s)")
	for unit_name: String in plan["orders"]:
		assert_eq(String(plan["orders"][unit_name]["verb"]), "move", "%s drives there" % unit_name)
		assert_eq(String(plan["orders"][unit_name]["target"]), "", "%s drives with its gun quiet (firing deploys it)" % unit_name)


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
	ElementPlan.APPROACH_BATTERY = false
	var b0 := ElementPlan.build(_situation(_round(170.0)), _state(_attack()), table)
	assert_near((b0["anchor"] as Vector3).distance_to(TARGET), 160.0, 25.0, "control (B0): round at its 160 m range")


## Round 29 (B1, his call: artillery fires only when set up, so it shells only from his side): once round, a battery crew
## inside the side cone shells (attack: it sets up where it stands); one outside it (a wing truck at 37 deg on seed 4) drives
## on to its place, guns quiet.
func test_once_round_only_a_crew_inside_the_side_cone_shells() -> void:
	var table := _table()
	var standoff := ElementPlan.battery_standoff(_situation(_round(0.0, 90.0)), "Rust_1", TARGET)
	var situation := _situation(_round(15.0, standoff))
	var bearings := [10.0, 25.0, 37.0]
	for i in 3:
		(situation["members"][i] as Dictionary)["position"] = _round(bearings[i], standoff)
	var plan := ElementPlan.build(situation, _state(_attack(), {"approach_round": {"in": true, "side": 1}}), table)
	assert_true(bool(plan.get("relocating", false)), "crews still driving to their places hold their fire")
	assert_eq(String(plan["orders"]["Green_1"]["verb"]), "attack", "10 deg off the side: it sets up and shells")
	assert_eq(String(plan["orders"]["Green_2"]["verb"]), "attack", "25 deg: inside the cone, it shells")
	assert_eq(String(plan["orders"]["Green_3"]["verb"]), "move", "37 deg: off the side, it drives on to its place")
	assert_eq(String(plan["orders"]["Green_3"]["target"]), "", "...with its gun quiet (firing deploys it)")
	var post_off := ElementPlan.approach_off_deg(plan["anchor"], TARGET, Vector3(-1.0, 0.0, 0.0))
	assert_near(post_off, ElementPlan.APPROACH_ARTILLERY_EDGE_DEG, 0.5,
			"its line once round is the post it drove to, not the side's centre line (a set-up truck packed up): %.1f deg"
			% post_off)


## Round 29 (B1): going round, the battery is relocating (TankBrain holds a deploying gun's fire on a MOVE).
func test_going_round_it_is_relocating() -> void:
	var plan := ElementPlan.build(_situation(_round(90.0)), _state(_attack()), _table())
	assert_true(bool(plan.get("relocating", false)), "guns quiet all the way round")
	ElementPlan.APPROACH_BATTERY = false
	var b0 := ElementPlan.build(_situation(_round(90.0)), _state(_attack()), _table())
	assert_true(not bool(b0.get("relocating", false)), "control (B0): no relocation flag")
