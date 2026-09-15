extends TestCase
## Round 3 combat X1 (checkpoint CP2): contract K2 in _agents/workstreams.md. Weapon profile v3 fields, the
## `weapon_fired` / `projectile_impact` events every weapon path emits, and `incoming_projectiles` for dodging.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Open lane on the west side of the arena.
const LANE_X := -100.0
const V3_FIELDS := ["fire_model", "reload_s", "burst_count", "burst_interval_s", "projectile_speed_mps", "spread_deg",
		"damage", "penetration", "splash_radius"]
const FIRED_FIELDS := ["tick", "shooter", "weapon", "fire_model", "muzzle", "direction", "projectile_id"]
const IMPACT_FIELDS := ["tick", "projectile_id", "position", "normal", "weak_spot", "damage", "killed"]


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(11, 0.0)
	return game_match


func _unshielded(tank: Tank) -> void:
	tank.max_shield = 0.0
	tank.shield = 0.0


## Record every K2 event a match emits.
func _record(game_match: Match) -> Dictionary:
	var events := {"fired": [], "impacts": []}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void: events["fired"].append(event))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void: events["impacts"].append(event))
	return events


func _hold_fire(shooter: Tank, target_point: Vector3, others: Array, ticks: int) -> void:
	for tick in ticks:
		shooter.command = TankCommand.new(0.0, 0.0, target_point, true)
		for other: Tank in others:
			other.command = TankCommand.new()
		await tree.physics_frame


# ---- Profile v3 -----------------------------------------------------------------------------

func test_every_weapon_has_the_v3_fields() -> void:
	for weapon_id: String in Weapons.PROFILES:
		var weapon := Weapons.profile(weapon_id)
		for key: String in V3_FIELDS:
			assert_true(weapon.has(key), "%s is missing %s" % [weapon_id, key])
		assert_true(Weapons.FIRE_MODELS.has(weapon.get("fire_model")), "%s has a known fire model (%s)" % [weapon_id, weapon.get("fire_model")])
		assert_true(int(weapon.get("burst_count", 0)) >= 1, "%s fires at least one round per trigger pull" % weapon_id)
		assert_true(float(weapon.get("projectile_speed_mps", -1.0)) >= 0.0, "%s: 0 = hitscan, else a speed" % weapon_id)
		assert_near(float(weapon.get("reload_s", -1.0)), float(weapon.get("reload", -2.0)), 0.0001,
				"%s: reload_s and the round-2 reload key never drift apart" % weapon_id)


func test_fire_models_match_the_mechanics() -> void:
	assert_eq(Weapons.profile("cannon")["fire_model"], "shell", "the tank fires shells")
	assert_eq(Weapons.profile("autocannon")["fire_model"], "burst", "the IFV fires bursts")
	assert_eq(Weapons.profile("machine_gun")["fire_model"], "stream", "the scout fires a stream")
	assert_eq(Weapons.profile("laser")["fire_model"], "beam", "the Lancer fires a beam")
	assert_eq(Weapons.profile("mortar")["fire_model"], "arc", "artillery lobs arcs")
	for weapon_id: String in Weapons.PROFILES:
		var weapon := Weapons.profile(weapon_id)
		var hitscan := float(weapon["projectile_speed_mps"]) == 0.0
		match int(weapon["kind"]):
			Weapons.Kind.PROJECTILE, Weapons.Kind.ARC:
				assert_true(not hitscan, "%s flies, so it has a speed" % weapon_id)
			_:
				assert_true(hitscan, "%s is instant (projectile_speed_mps 0)" % weapon_id)


# ---- weapon_fired and projectile_impact ------------------------------------------------------

func test_a_cannon_shell_reports_its_shot_and_its_hit() -> void:
	var game_match := _setup()
	var events := _record(game_match)
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	target.global_position = Vector3(LANE_X, 0.0, -10.0)
	target.rotation.y = PI / 2.0  # its side toward the gunner
	await wait_physics_frames(2)
	await _hold_fire(shooter, target.global_position, [target], 60)
	assert_true(events["fired"].size() >= 1, "the shot was announced")
	assert_true(events["impacts"].size() >= 1, "and its hit")
	if events["fired"].is_empty() or events["impacts"].is_empty():
		return
	var fired: Dictionary = events["fired"][0]
	for key: String in FIRED_FIELDS:
		assert_true(fired.has(key), "weapon_fired has %s" % key)
	assert_eq(fired["shooter"], "Gunner", "shooter is the tank's name")
	assert_eq(fired["weapon"], "cannon", "weapon is the profile id")
	assert_eq(fired["fire_model"], "shell", "fire model copied from the profile")
	assert_eq((fired["muzzle"] as Array).size(), 3, "muzzle is [x, y, z]")
	assert_eq((fired["direction"] as Array).size(), 3, "direction is [x, y, z]")
	assert_true(float(fired["direction"][2]) < -0.9, "the shell heads north toward the target")
	var impact: Dictionary = events["impacts"][0]
	for key: String in IMPACT_FIELDS:
		assert_true(impact.has(key), "projectile_impact has %s" % key)
	assert_eq(impact["projectile_id"], fired["projectile_id"], "the hit pairs with its shot")
	assert_eq(impact.get("target", ""), "Target", "it names what it hit")
	assert_eq(impact.get("face", ""), "side", "and the face it struck")
	assert_true(int(impact["tick"]) > int(fired["tick"]), "a shell takes time to arrive")
	assert_near(float(impact["damage"]), float(target.max_health - target.health) + target.max_shield - target.shield, 1.0,
			"damage is the shield and hull the hit took")
	assert_eq(impact["killed"], false, "one shell doesn't kill a tank")
	assert_eq((impact["position"] as Array).size(), 3, "position is [x, y, z]")
	assert_eq((impact["normal"] as Array).size(), 3, "normal is [x, y, z]")


