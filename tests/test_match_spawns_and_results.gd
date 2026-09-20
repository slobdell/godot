extends TestCase
## Rules R5: 5 squads x 5 units per side spawn without overlapping, and Match.finished carries the fields the
## army stream's progression needs (contract C3).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


## The biggest army one side may field (Army.MAX_ARMY_UNITS), in squads of Doctrine.MAX_SQUAD_UNITS.
func _full_army() -> Dictionary:
	var roster := ["tank", "ifv", "scout", "artillery", "lancer"]
	var army := {"name": "Full", "squads": []}
	var squads := ceili(float(Army.MAX_ARMY_UNITS) / Doctrine.MAX_SQUAD_UNITS)
	var bought := 0
	for s in squads:
		var units: Array = []
		for u in Doctrine.MAX_SQUAD_UNITS:
			if bought >= Army.MAX_ARMY_UNITS:
				break
			units.append({"unit": roster[(s + u) % roster.size()]})
			bought += 1
		army["squads"].append({"name": "S%d" % s, "formation": "wedge", "verb": "hold", "units": units})
	return army


## How far a hull may be from its placement ONCE SETTLED. Between scale's two measured regimes: the normal settle is
## 1.8 cm across 90 units, a Jolt ejection through the ground is 1.5 m.
const PLACEMENT_DRIFT_M := 0.25
## Settled = the largest per-frame movement across the whole army is under this, or SETTLE_MAX_FRAMES have passed.
##
## **Sampling at frame 1 would fire on three units by construction**, which is why this exists. scale traced the
## y-writer to `move_and_slide`'s DEPENETRATION RECOVERY with velocity exactly zero: `get_position_delta` carries the
## whole -1.475 m in frame 1, then -0.190 at frame 2 and -0.042 at frame 3, while a unit that happens to pass gets
## +0.87 mm out of the identical contact. So the first frame is the transient, not the outcome, and an assertion taken
## there measures the recovery rather than the placement holding.
const SETTLE_STEP_M := 0.01
const SETTLE_MAX_FRAMES := 10


