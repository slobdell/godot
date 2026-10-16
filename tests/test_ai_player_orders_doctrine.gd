extends "res://tests/ai_scenarios/player_orders_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in player_orders_case.gd.


## The same thing at the size and rhythm the lead plays at: five squads of six, each ordered a second after the last,
## which is as fast as a person can select and right-click.
## ROUND 9 (scale, CP2): a unit the enemy DESTROYED is excluded, which its sibling below has always done.
##
## This test left respawn on -- `elimination` is unset, so `Match` brings a destroyed unit back at its own SPAWN
## SLOT, with full health and **no order**. The sibling states the principle in its own comment: *"skirmish plays
## to elimination: a destroyed unit doesn't come back without its orders."* This one asserted that all 30 units end
## on their slots while a live enemy respawned beside them for 40 s, and it held by luck of geometry.
##
## CP2 moved the geometry. The spawn grid went from 13 columns to 19, the respawning `Rust_A_1` came back somewhere
## it could reach the player's line, and it killed `Green_Charlie_1` -- which reappeared at slot 12, which is
## exactly `SLOT_X[12] = 45.0` at `BASE_Z = 90.0`, and sat there. Measured: 104.9 m from its formation slot, **the
## same value to 0.1 m on builder0 and on the laptop**, because it is a teleport to a grid point rather than a
## drive that came up short. Reverting only the spawn grid makes it pass again (4/4, worst gap 7.9 m).
##
## So the grid is what CHANGED it, and what was WRONG is that a respawned unit was being asked to hold a post it
## was never given. The fix is the sibling's rule, not a bigger tolerance.
func test_five_squads_ordered_in_quick_succession() -> void:
	var squads := await _setup(5, 6)
	var destroyed := {}
	_match.tank_destroyed.connect(func(victim: Tank, _killer: String) -> void: destroyed[String(victim.name)] = true)
	var goals := {"Alpha": Vector3(-80, 0, 10), "Bravo": Vector3(-40, 0, 10), "Charlie": Vector3(0, 0, 10),
			"Delta": Vector3(40, 0, 10), "Echo": Vector3(80, 0, 10)}
	var spawned := {}
	for squad_name: String in squads:
		spawned.merge(_positions(squads[squad_name]))
	# ROUND 10 (combat, backlog item 2): `FIVE_SQUADS_ORDER=EDCBA` issues the same five orders in another order, so
	# "the seating squad follows the order" and "it follows the geometry" can be told apart. Unset = the order below.
	var order: Array = squads.keys()
	var asked := OS.get_environment("FIVE_SQUADS_ORDER")
	if not asked.is_empty():
		order = []
		for letter in asked:
			for squad_name: String in squads:
				if squad_name.begins_with(letter):
					order.append(squad_name)
		print("MEASURE player_orders_rapid order %s" % [order])
	Tank.refused_run_max = 0
	for squad_name: String in order:
		var goal: Vector3 = goals[squad_name]
		assert_eq(_orders.issue({"units": squads[squad_name], "verb": "move", "to": [goal.x, goal.z],
				"source": "player"}, Match.Team.GREEN), "", "squad %s accepts a move order" % squad_name)
		await wait_physics_frames(SimClock.TICK_RATE * CLICK_GAP_SECONDS)
	await wait_physics_frames(SimClock.TICK_RATE * 40)
	var settled := {}
	for squad_name: String in squads:
		settled.merge(_positions(squads[squad_name]))
	var worst := {}
	var off_slot: Array = []
	var worst_unit := {}
	var away := 0
	var without_a_slot := 0
	for squad_name: String in squads:
		var slots := _slots(squads[squad_name])
		var far := 0.0
		for unit_name: String in squads[squad_name]:
			if destroyed.has(unit_name):
				continue  # destroyed and respawned at its spawn slot: it has no post, because it was never given one
			var slot: Variant = slots[unit_name]
			if slot == null:
				without_a_slot += 1
				continue
			var gap: float = (settled[unit_name] as Vector3).distance_to(slot as Vector3)
			far = maxf(far, gap)
			# The leash a unit fighting at its post keeps to, with the longer lead an escape (cover, breaking contact) is
			# allowed: beyond that it has left the ground the player gave it.
			if gap > far - 0.001:
				# The worst unit in this squad, printed on EVERY run and not only on a failure. Two reasons, and the
				# second is why it is not just nice to have: a squad at 22.2 m against a 36 m bar (which is where Delta
				# sits on main, 62% of the budget, while the other four sit at 3-7 m) is invisible in a passing run that
				# reports only an aggregate -- and it will start failing for whatever lands next and get blamed on it.
				# And this code path then RUNS on every green run, so it cannot rot unexercised waiting for a red, which
				# is the defect that produced half of today's wrong diagnoses.
				worst_unit[squad_name] = "%s %.1f m off%s" % [unit_name, gap, _nose_of(unit_name, settled)]
			if gap > TankBrain.PLAYER_POST_LEASH * TankBrain.ESCAPE_LEASH_FACTOR:
				away += 1
				# EVERY OFF-SLOT UNIT NAMES ITSELF: its gap, where it stands, and where it was sent. The aggregate alone
				# cannot tell "seated in another squad's formation" from "never moved" from "sent somewhere that does
				# not exist", and those have three different owners. Because this test printed only the aggregate, a
				# reader hunting the cause reached for the NEXT test's roster lines, and they fitted well enough to
				# carry a confident wrong diagnosis for half an hour -- two of us, in writing. **A measurement that
				# forces its reader to borrow numbers from another measurement is incomplete, however correct its own
				# total is.**
				off_slot.append("%s %.0f m off: at (%.0f, %.0f), sent to (%.0f, %.0f) with squad %s%s" % [unit_name,
						gap, (settled[unit_name] as Vector3).x, (settled[unit_name] as Vector3).z,
						(slot as Vector3).x, (slot as Vector3).z, squad_name, _nose_of(unit_name, settled)])
		worst[squad_name] = snappedf(far, 0.1)
	print("MEASURE player_orders_rapid worst gap to its OWN slot per squad %s; %d of %d units off their slot, %d with no slot at all, %d destroyed" % [
			worst, away, spawned.size(), without_a_slot, destroyed.size()])
	# Combat's CP4 bar (research B2): the longest run of consecutive refused yaw ticks by any hull (0 with the
	# constraint off, where nothing is ever refused).
	print("MEASURE player_orders_rapid yaw refusals: longest run %d ticks, yaw_fit %s, world mask %s" % [
			Tank.refused_run_max, Tank.yaw_fit_on(), Tank.yaw_world_on()])
	# Printed as its own lines rather than folded into the MEASURE line: a roster belongs beside the total it explains,
	# and grep-ability matters more than tidiness when the next reader is hunting a cause across two tests' output.
	for squad_name: String in worst_unit:
		print("  player_orders_rapid worst in %s: %s" % [squad_name, worst_unit[squad_name]])
	for line: String in off_slot:
		print("  player_orders_rapid off-slot: %s" % line)
	# The exclusion must not be able to hide the thing the test is for: if the enemy wiped out most of the player's
	# force there is nothing left to assert about formations, and a green run would mean nothing.
	assert_true(destroyed.size() <= 3, "at most a few units were destroyed (%d of %d); more than that and this test "
			% [destroyed.size(), spawned.size()] + "is measuring a massacre rather than five squads taking their slots")
	assert_eq(without_a_slot, 0, "every ordered unit still knows where it belongs")
	assert_eq(away, 0, "every unit of every squad ends up on its own slot in its squad's formation")


