extends TestCase
## The spawn grid against the ROSTER, not against a remembered hull (scale, round 9, backlog item 3).
##
## `Match.SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING` were sized for "a jittered 2.6 x 4 m hull" (the comment at
## match.gd:70), and round 8 found that *"length was the axis the spawn grid appeared to cap"* when the War Rig
## reached 14 m. S1 then grew eighteen more hulls, including `Units.DEFAULT` from 3.6 m to 8.62 m.
##
## WHAT THE GRID ACTUALLY HAS TO HOLD is less than it looks, and the third test here is the one that establishes
## it rather than quoting it: a doctrine army is re-laid by `ArmyLayout.deploy()` at tick 0, synchronously, before
## any physics step, so it never stands on this grid. What stays here is what `Match.spawn_tank` puts here and
## leaves -- network players and legacy bots, driving `Units.DEFAULT`. Sizing the grid for the roster's 14 m rig
## would be guarding a holding position nothing occupies (combat's finding, round 8).
##
## For the record, and deliberately NOT asserted: at the round-9 roster the grid does NOT hold the biggest hull.
## Adjacent columns leave 7.5 - 2x1.5 - 4.74 = -0.24 m for the Condemned artillery's width, and adjacent rows leave
## 12.0 - 2x0.6 - 14.0 = -3.2 m for the War Rig's length. Both are fine because of `deploy()`, and both would be
## findings the day `deploy()` stopped running -- which is what `test_a_doctrine_army_is_never_left_standing_on_the_grid`
## is for.

const TOLERANCE_M := 0.01


func _default_hull() -> Vector3:
	var box: Array = Units.stat(Units.DEFAULT, "hull_size")
	return Vector3(float(box[0]), float(box[1]), float(box[2]))


## Every slot's spawn point for one side, from the layout's BAKED list (which is what a real match uses:
## `Match.spawn_position` consults `Arena.spawn_spot` first and only then falls back to the constants).
func _spots(south: bool) -> Array:
	var out: Array = []
	for slot in Match.SPAWN_SLOTS:
		out.append(Match.spawn_position(Match.Team.GREEN if south else Match.Team.RUST, slot))
	return out


## THE MIRROR. Every layout carries a BAKED spawn list, and `Arena.spawn_spot` is consulted before the constants,
## so the baked list WINS -- which is why round 4's `make_arenas.py` copy of `SLOT_X` behind a "must mirror"
## comment is the worst row in Invariant 0's table: changing a constant changed nothing in a real match. The
## generator reads the constants now; this is what says so on every shipped map.
func test_every_layouts_baked_spawn_list_is_the_grid_the_constants_describe() -> void:
	for layout_name: String in Arena.layout_names():
		var result := Arena.load_layout(layout_name)
		assert_true(not result.has("error"), "%s loads (%s)" % [layout_name, result.get("error", "")])
		var loaded: Dictionary = result["layout"]
		assert_true(loaded.has("spawns"), "%s carries a baked spawn list" % layout_name)
		var previous := Arena.active
		Arena.active = {}
		var from_constants := _spots(true)
		Arena.active = loaded
		var from_layout := _spots(true)
		Arena.active = previous
		for slot in from_layout.size():
			var baked: Vector3 = from_layout[slot]
			var constant: Vector3 = from_constants[slot]
			assert_true(baked.distance_to(constant) < TOLERANCE_M,
					"%s slot %d: the baked list says %s, the constants say %s. `make arenas` has not been re-run, "
					% [layout_name, slot, baked, constant] + "and the baked list is the one a match uses.")


## What a bare spawn leaves standing here has to fit between its neighbours at the WORST jitter, not the average.
## The clearance is READ from squad's `ArmyLayout.HULL_CLEAR_M` -- the project's existing answer to "how much clear
## ground between two vehicles" -- rather than a number invented in this file.
func test_the_bare_spawn_unit_clears_its_neighbours_at_the_worst_jitter() -> void:
	var hull := _default_hull()
	for layout_name: String in Arena.layout_names():
		var previous := Arena.active
		Arena.active = Arena.load_layout(layout_name)["layout"]
		var spots := _spots(true)
		var worst := INF
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				var a: Vector3 = spots[i]
				var b: Vector3 = spots[j]
				# Two boxes are clear if they are clear on EITHER axis, so a pair's clearance is the better one.
				var gap_x := absf(a.x - b.x) - 2.0 * Match.SPAWN_JITTER_MAX_X - hull.x
				var gap_z := absf(a.z - b.z) - 2.0 * Match.SPAWN_JITTER_MAX_Z - hull.z
				worst = minf(worst, maxf(gap_x, gap_z))
		Arena.active = previous
		assert_true(worst >= ArmyLayout.HULL_CLEAR_M - TOLERANCE_M,
				"%s: the closest pair of slots leaves %.2f m clear for a jittered %.2f x %.2f m bare spawn, and %.2f m is the floor"
				% [layout_name, worst, hull.x, hull.z, ArmyLayout.HULL_CLEAR_M])


