extends TestCase
## Round 23 (brains B0/B1): HIS CASE. "When I had tanks in line abreast and had them move somewhere, they never got
## into formation until the very end - because the lead vehicle was already close to the target point at the start, the
## other vehicles never caught up to it until it stopped." Five Law tanks in a line whose own axis points at the click,
## 150 m across the parade ground's open middle (tests/tactics/pace_stage.gd): the line must swing into a line across
## the new heading on the way. B0 measures it (a MEASURE line per arm); B1 asserts the squad is formed within the first
## third of the route with the pace ON and arrives no later than a second after the OFF arm.

const UNITS: PackedStringArray = ["law_tank", "law_tank", "law_tank", "law_tank", "law_tank"]
const METRES := 150.0
const SECONDS := 75.0
## PACE_TRACK lines from the scenario runs (tools/tactics: the trace reader in the Status); off in the suite.
const TRACE := false


func teardown() -> void:
	ElementPlan.PACE_ENABLED = true
	super.teardown()


func _pair(seed_value: int, units: PackedStringArray, layout: String, shape: String, arena := "") -> Array:
	ElementPlan.PACE_ENABLED = false
	var off: Dictionary = await PaceStage.run(self, seed_value, arena, units, METRES if arena == "" else 100.0,
			layout, shape, SECONDS, "abreast", TRACE)
	ElementPlan.PACE_ENABLED = true
	var on: Dictionary = await PaceStage.run(self, seed_value, arena, units, METRES if arena == "" else 100.0,
			layout, shape, SECONDS, "abreast", TRACE)
	print("MEASURE pace %s seed %d %s %s %s: off %s | on %s" % ["parade" if arena == "" else arena, seed_value,
			":".join(units), layout, shape, off, on])
	return [off, on]


const HEADING := Vector3(0.0, 0.0, -1.0)
const CRUISE := 10.2  # 0.85 of a 12 m/s squad
const SPAN := 30.0


static func _member(unit_name: String, x: float, z: float, speed := 12.0) -> Dictionary:
	return {"name": unit_name, "position": Vector3(x, 0.0, z), "speed": speed}


## The anchor's pace: a crew on its seat asks for nothing; one beside closes on a diagonal; one behind gets what the
## cruise's margin cannot give it; a crew ahead never slows the anchor; the floor holds.
func test_the_anchor_paces_to_the_slowest_to_seat_crew() -> void:
	var shape := {"a": Vector3(0, 0, 0), "b": Vector3(15, 0, 0), "c": Vector3(-15, 0, 0), "d": Vector3(30, 0, 0)}
	assert_eq(ElementPlan.form_pace([_member("a", 0, 0)], shape, HEADING, CRUISE, SPAN), 1.0, "on its seat: 1.0")
	assert_eq(ElementPlan.form_pace([_member("a", 0, -20)], shape, HEADING, CRUISE, SPAN), 1.0, "ahead of it: 1.0")
	assert_eq(ElementPlan.form_pace([_member("a", 0, 2.5)], shape, HEADING, CRUISE, SPAN), 1.0, "within the slack: formed")
	# Beside by 15 m: the 3 m the PID dresses come off the gap: 30 / sqrt(12^2 + 30^2).
	var beside := ElementPlan.form_pace([_member("b", 0, 0)], shape, HEADING, CRUISE, SPAN)
	assert_true(absf(beside - SPAN / sqrt(12.0 * 12.0 + SPAN * SPAN)) < 0.001, "beside by 15 m: %.3f" % beside)
	# His case: 16 m behind (z = +16 on a heading of -z) and 15 m beside, a same-type squad (held = the cruise); the
	# gap 21.9 m less the slack, in the same direction: lateral 12.9, behind 13.8: 30 / sqrt(12.9^2 + 43.8^2) = 0.657.
	var behind := ElementPlan.form_pace([_member("c", 0, 16)], shape, HEADING, CRUISE, SPAN)
	assert_true(absf(behind - 0.657) < 0.005, "16 m behind, 15 beside: %.3f" % behind)
	var worst := ElementPlan.form_pace([_member("a", 0, 0), _member("c", 0, 16)], shape, HEADING, CRUISE, SPAN)
	assert_true(absf(worst - behind) < 0.001, "the lowest crew's: %.3f" % worst)
	assert_eq(ElementPlan.form_pace([_member("a", 0, 200)], shape, HEADING, CRUISE, SPAN), ElementPlan.TRANSIT_MIN_PACE, "the floor")
	# A faster crew needs less: a 16 m/s scout 16 m behind asks for 0.657 * 16 / 12.
	var scout := ElementPlan.form_pace([_member("c", 0, 16, 16.0)], shape, HEADING, CRUISE, SPAN)
	assert_true(absf(scout - 0.657 * 16.0 / 12.0) < 0.01, "a scout behind: %.3f" % scout)
	assert_eq(ElementPlan.form_pace([_member("a", 0, 16)], {}, HEADING, CRUISE, SPAN), 1.0, "no shape yet: 1.0")


