class_name GameTheme
extends RefCounted
## The active LOOK of the game: which scene fills each visual slot, team colors, and the UI
## palette. Gameplay code never references art directly; it places a VisualSlot and names a slot.
##
## Owned by the look-and-feel workstream (_agents/streams/archive/round1/look_and_feel.md). Slot contracts
## (orientation, size, origin, optional methods) are in _agents/slot_contracts.md, so generated
## or imported models can drop in.
##
## Themes: `default` (the original placeholder boxes) and `cyberpunk` (the night arena).
## Pick one with `--theme=NAME` (browser: `?theme=NAME`); DEFAULT_THEME applies otherwise.

## Slot id → scene path. A theme is just a different dictionary with the same keys.
const DEFAULT_SLOTS := {
	"tank.hull": "res://game/theme/default/tank_hull.tscn",
	"tank.turret": "res://game/theme/default/tank_turret.tscn",
	"weapon.cannon": "res://game/theme/default/weapon_cannon.tscn",
	"weapon.flamethrower": "res://game/theme/default/weapon_flamethrower.tscn",
	"fx.shell": "res://game/theme/default/fx_shell.tscn",
	# Added by gameplay G7 (2026-09-14), placeholder art: see _agents/slot_contracts.md.
	"weapon.laser": "res://game/theme/default/weapon_laser.tscn",
	"fx.laser_beam": "res://game/theme/default/fx_laser_beam.tscn",
	# Added by gameplay (directive set 2, 2026-09-15), placeholders: the scout's machine gun.
	"weapon.machine_gun": "res://game/theme/default/weapon_cannon.tscn",
	"fx.tracer": "res://game/theme/default/fx_tracer.tscn",
	"weapon.mortar": "res://game/theme/default/weapon_cannon.tscn",
	# Added by gameplay G1 (2026-09-14), placeholder: the 3D fog-of-war sheet (setup(data) contract in assets.md).
	"fx.fog_of_war": "res://game/theme/default/fx_fog_of_war.tscn",
	"prop.crate": "res://game/theme/default/prop_crate.tscn",
	"prop.wall": "res://game/theme/default/prop_wall.tscn",
	"arena.environment": "res://game/theme/default/arena_environment.tscn",
	"arena.dressing": "res://game/theme/default/arena_dressing.tscn",
	# Assets X1 (round 3): stackable shipping containers, one MultiMesh per kind (arena_kit/containers). Real models in
	# every theme: they're plain steel, so the default look can use them too.
	"prop.container_20": "res://game/theme/arena_kit/prop_container_20.tscn",
	"prop.container_40": "res://game/theme/arena_kit/prop_container_40.tscn",
	# Assets X2: a giant ad screen showing its broadcast channel (arena_kit/ads).
	"prop.ad_screen": "res://game/theme/arena_kit/prop_ad_screen.tscn",
}

const DEFAULT_TEAM_COLORS := [Color(0.33, 0.4, 0.22), Color(0.55, 0.27, 0.2)]
## Emissive team colors (tracers, underglow, trims). The default theme keeps warm, low-key ones.
const DEFAULT_TEAM_GLOWS := [Color(0.55, 1.0, 0.45), Color(1.0, 0.55, 0.3)]

const DEFAULT_UI := {
	"friendly": Color(0.45, 0.85, 0.4),
	"enemy": Color(0.95, 0.35, 0.3),
	"commander": Color(1.0, 0.85, 0.25),
	"ghost": Color(1, 1, 1, 0.55),
	# Requested by the garage stream (read with fallbacks there).
	"garage_bg": Color(0.12, 0.13, 0.12),
	"garage_panel": Color(0.2, 0.22, 0.2, 0.9),
	"garage_text_dim": Color(0.75, 0.75, 0.72),
}