## `DRIVABLE_LIMIT` is a square fallback and three shipped maps are hexagons, so the bound that matters is
## `Arena.contains`. Checked at the jittered hull's CORNER: a slot whose centre is inside is not enough.
func test_every_spawn_slot_is_somewhere_a_unit_can_be() -> void:
	var hull := _default_hull()
	for layout_name: String in Arena.layout_names():
		var loaded: Dictionary = Arena.load_layout(layout_name)["layout"]
		var previous := Arena.active
		Arena.active = loaded
		for south in [true, false]:
			for spot: Vector3 in _spots(south):
				var corner := spot + Vector3(
						signf(spot.x) * (Match.SPAWN_JITTER_MAX_X + hull.x / 2.0), 0.0,
						signf(spot.z) * (Match.SPAWN_JITTER_MAX_Z + hull.z / 2.0))
				assert_true(Arena.contains(corner, loaded),
						"%s: a jittered %.2f x %.2f m hull at slot %s reaches %s, outside the arena"
						% [layout_name, hull.x, hull.z, spot, corner])
		Arena.active = previous


## THE ASSUMPTION THE GRID'S SIZE RESTS ON, made checkable. `Match.load_doctrine` ends with `ArmyLayout.deploy()`,
## which re-lays every unit by its own hull size before any physics step -- so the grid never has to hold a 14 m
## rig. That is a comment in match.gd and in combat's round-8 test, and a comment is not a guard: the day something
## defers `deploy()` by a frame, a resized roster piles 45 vehicles into a grid sized for one 8.6 m hull and
## nothing says so. This spawns a real faction army and looks at where the vehicles actually are.
func test_a_doctrine_army_is_never_left_standing_on_the_grid() -> void:
	for faction: String in ["gangs", "condemned"]:
		var game_match: Match = (load("res://game/match/match.tscn") as PackedScene).instantiate()
		add_to_tree(game_match)
		await wait_physics_frames(1)
		game_match.budget = Units.BASELINE_BUDGET
		var before := game_match.tick
		var army := Army.load_army("cpu", 1, Units.BASELINE_BUDGET, faction)
		assert_true(not army.has("error"), "setup: a %s army loads (%s)" % [faction, army.get("error", "")])
		assert_eq(game_match.load_doctrine(Match.Team.GREEN, army["doctrine"]), "", "setup: the %s army deploys" % faction)
		var tanks := game_match.sorted_team_tanks(Match.Team.GREEN)
		assert_true(tanks.size() > 15, "setup: a baseline %s army is a real army (%d vehicles)" % [faction, tanks.size()])
		# The property the grid's size depends on: after load_doctrine and BEFORE any physics step, every vehicle
		# stands clear of every other. On the grid alone they would not -- the rig is 14 m and the rows are 12 m
		# apart -- so this fails the moment `deploy()` stops running first, which is the only thing that lets the
		# grid stay sized for one bare-spawn hull.
		assert_eq(game_match.tick, before, "setup: not one tick has been simulated since the army spawned")
		var overlapping: Array = []
		for i in tanks.size():
			for j in range(i + 1, tanks.size()):
				var a: Tank = tanks[i]
				var b: Tank = tanks[j]
				var hull_a: Array = Units.stat(a.unit_id, "hull_size")
				var hull_b: Array = Units.stat(b.unit_id, "hull_size")
				# Every vehicle faces the same way at deploy, so an axis-aligned test is the right one.
				var gap_x := absf(a.global_position.x - b.global_position.x) - (float(hull_a[0]) + float(hull_b[0])) / 2.0
				var gap_z := absf(a.global_position.z - b.global_position.z) - (float(hull_a[2]) + float(hull_b[2])) / 2.0
				if maxf(gap_x, gap_z) < 0.0 and overlapping.size() < 6:
					overlapping.append("%s (%s) and %s (%s) overlap by %.2f m" % [a.name, a.unit_id, b.name, b.unit_id,
							-maxf(gap_x, gap_z)])
		assert_eq(overlapping, [], "%s: every vehicle was re-laid clear of every other before the first physics step" % faction)
		game_match.queue_free()
		await wait_physics_frames(1)
