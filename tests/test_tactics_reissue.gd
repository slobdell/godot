extends TestCase
## control, 2026-09-17: with elements running and nobody touching the controls, Orders accepted ~200 commands and ~35
## order changes a second across 21 units, verbs flapping between move / hold / attack_move — every change drew a marker
## and played a cue on the lead's screen ("these blue dots ... they just keep repeating or re-orienting"), and cost
## frames. The re-issuing is doctrine's, so the gate belongs here: an element re-issues a member's order only when the
## intention actually changed, and what it issues is tagged `source: "element"` so anything downstream can tell it from
## the player's own clicks.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const WATCH_SECONDS := 6
## An order that repeats what the unit is already doing is pure thrash: it redraws the player's marker, plays a cue and
## restarts the unit's path for nothing. A few a second across an army is the symptom the lead saw.
const SAME_INTENTION_PER_SECOND := 0.5
## Two orders are the same intention when the verb, the target and the destination (within this) all match.
const SAME_M := 8.0


func teardown() -> void:
	TacticsFlags.reset()
	super()


func test_elements_do_not_re_issue_orders_while_nothing_changes() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(5, 0.0)
	game_match.elimination = true
	for side in 2:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % ["combined_arms", "anvil_hammer"][side])
		assert_true(not loaded.has("error"), "army loads")
		assert_eq(game_match.load_doctrine(side, loaded["doctrine"]), "", "army spawns")
	await wait_physics_frames(TacticsFlags.SETTLE_TICKS)
	TacticsFlags.install(game_match, ["", ""], false)
	var orders := Orders.of(game_match)
	var changes := {"count": 0, "same": 0, "sources": {}, "last": {}}
	orders.order_changed.connect(func(unit_name: String) -> void:
		var order: Dictionary = orders.current(unit_name)
		if order.is_empty():
			return  # an order finishing is not an order being given
		changes["count"] += 1
		var goal: Variant = OrderFeed.point(order.get("goal"))
		var previous: Dictionary = (changes["last"] as Dictionary).get(unit_name, {})
		var same: bool = not previous.is_empty() and String(previous["verb"]) == String(order.get("verb", "")) \
				and String(previous["target"]) == String(order.get("target", "")) \
				and ((goal == null and previous["goal"] == null)
					or (goal != null and previous["goal"] != null and (goal as Vector3).distance_to(previous["goal"]) <= SAME_M))
		changes["same"] += 1 if same else 0
		(changes["last"] as Dictionary)[unit_name] = {"verb": String(order.get("verb", "")),
				"target": String(order.get("target", "")), "goal": goal}
		var key := "%s/%s%s" % [order.get("verb", "?"), order.get("source", "(untagged)"), " REPEAT" if same else ""]
		(changes["sources"] as Dictionary)[key] = int((changes["sources"] as Dictionary).get(key, 0)) + 1)
	# Let them form up and start moving, then watch a window in which no player touches anything.
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	changes["count"] = 0
	changes["same"] = 0
	changes["sources"] = {}
	var units := game_match.alive_count(Match.Team.GREEN) + game_match.alive_count(Match.Team.RUST)
	await wait_physics_frames(SimClock.TICK_RATE * WATCH_SECONDS)
	var per_second := float(changes["count"]) / WATCH_SECONDS
	var repeats := float(changes["same"]) / WATCH_SECONDS
	print("MEASURE element_reissue %.1f orders a second across %d units, of which %.1f a second repeat what the unit was already doing; by verb and source: %s" % [
			per_second, units, repeats, changes["sources"]])
	for key: String in changes["sources"]:
		assert_true(key.ends_with("/element") or key.begins_with("(cleared)"),
				"everything an element issues says so: %s" % key)
	assert_true(repeats <= SAME_INTENTION_PER_SECOND,
			"an element does not hand a unit the order it is already carrying out (%.1f a second)" % repeats)


## The lead's case: his squads are also elements, and he gives them orders. An element must not take a member back off
## the order the player gave it — that is "I have no control whatsoever" — and it must not re-issue around it.
func test_an_element_leaves_the_players_orders_alone() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(5, 0.0)
	game_match.elimination = true
	game_match.set_meta("player_team", Match.Team.GREEN)
	for side in 2:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % ["combined_arms", "anvil_hammer"][side])
		assert_eq(game_match.load_doctrine(side, loaded["doctrine"]), "", "army spawns")
	await wait_physics_frames(TacticsFlags.SETTLE_TICKS)
	TacticsFlags.install(game_match, ["", ""], false)
	var orders := Orders.of(game_match)
	var squad: Squad = game_match.team_squads(Match.Team.GREEN)[0]
	for candidate: Squad in game_match.team_squads(Match.Team.GREEN):
		if candidate.roster.size() > squad.roster.size():
			squad = candidate  # the biggest squad: a line element, not the single artillery piece
	var roster: Array = []
	for unit_name in squad.roster:
		roster.append(String(unit_name))
	var goal := Vector3(-40, 0, 40)
	assert_eq(orders.issue({"units": roster, "verb": "move", "to": [goal.x, goal.z], "source": "player"},
			Match.Team.GREEN), "", "the player's order is accepted")
	var stolen := {"count": 0, "verbs": {}}
	orders.order_changed.connect(func(unit_name: String) -> void:
		if not roster.has(unit_name):
			return
		var order: Dictionary = orders.current(unit_name)
		if order.is_empty() or String(order.get("source", "")) == "player":
			return
		stolen["count"] += 1
		var key := "%s/%s" % [order.get("verb", "?"), order.get("source", "(untagged)")]
		(stolen["verbs"] as Dictionary)[key] = int((stolen["verbs"] as Dictionary).get(key, 0)) + 1)
	await wait_physics_frames(SimClock.TICK_RATE * 30)
	var arrived := 0
	for unit_name: String in roster:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		arrived += 1 if Vector3(tank.global_position.x, 0.0, tank.global_position.z).distance_to(goal) < 20.0 else 0
	for unit_name: String in roster:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
		print("      %s: %.0f m from the spot, order %s, choice %s, alive %s" % [unit_name,
				Vector3(tank.global_position.x, 0.0, tank.global_position.z).distance_to(goal) if tank != null else -1.0,
				orders.current(unit_name).get("verb", "(none)"), brain.choice.get("option", "?") if brain != null else "?",
				tank != null and tank.is_alive()])
	print("MEASURE element_vs_player %d of %d units of the ordered squad reached the spot; %d orders from anything but the player: %s" % [
			arrived, roster.size(), stolen["count"], stolen["verbs"]])
	assert_eq(stolen["count"], 0, "nothing but the player orders the squad the player is commanding")
