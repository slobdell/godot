extends TestCase
## Round 38 (settle, R38.37: S1 v5): A LANE HERRINGBONE IS NOT TURNED ACROSS ITS STREET (ElementPlan.DEPLOY_FIT_STREET).
## S1 v4 failed its never-in guard on terminus 5 route s4410 (builder2 fdeb18ce6, traced builder0 light): the fit turned
## Delta's herringbone 72 degrees, from main's heading along the east-west street to across it, and Echo never got
## through the lane mouth its seats stood in. Of the fit's 71 turns, 64 were herringbones, median 71 degrees. Here a
## herringbone's turn must land within DEPLOY_FIT_STREET_DEG of the street's axis (ElementSituation.street_axis: the
## heading of the longest clear run, or null on ground with no clear street); coils turn freely.
## 1. The street: terminus at (23.5, 85.65) runs east-west.
## 2. s4410's Delta: the fit turns it (the counter); with the street cap it stays on main's heading.
## 3. The R37.37 across-the-street squad (the same street, ordered across it) still turns, along it, and keeps its deal.

const MAP := "terminus"
const STREET_AT := Vector3(23.5, 0, 85.65)

var _fit := ElementPlan.DEPLOY_FIT
var _street := ElementPlan.DEPLOY_FIT_STREET


func teardown() -> void:
	ElementPlan.DEPLOY_FIT = _fit
	ElementPlan.DEPLOY_FIT_STREET = _street
	super.teardown()


static func _members(at: Dictionary) -> Array:
	var out: Array = []
	for n: String in at:
		out.append({"name": n, "unit": "tank", "role": "tank", "position": Vector3(float(at[n][0]), 0, float(at[n][1]))})
	return out


## {"deploy"} after the fit, with the street cap on or off.
func _fit_of(street: bool, at: Dictionary, ordered: Vector3, anchor: Vector3) -> Dictionary:
	ElementPlan.DEPLOY_FIT = true
	ElementPlan.DEPLOY_FIT_STREET = street
	var members := _members(at)
	var deploy := {"heading": ordered, "anchor": anchor}
	ElementPlan._deploy_fit(deploy, {"members": members, "center": anchor, "tick": 300}, anchor, "herringbone", 10.0)
	return deploy


func test_the_street_runs_east_west() -> void:
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var axis: Variant = ElementSituation.street_axis(STREET_AT)
	lab.dispose()
	print("MEASURE street axis at %s: %s" % [STREET_AT, axis])
	assert_true(axis is Vector3, "a street")
	assert_true(absf((axis as Vector3).dot(Vector3.RIGHT)) >= cos(deg_to_rad(15.0)), "along x (%s)" % [axis])


func test_s4410s_delta_stays_along_its_street() -> void:
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var at := {"Green_Delta_1": [-0.53, 60.52], "Green_Delta_2": [9.29, 85.79], "Green_Delta_3": [24.32, 88.59],
			"Green_Delta_4": [24.97, 95.9], "Green_Delta_5": [15.15, 105.71]}
	var ordered := Vector3(0.9813, 0, -0.1922)
	var free := _fit_of(false, at, ordered, STREET_AT)
	var capped := _fit_of(true, at, ordered, STREET_AT)
	lab.dispose()
	print("MEASURE s4410 Delta: fit %s %s | street cap %s %s" % [free["fit"], free["heading"], capped["fit"], capped["heading"]])
	assert_true(bool(free["fit"]["turned"]), "counter: the fit turns it")
	assert_true(not bool(capped["fit"]["turned"]), "the street cap keeps it")
	assert_eq(capped["heading"], ordered, "on main's heading")
	assert_true(bool(capped["fit"].get("street_refused", false)), "refused by the street")


func test_the_across_the_street_squad_still_turns_along_it() -> void:
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var at := {"Green_Delta_1": [7.07, 81.91], "Green_Delta_2": [44.23, 88.33], "Green_Delta_3": [27.42, 87.28],
			"Green_Delta_4": [19.77, 103.07], "Green_Delta_5": [17.54, 91.25]}
	var ordered := Vector3(0.0516, 0, -0.9987)
	var capped := _fit_of(true, at, ordered, Vector3(22.22, 0, 84.5))
	lab.dispose()
	print("MEASURE across the street: %s %s" % [capped["fit"], capped["heading"]])
	assert_true(bool(capped["fit"]["turned"]), "turns")
	assert_eq((capped.get("keep", {}) as Dictionary).size(), 5, "and keeps its deal")
	assert_true(absf((capped["heading"] as Vector3).dot(Vector3.RIGHT)) >= cos(deg_to_rad(30.0)), "along the street")


func test_open_ground_has_no_street() -> void:
	var was: Dictionary = Arena.active
	Arena.active = {"name": "settle_open_lab", "obstacles": []}
	ElementSituation.forget_terrain()
	var axis: Variant = ElementSituation.street_axis(Vector3.ZERO)
	Arena.active = was
	ElementSituation.forget_terrain()
	assert_eq(axis, null, "no obstacles: no street")
