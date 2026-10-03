extends SceneTree
## S1 (round 16): what the skirmish's VisibilityField costs per viewer, split into its three parts (rays, the cell
## mark, the image rebuild), the shipping field against the pre-S1 reference, in ONE process on one map. Light enough
## to run locally (state the load); builder0 for the record:
##
##   .tools/.../godot --headless --path . --script res://tests/scale/visfield_bench.gd -- [--arena=sumps] [--viewers=24]
##
## Viewers stand at Green's spawn slots (his match's first seconds) and then spread over Green's half (mid-match).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const REFERENCE := preload("res://tests/scale/visfield_reference.gd")
const REPEATS := 40


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var arena: Node = ARENA.instantiate()
	arena.layout_name = flags.text("arena", "sumps")
	root.add_child(arena)
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	var roster: Array = Array(Units.roster("law"))
	var viewers: Array[Tank] = []
	for i in flags.integer("viewers", 24):
		viewers.append(game_match.spawn_tank("V%02d" % i, 0, Match.Team.GREEN, roster[i % roster.size()]))
	for i in 3:
		await physics_frame
	var shipping := VisibilityField.new()
	shipping.game_match = game_match
	game_match.add_child(shipping)
	var reference: Node = REFERENCE.new()
	reference.game_match = game_match
	game_match.add_child(reference)
	SimProfile.enabled = true
	for pose: String in ["spawn", "spread"]:
		if pose == "spread":
			var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
			for i in viewers.size():
				viewers[i].global_position = Vector3(-half * 0.7 + (i % 6) * half * 0.28, 0.0, 10.0 + (i / 6) * 18.0)
			for i in 3:
				await physics_frame
		for arm in 4:
			# 0 the reference; 1 shipping with every look computed (viewers that moved); 2 shipping, standing still
			# (memo); 3 moving with the marks on a worker thread (look_from's main-thread share; the join is in finish)
			var field: Node = reference if arm == 0 else shipping
			var label: String = ["reference", "moving", "still", "threaded"][arm]
			var rays := 0
			var total := 0
			for repeat in REPEATS:
				if arm == 1 or arm == 3:
					shipping._memo.clear()
				for viewer in viewers:
					var started := Time.get_ticks_usec()
					if arm == 3:
						field.look_from(viewer, false)
					else:
						field.look_from(viewer)
					total += Time.get_ticks_usec() - started
				var started := Time.get_ticks_usec()
				field._finish_refresh(viewers)
				rays += Time.get_ticks_usec() - started
			var looks := float(REPEATS * viewers.size())
			if arm == 1:
				print("VISFIELD_BENCH sections ", JSON.stringify(SimProfile.report()["sections"]))
			SimProfile.reset()
			print("VISFIELD_BENCH %s %-9s look_from %.3f ms/viewer, finish %.3f ms/refresh (%d viewers, %d repeats, %s)"
					% [Arena.active.get("name", "?"), label, total / looks / 1000.0, rays / float(REPEATS) / 1000.0,
						viewers.size(), REPEATS, pose])
	print("VISFIELD_BENCH_DONE")
	quit()
