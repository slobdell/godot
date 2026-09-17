extends TestCase
## X3 (round 4 combat): heavies shielding the fragile. The lead: *"tanks would probably want to provide protective
## cover for weaker units"*. There is deliberately NO guard buff — a shell stops at the first hull it meets, and
## armor facing decides what that costs — so this file's job is to prove position really does the work, and to say
## by how much.
##
##   make remote T="test FILTER=combat_screening"   (every MEASURE line feeds balance.md)

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## An empty stretch of the west side: foundry's cover is elsewhere (a crate sits at the arena centre).
const LANE_X := -95.0
## Where the shooter, the screen and the protected unit stand along z.
const SHOOTER_Z := 40.0
const SCREEN_Z := -10.0
const PROTECTED_Z := -18.0


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.seed_spawns(77, 0.0)  # trip-up 38: shot spread is a dice roll until the RNG is seeded
	# Destroyed means destroyed. Without this a killed unit respawns at full health in its spawn slot four seconds
	# later, and "how much did it lose?" reads as zero (which is exactly what this file measured the first time).
	game_match.elimination = true
	return game_match


func _dispose(game_match: Match) -> void:
	(game_match.get_meta("arena") as Node).queue_free()
	game_match.queue_free()
	await wait_physics_frames(2)


## A Rust shooter of `shooter_unit` firing at a Green Lancer, optionally with a Green tank interposed at
## `screen_offset_x` (INF = no screen at all). Returns what each Green unit lost over `seconds`.
func _volley(shooter_unit: String, screen_offset_x: float, seconds: float) -> Dictionary:
	var game_match := _setup()
	var green: Array = [{"unit": "lancer"}]
	if is_finite(screen_offset_x):
		green.append({"unit": "tank"})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A", "units": green}]}),
			"", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
			"units": [{"unit": shooter_unit}]}]}), "", "rust loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var protected_unit := game_match.tanks.get_node("Green_A_1") as Tank
	var shooter := game_match.tanks.get_node("Rust_A_1") as Tank
	protected_unit.global_position = Vector3(LANE_X, 0.0, PROTECTED_Z)
	protected_unit.rotation.y = PI  # facing the shooter: this measures screening, not flanking
	shooter.global_position = Vector3(LANE_X, 0.0, SHOOTER_Z)
	var screen: Tank = null
	if is_finite(screen_offset_x):
		screen = game_match.tanks.get_node("Green_A_2") as Tank
		screen.global_position = Vector3(LANE_X + screen_offset_x, 0.0, SCREEN_Z)
		screen.rotation.y = PI
	await wait_physics_frames(2)  # the physics server needs a step before a ray can see the hulls we just moved
	var before := {"protected": protected_unit.health + protected_unit.shield,
			"screen": (screen.health + screen.shield) if screen != null else 0.0}
	var screened_at_start := game_match.screen_for(protected_unit, shooter.global_position)
	for tick in int(seconds * float(SimClock.TICK_RATE)):
		shooter.command = TankCommand.new(0.0, 0.0, protected_unit.global_position, true)
		protected_unit.command = TankCommand.new(0.0, 0.0, shooter.global_position, false)
		if screen != null:
			screen.command = TankCommand.new(0.0, 0.0, shooter.global_position, false)
		await wait_physics_frames(1)
	var result := {"protected_lost": snappedf(before["protected"] - (protected_unit.health + protected_unit.shield), 0.1),
			"screen_lost": snappedf(before["screen"] - ((screen.health + screen.shield) if screen != null else 0.0), 0.1),
			"protected_alive": protected_unit.is_alive(),
			"screened": screened_at_start != null and screen != null and screened_at_start == screen,
			"shots": game_match.stats["shots"][Match.Team.RUST], "hits": game_match.stats["hits"][Match.Team.RUST],
			"where": [snappedf(protected_unit.global_position.x, 0.1), snappedf(protected_unit.global_position.z, 0.1)],
			"shooter_at": [snappedf(shooter.global_position.x, 0.1), snappedf(shooter.global_position.z, 0.1)]}
	await _dispose(game_match)
	return result


