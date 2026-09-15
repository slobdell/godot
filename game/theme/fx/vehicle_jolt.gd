class_name VehicleJolt
extends RefCounted
## Vehicles rocking from their own gun's recoil, a heavy hit, or hard braking (feel X2, X6). Visual only: it tilts and
## shifts a vehicle's art (its VisualSlot nodes) around the vehicle's ground center and never moves the simulated body
## or turret. Each jolt is a damped oscillation computed from its start time (no integration state), so it's cheap,
## frame-rate independent, and returns the art exactly to where it was.

## Jolts summed per vehicle at once (the newest replace the oldest).
const MAX_PER_UNIT := 3
## A jolt is over (and its art restored) after this many seconds.
const SETTLE_SECONDS := 1.4

## vehicle (Node3D) -> {"jolts": [{axis, angle, shift, start, frequency, decay}], "bases": {slot node: Transform3D}}
var _active := {}


func active_count() -> int:
	return _active.size()


## Rock `unit` as if shoved along `world_push` (horizontal): tip `angle_deg` away from the push and slide `shift_m`
## with it, oscillating at `frequency` rad/s and dying out at `decay` 1/s.
func kick(unit: Node3D, world_push: Vector3, angle_deg: float, shift_m: float, now: float, frequency := 17.0, decay := 5.5) -> void:
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	var local := unit.global_basis.inverse() * Vector3(world_push.x, 0.0, world_push.z)
	local.y = 0.0
	if local.length() < 0.001:
		return
	local = local.normalized()
	var state: Dictionary = _active.get(unit, {})
	if state.is_empty():
		var bases := {}
		for slot in _slots(unit):
			bases[slot] = slot.transform
		if bases.is_empty():
			return
		state = {"jolts": [], "bases": bases}
		_active[unit] = state
	var jolts: Array = state["jolts"]
	# Tipping away from the push: a shove toward +Z (backward) lifts the nose.
	jolts.append({"axis": Vector3.UP.cross(local), "angle": deg_to_rad(angle_deg), "shift": local * shift_m, "start": now,
			"frequency": frequency, "decay": decay})
	while jolts.size() > MAX_PER_UNIT:
		jolts.pop_front()


## The oscillation's value at `t` seconds for amplitude 1: up fast, overshoot, settle.
static func sway(t: float, frequency: float, decay: float) -> float:
	if t < 0.0:
		return 0.0
	return exp(-decay * t) * sin(frequency * t)


## Apply every active jolt at `now`; restore and forget vehicles whose jolts have settled.
func update(now: float) -> void:
	for unit in _active.keys():
		var state: Dictionary = _active[unit]
		var bases: Dictionary = state["bases"]
		if not is_instance_valid(unit) or not (unit as Node3D).is_inside_tree():
			_active.erase(unit)
			continue
		var jolts: Array = state["jolts"]
		for i in range(jolts.size() - 1, -1, -1):
			if now - float(jolts[i]["start"]) > SETTLE_SECONDS:
				jolts.remove_at(i)
		if jolts.is_empty():
			_restore(bases)
			_active.erase(unit)
			continue
		var rock := Transform3D.IDENTITY
		for jolt: Dictionary in jolts:
			var amount := sway(now - float(jolt["start"]), float(jolt["frequency"]), float(jolt["decay"]))
			rock = Transform3D(Basis(jolt["axis"], float(jolt["angle"]) * amount), jolt["shift"] * amount) * rock
		var body := unit as Node3D
		var inverse_body := body.global_transform.affine_inverse()
		for slot: Node3D in bases:
			if not is_instance_valid(slot):
				continue
			# The slot's parent in the vehicle's frame (identity for the hull; the turret's yaw for turret art).
			var parent := inverse_body * (slot.get_parent() as Node3D).global_transform
			slot.transform = parent.affine_inverse() * rock * parent * (bases[slot] as Transform3D)


func _restore(bases: Dictionary) -> void:
	for slot: Node3D in bases:
		if is_instance_valid(slot):
			slot.transform = bases[slot]


## The vehicle's art: its VisualSlot children and grandchildren (hull, turret, weapon).
static func _slots(unit: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in unit.get_children():
		if child is VisualSlot:
			result.append(child)
		elif child is Node3D:
			for grandchild in child.get_children():
				if grandchild is VisualSlot:
					result.append(grandchild)
	return result
