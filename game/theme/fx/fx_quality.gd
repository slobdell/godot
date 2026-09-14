class_name FxQuality
extends RefCounted
## One setting that scales every effect budget: light-pool size, splats, glow, render scale, MSAA,
## moon shadows. Budgets come from the FX lab (_agents/streams/references/fx_tricks.md → Results).
##
## Which tier: `--fx-quality=low|medium|high` (URL `?fx-quality=low`) > the player's saved choice
## (the HUD's FX button, `user://fx_quality.cfg`) > the platform default (web/mobile LOW, desktop
## HIGH). On web/mobile, without an explicit choice, FxAutoQuality may step down when frames drop.

enum Tier { LOW, MEDIUM, HIGH }

const NAMES := {Tier.LOW: "low", Tier.MEDIUM: "medium", Tier.HIGH: "high"}
const SAVE_PATH := "user://fx_quality.cfg"

## Per tier: real lights in the pool, projectile ground splats, Environment glow, 3D render scale,
## MSAA, moon shadows, and capacity of the transient effect buffer (explosions, flashes, glows).
const SETTINGS := {
	Tier.LOW: {"lights": 4, "splats": true, "glow": true, "render_scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "effects": 48},
	Tier.MEDIUM: {"lights": 8, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "effects": 96},
	Tier.HIGH: {"lights": 16, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_2X, "shadows": true, "effects": 128},
}

static var _tier := -1
## "flag", "saved", "platform", "auto", or "player": where the current tier came from.
static var source := ""


## The active tier (resolved on first use).
static func tier() -> int:
	if _tier < 0:
		_resolve()
	return _tier


static func set_tier(new_tier: int, from := "code") -> void:
	_tier = clampi(new_tier, Tier.LOW, Tier.HIGH)
	source = from


## Switch tiers at runtime and push the budgets into the live effect systems. `persist` saves it
## as the player's choice for this device.
static func apply(new_tier: int, from := "player", persist := false) -> void:
	set_tier(new_tier, from)
	if persist:
		var config := ConfigFile.new()
		config.set_value("fx", "tier", NAMES[_tier])
		config.save(SAVE_PATH)
	var fx := FxWorld.existing()
	if fx != null:
		fx.apply_quality()
	print("FX_QUALITY %s (%s)" % [NAMES[_tier], from])


## True when nobody chose a tier explicitly (so automatic adjustment may change it).
static func is_automatic() -> bool:
	tier()
	return source == "platform" or source == "auto"


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


static func _resolve() -> void:
	var requested := parse(LaunchFlags.from_environment().text("fx-quality"))
	if requested >= 0:
		set_tier(requested, "flag")
		return
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var saved := parse(str(config.get_value("fx", "tier", "")))
		if saved >= 0:
			set_tier(saved, "saved")
			return
	set_tier(platform_default(), "platform")
