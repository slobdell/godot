class_name GameTheme
extends RefCounted
## The active LOOK of the game: which scene fills each visual slot, team colors, and the UI
## palette. Gameplay code never references art directly; it places a VisualSlot and names a slot.
##
## Owned by the look-and-feel workstream (_agents/streams/look_and_feel.md). Slot contracts
## (orientation, size, origin, optional methods) are in _agents/streams/assets.md, so generated
## or imported models can drop in.

## Slot id → scene path. A theme is just a different dictionary with the same keys.
const DEFAULT_SLOTS := {
	"tank.hull": "res://game/theme/default/tank_hull.tscn",
	"tank.turret": "res://game/theme/default/tank_turret.tscn",
	"weapon.cannon": "res://game/theme/default/weapon_cannon.tscn",
	"weapon.flamethrower": "res://game/theme/default/weapon_flamethrower.tscn",
	"fx.shell": "res://game/theme/default/fx_shell.tscn",
	# Added by gameplay G7 (2026-09-14), placeholder art: see streams/assets.md slot contracts.
	"weapon.laser": "res://game/theme/default/weapon_laser.tscn",
	"fx.laser_beam": "res://game/theme/default/fx_laser_beam.tscn",
	"prop.crate": "res://game/theme/default/prop_crate.tscn",
	"prop.wall": "res://game/theme/default/prop_wall.tscn",
	"arena.environment": "res://game/theme/default/arena_environment.tscn",
	"arena.dressing": "res://game/theme/default/arena_dressing.tscn",
}

const DEFAULT_TEAM_COLORS := [Color(0.33, 0.4, 0.22), Color(0.55, 0.27, 0.2)]

const DEFAULT_UI := {
	"friendly": Color(0.45, 0.85, 0.4),
	"enemy": Color(0.95, 0.35, 0.3),
	"commander": Color(1.0, 0.85, 0.25),
	"ghost": Color(1, 1, 1, 0.55),
}

static var slots: Dictionary = DEFAULT_SLOTS
static var team_colors: Array = DEFAULT_TEAM_COLORS
static var ui: Dictionary = DEFAULT_UI


static func scene(slot: String) -> PackedScene:
	if not slots.has(slot):
		push_error("theme has no scene for visual slot '%s'" % slot)
		return null
	return load(slots[slot]) as PackedScene


static func team_color(team: int) -> Color:
	return team_colors[team % team_colors.size()]
