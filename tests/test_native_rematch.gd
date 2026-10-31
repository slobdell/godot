extends TestCase
## Round 48 (native N3): THE SAME-PROCESS REMATCH. One lab (the CPU sliver case of test_manoeuvre_noprogress: four syndicate crews on
## Crossing under an ambush task) run REMATCH_RUNS times in ONE process, each from a freed world and an empty navigation map, and each
## run's per-tick hull poses compared with the first run's: a process's earlier matches must not move a later one (rematches, netplay,
## the sliver test R47.47). Prints REMATCH_ROW run k first_part_tick T worst_m M crew C (T = -1: identical for every tick).
## Round 48 (N3, R48.5): each run starts with FreshWorld.apply (the game's Main._enter_tree path), as every match now does; the
## control arm REMATCH_RESET=none (the old shared world) parts at tick 2 (0.32 m, builder3 f0900328a). Other arms: world (a bare
## swap: an engine error per swap), own (own_world_3d toggled: an error per drop), held (= FreshWorld.apply).

const TICKS := 300
const POSE := {"Rust_Hunters_1": [Vector2(-26.7, -7.3), -76.0, "syn_ifv"], "Rust_Hunters_2": [Vector2(-31.5, -6.9), 163.0, "syn_ifv"],
		"Rust_Hunters_3": [Vector2(-32.5, -9.7), -59.0, "syn_ifv"], "Rust_Hunters_4": [Vector2(-28.8, -9.6), -180.0, "syn_scout"]}


func _run(names: Array) -> Array:
	var reset := OS.get_environment("REMATCH_RESET")
	if reset == "":
		reset = "held"
	if reset.contains("none"):
		pass
	elif reset.contains("world"):
		# A fresh World3D: a new physics space (Jolt's bodies, broadphase, contact cache) and a new navigation map.
		tree.root.world_3d = World3D.new()
	elif reset.contains("held"):
		# The swap with the old World3D held until the viewport has let go of it (else the engine frees it first and reports
		# its scenario as null), and the old world's environments carried over.
		FreshWorld.apply(tree.root, false)
	elif reset.contains("own"):
		# The same through Viewport.own_world_3d: toggled off and on, the viewport makes itself a new World3D.
		tree.root.own_world_3d = false
		tree.root.own_world_3d = true
	var lab := TacticsLab.create(self, 101, "crossing")
	for n: String in names:
		var at: Vector2 = POSE[n][0]
		lab.unit(Match.Team.RUST, n, Vector3(at.x, 0.0, at.y), deg_to_rad(float(POSE[n][1])), String(POSE[n][2]))
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("syndicate").get("table")
	var element := lab.elements.form(names, "Hunters", table)
	await lab.start()
	var start := "start_tick %d waited %d" % [lab.game_match.tick, lab.waited_frames]
	element.assign({"verb": "ambush", "from": [-13.4375, -9.5], "to": [-50.467, 15.627]})
	var poses: Array = []
	for i in TICKS:
		await lab.step()
		var row := PackedFloat64Array()
		for n: String in names:
			var tank := lab.tank_of(n)
			row.append_array([tank.global_position.x, tank.global_position.y, tank.global_position.z, tank.global_rotation.y])
		poses.append(row)
	free_owned()
	await drain_navigation()
	return [poses, start]


func test_a_rematch_in_one_process_is_the_first_match() -> void:
	var names := POSE.keys()
	names.sort()
	var runs := maxi(2, int(OS.get_environment("REMATCH_RUNS")))
	var first: Array = []
	var parted := 0
	for k in runs:
		var got: Array = await _run(names)
		var poses: Array = got[0]
		if k == 0:
			first = poses
			print("REMATCH_ROW run 0 %s (the reference)" % got[1])
			continue
		var part := -1
		var worst := 0.0
		var crew := ""
		for i in TICKS:
			var a: PackedFloat64Array = first[i]
			var b: PackedFloat64Array = poses[i]
			if a == b:
				continue
			if part < 0:
				part = i
			for c in names.size():
				var d := Vector2(a[c * 4] - b[c * 4], a[c * 4 + 2] - b[c * 4 + 2]).length()
				if d > worst:
					worst = d
					crew = names[c]
		parted += 1 if part >= 0 else 0
		print("REMATCH_ROW run %d %s first_part_tick %d worst_m %.4f crew %s" % [k, got[1], part, worst, crew])
	assert_eq(parted, 0, "every rematch in one process is the first match, tick for tick (%d of %d parted)" % [parted, runs - 1])