## The night arena (look_and_feel.md): neon over rust, cyan vs magenta teams.
const CYBERPUNK_SLOTS := {
	# The assets stream's Meshy "prison dozer" (art_direction.md north star), wearing the theme's team
	# accents, underglow, and shield (dozer_part.gd). The procedural tank_hull/tank_turret/weapon_cannon
	# scenes remain for the vehicle gallery and as fallback art.
	"tank.hull": "res://game/theme/cyberpunk/tank_hull_dozer.tscn",
	"tank.turret": "res://game/theme/cyberpunk/tank_turret_dozer.tscn",
	"weapon.cannon": "res://game/theme/cyberpunk/weapon_cannon_dozer.tscn",
	"weapon.flamethrower": "res://game/theme/cyberpunk/weapon_flamethrower.tscn",
	"fx.shell": "res://game/theme/cyberpunk/fx_shell.tscn",
	# Gameplay G7's slots (contracts in _agents/slot_contracts.md); default placeholders live on stream/gameplay.
	"weapon.laser": "res://game/theme/cyberpunk/weapon_laser.tscn",
	"fx.laser_beam": "res://game/theme/cyberpunk/fx_laser_beam.tscn",
	# Gameplay G1's 3D fog of war (setup(data) contract); default placeholder on stream/gameplay.
	"fx.fog_of_war": "res://game/theme/cyberpunk/fx_fog_of_war.tscn",
	# Art X6: the lead's approved Meshy props (theme arena_kit, tools/assets/build_arena_kit.sh) with a neon footprint frame
	# for the tactical overview (prop_generated.gd). The procedural neon
	# crate and wall (cyberpunk/prop_*.tscn) remain as fallback art.
	"prop.crate": "res://game/theme/cyberpunk/prop_crate_generated.tscn",
	"prop.wall": "res://game/theme/cyberpunk/prop_wall_generated.tscn",
	"arena.environment": "res://game/theme/cyberpunk/arena_environment.tscn",
	"arena.dressing": "res://game/theme/cyberpunk/arena_dressing.tscn",
	# Round 2 unit roster (art X4, the lead's approved Meshy concepts; game/theme/roster, tools/assets/build_roster.sh).
	# Tank fills unit.<id>.* when the theme has them (C6). A fixed-mount scout has no turret and the artillery's rack
	# carries its tubes, so those slots are deliberately empty (no_part.tscn) rather than falling back to the dozer's.
	"unit.scout.hull": "res://game/theme/cyberpunk/units/unit_scout_hull.tscn",
	"unit.scout.turret": "res://game/theme/cyberpunk/units/no_part.tscn",
	"unit.scout.weapon": "res://game/theme/cyberpunk/units/unit_scout_weapon.tscn",
	"unit.ifv.hull": "res://game/theme/cyberpunk/units/unit_ifv_hull.tscn",
	"unit.ifv.turret": "res://game/theme/cyberpunk/units/unit_ifv_turret.tscn",
	"unit.ifv.weapon": "res://game/theme/cyberpunk/units/unit_ifv_weapon.tscn",
	"unit.artillery.hull": "res://game/theme/cyberpunk/units/unit_artillery_hull.tscn",
	"unit.artillery.turret": "res://game/theme/cyberpunk/units/unit_artillery_turret.tscn",
	"unit.artillery.weapon": "res://game/theme/cyberpunk/units/no_part.tscn",
	"unit.lancer.hull": "res://game/theme/cyberpunk/units/unit_lancer_hull.tscn",
	"unit.lancer.turret": "res://game/theme/cyberpunk/units/unit_lancer_turret.tscn",
	"unit.lancer.weapon": "res://game/theme/cyberpunk/units/unit_lancer_weapon.tscn",
}

## Vehicle parts receive the team's neon and derive their dark paint from it (cyber_vehicle.gd).
const CYBERPUNK_TEAM_COLORS := [Color("#00F3FF"), Color("#FF0099")]
const CYBERPUNK_TEAM_GLOWS := [Color("#00F3FF"), Color("#FF0099")]

