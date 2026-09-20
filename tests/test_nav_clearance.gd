extends TestCase
## Round 9 (nav, after CP2): **the navmesh is baked for a hull smaller than most of the roster.**
##
## `arena.tscn` bakes at `agent_radius = 2.0`. After the resize **14 of 21 units need more than that** — `gang_tank`
## 4.58 m (2.3x the bake), median 2.50 m, smallest `gang_scout` 1.36 m. So a corridor the mesh certifies as clear
## for a 2.0 m agent is not clear for two thirds of the units routed down it.
##
## Ruled this round: the bake radius stays 2.0 (raising it to 4.58 closes every alley the two thirds that fit can
## legitimately use; per-class meshes are a round-10 cost). nav's job is to **consult the shortfall** instead, so
## routing can refuse or widen rather than discovering it by wedging.

const MATCH := preload("res://game/match/match.tscn")


## THE FINDING, asserted over the live roster so a re-scale cannot silently un-make it. Not a bar on the hull sizes
## (those are scale's) — a statement of what nav's routing has to cope with, which goes red if it stops being true.
func test_most_of_the_roster_needs_more_clearance_than_the_navmesh_bakes() -> void:
	var over: Array[String] = []
	var worst := 0.0
	var worst_id := ""
	for unit_id: String in Units.PROFILES.keys():
		var r := Avoidance.radius_of(unit_id)
		if r > Movement.NAV_AGENT_RADIUS:
			over.append(unit_id)
		if r > worst:
			worst = r
			worst_id = unit_id
	print("MEASURE clearance: %d of %d units exceed the %.1f m bake; worst %s at %.2f m (%.1fx)" % [
			over.size(), Units.PROFILES.size(), Movement.NAV_AGENT_RADIUS, worst_id, worst,
			worst / Movement.NAV_AGENT_RADIUS])
	assert_true(over.size() > 0,
			"POSITIVE CONTROL: the roster contains hulls larger than the bake, or this measures nothing")
	assert_true(worst > Movement.NAV_AGENT_RADIUS * 2.0,
			"the largest hull needs more than TWICE the baked clearance (%s at %.2f m) - this is the resize's "
			% [worst_id, worst] + "second structural consequence and routing must consult it")


## The bake radius is READ, not mirrored: with an arena in the tree it comes from that arena's navigation mesh.
## The constant is the cross-check and `bake_radius()` complains if they disagree, so a re-bake cannot leave nav
## quietly routing to a number nobody baked.
func test_the_bake_radius_is_read_from_the_arena_not_from_the_constant() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Reader", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	await tree.physics_frame
	Movement._bake_radius = -1.0  # clear the cache so this reads the arena rather than a previous test's value
	var read := Movement.bake_radius(tank)
	assert_true(read > 0.0, "a radius was read from the live navigation mesh (%.2f)" % read)
	assert_true(absf(read - Movement.NAV_AGENT_RADIUS) < 0.001,
			"and it agrees with the cross-check constant (%.2f vs %.2f) - if this fails, arena re-baked and "
			% [read, Movement.NAV_AGENT_RADIUS] + "NAV_AGENT_RADIUS is stale, which is what it exists to catch")


## The shortfall is published per hull, positive for the hulls the mesh under-promises for and not for the rest.
func test_the_shortfall_is_published_and_has_the_right_sign() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var big := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	big.global_position = Vector3(-100, 0, 40)
	var small := game_match.spawn_tank("Scout", 1, Match.Team.GREEN, "scout")
	small.global_position = Vector3(-90, 0, 40)
	await tree.physics_frame
	var big_short := Movement.clearance_shortfall(big, "gang_tank")
	var small_short := Movement.clearance_shortfall(small, "scout")
	print("MEASURE clearance_shortfall: gang_tank %+.2f m, scout %+.2f m" % [big_short, small_short])
	assert_true(big_short > 1.0, "the semi needs well over a metre more than the mesh promises (%+.2f)" % big_short)
	assert_true(small_short < 0.0, "a scout fits anything the mesh calls clear (%+.2f)" % small_short)
	# ...and it reaches the reading, which is what routing and the readout consume.
	var ctl := OrderController.new()
	ctl.tank = big
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "move_to", "x": -60.0, "z": 40.0}, {"type": "hold_fire"}), "", "ordered")
	await tree.physics_frame
	var published: float = Movement.state(big).get("clearance_shortfall_m", 0.0)
	assert_true(absf(published - big_short) < 0.001,
			"`clearance_shortfall_m` is published in the reading (%+.2f)" % published)


## THE ROUTING HALF: an oversized hull must not take a mesh-hugging shortcut, and a hull that fits must still take
## them. The second half is the guard and it matters more — a rule that refused every shortcut would "fix" the
## clearance problem by making every hull follow every waypoint, which is a different regression wearing a fix's
## clothes.
func test_an_oversized_hull_refuses_the_shortcut_and_a_small_one_keeps_it() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray(["clearance"])
	Movement._off_parsed = true
	Movement.clearance_chords = 0
	Movement.clearance_refused = 0
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var big := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	big.global_position = Vector3(-100, 0, 40)
	var small := game_match.spawn_tank("Scout", 1, Match.Team.GREEN, "scout")
	small.global_position = Vector3(-90, 0, 40)
	await tree.physics_frame
	var big_slack := Movement.of(big)._chord_slack() if Movement.of(big) != null else NAN
	var small_slack := Movement.of(small)._chord_slack() if Movement.of(small) != null else NAN
	Movement._off = was
	Movement._off_parsed = true
	print("MEASURE clearance_routing: gang_tank chord slack %.2f m, scout %.2f m (chords %d, refused %d)" % [
			big_slack, small_slack, Movement.clearance_chords, Movement.clearance_refused])
	# The denominator first: a zero here would mean the rule never ran, which is not the same as "it changed
	# nothing" - the distinction this round found six times.
	assert_true(Movement.clearance_chords > 0,
			"the rule was CONSULTED (%d chords), so the numbers below are measurements" % Movement.clearance_chords)
	assert_true(big_slack < 0.0,
			"the semi's slack goes negative, which IS the refusal: every probe is then further from the mesh than "
			+ "allowed and no carrot is cut (%.2f m)" % big_slack)
	assert_true(small_slack > 0.0,
			"THE GUARD: a scout fits what the mesh certifies and keeps its shortcuts (%.2f m) - a rule that refused "
			% small_slack + "every hull would be a regression wearing a fix's clothes")
	assert_eq(Movement.clearance_refused, 1,
			"exactly one of the two hulls was refused (%d)" % Movement.clearance_refused)


## And with the switch OFF the slack is exactly what it was before this row existed, for both hulls.
func test_the_switch_off_reproduces_the_old_slack() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray()
	Movement._off_parsed = true
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var big := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	big.global_position = Vector3(-100, 0, 40)
	await tree.physics_frame
	var mover := Movement.of(big)
	var slack := mover._chord_slack() if mover != null else NAN
	var size: Variant = Units.stat("gang_tank", "hull_size", [2.4, 1.6, 3.8])
	var expected := maxf(Movement.CHORD_SLACK,
			Movement.NAV_AGENT_RADIUS - float(size[0]) / 2.0 - Movement.CHORD_MARGIN)
	Movement._off = was
	Movement._off_parsed = true
	assert_true(absf(slack - expected) < 0.001,
			"default path is byte-identical to the pre-row formula (%.3f vs %.3f)" % [slack, expected])