## The crews' paces: behind or beside 1.0; ahead by the slack or less 1.0; ahead, (u / v) (1 - ahead / span), floored;
## far ahead, 0 (stand).
func test_a_crew_ahead_of_its_seat_slows_and_only_a_far_one_stands() -> void:
	var shape := {"a": Vector3(0, 0, 0), "b": Vector3(15, 0, 0)}
	var paces := ElementPlan.crew_paces([_member("a", 0, 10), _member("b", 0, 0), _member("c", 0, -5)], shape, HEADING, CRUISE, SPAN)
	assert_eq(paces["a"], 1.0, "behind: 1.0")
	assert_eq(paces["b"], 1.0, "beside: 1.0")
	assert_eq(paces["c"], 1.0, "no seat: 1.0")
	var at_slack: float = ElementPlan.crew_paces([_member("a", 0, -3)], shape, HEADING, CRUISE, SPAN)["a"]
	assert_true(absf(at_slack - 0.85 * (1.0 - 3.0 / SPAN)) < 0.001, "3 m ahead: the paced value (%.3f)" % at_slack)
	var eased: float = ElementPlan.crew_paces([_member("a", 0, -1.5)], shape, HEADING, CRUISE, SPAN)["a"]
	assert_true(absf(eased - lerpf(1.0, at_slack, 0.5)) < 0.001, "1.5 m ahead: half way from 1.0 (%.3f)" % eased)
	var half: float = ElementPlan.crew_paces([_member("a", 0, -15)], shape, HEADING, CRUISE, SPAN)["a"]
	assert_true(absf(half - 0.85 * 0.5) < 0.001, "15 m ahead of a 30 m span at u/v 0.85: %.3f" % half)
	assert_eq(ElementPlan.crew_paces([_member("a", 0, -29)], shape, HEADING, CRUISE, SPAN)["a"], ElementPlan.PACE_AHEAD_MIN, "29 m ahead: the creep")
	assert_eq(ElementPlan.crew_paces([_member("a", 0, -31)], shape, HEADING, CRUISE, SPAN)["a"], 0.0, "31 m ahead: stands")
	# The anchor at its floor: a crew 5 m ahead creeps at the floor rather than matching 0.35 * cruise.
	var slow: float = ElementPlan.crew_paces([_member("a", 0, -5)], shape, HEADING, 0.35 * CRUISE, SPAN)["a"]
	assert_eq(slow, ElementPlan.PACE_AHEAD_MIN, "under a crawling anchor: the creep (%.3f)" % slow)


## His case, end to end, one seed in the suite (the forming gain itself is the series' number, `make pace-series`,
## builder0, probe mode: in the suite's real-time mode the same seed dresses to 2-5 m by 10 s in both arms and the
## 3 m bar is met at the end by both). What must hold on any seed, any mode, with the pace ON: nobody stands still on
## the way, the squad arrives no more than a second later than with it OFF, the shape error over the transit is no
## larger, and the shape IS formed before the hand-off.
func test_his_line_along_its_axis_forms_on_the_way() -> void:
	var pair: Array = await _pair(1, UNITS, "along", "line")
	var off: Dictionary = pair[0]
	var on: Dictionary = pair[1]
	for report: Dictionary in pair:
		assert_true(float(report["arrived_s"]) > 0.0, "the squad arrives (%s)" % report)
		assert_true(float(report["route_m"]) >= 140.0, "the move travelled as a formation (%s)" % report)
	assert_true(float(on["formed_m"]) >= 0.0, "pace on: formed before the hand-off (%s)" % on)
	assert_eq(int(on["stops"]), 0, "pace on: nobody stops dead on the way (%s)" % on)
	assert_true(float(on["arrived_s"]) <= float(off["arrived_s"]) + 1.0,
			"pace on: arrives no more than a second later (%s vs %s)" % [on["arrived_s"], off["arrived_s"]])
	assert_true(float(on["rms_m"]) <= float(off["rms_m"]) + 0.5,
			"pace on: the shape error over the transit is no larger (%s vs %s)" % [on["rms_m"], off["rms_m"]])
	assert_true(float(on["lead_pace"]) < 1.0, "pace on: the lead crew was paced (%s)" % on)
