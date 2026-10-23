extends TestCase
## Round 38 (settle S1): THE DEPLOY DEAL. A squad that has stopped is not sent across itself to its halt. The lab is the
## traced case (R37.37; terminus 5-squad click, squad 4 Delta, laptop GDScript e5c436f46 `--deploy-trace`): five crews
## strung ~37 m along an east-west street, the halt (a 5-crew herringbone at spacing 10) laid on the click's heading
## (0.05, -1.0), i.e. ACROSS the street. Pure: ElementPlan._deploy_fit / crew_axis / _fit_deal on the nominal seats (the
## real case also grounds the end seats out of the blocks, 25 m into the next street; the probe reads that, not this lab).
## A toy street (`_street`) checks only that the deal pays the GROUNDED drive.

const ANCHOR := Vector3(22.22, 0, 84.5)
const ORDERED := Vector3(0.0516, 0, -0.9987)
const SPACING := 10.0
## The street the squad stands in (z between these), as the trace's crews and grounded goals show it.
const STREET_Z := [78.0, 106.0]

var _was := ElementPlan.DEPLOY_FIT


func teardown() -> void:
	ElementPlan.DEPLOY_FIT = _was
	super.teardown()


func _members() -> Array:
	var at := {"Green_Delta_1": [7.07, 81.91, "tank"], "Green_Delta_2": [44.23, 88.33, "tank"],
			"Green_Delta_3": [27.42, 87.28, "tank"], "Green_Delta_4": [19.77, 103.07, "ifv"],
			"Green_Delta_5": [17.54, 91.25, "ifv"]}
	var out: Array = []
	for n: String in at:
		out.append({"name": n, "unit": String(at[n][2]), "role": String(at[n][2]), "position": Vector3(float(at[n][0]), 0, float(at[n][1]))})
	return out


static func _street(point: Vector3, _unit: String, _anchor: Variant) -> Vector3:
	return Vector3(point.x, 0.0, clampf(point.z, float(STREET_Z[0]), float(STREET_Z[1])))


func _situation(grounded: bool) -> Dictionary:
	var situation := {"members": _members(), "center": ANCHOR, "tick": 300}
	if grounded:
		situation["ground_seat"] = _street
	return situation


func test_the_crews_stand_strung_along_the_street() -> void:
	var axis: Variant = ElementPlan.crew_axis(_members())
	assert_true(axis is Vector3, "five crews strung along a street have an axis")
	assert_true(absf((axis as Vector3).x) > 0.9, "the axis runs east-west, along the street: %s" % [axis])
	var round_squad: Array = []
	for i in 4:
		round_squad.append({"name": "S_%d" % i, "position": Vector3(cos(i * PI / 2.0) * 10.0, 0, sin(i * PI / 2.0) * 10.0)})
	assert_true(ElementPlan.crew_axis(round_squad) == null, "a squad standing round its middle has no axis")


func test_across_the_street_a_stopped_crew_drives_past_its_squad() -> void:
	# The control: today's lay (the ordered heading) dealt by the grounded drives still sends one crew a long way.
	var across := ElementPlan._fit_deal(_members(), "herringbone", ANCHOR, ORDERED, SPACING, _situation(false))
	print("MEASURE across the street: worst %.1f m, total %.1f m" % [across["worst"], across["total"]])
	assert_true(float(across["worst"]) > 20.0, "laid across the street, some crew drives %.1f m" % across["worst"])


func test_the_deploy_lays_along_the_street_and_nobody_drives_far() -> void:
	ElementPlan.DEPLOY_FIT = true
	var deploy := {"heading": ORDERED, "anchor": ANCHOR, "deployed": true, "tick": 300}
	ElementPlan._deploy_fit(deploy, _situation(false), ANCHOR, "herringbone", SPACING)
	var fit: Dictionary = deploy["fit"]
	print("MEASURE deploy fit %s heading %s" % [fit, deploy["heading"]])
	assert_true(bool(fit["turned"]), "the halt is turned onto the squad's own axis")
	assert_true(absf((deploy["heading"] as Vector3).x) > 0.9, "laid along the street")
	assert_true((deploy["heading"] as Vector3).dot(ORDERED) >= 0.0, "facing the ordered side of the axis")
	assert_true(float(fit["worst_m"]) <= 15.0, "the longest drive to a seat %.1f m (ordered lay %.1f m)" % [fit["worst_m"], fit["ordered_worst_m"]])
	var used: Array = (deploy["keep"] as Dictionary).values()
	used.sort()
	assert_eq(used, [0, 1, 2, 3, 4], "a seat each")


func test_a_squad_that_fits_the_ordered_lay_keeps_it() -> void:
	ElementPlan.DEPLOY_FIT = true
	# The same crews in open ground (no grounding) on a heading along their own line: nothing to gain, nothing turns.
	var deploy := {"heading": Vector3(1, 0, 0), "anchor": ANCHOR, "deployed": true, "tick": 300}
	ElementPlan._deploy_fit(deploy, _situation(false), ANCHOR, "herringbone", SPACING)
	assert_true(not bool(deploy["fit"]["turned"]), "kept the ordered heading")
	assert_eq(deploy["heading"], Vector3(1, 0, 0), "unchanged")


func test_the_deal_is_by_the_grounded_drive() -> void:
	# One seat far out of the street: grounded, it lands on the street edge; the deal pays the crew's drive to THAT point.
	var members: Array = [{"name": "A", "unit": "tank", "position": Vector3(0, 0, 88)},
			{"name": "B", "unit": "tank", "position": Vector3(10, 0, 88)}]
	var dealt := ElementPlan._fit_deal(members, "line", Vector3(5, 0, 88), Vector3(0, 0, -1), SPACING, {"ground_seat": _street})
	assert_true(float(dealt["worst"]) < 12.0, "two crews side by side deal to the seats beside them (worst %.1f m)" % dealt["worst"])
