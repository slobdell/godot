extends TestCase
## HUD messages (overnight backlog item 3): what the player is told, and when.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var _messages: Array = []


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var squad := {"name": "Alpha", "formation": "wedge", "verb": "hold", "tanks": [{"weapon": "cannon"}, {"weapon": "cannon"}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "Us", "squads": [squad]}), "", "setup: player doctrine")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "Them", "squads": [{"name": "X", "tanks": [{}, {}]}]}), "",
			"setup: enemy doctrine")
	game_match.elimination = true
	var announcer := MatchAnnouncer.new()
	announcer.game_match = game_match
	game_match.add_child(announcer)
	_messages = []
	announcer.announced.connect(func(text: String, severity: int) -> void: _messages.append([text, severity]))
	return [game_match, announcer]


func _said(fragment: String) -> Array:
	for message in _messages:
		if String(message[0]).contains(fragment):
			return message
	return []


func test_losses_succession_and_victory_are_announced() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var alpha_1 := game_match.tanks.get_node("Green_Alpha_1") as Tank
	game_match.tanks.get_node("Rust_X_1").apply_damage(10000)
	game_match._score_kill(Match.Team.GREEN, "Green_Alpha_2", game_match.tanks.get_node("Rust_X_1"))
	assert_eq(_said("Enemy tank destroyed"), ["Enemy tank destroyed (1 enemies left)", Hud.INFO], "an enemy kill is good news")
	alpha_1.apply_damage(10000)
	game_match._score_kill(Match.Team.RUST, "Rust_X_2", alpha_1)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(_said("lost"), ["Alpha lost Alpha 1 (1 tanks left)", Hud.WARNING], "a loss is a warning, naming the squad")
	assert_eq(_said("commander down"), ["Alpha: commander down, Alpha 2 takes command", Hud.WARNING],
			"succession is announced")
	var rust_2 := game_match.tanks.get_node("Rust_X_2") as Tank
	rust_2.apply_damage(10000)
	await wait_physics_frames(3)
	assert_eq(_said("VICTORY"), ["VICTORY", Hud.INFO], "the result is announced when the last enemy falls")


func test_orders_and_first_contact_are_announced() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var announcer: MatchAnnouncer = setup[1]
	announcer.announce_command("Alpha: Move in Wedge", "")
	announcer.announce_command("", "no squad Zulu on Green")
	assert_eq(_said("Move in Wedge"), ["Alpha: Move in Wedge", Hud.INFO], "an accepted order is acknowledged")
	assert_eq(_said("Can't"), ["Can't: no squad Zulu on Green", Hud.WARNING], "a rejected one explains why")
	var enemy := game_match.tanks.get_node("Rust_X_1") as Tank
	var scout := game_match.tanks.get_node("Green_Alpha_1") as Tank
	scout.global_position = Vector3(-100, 0, 30)
	enemy.global_position = Vector3(-100, 0, -10)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS * 3)
	assert_eq(_said("Contact"), ["Contact: 1 enemy in sight", Hud.WARNING], "first sight of the enemy is called out")
	var contacts := 0
	for message in _messages:
		contacts += 1 if String(message[0]).begins_with("Contact") else 0
	assert_eq(contacts, 1, "and not repeated every intel refresh")