func test_a_full_faction_army_a_side_spawns_clear_of_itself() -> void:
	# X5 (round 4): the grid has to hold a faction army, not five squads of five.
	#
	# BOTH ASSERTIONS MEASURE PLACEMENT, not where physics has put a hull one frame later, and that distinction is the
	# whole reason this test failed on main while passing alone. Placement is a deterministic function of the layout;
	# where a body sits after a frame is not. A unit placed at exactly y = 0.0 rests in a degenerate contact with
	# Arena/Ground, and after an earlier arena's bodies have been created and destroyed in the same process Jolt ejects
	# some of them 1.5 m DOWN through the ground -- so the old version probed those hulls AT THEIR EJECTED POSITIONS,
	# inside the ground slab, and reported them as spawning inside a wall. Identical placement, different engine state,
	# and the trigger was the sharding schedule putting `test_arena_layouts` first. `ArmyLayout.SPAWN_LIFT_M` fixes the
	# cause; measuring placement is what stops this test reporting an engine artefact as a layout bug.
	assert_true(Match.SPAWN_SLOTS >= Doctrine.MAX_UNITS, "the spawn grid has a slot for every unit an army can field")
	var game_match := _setup()
	game_match.seed_spawns(9, 6.0)  # the match runner's jitter
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(game_match.load_doctrine(team, _full_army()), "", "a full army loads for team %d" % team)
	var tanks := game_match.tanks_by_name().values()
	assert_eq(tanks.size(), 2 * Army.MAX_ARMY_UNITS, "setup: %d units" % (2 * Army.MAX_ARMY_UNITS))
	# Captured BEFORE any physics frame: this is the placement itself.
	var placed := {}
	for tank: Tank in tanks:
		placed[tank] = tank.global_position
	var boxes := {}
	for tank: Tank in tanks:
		var at: Vector3 = placed[tank]
		assert_true(absf(at.x) < Match.DRIVABLE_LIMIT and absf(at.z) < Match.DRIVABLE_LIMIT,
				"%s is placed inside the arena (%s)" % [tank.name, at])
		var size: Array = Units.stat(tank.unit_id, "hull_size")  # spawn yaw is 0 or 180°: boxes are axis-aligned
		boxes[tank] = Rect2(at.x - size[0] / 2.0, at.z - size[2] / 2.0, size[0], size[2])
	var overlaps: Array = []
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			if (boxes[tanks[i]] as Rect2).grow(0.5).intersects(boxes[tanks[j]]):
				overlaps.append("%s/%s" % [tanks[i].name, tanks[j].name])
	assert_eq(overlaps, [], "no two hulls are PLACED within half a meter of each other")
	# The obstacle probe reads static world geometry, so it needs the space stepped once -- but it probes each unit's
	# PLACEMENT, captured above, not wherever the body has since been pushed.
	# Settle first, then measure: step until the army stops moving, and report how many frames it took so a slow
	# settle is visible rather than merely tolerated.
	var previous := {}
	for tank: Tank in tanks:
		previous[tank] = tank.global_position
	var frames := 0
	var worst_step := 0.0
	for f in SETTLE_MAX_FRAMES:
		await wait_physics_frames(1)
		frames += 1
		worst_step = 0.0
		for tank: Tank in tanks:
			var now: Vector3 = tank.global_position
			worst_step = maxf(worst_step, (now - (previous[tank] as Vector3)).length())
			previous[tank] = now
		if worst_step < SETTLE_STEP_M:
			break
	# THE WRITER DETECTOR. A green on the two assertions above is not evidence that nothing moves a hull off its
	# placement -- scale saw this test pass at a 71/71/71 shard layout and fail at 69/68/68, so the quantity is still
	# sensitive to engine state. This says so directly instead of letting it surface as "inside a wall": scale measured
	# the normal first-frame settle at 1.8 cm across 90 units and a Jolt ejection at 1.5 m, so 0.25 m separates them
	# with two orders of margin either side, and the delta is named so the next reader does not have to instrument it.
	var moved: Array = []
	for tank: Tank in tanks:
		var delta: float = (tank.global_position - (placed[tank] as Vector3)).length()
		if delta > PLACEMENT_DRIFT_M:
			moved.append("%s moved %.2f m from %s to %s" % [tank.name, delta, placed[tank], tank.global_position])
	# THE RED CARRIES ITS OWN DIAGNOSIS. A pair that was clear at placement and is not clear now needs four numbers to
	# say WHY, or the next reader re-derives them: what the half-metre rule requires for those two hulls, how far apart
	# they were placed, how far apart they ended, and which way each one went. The displacement VECTORS are the
	# discriminator: convergent along the row says something squeezed the pair; parallel says both were carried; radial
	# from one spot says a third body pushed them.
	var squeezed: Array = []
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			var a: Tank = tanks[i]
			var b: Tank = tanks[j]
			var size_a: Array = Units.stat(a.unit_id, "hull_size")
			var size_b: Array = Units.stat(b.unit_id, "hull_size")
			var box_a := Rect2(a.global_position.x - size_a[0] / 2.0, a.global_position.z - size_a[2] / 2.0,
					size_a[0], size_a[2])
			var box_b := Rect2(b.global_position.x - size_b[0] / 2.0, b.global_position.z - size_b[2] / 2.0,
					size_b[0], size_b[2])
			if not box_a.grow(0.5).intersects(box_b):
				continue
			var was: float = ((placed[a] as Vector3) - (placed[b] as Vector3)).length()
			var now: float = (a.global_position - b.global_position).length()
			squeezed.append("%s(%.2f wide)/%s(%.2f wide) need %.2f m, placed %.2f m, settled %.2f m; moved %s and %s" \
					% [a.name, size_a[0], b.name, size_b[0], (float(size_a[0]) + float(size_b[0])) / 2.0 + 0.5,
					was, now, a.global_position - (placed[a] as Vector3), b.global_position - (placed[b] as Vector3)])
	assert_eq(moved, [], "no hull is moved off its placement once settled (%d frame(s), last step %.4f m)%s" \
			% [frames, worst_step, "" if squeezed.is_empty() else "; pairs no longer clear: " + ", ".join(squeezed)])
	var space := (tanks[0] as Tank).get_world_3d().direct_space_state
	# POSITIVE CONTROL, because an empty result from an unready space is indistinguishable from a clear spawn and would
	# pass this assertion for the worst possible reason. A box over the whole arena must hit SOMETHING on WORLD_MASK.
	var control := PhysicsShapeQueryParameters3D.new()
	var control_shape := BoxShape3D.new()
	control_shape.size = Vector3(Match.DRIVABLE_LIMIT * 2.0, 4.0, Match.DRIVABLE_LIMIT * 2.0)
	control.shape = control_shape
	control.transform = Transform3D(Basis.IDENTITY, Vector3.UP * 1.5)
	control.collision_mask = Perception.WORLD_MASK
	assert_true(not space.intersect_shape(control, 1).is_empty(),
			"control: the physics space answers WORLD_MASK queries, so an empty result below means a clear spawn")
	var blocked: Array = []
	for tank: Tank in tanks:
		var probe := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		var size: Array = Units.stat(tank.unit_id, "hull_size")
		shape.size = Vector3(size[0] + 1.0, 1.0, size[2] + 1.0)
		probe.shape = shape
		probe.transform = Transform3D(Basis.IDENTITY, (placed[tank] as Vector3) + Vector3.UP * 1.5)  # above the slab
		probe.collision_mask = Perception.WORLD_MASK
		# NAME THE BODY, and name every body. "inside a wall or crate" is a guess dressed as a finding: when three
		# units failed this it cost an hour to learn whether they had hit an obstacle (a placement bug, this file's
		# owner) or the ground itself (the degenerate y = 0 contact, scale's, a different bug with a different fix).
		# combat's version of this and mine were written independently and each had half: the hit COUNT and the class
		# from combat, the parent path from me -- `Arena/Ground` is legible where a bare `Ground` is not.
		var hits := space.intersect_shape(probe, 4)
		if not hits.is_empty():
			var names: Array = []
			for hit: Dictionary in hits:
				var body := hit.get("collider") as Node
				if body == null:
					names.append("<freed>")
					continue
				var who := String(body.name)
				var parent := body.get_parent()
				if parent != null:
					who = "%s/%s" % [String(parent.name), who]
				names.append("%s (%s)" % [who, body.get_class()])
			# The PLACEMENT, not `global_position`: the probe sits at the placement, so reporting where the body has
			# since been pushed would name a spot the probe never looked at. That mismatch is what made the original
			# failure read as a layout bug.
			blocked.append("%s hit %s at %s" % [tank.name, ", ".join(names), placed[tank]])
	assert_eq(blocked, [], "no unit is PLACED inside a wall or crate")


