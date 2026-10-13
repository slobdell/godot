class_name NativeGun
extends RefCounted
## Round 27 (native, stage 1 E3): `Gunnery.apply` as ONE native call per crew per tick (native/src/gun_native.cpp), the
## same bits as the GDScript (tests/test_native_gun.gd runs both from one snapshot). The constants and scripts are handed
## over from the live scripts once (configure), so an edit to a constant is followed. BrainSwitches.native_gun (OFF until
## priced) puts it in `OrderController.compute_command`; `owned` runs it on the C++-owned state (NativeDrive.owned's twin).

static var _configured := false


static func usable(_gunnery: Gunnery) -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_gun and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("gun")
	return ok


static func configure() -> bool:
	if _configured:
		return true
	if not NativeBridge.available or not NativeDrive.configure():
		return false
	_configured = NativeBridge.impl.gun_configure({
		"SCAN_EVERY_TICKS": Gunnery.SCAN_EVERY_TICKS, "LANE_RECHECK_TICKS": Gunnery.LANE_RECHECK_TICKS,
		"WANDER_PERIOD_TICKS": Difficulty.WANDER_PERIOD_TICKS, "KIND_PROJECTILE": Weapons.Kind.PROJECTILE,
		"KIND_ARC": Weapons.Kind.ARC, "WORLD_MASK": Perception.WORLD_MASK,
		"LOW_AMMO_FRACTION": Gunnery.LOW_AMMO_FRACTION, "HELD_AIM_DISTANCE": Gunnery.HELD_AIM_DISTANCE,
		"SHELL_SPEED": Shell.SPEED, "EYE_HEIGHT": Perception.EYE_HEIGHT,
		"ACQUIRE_NEAR_SECONDS": Engagement.ACQUIRE_NEAR_SECONDS, "ACQUIRE_FAR_SECONDS": Engagement.ACQUIRE_FAR_SECONDS,
		"SUPPRESSION_ACQUIRE_PENALTY": Engagement.SUPPRESSION_ACQUIRE_PENALTY,
		"DESIGNATED_ACQUIRE_SCALE": Engagement.DESIGNATED_ACQUIRE_SCALE, "SCOUT_ACQUIRE_SCALE": Engagement.SCOUT_ACQUIRE_SCALE,
		"CROSSING_ACQUIRE_PENALTY": Engagement.CROSSING_ACQUIRE_PENALTY,
		"CROSSING_REFERENCE_RATE": Engagement.CROSSING_REFERENCE_RATE, "CROSSING_ACQUIRE_MAX": Engagement.CROSSING_ACQUIRE_MAX,
		"LOST_LAY_DECAY": Engagement.LOST_LAY_DECAY, "RELEASE_FACTOR": Engagement.RELEASE_FACTOR,
		"RETURN_FIRE_SUPPRESSION": Engagement.RETURN_FIRE_SUPPRESSION,
		"engagement": Engagement, "order_controller": OrderController, "difficulty": Difficulty,
		"ai_tick_cache": AiTickCache, "fire_lanes": FireLanes, "units": Units, "switches": BrainSwitches,
		"perception": Perception, "match_script": Match,
	})
	return _configured


static func apply(gunnery: Gunnery, cmd: TankCommand, seconds: float) -> void:
	NativeBridge.impl.gun_apply(gunnery, cmd, seconds, NativeDrive.owned)
