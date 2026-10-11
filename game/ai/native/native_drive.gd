class_name NativeDrive
extends RefCounted
## Round 24 (native, N3c): `Movement.drive` as ONE native call per tank per tick (native/src/drive_native.cpp). The
## C++ works on the mover's own members (0.03 usec a read from C++), so the GDScript Movement stays the owner of the
## state and every branch not yet ported is a callback into the live GDScript method. The seam at the top of
## `Movement.drive` (after CP1) is `if NativeDrive.usable(self): return NativeDrive.drive(self, cmd, order, delta)`;
## the GDScript below it stays the reference (tests/test_native_drive.gd drives from the same state both ways).
##
## Only in the default configuration: no `--nav-off=` switch (every opt-in arm then folds to its constant in the C++)
## and no k-turn / circle diagnosis log (reverse_log, kturn_log). The constants are handed over from the live scripts once (configure), so an
## edit to one of them in movement.gd is followed, not frozen.

static var _configured := false
## Measurement only: `--native-drive-profile` prints NATIVE_DRIVE_PROFILE (usec a drive inside each GDScript callback and
## each native section, drive_native.cpp's clocks) every PROFILE_EVERY native drives.
static var profile := OS.get_cmdline_user_args().has("--native-drive-profile")
const PROFILE_EVERY := 20000
static var _drives := 0


static func usable(_mover: Movement) -> bool:
	return BrainSwitches.native and BrainSwitches.native_drive and BrainSwitches.chord_memo \
			and Movement._off.is_empty() and not Movement.reverse_log and not Movement.kturn_log and configure()