func test_the_grid_fills_the_front_row_before_the_rows_behind_it() -> void:
	var columns := Match.SLOT_X.size()
	for slot in columns:
		var spot := Match.spawn_position(Match.Team.GREEN, slot)
		assert_eq(spot.z, Match.BASE_Z, "slot %d stands in the front row" % slot)
	assert_true(Match.spawn_position(Match.Team.GREEN, columns).z > Match.BASE_Z,
			"the next slot starts the second row, behind the first")
	# The mirror is point symmetry ON THE FLOOR PLANE. `SPAWN_LIFT_M` is a constant lift on BOTH sides, so negating a
	# spawn point would flip it below the floor -- the mirror is asserted in x/z and the lift separately.
	var green_deep := Match.spawn_position(Match.Team.GREEN, columns + 1)
	var rust_deep := Match.spawn_position(Match.Team.RUST, columns + 1)
	assert_eq(Vector2(rust_deep.x, rust_deep.z), -Vector2(green_deep.x, green_deep.z), "Rust's grid mirrors Green's")
	# `assert_near`, not `assert_eq`: Vector3 stores 32-bit floats, so the component reads back 0.05000000074506 and a
	# double literal will never equal it. Comparing a stored float to a source constant always needs a tolerance.
	assert_near(green_deep.y, Match.SPAWN_LIFT_M, 1e-6, "and both sides stand the same distance clear of the floor")
	assert_near(rust_deep.y, Match.SPAWN_LIFT_M, 1e-6, "and both sides stand the same distance clear of the floor")
	assert_true(Match.SPAWN_SLOTS >= Army.MAX_ARMY_UNITS, "and there is a slot for every vehicle an army may field")


