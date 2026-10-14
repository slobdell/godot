extends TestCase
## Round 29 (brains B4): a line's slots stay a hull apart after grounding. Traced (TacticsLab seed 61, four gang trucks
## with 14 m hulls screening east, builder0): grounding moved each slot on its own and two landed 6.0 m apart, and one
## truck tried to park between its squadmates for 80 s and never got in. Element.spread_line slides a squeezed slot
## along the line to the nearest grounded spot clear of the slots already kept.

const EAST := Vector3(1.0, 0.0, 0.0)
const TRUCK := 7.15  # a 14 m x 2.9 m hull's turning envelope (half its diagonal)


func _flat(point: Vector3, _unit_name: String) -> Vector3:
	return point


func _gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_two_squeezed_slots_are_slid_a_hull_apart_along_the_line() -> void:
	var slots := {"A": Vector3(-93.7, 0.0, 5.8), "B": Vector3(-99.1, 0.0, -18.6), "C": Vector3(-97.7, 0.0, -12.8),
			"D": Vector3(-93.1, 0.0, 25.6)}
	var envelopes := {"A": TRUCK, "B": TRUCK, "C": TRUCK, "D": TRUCK}
	Element.spread_line(slots, EAST, envelopes, _flat)
	var names: Array = slots.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			assert_true(_gap(slots[names[i]], slots[names[j]]) >= 2.0 * TRUCK + Element.LINE_GAP_M - 0.01,
					"%s and %s stand a hull apart (%.1f m)" % [names[i], names[j], _gap(slots[names[i]], slots[names[j]])])
	assert_near((slots["B"] as Vector3).x, -99.1, 0.01, "the squeezed slot slides ALONG the line (across the heading)")
	assert_true((slots["B"] as Vector3).z < -18.6, "outward, away from the line's middle")
	assert_eq(slots["A"], Vector3(-93.7, 0.0, 5.8), "the middle slot stays")


func test_a_line_already_a_hull_apart_is_untouched() -> void:
	var slots := {"A": Vector3(0.0, 0.0, -21.0), "B": Vector3(0.0, 0.0, 0.0), "C": Vector3(0.0, 0.0, 21.0)}
	var before := slots.duplicate()
	Element.spread_line(slots, EAST, {"A": TRUCK, "B": TRUCK, "C": TRUCK}, _flat)
	assert_eq(slots, before, "nothing moves")


func test_ordinary_hulls_on_doctrine_spacing_are_untouched() -> void:
	# A Law tank's envelope is ~4.2 m: a 12 m line already clears 9.4 m.
	var slots := {"A": Vector3(0.0, 0.0, -12.0), "B": Vector3(0.0, 0.0, 0.0), "C": Vector3(0.0, 0.0, 12.0)}
	var before := slots.duplicate()
	Element.spread_line(slots, EAST, {"A": 4.2, "B": 4.2, "C": 4.2}, _flat)
	assert_eq(slots, before, "nothing moves")


func test_a_slot_with_no_clear_ground_along_the_line_stays_where_it_was() -> void:
	var slots := {"A": Vector3(0.0, 0.0, 0.0), "B": Vector3(0.0, 0.0, 5.0)}
	Element.spread_line(slots, EAST, {"A": TRUCK, "B": TRUCK},
			func(_point: Vector3, unit_name: String) -> Vector3: return Vector3(0.0, 0.0, 5.0))
	assert_eq(slots["B"], Vector3(0.0, 0.0, 5.0), "nowhere better to stand: it keeps its slot")
