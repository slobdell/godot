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

## Per tier: real lights in the pool, the lowest LightPool priority that may take one, projectile ground splats,
## Environment glow, 3D render scale, MSAA, moon shadows, capacity of the transient effect buffer (explosions, flashes,
## glows, smoke), the long-lived scorch-mark pool, sparks/debris chunks per spray (a per-pixel loop), and heat haze over
## fires (a screen copy).
##
## Render X3 (round 5, contract M1 in fx_tricks.md): on the lead's UHD 620 a 30-a-side battle measured moon shadows
## +4.6 ms GPU, MSAA 2x +2.5 ms, and 16 pooled lights (most of them vehicle underglow) +1.7 ms. So no tier has dynamic
## shadows (vehicles sit on blob shadows) or MSAA, and at most 4 pooled lights go to explosions, shells, beams and
## muzzle flashes: never to tracers or vehicles.
const SETTINGS := {
	Tier.LOW: {"lights": 2, "light_floor": LightPool.PRIORITY_MUZZLE, "splats": true, "glow": true, "render_scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "effects": 128, "decals": 12, "sprays": 6, "haze": false},
	Tier.MEDIUM: {"lights": 4, "light_floor": LightPool.PRIORITY_MUZZLE, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "effects": 192, "decals": 24, "sprays": 10, "haze": false},
	Tier.HIGH: {"lights": 4, "light_floor": LightPool.PRIORITY_MUZZLE, "splats": true, "glow": true, "render_scale": 1.0, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "effects": 320, "decals": 48, "sprays": 14, "haze": true},
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


## Render X5 (round 5, M1): the 3D resolution a window of `window_height` pixels renders at. Past ~918 lines the GPU
## cost grows with pixels the RTS camera doesn't show more of (1080p at 0.85 saved 4.8 ms on the lead's UHD 620); the UI
## keeps the full resolution. Never below 0.7, and never above the tier's own scale.
const MAX_3D_LINES := 918.0
const MIN_AUTO_SCALE := 0.7


static func render_scale_for(tier_scale: float, window_height: int) -> float:
	if window_height <= 0:
		return tier_scale
	return minf(tier_scale, clampf(MAX_3D_LINES / float(window_height), MIN_AUTO_SCALE, 1.0))


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
