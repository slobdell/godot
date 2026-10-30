extends TestCase
## Round 46 (R46.19): ENGAGE's direct hop never crosses water, cached plan or fresh. efe4d8ba9's check: the CPU's squad on
## his Locks bridge (test_tactics_bridge rust) drove 4 ticks of a reverse weave over the canal once the lane rule changed
## that fight. TankBrain.dry_hop is the last word on a direct hop: a leg over water is a face toward the target instead.

const FROM := Vector3(81.3, 0.0, 15.0)
const HOP := Vector3(91.2, 0.0, -7.6)
const TARGET := Vector3(90.0, 0.0, -40.0)


func _hop(direct := true) -> Dictionary:
	var order := TankBrain._move_to(HOP, true, 1.0, 1.0, direct)
	return order


func test_a_direct_hop_over_water_becomes_a_face() -> void:
	var saved := TankBrain.water_between
	TankBrain.water_between = func(_a: Vector3, _b: Vector3) -> bool: return true
	var order := TankBrain.dry_hop(_hop(), FROM, TARGET)
	TankBrain.water_between = saved
	assert_eq(String(order.get("type", "")), "face", "the hop over the canal is not driven (%s)" % [order])
	assert_true(is_equal_approx(float(order.get("x", 0.0)), TARGET.x) and is_equal_approx(float(order.get("z", 0.0)), TARGET.z),
			"it faces the target instead (%s)" % [order])


func test_a_dry_hop_or_a_pathed_move_is_unchanged() -> void:
	var saved := TankBrain.water_between
	TankBrain.water_between = func(_a: Vector3, _b: Vector3) -> bool: return false
	var dry := TankBrain.dry_hop(_hop(), FROM, TARGET)
	TankBrain.water_between = func(_a: Vector3, _b: Vector3) -> bool: return true
	var pathed := TankBrain.dry_hop(_hop(false), FROM, TARGET)
	TankBrain.water_between = saved
	assert_eq(dry, _hop(), "a dry hop is driven as planned")
	assert_eq(pathed, _hop(false), "a pathed move (not direct) is the mover's, which routes round water")