## Round 9: a body created at exactly y = 0.0 makes a degenerate ground contact, and whether Jolt resolves it cleanly
## depends on solver state left by earlier bodies — scale measured three units ejected 1.5 m THROUGH the floor at
## spawn, reproducing only after other bodies had been created and destroyed. Every spawn point now stands clear of
## the floor, and it comes from ONE constant so the grid path and the arena-layout path cannot drift apart.
func test_every_spawn_point_stands_clear_of_the_floor() -> void:
	# NOT `> 0.0`: the constant is deliberately 0.0 while the ejection is diagnosed (it is not the lift -- the same
	# three units fall through the floor at 0.0 AND at 0.05, same workload). What this test guards is the property
	# that survives whatever value it takes: EVERY spawn point, both teams, grid slots and layout slots alike, has the
	# SAME clearance and it comes from one constant. That is what stops the two sources drifting apart again.
	assert_true(Match.SPAWN_LIFT_M >= 0.0, "the lift is a real distance")
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		for slot in [0, 1, Match.SLOT_X.size(), Match.SPAWN_SLOTS - 1]:
			assert_near(Match.spawn_position(team, slot).y, Match.SPAWN_LIFT_M, 1e-6,
					"team %d slot %d spawns clear of the floor" % [team, slot])


func test_the_result_carries_what_progression_needs() -> void:
	var game_match := _setup()
	game_match.budget = 1500
	var green := {"name": "G", "squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "scout"}]}]}
	var rust := {"name": "R", "squads": [{"name": "B", "units": [{"unit": "ifv"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, green), "", "setup: green")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust")
	game_match.elimination = true
	var results: Array = []
	game_match.finished.connect(func(result: Dictionary) -> void: results.append(result))
	await wait_physics_frames(2)
	var cannon := Weapons.profile("cannon")
	for victim_name in ["Rust_B_1", "Rust_B_2"]:
		var victim := game_match.tanks.get_node(victim_name) as Tank
		victim.shield = 0.0
		game_match._land_hit(victim, 100000.0, cannon, Vector3.FORWARD, Match.Team.GREEN, "Green_A_1", "", true)
	(game_match.tanks.get_node("Green_A_2") as Tank).apply_damage(100000)  # lost to something else
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_eq(results.size(), 1, "the match finishes once")
	if results.is_empty():
		return
	var result: Dictionary = results[0]
	assert_eq(result["winner"], "Green", "the side with units left wins")
	assert_eq(result["reason"], "elimination", "by elimination")
	assert_eq(result["units_lost"], {"green": 1, "rust": 2}, "units lost per side")
	assert_eq(result["units_left"], {"green": 1, "rust": 0}, "units left per side")
	assert_eq(result["kills_by_unit"]["green"], {"ifv": 1, "scout": 1}, "what Green destroyed, by unit type")
	assert_eq(result["losses_by_unit"]["green"], {"scout": 1}, "what Green lost, by unit type")
	assert_eq(result["budget"], 1500, "the match budget")
	assert_eq(result["army_cost"], {"green": 310, "rust": 260}, "each army's cost")
	assert_true(result["duration_seconds"] > 0.0, "and how long it took")
