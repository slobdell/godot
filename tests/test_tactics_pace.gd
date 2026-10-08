extends TestCase
## Round 23 (brains B0/B1): HIS CASE. "When I had tanks in line abreast and had them move somewhere, they never got
## into formation until the very end - because the lead vehicle was already close to the target point at the start, the
## other vehicles never caught up to it until it stopped." Five Law tanks in a line whose own axis points at the click,
## 150 m across the parade ground's open middle (tests/tactics/pace_stage.gd): the line must swing into a line across
## the new heading on the way. B0 measures it (a MEASURE line per arm); B1 adds the acceptance.

const UNITS: PackedStringArray = ["law_tank", "law_tank", "law_tank", "law_tank", "law_tank"]
const METRES := 150.0
const SECONDS := 75.0


func teardown() -> void:
	ElementPlan.PACE_ENABLED = true
	super.teardown()


func _pair(seed_value: int, units: PackedStringArray, layout: String, shape: String, arena := "") -> Array:
	ElementPlan.PACE_ENABLED = false
	var off: Dictionary = await PaceStage.run(self, seed_value, arena, units, METRES if arena == "" else 100.0,
			layout, shape, SECONDS)
	ElementPlan.PACE_ENABLED = true
	var on: Dictionary = await PaceStage.run(self, seed_value, arena, units, METRES if arena == "" else 100.0,
			layout, shape, SECONDS)
	print("MEASURE pace %s seed %d %s %s %s: off %s | on %s" % ["parade" if arena == "" else arena, seed_value,
			":".join(units), layout, shape, off, on])
	return [off, on]


func test_his_line_along_its_axis_arrives_both_arms() -> void:
	var pair: Array = await _pair(1, UNITS, "along", "line")
	for report: Dictionary in pair:
		assert_true(float(report["arrived_s"]) > 0.0, "the squad arrives (%s)" % report)
		assert_true(float(report["route_m"]) >= 140.0, "the move travelled as a formation (%s)" % report)
