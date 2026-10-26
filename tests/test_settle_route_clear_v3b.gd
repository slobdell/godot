extends TestCase
## Round 40 (settle S1 v3b, `--seat-route-clear=v3b`, R40.14; dev trace main 9d5907ddd + v3, builder2, terminus 5 click
## s6306): a driving squad's SWEPT BAND (DeployPassers.band) covers the width it drives in, not only each crew's path to its
## slot down the lane's centre line. Pure: a lane running south along x 0 from z 100 to z 20; the squad drives it 10 m
## wide. Alpha_3's case: a seat at (8.6, 68), 8.6 m off the centre line (over ROUTE_CLEAR_M), reads clear to v3 and blocked
## to v3b. A seat 20 m out stays clear.

const LANE := [Vector3(0, 0, 100), Vector3(0, 0, 60), Vector3(0, 0, 20)]


func test_the_band_covers_the_travel_width() -> void:
	var lines := DeployPassers.band(LANE, 10.0)
	assert_eq(lines.size(), 4, "7 m and 10 m, each side")
	var seat := Vector3(8.6, 0, 68)
	var v3 := {"routes": [LANE], "halts": []}
	var v3b := {"routes": [LANE] + lines, "halts": []}
	assert_true(DeployPassers.blocking(seat, v3).is_empty(), "counter: v3 reads Alpha_3's line clear")
	assert_true(not DeployPassers.blocking(seat, v3b).is_empty(), "v3b: on the band, blocked")
	assert_true(DeployPassers.blocking(Vector3(20, 0, 68), v3b).is_empty(), "20 m out: clear")


func test_a_narrow_squad_adds_nothing() -> void:
	assert_true(DeployPassers.band(LANE, 0.0).is_empty(), "no width, no band")
	var two := DeployPassers.band(LANE, 5.0)
	assert_eq(two.size(), 2, "inside one corridor: the one copy each side at the half-width")
	assert_true(absf(((two[0] as Array)[1] as Vector3).x) > 4.9, "shifted across the lane")


func test_the_band_follows_a_turn() -> void:
	var turn := [Vector3(0, 0, 100), Vector3(0, 0, 40), Vector3(-60, 0, 40)]
	var lines := DeployPassers.band(turn, 10.0)
	for line: Array in lines:
		var end: Vector3 = line[line.size() - 1]
		assert_true(absf(end.z - 40.0) > 6.9 and absf(end.x + 60.0) < 0.01, "the westward leg shifted north or south (%s)" % [end])
