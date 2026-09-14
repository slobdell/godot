class_name FxQuality
extends RefCounted
## One setting that scales every effect budget: light-pool size, splats, glow, render scale.
## Phones and browsers start LOW; desktops HIGH. Override with `--fx-quality=low|medium|high`
## (URL: `?fx-quality=low`). The budgets come from the FX lab (_agents/streams/references/fx_tricks.md).

enum Tier { LOW, MEDIUM, HIGH }

const NAMES := {Tier.LOW: "low", Tier.MEDIUM: "medium", Tier.HIGH: "high"}

## Per tier: real lights in the pool, projectile ground splats, Environment glow, 3D render
## scale, MSAA, and capacity of the transient effect buffer (explosions, flashes, glows).
const SETTINGS := {
	Tier.LOW: {"lights": 4, "splats": true, "glow": true, "render_scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "effects": 48},
	Tier.MEDIUM: {"lights": 8, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "effects": 96},
	Tier.HIGH: {"lights": 16, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_2X, "effects": 128},
}

static var _tier := -1


## The active tier (resolved from the flag / platform on first use).
static func tier() -> int:
	if _tier < 0:
		_tier = _initial_tier()
	return _tier


static func set_tier(new_tier: int) -> void:
	_tier = clampi(new_tier, Tier.LOW, Tier.HIGH)


static func current() -> Dictionary:
	return SETTINGS[tier()]


static func value(key: String) -> Variant:
	return SETTINGS[tier()][key]


static func tier_name() -> String:
	return NAMES[tier()]


static func parse(text: String) -> int:
	for key in NAMES:
		if NAMES[key] == text.to_lower():
			return key
	return -1


## The platform default: web and mobile start low (the lead's phone is the target), desktop high.
static func platform_default() -> int:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return Tier.LOW
	return Tier.HIGH


static func _initial_tier() -> int:
	var requested := parse(LaunchFlags.from_environment().text("fx-quality"))
	return requested if requested >= 0 else platform_default()
