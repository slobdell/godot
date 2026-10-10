class_name NativeWeapon
extends RefCounted
## Round 25/26 (native N7, granted 8e42247e): Gunnery's work after the scan as native calls, behind `native_weapon`
## (OFF until priced with act and the k-turn planner as ONE laptop bundle). The first slice is the aim solution:
## `Gunnery._aim_solution` (the lead, the Difficulty offset, the distance and the aim error) as
## `TankNative.weapon_aim`, the same bits as the GDScript (tests/test_native_weapon.gd asks the LIVE functions).


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_weapon and NativeBridge.available


## `Gunnery._aim_solution(target, muzzle)`'s answer, natively: [aim: Vector3, distance: float, aim error: float].
## `ticked`: the shooter's brain has a match (the Difficulty offset applies).
static func aim(gunnery: Gunnery, target: Tank, muzzle: Vector3, ticked: bool) -> Array:
	var tank := gunnery.tank
	var weapon := tank.weapon
	var round_speed := 0.0
	if weapon["kind"] == Weapons.Kind.PROJECTILE:
		var speed := float(weapon.get("projectile_speed_mps", 0.0))
		round_speed = speed if speed > 0.0 else Shell.SPEED
	var tick := 0
	var wander := 0.0
	if ticked:
		tick = (gunnery.ctl as TankBrain).game_match.tick
		wander = float(Difficulty.for_team(tank.team)["aim_wander_m"])
	var out: PackedFloat64Array = NativeBridge.impl.weapon_aim(muzzle, target.global_position, target.estimated_velocity,
			round_speed, wander, tick, tank.slot, Difficulty.WANDER_PERIOD_TICKS if ticked else 0, tank.turret_forward())
	return [Vector3(out[0], out[1], out[2]), out[3], out[4]]


## Engagement's constants were sent to the library (once per run: they are consts of the live script).
static var _configured := false


static func _configure() -> void:
	if _configured:
		return
	_configured = true
	NativeBridge.impl.weapon_engage_configure(PackedFloat64Array([Engagement.ACQUIRE_NEAR_SECONDS,
			Engagement.ACQUIRE_FAR_SECONDS, Engagement.SUPPRESSION_ACQUIRE_PENALTY, Engagement.DESIGNATED_ACQUIRE_SCALE,
			Engagement.SCOUT_ACQUIRE_SCALE, Engagement.CROSSING_ACQUIRE_PENALTY, Engagement.CROSSING_REFERENCE_RATE,
			Engagement.CROSSING_ACQUIRE_MAX, Engagement.RELEASE_FACTOR, Engagement.RETURN_FIRE_SUPPRESSION]))


## `Gunnery._engage(target)`, natively: Engagement.Lay.engage's gates 2 and 3 on the crew's lay (its state and
## Engagement's two counters written back exactly as the GDScript writes them).
static func engage(gunnery: Gunnery, target: Tank, distance: float, ordered: bool) -> bool:
	_configure()
	var lay := gunnery.engagement_lay
	var tank := gunnery.tank
	var target_name := String(target.name)
	if target_name != lay.target:
		lay.target = target_name
		lay.progress = 0.0
		lay.firing = false
	var weapon := tank.weapon
	var effective := Engagement.effective_range(weapon)
	var out: PackedFloat64Array = NativeBridge.impl.weapon_engage(lay.progress, lay.firing, tank.global_position,
			target.global_position, target.estimated_velocity, distance, gunnery._seconds_step(), tank.sight_radius,
			tank.suppression, target.designated_seconds, Units.role_of(tank.unit_id) == "scout",
			effective, float(weapon.get("range", effective)), ordered,
			Engagement.acquisition_enabled, Engagement.crossing_enabled)
	lay.progress = out[0]
	lay.firing = out[1] != 0.0
	if out[3] == 1.0:
		Engagement.held_by_acquisition += 1
	elif out[3] == 2.0:
		Engagement.held_by_discipline += 1
	return out[2] != 0.0
