extends Node
## Runs the real game with a generated theme's slots layered over the active GameTheme, without
## touching gameplay or theme code. Every normal launch flag still works (they're read from the
## command line by game/main.gd), e.g.
##   godot --path . res://assets/pipeline/theme_preview.tscn -- --theme=kitbash --skirmish --screenshot=/abs.png
## `make assets-preview THEME=kitbash` wraps it. Look & feel decides what becomes a real theme.

const MAIN_SCENE := "res://game/main.tscn"


func _enter_tree() -> void:
	var theme := LaunchFlags.from_environment().text("theme", "kitbash")
	var overrides := AssetIO.theme_slots(theme)
	if overrides.is_empty():
		push_error("generated theme '%s' has no slots (game/theme/%s/generated/manifest.json)" % [theme, theme])
	var merged := GameTheme.slots.duplicate()
	merged.merge(overrides, true)
	GameTheme.slots = merged
	print("ASSET_PREVIEW theme=%s slots=%s" % [theme, overrides.keys()])


func _ready() -> void:
	add_child((load(MAIN_SCENE) as PackedScene).instantiate())
