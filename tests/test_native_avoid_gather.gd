extends TestCase
## Round 24 (native): `Avoidance.refresh`'s table gathered by the C++ (TankNative.avoidance_gather) is the GDScript
## build's, column for column: the same hulls in the same order, the same float32 bits, the same still flags (a mover
## arrived or driving, a hull with no mover), and the grid and index the GDScript readers use (filled lazily after a
## native gather). Asked of the live refresh both ways on the same tick, over a driving crowd of mixed hulls.

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv"]
const COLUMNS: Array[String] = ["_names", "_xs", "_zs", "_vxs", "_vzs", "_radii", "_half_w", "_half_l", "_fxs", "_fzs",
		"_still", "_grid", "_index"]


func _columns() -> Dictionary:
	var out := {}
	for name in COLUMNS:
		var value: Variant = _static(name)
		out[name] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return out


func _static(name: String) -> Variant:
	match name:
		"_names": return Avoidance._names
		"_xs": return Avoidance._xs
		"_zs": return Avoidance._zs
		"_vxs": return Avoidance._vxs
		"_vzs": return Avoidance._vzs
		"_radii": return Avoidance._radii
		"_half_w": return Avoidance._half_w
		"_half_l": return Avoidance._half_l
		"_fxs": return Avoidance._fxs
		"_fzs": return Avoidance._fzs
		"_still": return Avoidance._still
		"_grid": return Avoidance._grid
		"_index": return Avoidance._index
	return null


func test_the_gathered_table_is_the_gdscript_build() -> void:
	if not NativeBridge.available:
		print("native: absent, the gathered table is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2406
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Gather%d" % i, 0, Match.Team.GREEN if i % 3 else Match.Team.RUST, UNITS[i])
		tank.global_position = Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))
		if i < UNITS.size() - 2:  # the last two have no controller (no mover: still)
			var orders := OrderController.new()
			orders.tank = tank
			orders.tanks_root = game_match.tanks
			add_to_tree(orders)
			if i % 2 == 0:  # some drive, some stay arrived
				orders.set_orders({"type": "move_to", "x": rng.randf_range(-90.0, 90.0), "z": rng.randf_range(-90.0, 90.0)}, null)
	var saved := BrainSwitches.native
	var compared := 0
	var mismatches: Array[String] = []
	var stills := 0
	for frame in 40:
		await wait_physics_frames(1)
		if frame % 4 != 3:
			continue
		BrainSwitches.native = false
		Avoidance._table_frame = -1
		Avoidance.refresh(game_match.tanks)
		var gdscript := _columns()
		BrainSwitches.native = true
		Avoidance._table_frame = -1
		Avoidance.refresh(game_match.tanks)
		Avoidance._ensure_gd()
		var gathered := _columns()
		BrainSwitches.native = saved
		compared += 1
		for still: bool in gdscript["_still"]:
			stills += 1 if still else 0
		for name in COLUMNS:
			if typeof(gdscript[name]) != typeof(gathered[name]) or gdscript[name] != gathered[name]:
				mismatches.append("frame %d %s: gdscript %s, native %s" % [frame, name, var_to_str(gdscript[name]).left(200),
						var_to_str(gathered[name]).left(200)])
	Avoidance._table_frame = -1
	print("native avoid gather: %d ticks compared, %d still rows, %d mismatches" % [compared, stills, mismatches.size()])
	assert_true(mismatches.is_empty(), "the gathered table is the GDScript build: %s" % "; ".join(mismatches.slice(0, 3)))
	assert_true(compared >= 8 and stills >= 8, "ticks compared with still rows in them (%d, %d)" % [compared, stills])
