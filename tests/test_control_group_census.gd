extends TestCase
## Round 41 (orders O1): the group-order census's crossing rule (tests/orders_probe_group.gd). Two first legs cross when
## segments meet at more than CROSS_DEG; two crews merging onto one road (a shallow meeting) or running side by side do not.

const Probe := preload("res://tests/orders_probe_group.gd")


func _legs(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)


func test_a_square_crossing_counts() -> void:
	var a := _legs([Vector2(0, 0), Vector2(20, 0)])
	var b := _legs([Vector2(10, -10), Vector2(10, 10)])
	assert_true(Probe._legs_cross(a, b), "a north-going leg through an east-going one crosses")


func test_parallel_and_merging_legs_do_not_count() -> void:
	var a := _legs([Vector2(0, 0), Vector2(30, 0)])
	assert_true(not Probe._legs_cross(a, _legs([Vector2(0, 5), Vector2(30, 5)])), "side by side")
	# Joining the same road at 15 deg: a merge, not a crossing.
	assert_true(not Probe._legs_cross(a, _legs([Vector2(0, -4), Vector2(15, 0.0), Vector2(30, 2)])), "a shallow merge")


func test_legs_that_never_meet_do_not_count_and_a_bent_leg_is_read_per_segment() -> void:
	var a := _legs([Vector2(0, 0), Vector2(10, 0)])
	assert_true(not Probe._legs_cross(a, _legs([Vector2(20, -10), Vector2(20, 10)])), "beyond its end")
	var bent := _legs([Vector2(-5, 5), Vector2(5, 5), Vector2(5, -5)])
	assert_true(Probe._legs_cross(a, bent), "its second segment turns across")
