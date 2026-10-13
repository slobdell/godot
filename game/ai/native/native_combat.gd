class_name NativeCombat
extends RefCounted
## Round 28 (native N6.2): combat resolution's rules natively (native/src/combat_native.cpp): Match._land_hit_result's
## terms before a hit lands (the armour facing, the weak spot, penetration over Units.armor, the shield factor) and
## Tank.take_hit's arithmetic. Seams at those two places; the GDScript stays the reference. BrainSwitches.native_combat.
## The engine-deck probe (Armor.deck_probe) keeps the GDScript (it prints from the middle of the terms).

static var _configured := false
static var _ok := false


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_combat and not Armor.deck_probe and configure()


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.combat_configure({"ARC_DEG": Armor.ARC_DEG, "WEAK_SPOT_ARC_DEG": Armor.WEAK_SPOT_ARC_DEG,
		"WEAK_SPOT_ARMOR_FRACTION": Armor.WEAK_SPOT_ARMOR_FRACTION, "PENETRATION_FLOOR": Armor.PENETRATION_FLOOR,
		"PENETRATION_CAP": Armor.PENETRATION_CAP, "SHIELD_FRONT": Armor.SHIELD_FACING["front"],
		"SHIELD_SIDE": Armor.SHIELD_FACING["side"], "SHIELD_REAR": Armor.SHIELD_FACING["rear"],
		"KIND_ARC": Weapons.Kind.ARC, "KIND_CONE": Weapons.Kind.CONE, "units": Units, "armor": Armor})
	return _ok


## [face, weak, through armor, shield factor]
static func hit_terms(victim: Tank, weapon: Dictionary, direction: Vector3) -> Array:
	return NativeBridge.impl.combat_hit_terms(victim, weapon, direction)


static func take_hit(tank: Tank, raw: float, shield_multiplier: float, armor_multiplier: float) -> Dictionary:
	return NativeBridge.impl.combat_take_hit(tank, raw, shield_multiplier, armor_multiplier)