static func configure() -> bool:
	if _configured:
		return true
	if not NativeBridge.available:
		return false
	_configured = NativeBridge.impl.drive_configure({
		"NEW_GOAL_JUMP": Movement.NEW_GOAL_JUMP, "WAYPOINT_MIN_M": Movement.WAYPOINT_MIN_M,
		"GIVE_WAY_PACE": Movement.GIVE_WAY_PACE, "STATION_RANGE": Movement.STATION_RANGE,
		"STATION_MIN_SPEED": Movement.STATION_MIN_SPEED, "ASK_SECONDS": Movement.ASK_SECONDS,
		"ASK_EVERY_SECONDS": Movement.ASK_EVERY_SECONDS, "AVOID_ASK_PACE": Movement.AVOID_ASK_PACE,
		"BLOCKED_SECONDS": Movement.BLOCKED_SECONDS, "UNREACHABLE_AT_END": Movement.UNREACHABLE_AT_END,
		"OFF_PATH_REPATH": Movement.OFF_PATH_REPATH, "REPATH_SECONDS": Movement.REPATH_SECONDS,
		"NO_PATH_MARGIN": Movement.NO_PATH_MARGIN, "STATION_STALE_SECONDS": Movement.STATION_STALE_SECONDS,
		"STATION_STOPPED_SECONDS": Movement.STATION_STOPPED_SECONDS, "WEDGED_SHARE": Movement.WEDGED_SHARE,
		"PATH_LOOKAHEAD": Movement.PATH_LOOKAHEAD, "WHEELS_LOOKAHEAD_RADII": Movement.WHEELS_LOOKAHEAD_RADII,
		"CARROT_ALIGNED_COS": Movement.CARROT_ALIGNED_COS, "WHEELS_LOOKAHEAD_MAX_RADII": Movement.WHEELS_LOOKAHEAD_MAX_RADII,
		"CARROT_PULLBACK_0": Movement.CARROT_PULLBACK[0], "CARROT_PULLBACK_1": Movement.CARROT_PULLBACK[1],
		"GIVE_WAY_AFTER_TICKS": Movement.GIVE_WAY_AFTER_TICKS, "GIVE_WAY_TICKS": Movement.GIVE_WAY_TICKS,
		"AVOID_GRACE_TICKS": Movement.AVOID_GRACE_TICKS, "WEDGED_WINDOW": Movement.WEDGED_WINDOW,
		"TICK_RATE": SimClock.TICK_RATE, "FIRE_CHECK_TICKS": Movement.FIRE_CHECK_TICKS, "ARRIVE_RADIUS": OrderController.ARRIVE_RADIUS,
		"FULL_TURN_ERROR_DEG": Steering.FULL_TURN_ERROR_DEG, "TURN_IN_PLACE_DEG": Steering.TURN_IN_PLACE_DEG,
		"SLOW_RADIUS": Steering.SLOW_RADIUS, "WHEELS_CIRCLE_MARGIN": Steering.WHEELS_CIRCLE_MARGIN,
		"WHEELS_FULL_LOCK_DEG": Steering.WHEELS_FULL_LOCK_DEG, "WHEELS_REVERSE_THROTTLE": Steering.WHEELS_REVERSE_THROTTLE,
		"WHEELS_MIN_THROTTLE": Steering.WHEELS_MIN_THROTTLE,
		"AVOID_STEER_MIN": Movement.AVOID_STEER_MIN, "AVOID_STEER_MAX": Movement.AVOID_STEER_MAX,
		"AVOID_MESH_PROBE": Movement.AVOID_MESH_PROBE, "AVOID_MESH_SLACK": Movement.AVOID_MESH_SLACK,
		"AVOID_MIN_PACE": Movement.AVOID_MIN_PACE, "CHORD_SLACK": Movement.CHORD_SLACK, "CHORD_MARGIN": Movement.CHORD_MARGIN,
		"APPROACH_RADII": Movement.APPROACH_RADII, "APPROACH_MIN": Movement.APPROACH_MIN,
		"APPROACH_MAX": Movement.APPROACH_MAX, "APPROACH_ALIGNED_COS": Movement.APPROACH_ALIGNED_COS,
		"MESH_GATE_SLACK": Movement.MESH_GATE_SLACK, "GATE_REACHED": Movement.GATE_REACHED,
		"OFF_MESH_PROBE_0": Movement.OFF_MESH_PROBES[0], "OFF_MESH_PROBE_1": Movement.OFF_MESH_PROBES[1],
		"OFF_MESH_PROBE_2": Movement.OFF_MESH_PROBES[2],
		"KTURN_THROTTLE": Movement.KTURN_THROTTLE, "KTURN_SECONDS_PER_M": Movement.KTURN_SECONDS_PER_M,
		"KTURN_INTO_WALL_COS": Movement.KTURN_INTO_WALL_COS, "KTURN_ROLLING_SPEED": Movement.KTURN_ROLLING_SPEED,
		"KTURN_BRAKE_HULL_M": Movement.KTURN_BRAKE_HULL_M, "KTURN_RETRY_TICKS": Movement.KTURN_RETRY_TICKS, "avoidance": Avoidance, "switches": BrainSwitches,
		"pathing": Pathing, "levers": BrainLevers, "tank_command": TankCommand, "nav": NativeBridge.nav,
		"profile": profile,
		# N4: Movement._around_fire (BrainSwitches.native_fire)
		"FIRE_LOOKAHEAD": Movement.FIRE_LOOKAHEAD, "FIRE_DETOUR_MARGIN": Movement.FIRE_DETOUR_MARGIN,
		"FIRE_DETOUR_REACHED": Movement.FIRE_DETOUR_REACHED, "FIRE_KEEP_SHARE": Movement.FIRE_KEEP_SHARE,
		"BEATEN_ZONE_DENSITY": Match.BEATEN_ZONE_DENSITY, "DRIVABLE_LIMIT": Match.DRIVABLE_LIMIT,
		"MARCH_FRACTION": ThreatField.MARCH_FRACTION, "FIRE_DETOUR_STEP_0": Movement.FIRE_DETOUR_STEPS[0],
		"FIRE_DETOUR_STEP_1": Movement.FIRE_DETOUR_STEPS[1], "FIRE_DETOUR_STEP_2": Movement.FIRE_DETOUR_STEPS[2],
		"FIRE_DETOUR_TICKS": Movement.FIRE_DETOUR_TICKS, "FIRE_AVOID_MAX": Movement.FIRE_AVOID_MAX,
		"FIRE_DETOUR_COOLDOWN": Movement.FIRE_DETOUR_COOLDOWN, "FIRE_LEG_MIN_TICKS": Movement.FIRE_LEG_MIN_TICKS,
		"match_script": Match, "suppression_feed": SuppressionFeed, "order_controller": OrderController,
		"brain_variants": BrainVariants,
	})
	if Movement.FIRE_DETOUR_STEPS.size() != 3:
		push_error("NativeDrive: drive_native.cpp scores three sidesteps; movement.gd has %d" % Movement.FIRE_DETOUR_STEPS.size())
		_configured = false
	if Movement.OFF_MESH_PROBES.size() != 3:
		push_error("NativeDrive: drive_native.cpp probes three off-mesh shares; movement.gd has %d" % Movement.OFF_MESH_PROBES.size())
		_configured = false
	if Movement.CARROT_PULLBACK.size() != 2:
		push_error("NativeDrive: drive_native.cpp walks two carrot pull-back shares; movement.gd has %d" % Movement.CARROT_PULLBACK.size())
		_configured = false
	return _configured


static func drive(mover: Movement, cmd: TankCommand, order: Dictionary, delta: float) -> void:
	NativeBridge.impl.drive(mover, cmd, order, delta)
	if profile:
		_drives += 1
		if _drives % PROFILE_EVERY == 0:
			var clocks: Dictionary = NativeBridge.impl.drive_profile(true)
			var parts := []
			for key: String in clocks:
				if key != "drives":
					parts.append("%s %.1f" % [key, float(clocks[key]) / maxi(int(clocks["drives"]), 1)])
			print("NATIVE_DRIVE_PROFILE %d drives, usec a drive: %s" % [int(clocks["drives"]), ", ".join(parts)])


## N4 (tests): Movement._around_fire natively on this mover, from its state now (the proof asks it beside the GDScript).
static func around_fire(mover: Movement, waypoint: Vector3, goal: Vector3, order: Dictionary) -> Vector3:
	return NativeBridge.impl.drive_around_fire(mover, waypoint, goal, order)


static func fire_ready() -> bool:
	return configure() and NativeBridge.impl.drive_fire_ready()