## The same rhythm again, but with a real army loaded from a doctrine file the way skirmish loads one: its squads carry
## their own verbs, formations and directives, which is the layer between the player's K1 order and the brain.
func test_a_doctrine_army_re_arranges_when_each_squad_is_ordered() -> void:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(3, 0.0)
	_match.elimination = true  # skirmish plays to elimination: a destroyed unit doesn't come back without its orders
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	for side in 2:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % ["player_default", "anvil_hammer"][side])
		assert_true(not loaded.has("error"), "army loads: %s" % loaded.get("error", ""))
		assert_eq(_match.load_doctrine(side, loaded["doctrine"]), "", "army spawns")
	await wait_physics_frames(SimClock.TICK_RATE)
	var squads: Array[Squad] = _match.team_squads(Match.Team.GREEN)
	assert_true(squads.size() >= 2, "the player's army has squads to order (%d)" % squads.size())
	var goals := [Vector3(-70, 0, 30), Vector3(70, 0, 30), Vector3(0, 0, 50), Vector3(-40, 0, 60), Vector3(40, 0, 60)]
	var names := {}
	for i in squads.size():
		var roster: Array = []
		for unit_name in squads[i].roster:
			roster.append(String(unit_name))
		names[squads[i].squad_name] = roster
		var goal: Vector3 = goals[i % goals.size()]
		assert_eq(_orders.issue({"units": roster, "verb": "move", "to": [goal.x, goal.z], "source": "player"},
				Match.Team.GREEN), "", "squad %s accepts a move order" % squads[i].squad_name)
		# The slot each unit was actually given, read the moment the order goes in (a station is forgotten once the
		# order finishes, so asking later tells you nothing).
		for unit_name: String in roster:
			var given: Dictionary = _orders.current(unit_name)
			_given[unit_name] = OrderFeed.point(given.get("goal")) if not given.is_empty() else null
		await wait_physics_frames(SimClock.TICK_RATE * CLICK_GAP_SECONDS)
	# What happens to the player's order over the next 40 s: what the brain chose, and whether the order survived.
	var watched: Array = names[names.keys()[0]]
	var log := {}
	for tick in SimClock.TICK_RATE * 40:
		await wait_physics_frames(1)
		if tick % SimClock.TICK_RATE != 0:
			continue
		var unit_name: String = watched[0]
		var brain := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
		var order: Dictionary = _orders.current(unit_name)
		var key := "%s | order %s | %s" % [String(brain.choice.get("option", "")), order.get("verb", "(none)"),
				"goal " + str(OrderFeed.point(order.get("goal"))) if not order.is_empty() else "station"]
		log[key] = int(log.get(key, 0)) + 1
	print("      player_orders_leash: what %s did, seconds per state: %s" % [watched[0], log])
	var away := 0
	var dead := 0
	var worst := {}
	for squad_name: String in names:
		var settled := _positions(names[squad_name])
		var slots := _given
		var far := 0.0
		for unit_name: String in names[squad_name]:
			var tank := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank == null or not tank.is_alive():
				dead += 1  # a unit the enemy destroyed has no post to keep
				continue
			if slots[unit_name] == null:
				away += 1
				var lost := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
				print("        NO SLOT %s was never given one: current %s" % [unit_name, _orders.current(unit_name)])
				continue
			var gap: float = (settled[unit_name] as Vector3).distance_to(slots[unit_name] as Vector3)
			far = maxf(far, gap)
			var each := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
			print("        player_orders_leash roster: %s %.0f m from its slot; choice %s; post %s; order now %s" % [unit_name, gap,
					each.choice.get("option", "?") if each != null else "(no brain)",
					each._player_post if each != null else "?", _orders.current(unit_name).get("verb", "(none)")])
			# The leash a unit fighting at its post keeps to, with the longer lead an escape (cover, breaking contact) is
			# allowed: beyond that it has left the ground the player gave it.
			away += 1 if gap > TankBrain.PLAYER_POST_LEASH * TankBrain.ESCAPE_LEASH_FACTOR else 0
		worst[squad_name] = snappedf(far, 0.1)
	# How far from the ground the player gave them the living units actually sit, and what the fight cost: the leash
	# trades control for room to fight, so both numbers have to be read together.
	var gaps: Array = []
	for squad_name: String in names:
		var settled_now := _positions(names[squad_name])
		for unit_name: String in names[squad_name]:
			var tank := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive() and _given.get(unit_name) != null:
				gaps.append((settled_now[unit_name] as Vector3).distance_to(_given[unit_name] as Vector3))
	var mean := 0.0
	for gap: float in gaps:
		mean += gap / maxf(gaps.size(), 1)
	print("MEASURE player_orders_leash %.1f m leash: %d living units a mean %.1f m from their slot; green %d alive, rust %d alive" % [
			TankBrain.PLAYER_POST_LEASH, gaps.size(), mean, _match.alive_count(Match.Team.GREEN),
			_match.alive_count(Match.Team.RUST)])
	print("MEASURE player_orders_doctrine_army worst gap to its own slot per squad %s; %d units off their slot, %d destroyed" % [worst, away, dead])
	assert_eq(away, 0, "a doctrine army's squads go where the player sent them and fight from there")
