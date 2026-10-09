class_name NativeDecide
extends RefCounted
## Round 24 (native, N3d): `TankBrain.decide` as one native call (native/src/decide_native.cpp): every option's score,
## the order's filter, the cooldowns, the flip-back penalty, the flat commitment bonus, the choice and the ranked three,
## built as the same Dictionaries in the same order (ties break the same way). The default arm only: with
## `--tune=switch.cost=1` (SwitchingCost's arm) or the switch probe on, the GDScript decides. The constants come from
## the live scripts at first use. tests/test_native_decide.gd decides both ways on real situations.

static var _configured := false


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_decide and not SwitchingCost.cost_arm() \
			and not SwitchingCost.probing and configure()


static func configure() -> bool:
	if _configured:
		return true
	if not NativeBridge.available:
		return false
	_configured = NativeBridge.impl.decide_configure({
		"HOT_FIREPOWER": TankBrain.HOT_FIREPOWER, "PINNED_THREAT_FACTOR": TankBrain.PINNED_THREAT_FACTOR,
		"PINNED_RETREAT_HP": TankBrain.PINNED_RETREAT_HP, "CRITICAL_HP_MIN": TankBrain.CRITICAL_HP_MIN,
		"CRITICAL_HP_MAX": TankBrain.CRITICAL_HP_MAX, "RESUPPLY_TOP_UP": TankBrain.RESUPPLY_TOP_UP,
		"REPAIR_TOP_UP": TankBrain.REPAIR_TOP_UP, "PINNED_COVER": TankBrain.PINNED_COVER,
		"SHIELD_DOWN_BREAK_HP": TankBrain.SHIELD_DOWN_BREAK_HP, "RECHARGED": TankBrain.RECHARGED,
		"ORBIT_KEEP_ADVANTAGE": TankBrain.ORBIT_KEEP_ADVANTAGE, "ORBIT_START_ADVANTAGE": TankBrain.ORBIT_START_ADVANTAGE,
		"FOCUS_BONUS": TankBrain.FOCUS_BONUS, "COVER_TEAMMATE_BONUS": TankBrain.COVER_TEAMMATE_BONUS,
		"FRAGILE_THREAT_BONUS": TankBrain.FRAGILE_THREAT_BONUS, "ORDER_WEIGHT": TankBrain.ORDER_WEIGHT,
		"SUPPRESS_KILL_RATIO": TankBrain.SUPPRESS_KILL_RATIO, "PIN_HOLD_FRACTION": TankBrain.PIN_HOLD_FRACTION,
		"PINNED_SUPPRESSION": Tank.PINNED_SUPPRESSION, "SUPPRESS_WEIGHT": TankBrain.SUPPRESS_WEIGHT,
		"PINNED_FLANK_BONUS": TankBrain.PINNED_FLANK_BONUS, "FLANKER_APPETITE": TankBrain.FLANKER_APPETITE,
		"SCOUT_FIGHT": TankBrain.SCOUT_FIGHT, "SCOUT_HUNT": TankBrain.SCOUT_HUNT,
		"SCOUT_HUNT_FLOOR": TankBrain.SCOUT_HUNT_FLOOR, "COVER_FIRE_RELOAD_FLOOR": TankBrain.COVER_FIRE_RELOAD_FLOOR,
		"PINNED_COVER_FIRE": TankBrain.PINNED_COVER_FIRE, "SUPPRESS_UNDER_WINNABLE": TankBrain.SUPPRESS_UNDER_WINNABLE,
		"COMMIT_BONUS": TankBrain.COMMIT_BONUS, "CLEAR_LANE_EDGE": TankBrain.CLEAR_LANE_EDGE,
		"SCOUT_STANDOFF": TankBrain.SCOUT_STANDOFF, "SLOT_TOLERANCE": TankBrain.SLOT_TOLERANCE,
		"COOLDOWN_FACTOR": TankBrain.COOLDOWN_FACTOR, "REVISIT_S": TankBrain.REVISIT_S,
		"REVISIT_FACTOR": TankBrain.REVISIT_FACTOR, "ATTACK_MOVE_REACH_MARGIN": TankBrain.ATTACK_MOVE_REACH_MARGIN,
		"ATTACK_MOVE_FIGHT": TankBrain.ATTACK_MOVE_FIGHT, "ATTACK_MOVE_WEIGHT": TankBrain.ATTACK_MOVE_WEIGHT,
		"LOW_AMMO_FRACTION": OrderController.LOW_AMMO_FRACTION,
		"FULL_TANK_HEALTH": float(Units.stat("tank", "max_health")) + float(Units.stat("tank", "max_shield")),
		"COVER_FIRE_MEMORY_TICKS": TankBrain.COVER_FIRE_MEMORY_TICKS,
		"COVER_DENIED_MEMORY_TICKS": TankBrain.COVER_DENIED_MEMORY_TICKS,
		"CONTACT_FRESH_TICKS": TankBrain.CONTACT_FRESH_TICKS, "ORBIT_MEMORY_TICKS": TankBrain.ORBIT_MEMORY_TICKS,
		"LANE_BLOCKED_TICKS": TankBrain.LANE_BLOCKED_TICKS, "TICK_RATE": SimClock.TICK_RATE,
		"KIND_ARC": Weapons.Kind.ARC, "ORDER_OPTIONS": TankBrain.ORDER_OPTIONS, "FIGHT_OPTIONS": TankBrain.FIGHT_OPTIONS,
		"brain": TankBrain, "suppression_feed": SuppressionFeed, "element_feed": ElementFeed, "units": Units,
		"SUPPRESS_PENETRATION": TankBrain.SUPPRESS_PENETRATION, "SUPPRESSING_WEAPON": SuppressionFeed.SUPPRESSING_WEAPON,
	})
	return _configured
