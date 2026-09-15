extends TestCase
## Round 3 combat X3: weak spots that read. Flanks punish (side and rear through armor thickness), and a round into the
## engine deck (the rear, within Armor.WEAK_SPOT_ARC_DEG of dead astern) is a weak spot: flagged in projectile_impact
## and fought through thinner armor, so even light guns hurt there. Hand-placed shots in a real match scene.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0
const NORTH := Vector3(0, 0, -1)


func test_the_engine_deck_is_a_narrow_cone_inside_the_rear() -> void:
	assert_true(Armor.is_weak_spot(NORTH, NORTH), "a round travelling the way the hull faces hits the engine deck")
	var off_astern := NORTH.rotated(Vector3.UP, deg_to_rad(Armor.WEAK_SPOT_ARC_DEG - 5.0))
	var wide := NORTH.rotated(Vector3.UP, deg_to_rad(Armor.WEAK_SPOT_ARC_DEG + 8.0))
	assert_true(Armor.is_weak_spot(NORTH, off_astern), "%.0f° off astern still does" % (Armor.WEAK_SPOT_ARC_DEG - 5.0))
	assert_true(not Armor.is_weak_spot(NORTH, wide), "%.0f° off astern is plain rear armor" % (Armor.WEAK_SPOT_ARC_DEG + 8.0))
	assert_eq(Armor.facing(NORTH, wide), Armor.Facing.REAR, "setup: still the rear face")
	assert_true(not Armor.is_weak_spot(NORTH, Vector3(0, 0, 1)), "a head-on round never")
	assert_true(Armor.WEAK_SPOT_ARC_DEG < Armor.ARC_DEG, "narrower than the rear arc")


func test_flanks_punish_through_armor_for_every_direct_weapon() -> void:
	for weapon_id in ["cannon", "autocannon", "machine_gun", "laser"]:
		var weapon := Weapons.profile(weapon_id)
		for unit_id in ["tank", "ifv"]:
			var front := Match.armor_multiplier(weapon, unit_id, "front")
			var side := Match.armor_multiplier(weapon, unit_id, "side")
			var rear := Match.armor_multiplier(weapon, unit_id, "rear")
			var deck := Match.weak_spot_multiplier(weapon, unit_id)
			assert_true(side > front and rear > side or front >= Armor.PENETRATION_CAP,
					"%s into a %s: front %.2f < side %.2f < rear %.2f" % [weapon_id, unit_id, front, side, rear])
			assert_true(deck >= rear, "%s: the engine deck %.2f is at least the rear %.2f" % [weapon_id, deck, rear])
	var cannon := Weapons.profile("cannon")
	assert_true(Match.armor_multiplier(cannon, "tank", "side") >= 1.8 * Match.armor_multiplier(cannon, "tank", "front"),
			"a tank shell into a tank's side does about double the front")
	var mg := Weapons.profile("machine_gun")
	assert_true(Match.weak_spot_multiplier(mg, "tank") >= 1.5 * Match.armor_multiplier(mg, "tank", "rear"),
			"a scout's stream into a tank's engine deck hurts far more than into its plain rear (%.2f vs %.2f)"
			% [Match.weak_spot_multiplier(mg, "tank"), Match.armor_multiplier(mg, "tank", "rear")])


## Hull damage a scout's one-second stream does to an unshielded tank facing north, from `bearing_deg` off dead astern
## (0 = straight behind it), and the impacts' weak-spot flags.
func _stream_from(bearing_deg: float) -> Dictionary:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(9, 0.0)
	var flags := {"weak": 0, "plain": 0}
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if event.has("target"):
			flags["weak" if event["weak_spot"] else "plain"] += 1)
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	target.global_position = Vector3(LANE_X, 0.0, 0.0)
	target.rotation.y = 0.0  # facing north (Rust spawns facing south)
	target.max_shield = 0.0
	target.shield = 0.0
	# Behind a north-facing tank is south (+z); rotate that point around the tank by the bearing.
	var offset := Vector3(0.0, 0.0, 18.0).rotated(Vector3.UP, deg_to_rad(bearing_deg))
	scout.global_position = target.global_position + offset
	scout.look_at(target.global_position, Vector3.UP)
	await wait_physics_frames(2)
	for tick in 60:
		scout.command = TankCommand.new(0.0, 0.0, target.global_position + Vector3.UP, true)
		target.command = TankCommand.new()
		await tree.physics_frame
	var result := {"damage": target.max_health - target.health, "weak": flags["weak"], "plain": flags["plain"]}
	for node: Node in tree.root.get_children():
		if node is Match or node is Arena:
			node.queue_free()
	await wait_physics_frames(2)
	return result


func test_a_scout_on_a_tanks_engine_deck_hurts_and_says_so() -> void:
	var deck: Dictionary = await _stream_from(0.0)
	var quarter: Dictionary = await _stream_from(Armor.WEAK_SPOT_ARC_DEG + 12.0)
	assert_true(int(deck["weak"]) >= 5 and int(deck["plain"]) == 0, "dead astern: every hit is a weak spot (%s)" % deck)
	assert_true(int(quarter["weak"]) == 0 and int(quarter["plain"]) >= 5, "off the quarter: plain rear hits (%s)" % quarter)
	assert_true(float(deck["damage"]) >= 1.4 * float(quarter["damage"]),
			"the engine deck takes far more of the stream (%d vs %d hull)" % [deck["damage"], quarter["damage"]])


func test_two_rear_shells_still_needed_for_a_full_tank() -> void:
	# The weak spot sharpens flanking without making a tank shell a one-shot kill from full health.
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(4, 0.0)
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, "tank")
	var gunner := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	target.global_position = Vector3(LANE_X, 0.0, 0.0)
	target.rotation.y = 0.0  # facing north (Rust spawns facing south)
	gunner.global_position = Vector3(LANE_X, 0.0, 25.0)  # dead astern of the north-facing target
	var weak := [false]
	game_match.projectile_impact.connect(func(event: Dictionary) -> void: weak[0] = weak[0] or bool(event["weak_spot"]))
	await wait_physics_frames(2)
	for tick in 60:
		gunner.command = TankCommand.new(0.0, 0.0, target.global_position + Vector3.UP, tick == 0)
		target.command = TankCommand.new()
		await tree.physics_frame
	assert_true(weak[0], "setup: the shell hit the engine deck")
	assert_true(target.is_alive(), "one engine-deck shell leaves a full tank alive")
	assert_true(target.health <= target.max_health / 4, "but barely (%d of %d hull)" % [target.health, target.max_health])