func test_a_tank_parked_in_front_of_a_lancer_really_does_save_it() -> void:
	# 18 s is four shells at the cannon's 5 s reload: enough to kill the exposed Lancer twice over and not quite
	# enough to break the screening dozer, so the comparison is about who takes the fire, not who runs out first.
	var alone: Dictionary = await _volley("tank", INF, 18.0)
	var behind: Dictionary = await _volley("tank", 0.0, 18.0)
	var beside: Dictionary = await _volley("tank", 10.0, 18.0)
	print("MEASURE screening_vs_cannon alone %s / screened %s / screen_off_the_line %s" % [alone, behind, beside])

	assert_true(int(alone["shots"]) >= 3, "the shooter got a few shells away (%d)" % alone["shots"])
	assert_true(not alone["screened"], "nothing screens a lone Lancer")
	assert_true(float(alone["protected_lost"]) > 100.0, "which costs it dearly (%.0f)" % alone["protected_lost"])
	assert_true(behind["screened"], "a tank on the line IS the Lancer's screen (Match.screen_for finds it)")
	assert_true(float(behind["protected_lost"]) < float(alone["protected_lost"]) * 0.35,
			"and the Lancer loses far less behind it (%.0f vs %.0f alone)" % [behind["protected_lost"], alone["protected_lost"]])
	assert_true(float(behind["screen_lost"]) > 0.0, "because the tank takes the shells instead (%.0f)" % behind["screen_lost"])
	assert_true(behind["protected_alive"], "and survives, where alone it does not (%s)" % alone["protected_alive"])
	assert_true(not beside["screened"], "a tank 10 m off the line screens nothing")
	assert_true(float(beside["protected_lost"]) > float(alone["protected_lost"]) * 0.5,
			"so the Lancer is hit much as if it were alone (%.0f vs %.0f)" % [beside["protected_lost"], alone["protected_lost"]])


func test_the_screen_is_the_cheaper_place_for_a_shell_to_land() -> void:
	# Why interposing is worth doing at all, with no buff anywhere: the same cannon shell meets 8 mm of dozer front
	# instead of 3 mm of utility truck, and the dozer has half again the hull and shield to spend.
	var cannon := Weapons.profile("cannon")
	var on_screen := Match.armor_multiplier(cannon, "tank", "front")
	var on_fragile := Match.armor_multiplier(cannon, "lancer", "front")
	var screen_pool := float(Units.stat("tank", "max_health")) + float(Units.stat("tank", "max_shield"))
	var fragile_pool := float(Units.stat("lancer", "max_health")) + float(Units.stat("lancer", "max_shield"))
	var shells_to_kill := {"screen": screen_pool / (float(cannon["damage"]) * on_screen),
			"fragile": fragile_pool / (float(cannon["damage"]) * on_fragile)}
	print("MEASURE interposition_value cannon x%.2f on a dozer front vs x%.2f on a Lancer front; shells to kill %s"
			% [on_screen, on_fragile, shells_to_kill])
	assert_true(on_screen < on_fragile * 0.6, "a shell hurts the heavy far less (x%.2f vs x%.2f)" % [on_screen, on_fragile])
	assert_true(shells_to_kill["screen"] > shells_to_kill["fragile"] * 1.8,
			"so the heavy soaks roughly twice as many shells (%.1f vs %.1f)" % [shells_to_kill["screen"], shells_to_kill["fragile"]])


func test_what_a_screen_cannot_stop() -> void:
	# Position does the work, so anything that doesn't travel along the ground goes straight past it. The brains and
	# the drills need to know that screening is not blanket protection.
	var screened_arc: Dictionary = await _volley("artillery", 0.0, 30.0)
	print("MEASURE screening_vs_arc screened %s" % [screened_arc])
	assert_true(float(screened_arc["protected_lost"]) > 0.0,
			"a lobbed round comes down behind the screen and hurts the Lancer anyway (%.0f)" % screened_arc["protected_lost"])


func test_a_wreck_does_not_screen() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "lancer"}, {"unit": "tank"}]}]}), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
			"units": [{"unit": "tank"}]}]}), "", "rust loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var protected_unit := game_match.tanks.get_node("Green_A_1") as Tank
	var screen := game_match.tanks.get_node("Green_A_2") as Tank
	var shooter := game_match.tanks.get_node("Rust_A_1") as Tank
	protected_unit.global_position = Vector3(LANE_X, 0.0, PROTECTED_Z)
	screen.global_position = Vector3(LANE_X, 0.0, SCREEN_Z)
	shooter.global_position = Vector3(LANE_X, 0.0, SHOOTER_Z)
	await wait_physics_frames(2)
	assert_true(game_match.screen_for(protected_unit, shooter.global_position) == screen, "a living tank screens")
	screen.apply_damage(screen.health)
	await wait_physics_frames(2)
	assert_eq(game_match.screen_for(protected_unit, shooter.global_position), null,
			"a wreck does not: its collision is off, so shells fly through it (the stretch item would change this)")
	await _dispose(game_match)


func test_an_enemy_hull_is_not_a_screen() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "lancer"}]}]}), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
			"units": [{"unit": "tank"}, {"unit": "tank"}]}]}), "", "rust loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var protected_unit := game_match.tanks.get_node("Green_A_1") as Tank
	var enemy_between := game_match.tanks.get_node("Rust_A_1") as Tank
	var shooter := game_match.tanks.get_node("Rust_A_2") as Tank
	protected_unit.global_position = Vector3(LANE_X, 0.0, PROTECTED_Z)
	enemy_between.global_position = Vector3(LANE_X, 0.0, SCREEN_Z)
	shooter.global_position = Vector3(LANE_X, 0.0, SHOOTER_Z)
	await wait_physics_frames(2)
	assert_eq(game_match.screen_for(protected_unit, shooter.global_position), null,
			"an enemy hull in the way is a friendly-fire problem for them, not cover for us")
	await _dispose(game_match)
