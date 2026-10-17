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
## Round 27 (stage 1 E1c): the native drive on the C++-owned state (ExecState) instead of the live members; the same bits.
## `--native-exec-owned` (native-proof's `owned` arm) or a test sets it. Slower while the drive still calls GDScript back
## (the whole state is pulled at each drive's start and after each callback): a proof, not a speed, until E5.
static var owned := OS.get_cmdline_user_args().has("--native-exec-owned")
const OWNED_EVERY := 5000
static var _owned_drives := 0


static func usable(_mover: Movement) -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_drive and BrainSwitches.chord_memo \
			and Movement._off.is_empty() and not Movement.reverse_log and not Movement.kturn_log and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("drive")
	return ok


const PLANNER_SEAM := "res://game/ai/planner/planner_seam.gd"


static func configure() -> bool:
	if _configured:
		return true
	if not NativeBridge.available:
		return false
	var config := {
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
		# Round 27 (stage 1 E2): Movement._keep_station natively (its PID's step_with_rate in place).
		"STATION_LEAD_SECONDS": Movement.STATION_LEAD_SECONDS, "units": Units, "pid": Pid, "control_gains": ControlGains,
		"BLOCKER_REACH": Movement.BLOCKER_REACH, "BLOCKER_GAP_M": Movement.BLOCKER_GAP_M,
		"BLOCKER_AHEAD_COS": Movement.BLOCKER_AHEAD_COS, "MESH_EPSILON": Pathing.MESH_EPSILON,
		"KTURN_MIN_ERROR_DEG": Movement.KTURN_MIN_ERROR_DEG, "KTURN_CIRCLE_SPEED": Movement.KTURN_CIRCLE_SPEED,
		"manoeuvre_census": ManoeuvreCensus,
		# Round 28 (N5): Movement._repair
		"REPAIR_MAX_M": Movement.REPAIR_MAX_M, "slot_ground": SlotGround, "NAV_AGENT_RADIUS": Movement.NAV_AGENT_RADIUS,
		# Round 27 (stage 1 E5c): Movement.right_of_way
		"YIELD_REACHED": Movement.YIELD_REACHED, "YIELD_CLEAR": Movement.YIELD_CLEAR,
		"YIELD_HOLD_SECONDS": Movement.YIELD_HOLD_SECONDS,
		# Round 27 (stage 1 E4): Movement.unstick
		"STUCK_SPEED": Movement.STUCK_SPEED, "STUCK_SECONDS": Movement.STUCK_SECONDS,
		"UNSTICK_SECONDS": Movement.UNSTICK_SECONDS, "UNSTICK_CLEARANCE": Movement.UNSTICK_CLEARANCE,
		"PRESS_ESCAPE_THROTTLE": Movement.PRESS_ESCAPE_THROTTLE, "PRESS_BACKOFF_M": Movement.PRESS_BACKOFF_M,
		"PRESS_SECONDS": Movement.PRESS_SECONDS, "PRESS_PROGRESS_M": Movement.PRESS_PROGRESS_M,
		"PRESS_ESCAPE_MAX_S": Movement.PRESS_ESCAPE_MAX_S, "THROTTLE_MIN": WallContact.THROTTLE_MIN,
		# Round 26 (manoeuvre M1, C26.2): the gate of Movement._manoeuvre natively; absent (-1) before manoeuvre lands.
		"BEHIND_GAP_TICKS": int((Movement as Script).get_script_constant_map().get("BEHIND_GAP_TICKS", -1)),
		# Round 31 (manoeuvre CP-H, C31.4): H1 unstickback and H2 kturnarc's defaults (absent: false, the drive as before).
		"UNSTICK_BACK_DEFAULT": bool((Movement as Script).get_script_constant_map().get("UNSTICK_BACK_DEFAULT", false)),
		"KTURN_ARC_DEFAULT": bool((Movement as Script).get_script_constant_map().get("KTURN_ARC_DEFAULT", false)),
		"UNSTICK_BLIND_MAX_LEN_M": float((Movement as Script).get_script_constant_map().get("UNSTICK_BLIND_MAX_LEN_M", 10.0)),
		"tank_script": Tank,
		# Round 33 (N5.M): _manoeuvre's decision natively (Manoeuvre.choose and its simulation); the motion model's constants
		# configured here, since the decision steps it whatever BrainSwitches.native_motion says (the same bits, N6.1).
		"manoeuvre": Manoeuvre, "MAN_MAX_M": Manoeuvre.MAX_M, "MAN_BEHIND_DEG": Manoeuvre.BEHIND_DEG,
		"MAN_FACING_KEEP_DEG": Manoeuvre.FACING_KEEP_DEG, "MAN_SIM_DT": Manoeuvre.SIM_DT,
		"MAN_SIM_HORIZON_S": Manoeuvre.SIM_HORIZON_S, "MAN_CHECK_EVERY": Manoeuvre.CHECK_EVERY,
		"MAN_HULL_MARGIN_M": Manoeuvre.HULL_MARGIN_M, "REAIM_TICKS": Movement.REAIM_TICKS,
		"KTURN_MARGIN_M": Movement.KTURN_MARGIN_M, "CUSP_DEADBAND": ManoeuvreCensus.CUSP_DEADBAND,
		"motion_ok": NativeMotion.configure(),
	}
	# Round 31 (planner CP-P1): the seam's switch and its table, when this tree has the seam (loaded by path: the file
	# parses on a tree without it).
	if ResourceLoader.exists(PLANNER_SEAM):
		var seam: Script = load(PLANNER_SEAM)
		config["planner_seam"] = seam
		config["PLANNER_ON"] = bool(seam.call("on"))
	config.merge(NativeTraffic.drive_config())
  # round 29 (traffic T1): the street hold, when this tree has it
	_configured = NativeBridge.impl.drive_configure(config)
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
	if owned:
		NativeBridge.impl.drive_owned(mover, cmd, order, delta)
		_owned_drives += 1
		if _owned_drives % OWNED_EVERY == 0:
			var c: Dictionary = NativeBridge.impl.drive_owned_counts(false)
			var n := maxi(int(c["drives"]), 1)
			print("NATIVE_EXEC_OWNED %d drives: end push %.2f fields %.3f usec a drive; start pull %.2f usec; syncs a drive %.2f pulls %.2f pushes" % [
					n, float(c["end_push_fields"]) / n, float(c["end_push_usec"]) / n, float(c["start_pull_usec"]) / n,
					float(c["pulls"]) / n, float(c["pushes"]) / n])
	else:
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