func test_a_rear_hit_is_flagged_as_a_weak_spot() -> void:
	var game_match := _setup()
	var events := _record(game_match)
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	target.global_position = Vector3(LANE_X, 0.0, -10.0)
	target.rotation.y = 0.0  # facing north, away from the gunner
	_unshielded(target)
	await wait_physics_frames(2)
	await _hold_fire(shooter, target.global_position, [target], 60)
	assert_true(not events["impacts"].is_empty(), "the shell hit")
	if events["impacts"].is_empty():
		return
	assert_eq(events["impacts"][0].get("face", ""), "rear", "struck the rear")
	assert_eq(events["impacts"][0]["weak_spot"], true, "a rear hit is a weak spot")


func test_a_shell_into_a_wall_reports_an_impact_without_a_target() -> void:
	var game_match := _setup()
	var events := _record(game_match)
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	shooter.global_position = Vector3(0.0, 0.0, 100.0)
	shooter.rotation.y = PI  # facing the south wall at z = 120
	await wait_physics_frames(2)
	await _hold_fire(shooter, Vector3(0.0, 1.0, 130.0), [], 90)
	assert_true(not events["impacts"].is_empty(), "the wall stopped the shell")
	if events["impacts"].is_empty():
		return
	assert_true(not events["impacts"][0].has("target"), "no target on a wall hit")
	assert_eq(events["impacts"][0]["weak_spot"], false, "walls have no weak spots")
	assert_eq(float(events["impacts"][0]["damage"]), 0.0, "and take no damage")


func test_hitscan_weapons_report_shot_and_hit_on_the_same_tick() -> void:
	for unit_id in ["scout", "lancer"]:
		var game_match := _setup()
		var events := _record(game_match)
		var shooter := game_match.spawn_tank("Shooter_" + unit_id, 0, Match.Team.GREEN, unit_id)
		var target := game_match.spawn_tank("Target_" + unit_id, 0, Match.Team.RUST, "tank")
		shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
		target.global_position = Vector3(LANE_X, 0.0, 0.0)
		await wait_physics_frames(2)
		await _hold_fire(shooter, target.global_position, [target], 40)
		assert_true(not events["fired"].is_empty() and not events["impacts"].is_empty(), "%s: shot and hit" % unit_id)
		if events["fired"].is_empty() or events["impacts"].is_empty():
			break
		var fired: Dictionary = events["fired"][0]
		var impact: Dictionary = events["impacts"][0]
		assert_eq(impact["projectile_id"], fired["projectile_id"], "%s: the hit pairs with its shot" % unit_id)
		assert_eq(impact["tick"], fired["tick"], "%s: hitscan lands the same tick" % unit_id)
		assert_eq(fired["fire_model"], Weapons.profile(shooter.weapon_id)["fire_model"], "%s: fire model" % unit_id)
		assert_eq(impact.get("target", ""), String(target.name), "%s: it names the target" % unit_id)
		assert_eq(impact.get("face", ""), "front", "%s: struck the front" % unit_id)
		for node: Node in tree.root.get_children():
			if node is Match or node is Arena:
				node.queue_free()
		await wait_physics_frames(2)


func test_a_mortar_burst_reports_one_impact_with_its_victims() -> void:
	var game_match := _setup()
	var events := _record(game_match)
	var battery := game_match.spawn_tank("Battery", 0, Match.Team.GREEN, "artillery")
	var eyes := game_match.spawn_tank("Eyes", 0, Match.Team.GREEN, "scout")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	battery.global_position = Vector3(LANE_X, 0.0, 60.0)
	eyes.global_position = Vector3(LANE_X + 10.0, 0.0, 40.0)
	target.global_position = Vector3(LANE_X, 0.0, 0.0)
	_unshielded(target)
	await wait_physics_frames(2)
	await _hold_fire(battery, target.global_position, [eyes, target], 150)
	assert_true(not events["fired"].is_empty(), "the round was lobbed")
	assert_true(not events["impacts"].is_empty(), "and burst")
	if events["fired"].is_empty() or events["impacts"].is_empty():
		return
	assert_eq(events["fired"][0]["fire_model"], "arc", "an arc")
	var burst: Dictionary = events["impacts"][0]
	assert_eq(burst["projectile_id"], events["fired"][0]["projectile_id"], "the burst pairs with its round")
	assert_true(burst.has("victims"), "a burst lists everyone it hurt")
	assert_true(int(burst["tick"]) - int(events["fired"][0]["tick"]) >= 60, "60 m at 40 m/s flies over a second")
	if burst.get("target", "") == "Target":
		assert_true(float(burst["damage"]) > 0.0, "the burst hurt its target")


