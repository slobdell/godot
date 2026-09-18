class_name FormUp
extends RefCounted
## X3 (round 6): the lead's form-up formula. *"No matter where they might be currently, there's a formula to form up
## ... it might be easy enough computationally to estimate the position and time at which an individual unit would
## converge with its formation."* A formation order gives every unit a slot (TacticsFormation, N2); this file estimates
## when each will be in it, the element's form-up ETA (its slowest member's), and the pace each member drives at so
## they all arrive together.
##
## ETA is navigation's question, and since CP1 navigation answers it: `Movement.eta` is the navmesh route's length at
## a cruising share (0.85) of top speed plus the time to swing onto the route — so a unit behind a container stack is as
## late as it really is, which a straight line cannot see. Optimistic but calibrated: nothing here asserts on it.


## Seconds for `tank` to reach `to` (nav's N1).
static func eta(tank: Tank, to: Vector3) -> float:
	if tank == null or not is_instance_valid(tank):
		return 0.0
	return Movement.eta(tank, to)


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


## {unit: speed fraction}: each member slows so it arrives with the slowest — its own ETA over the slowest ETA, so the
## laggard drives flat out and nobody is paced below TacticsFormation.PACE_FLOOR. ETAs against ETAs: dividing a
## straight-line distance by nav's route ETA (which cruises at 0.85) paced even the laggard down to 0.85.
static func paces(tanks: Dictionary, slots: Dictionary, member_etas: Dictionary) -> Dictionary:
	var result := {}
	var slowest := group_eta(member_etas)
	for unit_name: String in member_etas:
		var tank := tanks.get(unit_name) as Tank
		var to: Vector3 = slots[unit_name]
		var remaining := Vector2(tank.global_position.x - to.x, tank.global_position.z - to.z).length()
		if remaining <= TacticsFormation.PACE_NEAR or slowest <= 0.0:
			result[unit_name] = 1.0
		else:
			result[unit_name] = clampf(float(member_etas[unit_name]) / slowest, TacticsFormation.PACE_FLOOR, 1.0)
	return result
