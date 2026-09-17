class_name GameLauncher
extends RefCounted
## Control (round 5): start the game scene in this process with a set of flags, for the menus that choose a mode (the
## title) or a match (the faction and arena menu). `Main` takes its flags from `Main.next_flags`, but the arena in
## main.tscn builds itself before `Main` runs and only reads the command line, so the launcher instances the scene,
## sets the arena's layout on it, then switches to it. `--arena=random` is resolved here, seeded by `--seed`.

const MAIN_SCENE := "res://game/main.tscn"
const RANDOM := "random"


static func start(tree: SceneTree, flags: LaunchFlags) -> void:
	var resolved := resolve_arena(flags)
	var main := instantiate(resolved)
	Main.next_flags = resolved
	tree.paused = false
	tree.change_scene_to_node(main)


## The game scene, not yet in the tree, with its arena set to the flags' layout.
static func instantiate(flags: LaunchFlags) -> Node:
	var resolved := resolve_arena(flags)
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	var arena := main.get_node_or_null("Arena")
	if arena != null and resolved.has("arena"):
		arena.set("layout_name", resolved.text("arena"))
	return main


## The arenas worth offering a player: layouts with a display title, [{"name", "title", "note"}] sorted by name.
static func arena_choices() -> Array:
	var result: Array = []
	for layout_name in Arena.layout_names():
		var file := FileAccess.open("%s/%s.json" % [Arena.LAYOUT_DIR, layout_name], FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) != TYPE_DICTIONARY or String(data.get("title", "")) == "":
			continue
		result.append({"name": layout_name, "title": String(data["title"]), "note": String(data.get("note", ""))})
	return result


## The flags with `arena=random` replaced by a real arena, chosen by `--seed` when there is one.
static func resolve_arena(flags: LaunchFlags) -> LaunchFlags:
	if flags.text("arena") != RANDOM:
		return flags
	var choices := arena_choices()
	var next := LaunchFlags.new()
	next.values = flags.values.duplicate()
	if choices.is_empty():
		next.values.erase("arena")
		return next
	var seed_value := flags.integer("seed", -1)
	var index := posmod(seed_value, choices.size()) if seed_value >= 0 else randi() % choices.size()
	next.values["arena"] = choices[index]["name"]
	return next
