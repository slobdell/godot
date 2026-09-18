class_name GameLauncher
extends RefCounted
## Control (round 5): start the game scene in this process with a set of flags, for the menus that choose a mode (the
## title) or a match (the faction and arena menu). `Main` takes its flags from `Main.next_flags`, but the arena in
## main.tscn builds itself before `Main` runs and reads only the command line, so the launcher instances the scene, sets
## the arena's layout on it, then switches to it.
##
## Arena owns the random roll (orchestrator's ruling): `--arena=random` goes through `Arena.resolve_name` with the
## match's `--seed`, and a launch without a seed gets one (the skirmish's clock formula), so the seed shown in the HUD
## replays the arena as well as the armies.

const MAIN_SCENE := "res://game/main.tscn"
const RANDOM := "random"


## Round 6 X4: staged, behind a LoadingScreen that stays up (on the root) until the match has drawn its first frame.
## Each stage yields frames first, so the screen that names it is actually on the monitor while the engine is busy.
static func start(tree: SceneTree, flags: LaunchFlags) -> void:
	var resolved := resolve_arena(with_seed(flags))
	var screen := LoadingScreen.show_for(tree, resolved)
	screen.enter("scene")
	await _drawn(tree)
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	var progress := [0.0]
	while ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		screen.report(float(progress[0]))
		await tree.process_frame
	var packed := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
	var main := instantiate(resolved, packed)
	screen.enter("arena")
	await _drawn(tree)
	# The arena builds (venue, navmesh) when the scene enters the tree, then Main starts the mode (armies, controls):
	# both inside the scene switch, so their split comes from signals rather than from frames.
	var arena := main.get_node_or_null("Arena")
	if arena != null:
		arena.ready.connect(screen.enter.bind("armies"), CONNECT_ONE_SHOT)
	main.ready.connect(screen.enter.bind("first_frame"), CONNECT_ONE_SHOT)
	Main.next_flags = resolved
	tree.paused = false
	tree.change_scene_to_node(main)
	await main.ready
	await _drawn(tree)
	screen.done()


## Two process frames: the first draws what the last one queued, the second is on screen when the next stall begins.
static func _drawn(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame


## The game scene, not yet in the tree, with its arena set to the flags' layout.
static func instantiate(flags: LaunchFlags, packed: PackedScene = null) -> Node:
	var resolved := resolve_arena(flags)
	var main := (packed if packed != null else load(MAIN_SCENE) as PackedScene).instantiate()
	var arena := main.get_node_or_null("Arena")
	if arena != null and resolved.has("arena"):
		arena.set("layout_name", resolved.text("arena"))
	return main


## The flags with a --seed, adding the skirmish's clock seed when there is none (so the arena roll and the armies share it).
static func with_seed(flags: LaunchFlags) -> LaunchFlags:
	if flags.has("seed"):
		return flags
	var next := LaunchFlags.new()
	next.values = flags.values.duplicate()
	next.values["seed"] = str(int(Time.get_unix_time_from_system()) % 100000)
	return next


## The arenas a player can pick: Arena's proven rotation, [{"name", "title", "note"}] in rotation order.
static func arena_choices() -> Array:
	var result: Array = []
	for layout_name: String in Arena.ROTATION:
		var file := FileAccess.open("%s/%s.json" % [Arena.LAYOUT_DIR, layout_name], FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if typeof(data) != TYPE_DICTIONARY:
			continue
		result.append({"name": layout_name, "title": String(data.get("title", layout_name.capitalize())),
				"note": String(data.get("note", ""))})
	return result


## The flags with `arena=random` replaced by the arena Arena's own roll picks for `--seed`.
static func resolve_arena(flags: LaunchFlags) -> LaunchFlags:
	if flags.text("arena") != RANDOM:
		return flags
	var next := LaunchFlags.new()
	next.values = flags.values.duplicate()
	next.values["arena"] = Arena.resolve_name(RANDOM, flags.integer("seed", -1))
	return next
