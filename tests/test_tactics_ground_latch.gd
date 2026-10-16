extends TestCase
## Round 32 (brains B10): a seat's grounding is latched while the point its shape asks for holds. Traced (B5c-v5's
## worst Sumps run, s17 t11, builder0): the side a pushed seat lands on is chosen by the element centre's 5 m cell, and a
## squad jostling on its spot flipped Green_S_3's seat between (-0.2, -51.1) and (1.7, -40.9) 67 times in 25 s.


func test_the_first_grounding_stands_while_the_asked_point_holds() -> void:
	var latch := {}
	var answers := [Vector3(-0.2, 0, -51.1), Vector3(1.7, 0, -40.9), Vector3(-0.2, 0, -51.1)]
	var calls := [0]
	var compute := func() -> Vector3:
		var answer: Vector3 = answers[calls[0] % answers.size()]
		calls[0] += 1
		return answer
	var asked := Vector3(2.0, 0, -45.0)
	var first := Element._latched(latch, "slot:Green_S_3", asked, compute)
	for i in 10:
		# The element's centre crosses a cell edge each plan: the side answer would flip; the latch keeps the first.
		var again := Element._latched(latch, "slot:Green_S_3", asked + Vector3(0.1, 0, 0.1) * (i % 2), compute)
		assert_eq(again, first, "plan %d: the seat stays where it was grounded" % i)
	assert_eq(calls[0], 1, "grounded once")


func test_a_seat_asked_somewhere_else_is_grounded_again() -> void:
	var latch := {}
	var calls := [0]
	var compute := func() -> Vector3:
		calls[0] += 1
		return Vector3(calls[0], 0, 0)
	Element._latched(latch, "slot:A", Vector3.ZERO, compute)
	var moved := Element._latched(latch, "slot:A", Vector3(0, 0, 3.0), compute)
	assert_eq(moved, Vector3(2, 0, 0), "the shape moved the seat 3 m: grounded afresh")
	assert_eq(Element._latched(latch, "slot:B", Vector3.ZERO, compute), Vector3(3, 0, 0), "each seat keeps its own")


func test_with_no_memo_every_plan_grounds_afresh() -> void:
	var calls := [0]
	var compute := func() -> Vector3:
		calls[0] += 1
		return Vector3.ZERO
	for i in 3:
		Element._latched(null, "slot:A", Vector3.ZERO, compute)
	assert_eq(calls[0], 3, "--ground-latch=off: round 21's side rule every plan")
