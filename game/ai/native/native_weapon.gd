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