const CYBERPUNK_UI := {
	"friendly": Color("#00F3FF"),
	"enemy": Color("#FF0099"),
	"commander": Color("#FFD500"),
	"ghost": Color(0.88, 0.88, 0.88, 0.55),
	"garage_bg": Color("#050510"),
	"garage_panel": Color(0x12 / 255.0, 0x12 / 255.0, 0x25 / 255.0, 0.86),
	"garage_text_dim": Color(0.88, 0.88, 0.88, 0.6),
	# Gameplay's radar (G2) styling: its field tint and arena outline (read with fallbacks, requested);
	# "radar_frame" (a StyleBox) is added in use() because constants can't hold objects.
	"radar_field": Color(0.0, 0.75, 0.9, 0.45),
	"radar_outline": Color("#D900FF"),
}

const THEMES := {
	"default": {"slots": DEFAULT_SLOTS, "team_colors": DEFAULT_TEAM_COLORS, "team_glows": DEFAULT_TEAM_GLOWS, "ui": DEFAULT_UI},
	"cyberpunk": {"slots": CYBERPUNK_SLOTS, "team_colors": CYBERPUNK_TEAM_COLORS, "team_glows": CYBERPUNK_TEAM_GLOWS, "ui": CYBERPUNK_UI},
}

const DEFAULT_THEME := "cyberpunk"

static var theme_name := DEFAULT_THEME
static var slots: Dictionary = DEFAULT_SLOTS
static var team_colors: Array = DEFAULT_TEAM_COLORS
static var team_glows: Array = DEFAULT_TEAM_GLOWS
static var ui: Dictionary = DEFAULT_UI


static func _static_init() -> void:
	var requested := LaunchFlags.from_environment().text("theme", DEFAULT_THEME)
	# Generated candidate themes (game/theme/<name>/generated, the assets stream) are applied by the asset
	# tools themselves (AssetIO.theme_slots); `--theme=<one of those>` isn't a mistake here.
	if not THEMES.has(requested) and DirAccess.dir_exists_absolute("res://game/theme/%s/generated" % requested):
		requested = DEFAULT_THEME
	if not use(requested):
		use(DEFAULT_THEME)


## Switch the active theme. Only affects visuals created afterwards. False if unknown.
static func use(name: String) -> bool:
	if not THEMES.has(name):
		push_warning("unknown theme '%s' (have: %s)" % [name, ", ".join(THEMES.keys())])
		return false
	var theme: Dictionary = THEMES[name]
	theme_name = name
	# Any slot a theme doesn't define falls back to the default scene, so a slot another stream adds
	# to DEFAULT_SLOTS works in every theme the moment it lands.
	slots = DEFAULT_SLOTS.merged(theme["slots"], true)
	team_colors = theme["team_colors"]
	team_glows = theme["team_glows"]
	ui = (theme["ui"] as Dictionary).duplicate()
	if name == "cyberpunk":
		ui["radar_frame"] = _cyber_panel_style()
	return true


## A chamfered dark panel with a neon border (the HUD language) for StyleBox styling hooks.
static func _cyber_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0x05 / 255.0, 0x05 / 255.0, 0x10 / 255.0, 0.86)
	box.border_color = Color("#00F3FF")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.corner_detail = 1
	box.anti_aliasing = true
	box.shadow_color = Color(0.0, 0.9, 1.0, 0.25)
	box.shadow_size = 6
	return box


static func scene(slot: String) -> PackedScene:
	if not slots.has(slot):
		push_error("theme has no scene for visual slot '%s'" % slot)
		return null
	return load(slots[slot]) as PackedScene


static func team_color(team: int) -> Color:
	return team_colors[team % team_colors.size()]


## The team's neon: tracers, underglow, emissive trims.
static func team_glow(team: int) -> Color:
	return team_glows[team % team_glows.size()]
