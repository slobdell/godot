extends SceneTree
## Prints the layouts the game deals, read from the game itself (ship, round 18, S1):
##
##     DEALT_LAYOUTS {"default": "foundry", "rotation": [...], "candidates": [...]}
##
## `make sim-baseline` keeps one state-hash line per dealt map, and the list of maps comes from HERE, not from a list
## in a Makefile: a map the lead deals tomorrow joins `Arena.ROTATION`, and the baseline then fails until that map has
## a line (a missing line is a failure, never a skip). Round 17's lesson behind it: the baseline ran on `foundry`
## alone, a map nobody is dealt, so a change to every container on every dealt map passed it unmoved.
##
## The constants are read off the script, not through the `Arena` class name, so this works before the global class
## cache is warm. `CANDIDATES` is the maps stream's class of playable-by-name, never-dealt layouts (C18.2); it is
## reported so the baseline can say, visibly, that a candidate carries no line. A missing constant is an empty list.


func _initialize() -> void:
	var arena: Script = load("res://game/arena/arena.gd")
	if arena == null:
		printerr("DEALT_LAYOUTS_ERROR could not load res://game/arena/arena.gd")
		quit(1)
		return
	var constants := arena.get_script_constant_map()
	var out := {
		"default": str(constants.get("DEFAULT_LAYOUT", "")),
		"rotation": _names(constants.get("ROTATION", [])),
		"candidates": _names(constants.get("CANDIDATES", [])),
	}
	print("DEALT_LAYOUTS " + JSON.stringify(out))
	quit(0)


func _names(value: Variant) -> Array:
	var names: Array = []
	if value is Array or value is PackedStringArray:
		for name: Variant in value:
			names.append(str(name))
	elif value is Dictionary:
		for name: Variant in value.keys():
			names.append(str(name))
	return names
