extends TestCase
## C6: the in-match message feed posts what matters (orders, losses by unit type, squads destroyed,
## friendly fire, the control point) without spamming the player.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var _posts: Array = []


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var messages := HudMessages.new()
	messages.game_match = game_match
	add_to_tree(messages)
	_posts = []
	messages.posted.connect(func(text: String, severity: int) -> void: _posts.append([text, severity]))
	await wait_physics_frames(2)
	return [game_match, messages]


func _kill(game_match: Match, tank_name: String, killer := "Rust_Gun_1") -> Tank:
	var tank := game_match.tanks.get_node(tank_name) as Tank
	tank.apply_damage(tank.health)
	game_match.tank_destroyed.emit(tank, killer)
	return tank


func _texts() -> Array:
	return _posts.map(func(p: Array) -> String: return p[0])


func test_losses_merge_per_squad_and_name_the_unit_type() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var messages: HudMessages = setup[1]
	# Squads mix unit types (catalog v2), so expected names come from the vehicles killed.
	var second := HudMessages.unit_name(_kill(game_match, "Green_Alpha_2"))
	messages.advance(0.5)
	var third := HudMessages.unit_name(_kill(game_match, "Green_Alpha_3"))
	assert_eq(_posts.size(), 0, "losses wait a moment to be merged")
	messages.advance(HudMessages.LOSS_MERGE_SECONDS)
	assert_eq(_texts(), ["Alpha lost 2 vehicles (%s, %s), 1 left" % [second, third]], "two quick losses are one message")
	assert_eq(_posts[0][1], Hud.WARNING, "a loss is a warning")
	_kill(game_match, "Green_Alpha_1")
	messages.advance(HudMessages.LOSS_MERGE_SECONDS)
	assert_eq(_texts().back(), "Alpha destroyed", "the last vehicle: the squad is destroyed")
	assert_eq(_posts.back()[1], Hud.ERROR, "and that is an error-level message")
	var single := _texts().size()
	var bravo := HudMessages.unit_name(_kill(game_match, "Green_Bravo_1"))
	messages.advance(HudMessages.LOSS_MERGE_SECONDS)
	assert_eq(_texts().size(), single + 1, "one loss, one message")
	assert_eq(_texts().back(), "Bravo lost %s, 1 left" % HudMessages.with_article(bravo), "naming the unit type and what's left")
	assert_eq([HudMessages.with_article("Tank"), HudMessages.with_article("IFV"), HudMessages.with_article("Artillery")],
			["a Tank", "an IFV", "an Artillery"], "the article fits the unit name")


func test_friendly_fire_is_called_out() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	_kill(game_match, "Green_Alpha_2", "Green_Bravo_1")
	assert_eq(_texts(), ["Friendly fire! Bravo 1 destroyed Alpha 2"], "a friendly-fire kill is reported at once")


func test_enemy_kills_merge_too() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var messages: HudMessages = setup[1]
	for i in 3:
		var enemy := game_match.spawn_tank("Rust_Gun_%d" % (i + 1), i, Match.Team.RUST)
		await wait_physics_frames(1)
		enemy.apply_damage(enemy.health)
		game_match.tank_destroyed.emit(enemy, "Green_Alpha_1")
	messages.advance(HudMessages.LOSS_MERGE_SECONDS)
	assert_eq(_texts(), ["Destroyed 3 enemies (0 left)"], "a burst of kills is one message")


func test_order_acknowledgements_do_not_spam() -> void:
	var setup: Array = await _setup()
	var messages: HudMessages = setup[1]
	messages.order("Alpha: Move in Wedge", "")
	messages.order("Alpha: Move in Wedge", "")
	messages.order("Bravo: Bound in Line", "")
	assert_eq(_posts.size(), 1, "rapid orders post one acknowledgement (the map's toast confirms each)")
	messages.order("", "no squad selected")
	assert_eq(_texts().back(), "Can't: no squad selected", "a rejected order always explains itself")
	messages.advance(HudMessages.ORDER_COOLDOWN)
	messages.order("Bravo: Bound in Line", "")
	assert_eq(_texts().back(), "Bravo: Bound in Line", "after the cooldown, orders are acknowledged again")


func test_duplicates_and_bursts_are_limited_but_warnings_get_through() -> void:
	var setup: Array = await _setup()
	var messages: HudMessages = setup[1]
	for i in 6:
		messages.post("info %d" % i, Hud.INFO)
	assert_eq(_posts.size(), HudMessages.WINDOW_MAX, "at most %d info messages at once" % HudMessages.WINDOW_MAX)
	assert_true(messages.post("Contact!", Hud.WARNING), "a warning still gets through")
	assert_true(not messages.post("Contact!", Hud.WARNING), "but not the same text twice in a row")
	# A hair past the window: the clock sums frame deltas, so "exactly DUPLICATE_SECONDS later" can land short of it
	# (it did once the tick rate changed what had been summed before this point).
	messages.advance(HudMessages.DUPLICATE_SECONDS + 0.01)
	assert_true(messages.post("Contact!", Hud.WARNING), "later it can repeat")


func test_announcer_lines_pass_through_except_the_ones_replaced() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var messages: HudMessages = setup[1]
	# Use the real announcer's wording, so a change to its format fails here instead of doubling messages.
	var announcer := MatchAnnouncer.new()
	announcer.game_match = game_match
	var said: Array = []
	announcer.announced.connect(func(text: String, severity: int) -> void: said.append([text, severity]))
	var ours := game_match.tanks.get_node("Green_Alpha_2") as Tank
	announcer._on_tank_destroyed(ours, "Rust_Gun_1")
	var enemy := game_match.spawn_tank("Rust_Gun_1", 0, Match.Team.RUST)
	announcer._on_tank_destroyed(enemy, "Green_Alpha_1")
	announcer._on_commander_lost("Green_Alpha_1", "Green_Alpha_2", "Alpha")
	assert_eq(said.size(), 3, "setup: the announcer said three things")
	for line in said:
		messages.relay(line[0], line[1])
	assert_eq(_texts(), ["Alpha: commander down, Alpha 2 takes command"],
			"its loss and kill lines are replaced by ours; everything else passes (%s)" % [_texts()])
	announcer.free()


func test_the_control_point_warns_when_a_side_is_close_to_winning() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var messages: HudMessages = setup[1]
	game_match.control_point = true
	game_match.control_score[Match.Team.RUST] = Match.CONTROL_POINTS_TO_WIN - 10
	messages.advance(0.1)
	messages.advance(0.1)
	assert_eq(_texts(), ["Enemy is 10 points from winning at the center"], "once, when the enemy is close")
	game_match.control_score[Match.Team.GREEN] = Match.CONTROL_POINTS_TO_WIN - 5
	messages.advance(0.1)
	assert_eq(_texts().back(), "5 points to win: hold the center!", "and when we are")
