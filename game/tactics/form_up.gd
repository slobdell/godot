class_name FormUp
extends RefCounted
## X3 (round 6): the lead's form-up formula. *"No matter where they might be currently, there's a formula to form up
## ... it might be easy enough computationally to estimate the position and time at which an individual unit would
## converge with its formation."* A formation order gives every unit a slot (TacticsFormation, N2); this file estimates
## when each will be in it, the element's form-up ETA (its slowest member's), and the pace each member drives at so
## they all arrive together.
##
## ETA is navigation's question. Until nav's Movement API (N1) exists the estimate is straight-line distance over top
## speed; `eta()` is the one seam, and becomes `Movement.eta(unit, to)` at CP1 — nothing else here changes.


## Seconds for `tank` to reach `to`.
static func eta(tank: Tank, to: Vector3) -> float:
	if tank == null or tank.max_forward_speed <= 0.0:
		return 0.0
	return Vector2(tank.global_position.x - to.x, tank.global_position.z - to.z).length() / tank.max_forward_speed


## {unit: seconds to its slot} for every unit with a slot in `slots` ({unit: Vector3}).
static func etas(tanks: Dictionary, slots: Dictionary) -> Dictionary:
	var result := {}
	for unit_name: String in slots:
		var tank := tanks.get(unit_name) as Tank
		if tank != null and tank.is_alive() and slots[unit_name] is Vector3:
			result[unit_name] = eta(tank, slots[unit_name])
	return result


## The element is formed up when its slowest member is: the largest ETA (0 with nobody moving).
static func group_eta(member_etas: Dictionary) -> float:
	var worst := 0.0
	for value: float in member_etas.values():
		worst = maxf(worst, value)
	return worst


## {unit: speed fraction}: each member slows so it arrives with the slowest (TacticsFormation.pace).
static func paces(tanks: Dictionary, slots: Dictionary, member_etas: Dictionary) -> Dictionary:
	var result := {}
	var slowest := group_eta(member_etas)
	for unit_name: String in member_etas:
		var tank := tanks.get(unit_name) as Tank
		var to: Vector3 = slots[unit_name]
		var remaining := Vector2(tank.global_position.x - to.x, tank.global_position.z - to.z).length()
		result[unit_name] = TacticsFormation.pace(remaining, tank.max_forward_speed, slowest)
	return result
