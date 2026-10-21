extends TestCase
## Round 37 (orders O6, C37.4): the deploy asks cover's low_cover_seat ONCE per crew when it lays its halt, keeps the
## answers in the deploy, and never asks again. Until cover's TacticalQuery.low_cover_seat is on main the seam answers null.


func test_the_seam_answers_null_until_covers_query_exists() -> void:
	if Callable(TacticalQuery, "low_cover_seat").is_valid():
		return  # cover's API has landed: its own tests cover the answer
	assert_eq(ElementPlan.low_cover_seat(null, Vector3(1, 0, 2), Vector3.FORWARD, 4.0, Vector3(3, 2, 6)), null, "no query yet: no seat moves")


func test_cover_seats_are_asked_once_and_then_stand() -> void:
	var plan := {"slots": {"A": Vector3(0, 0, 0), "B": Vector3(10, 0, 0)}}
	var deploy := {"heading": Vector3.FORWARD}
	ElementPlan._cover_seats(plan, deploy)
	assert_true(deploy.has("cover"), "the first lay records the answers")
	deploy["cover"] = {"A": Vector3(2, 0, -1)}  # as if cover had moved A's seat
	var again := {"slots": {"A": Vector3(0, 0, 0), "B": Vector3(10, 0, 0)}}
	ElementPlan._cover_seats(again, deploy)
	assert_eq(again["slots"]["A"], Vector3(2, 0, -1), "a later update keeps the seat chosen at the lay")
	assert_eq(again["slots"]["B"], Vector3(10, 0, 0), "a crew cover did not move keeps its seat")
