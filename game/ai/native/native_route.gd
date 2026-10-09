class_name NativeRoute
extends RefCounted
## Round 24 (native, N3b `move.path`): the route-following tail of `Movement._next_waypoint` (everything after its
## re-plan block) as ONE native call (`TankNative.follow_route`, native/src/route_native.cpp). The seam in
## `_next_waypoint` (after CP1) is `if NativeRoute.usable(self): return NativeRoute.tail(self, goal)`, placed after the
## `_path.size() < 2` return; the GDScript below the seam stays the reference (tests/test_native_route.gd asks the
## LIVE function both ways). The chord memo (`_chord_frame/_from/_to/_answer`) goes in and comes back, so the guard's
## ask later in the tick sees what the GDScript would have left there.


static func usable(mover: Movement) -> bool:
	# Not under `--nav-off=carrot` (round 5's follower) or the opt-in clearance arm (its counters count chords).
	return BrainSwitches.native and BrainSwitches.native_path and BrainSwitches.chord_memo \
			and not mover._off.has("carrot") and not Movement.clearance_on()


static func tail(mover: Movement, goal: Vector3) -> Vector3:
	var tank := mover.ctl.tank
	var frame := Engine.get_physics_frames()
	var ready := Pathing.enabled and Pathing.is_ready(tank)
	var flags := (1 if mover._reachable else 0) | (2 if mover._off.has("chord") else 0) | (4 if ready else 0) \
			| (8 if frame == mover._chord_frame else 0) | (16 if mover._chord_answer else 0) \
			| (32 if BrainLevers.chord_samples(tank.team, String(tank.name)) >= 2 else 0)
	# The slack only matters when a chord is computed; with the clearance arm off, _chord_slack() is a pure function
	# of the hull.
	var slack := mover._chord_slack() if ready else 0.0
	var out: PackedFloat32Array = NativeBridge.impl.follow_route(tank.global_position, tank.global_basis.z, mover._path,
			mover._path_index, goal, mover.wheel_radius(), flags, slack, tank.get_world_3d().navigation_map,
			mover._chord_from, mover._chord_to, NativeBridge.nav)
	mover._path_index = int(out[3])
	if out[4] > 0.5 and int(out[12]) > 0:
		mover._chord_frame = frame
		mover._chord_from = Vector3(out[5], out[6], out[7])
		mover._chord_to = Vector3(out[8], out[9], out[10])
		mover._chord_answer = out[11] > 0.5
	return Vector3(out[0], out[1], out[2])