func test_a_killing_hit_says_so() -> void:
	var game_match := _setup()
	var events := _record(game_match)
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "scout")
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	target.global_position = Vector3(LANE_X, 0.0, -10.0)
	_unshielded(target)
	target.health = 1
	await wait_physics_frames(2)
	await _hold_fire(shooter, target.global_position, [target], 60)
	var killing: Array = events["impacts"].filter(func(event: Dictionary) -> bool: return event["killed"])
	assert_eq(killing.size(), 1, "exactly one impact killed the scout")


# ---- incoming_projectiles --------------------------------------------------------------------

func test_a_unit_sees_the_shell_coming_at_it_and_nothing_else() -> void:
	var game_match := _setup()
	var shooter := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	var bystander := game_match.spawn_tank("Bystander", 0, Match.Team.RUST, "tank")
	shooter.global_position = Vector3(LANE_X, 0.0, 40.0)
	target.global_position = Vector3(LANE_X, 0.0, -20.0)
	bystander.global_position = Vector3(LANE_X + 30.0, 0.0, -20.0)
	await wait_physics_frames(2)
	for tick in 60:  # the turret starts on target
		shooter.command = TankCommand.new(0.0, 0.0, target.global_position, false)
		await tree.physics_frame
	var fired := [false]
	game_match.weapon_fired.connect(func(_event: Dictionary) -> void: fired[0] = true)
	var ticks := 0
	while not fired[0] and ticks < 30:
		shooter.command = TankCommand.new(0.0, 0.0, target.global_position, true)
		await tree.physics_frame
		ticks += 1
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, false)
	await wait_physics_frames(5)
	var incoming := game_match.incoming_projectiles(target)
	assert_eq(incoming.size(), 1, "one shell inbound")
	assert_eq(game_match.incoming_projectiles(bystander).size(), 0, "nothing heading at the bystander")
	assert_eq(game_match.incoming_projectiles(shooter).size(), 0, "a gunner isn't threatened by its own shell")
	if incoming.size() != 1:
		return
	var threat: Dictionary = incoming[0]
	for key in ["position", "velocity", "eta_ticks", "damage_estimate"]:
		assert_true(threat.has(key), "an incoming projectile has %s" % key)
	var speed := float(Weapons.profile("cannon")["projectile_speed_mps"])
	var distance := Vector2((threat["position"] as Vector3).x - target.global_position.x,
			(threat["position"] as Vector3).z - target.global_position.z).length()
	assert_near(float(threat["eta_ticks"]), distance / speed * 60.0, 3.0, "eta = distance / speed in ticks")
	assert_near((threat["velocity"] as Vector3).length(), speed, 0.5, "velocity is the shell's")
	assert_true(float(threat["damage_estimate"]) > 0.0, "a cannon shell is worth dodging")


func test_a_unit_sees_a_mortar_round_that_will_land_on_it() -> void:
	var game_match := _setup()
	var battery := game_match.spawn_tank("Battery", 0, Match.Team.GREEN, "artillery")
	var eyes := game_match.spawn_tank("Eyes", 0, Match.Team.GREEN, "scout")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	var far := game_match.spawn_tank("Far", 0, Match.Team.RUST, "tank")
	battery.global_position = Vector3(LANE_X, 0.0, 60.0)
	eyes.global_position = Vector3(LANE_X + 10.0, 0.0, 40.0)
	target.global_position = Vector3(LANE_X, 0.0, -20.0)
	far.global_position = Vector3(LANE_X + 60.0, 0.0, -20.0)
	await wait_physics_frames(2)
	var fired := [false]
	game_match.weapon_fired.connect(func(_event: Dictionary) -> void: fired[0] = true)
	var ticks := 0
	while not fired[0] and ticks < 120:
		battery.command = TankCommand.new(0.0, 0.0, target.global_position, true)
		await tree.physics_frame
		ticks += 1
	battery.command = TankCommand.new(0.0, 0.0, target.global_position, false)
	await wait_physics_frames(2)
	var incoming := game_match.incoming_projectiles(target)
	assert_eq(incoming.size(), 1, "the round is coming down near the target")
	assert_eq(game_match.incoming_projectiles(far).size(), 0, "not near the far tank")
	if incoming.size() == 1:
		assert_true(int(incoming[0]["eta_ticks"]) > 60, "80 m at 40 m/s: two seconds to move")


# ---- Match.orders (K1 field for control) ------------------------------------------------------

func test_the_match_has_a_slot_for_orders() -> void:
	var game_match := _setup()
	assert_true("orders" in game_match, "Match.orders exists for control's Orders (K1)")
