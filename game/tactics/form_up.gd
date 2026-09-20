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


## A9 (round 9, X3): the bottleneck arrival time as a TICK COUNT, which is what every member's longitudinal profile
## is parameterised against. Ticks rather than seconds on purpose (Invariant 7: tick-count phase synchronisation, not
## wall clock) — it makes the pace a ratio of two integers, so the same ETAs give the same paces on every machine
## whatever order the floats were summed in. 0 with nobody moving.
static func bottleneck_ticks(member_etas: Dictionary) -> int:
	var worst := 0
	for value: float in member_etas.values():
		worst = maxi(worst, ticks_of(value))
	return worst


## Seconds -> ticks, rounded up: a member that needs any of a tick needs the whole tick.
static func ticks_of(seconds: float) -> int:
	return maxi(int(ceil(maxf(seconds, 0.0) * SimClock.TICK_RATE)), 0)


## {unit: speed fraction}: A9's time-synchronised co-arrival. Every member — the LEADER INCLUDED — is paced by its own
## share of the element's bottleneck arrival time, so the laggard drives flat out and the rest hit the same waypoint at
## the same moment. ETAs against ETAs: dividing a straight-line distance by nav's route ETA (which cruises at 0.85)
## paced even the laggard down to 0.85.
##
## Round 9 (X3): the bottleneck is a TICK COUNT (see bottleneck_ticks), so the pace is a ratio of integers. Before
## this there were TWO pacing rules — this one, and `Element._pace_leader_for_flow`, which paced the leader
## separately by how far the worst follower trailed its follow offset. One bottleneck, one rule.
## Nobody is paced below TacticsFormation.PACE_FLOOR, and a member already within PACE_NEAR of its slot drives flat
## out: the K1 100 ms guarantee is about the FIRST response to an order, and co-arrival slows the cruise, never the
## start.
static func paces(tanks: Dictionary, slots: Dictionary, member_etas: Dictionary) -> Dictionary:
	var result := {}
	var slowest := bottleneck_ticks(member_etas)
	for unit_name: String in member_etas:
		var tank := tanks.get(unit_name) as Tank
		var to: Vector3 = slots[unit_name]
		var remaining := Vector2(tank.global_position.x - to.x, tank.global_position.z - to.z).length()
		if remaining <= TacticsFormation.PACE_NEAR or slowest <= 0:
			result[unit_name] = 1.0
		else:
			result[unit_name] = clampf(float(ticks_of(float(member_etas[unit_name]))) / float(slowest),
					TacticsFormation.PACE_FLOOR, 1.0)
	return result
