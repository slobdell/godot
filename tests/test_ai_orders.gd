extends TestCase
## Round-3 X1 (_agents/streams/archive/round3/ai.md): orders always win. Golden decide() tests over hand-built situations: whatever
## the brain was doing, a K1 order (contract K1, read through OrderFeed) decides what it does next; the brain only
## decides how. Scenarios on the real arena: tests/ai_scenarios/scenario_orders.gd.

const GOAL := Vector3(60, 0, 20)


func _situation(overrides: Dictionary = {}) -> Dictionary:
	var situation := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD,
				"health": 300, "max_health": 300, "shield": 150.0, "max_shield": 150.0, "weapon": Weapons.profile("cannon"),
				"unit": "tank", "reload": 1.0},
		"directives": Directives.resolve([]),
		"contacts": [],
		"allies": [],
		"objective": null,
		"objective_radius": 0.0,
		"squad_center": null,
		"cover": [],
		"rally": Vector3(0, 0, 90),
		"resupply": Vector3(0, 0, 90),
		"enemy_base": Vector3(0, 0, -90),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}
	situation.merge(overrides, true)
	return situation


func _enemy(contact_name: String, position: Vector3, overrides: Dictionary = {}) -> Dictionary:
	var contact := {"name": contact_name, "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK,
			"health": 300, "shield": 150, "weapon": "cannon", "unit": "tank", "turret_forward": Vector3.BACK, "visible": true,
			"age": 0, "exposed_face": "front", "facing_ally": false, "aiming_at_me": true, "threatens_me": true}
	contact.merge(overrides, true)
	return contact


func _order(verb: String, overrides: Dictionary = {}) -> Dictionary:
	var order := {"verb": verb, "goal": GOAL, "target": "", "speed": 1.0, "target_alive": false,
			"target_position": null, "target_forward": null, "target_velocity": null}
	order.merge(overrides, true)
	return order


## A tank in the thick of it: hurt, two guns on it, cover nearby, a hide/peek pair, a friend in its lane.
func _busy(order: Variant) -> Dictionary:
	var s := _situation({
		"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40)), _enemy("Rust_A_2", Vector3(15, 0, -45))],
		"cover": [Vector3(8, 0, 4)],
		"cover_fire": {"hide": Vector3(8, 0, 4), "peek": Vector3(10, 0, -2), "target": "Rust_A_1", "score": 0.9},
		"order": order,
	})
	s["self"]["health"] = 90
	s["self"]["shield"] = 0.0
	s["self"]["lane_blocked_ticks"] = 40
	return s


func _choice(s: Dictionary, current: Dictionary = {}) -> String:
	return TankBrain.label(TankBrain.decide(s, current)["choice"])


func test_a_move_order_beats_every_brain_state() -> void:
	for option: String in TankBrain.OPTIONS + TankBrain.ORDER_ONLY_OPTIONS:
		var current := {"option": option, "target": "Rust_A_1" if option in TankBrain.FIGHT_OPTIONS else "", "since": 995}
		assert_eq(_choice(_busy(_order("move")), current), "MOVE", "a move order wins over a committed %s" % option)


func test_without_an_order_the_same_tank_would_not_move_there() -> void:
	assert_true(_choice(_busy(null)) != "MOVE", "control: the busy tank has its own ideas without an order")


func test_hold_follow_and_attack_beat_every_brain_state_too() -> void:
	var friend := {"target": "Green_B_1", "target_alive": true, "target_position": Vector3(20, 0, 20),
			"target_forward": Vector3.FORWARD, "target_velocity": Vector3.ZERO}
	for option: String in TankBrain.OPTIONS + TankBrain.ORDER_ONLY_OPTIONS:
		var current := {"option": option, "target": "Rust_A_2", "since": 995}
		assert_eq(_choice(_busy(_order("hold")), current), "HOLD", "hold wins over %s" % option)
		assert_eq(_choice(_busy(_order("follow", friend)), current), "FOLLOW Green_B_1", "follow wins over %s" % option)
		var attack := _choice(_busy(_order("attack", {"target": "Rust_A_1", "target_alive": true})), current)
		assert_true(attack.ends_with(" Rust_A_1"), "attack fights only its target, not %s (was %s)" % [attack, option])


func test_an_attack_order_on_a_target_out_of_sight_chases_it() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_2", Vector3(0, 0, -30))],
			"order": _order("attack", {"target": "Rust_A_1", "target_alive": true, "target_position": Vector3(-50, 0, -60)})})
	assert_eq(_choice(s), "PURSUE Rust_A_1", "closes in on the ordered target instead of fighting the nearer one")


func test_attack_move_fights_what_it_meets_and_otherwise_drives_on() -> void:
	var quiet := _situation({"order": _order("attack_move")})
	assert_eq(_choice(quiet), "MOVE", "nothing in the way: keep going")
	var met := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -35))], "order": _order("attack_move")})
	var fighting := _choice(met)
	assert_true(fighting.ends_with("Rust_A_1"), "an enemy in reach on the way gets fought (%s)" % fighting)
	var far := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -200), {"aiming_at_me": false})],
			"order": _order("attack_move")})
	assert_eq(_choice(far), "MOVE", "a distant contact doesn't pull it off its route")


func test_attack_move_retreats_only_when_about_to_die() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -35)), _enemy("Rust_A_2", Vector3(5, 0, -35)),
			_enemy("Rust_A_3", Vector3(-5, 0, -35))], "order": _order("attack_move")})
	s["self"]["health"] = 120
	s["self"]["shield"] = 0.0
	assert_true(_choice(s) != "RETREAT", "hurt but not dying: the order stands")
	s["self"]["health"] = 10
	assert_eq(_choice(s), "RETREAT", "about to die: it saves itself")


func test_an_idle_unit_doesnt_roam_off_to_scout_or_contest() -> void:
	var s := _situation({"order": _order("idle"), "objective": GOAL, "objective_radius": 5.0,
			"control": {"center": Vector3.ZERO, "radius": 16.0, "owner": -1}})
	s["self"]["position"] = GOAL
	s["self"]["unit"] = "scout"
	s["self"]["weapon"] = Weapons.profile("machine_gun")
	s["directives"]["leash"] = TankBrain.IDLE_LEASH
	assert_eq(_choice(s), "HOLD", "an idle scout at its post waits there")


func test_an_idle_unit_far_from_its_post_goes_back() -> void:
	var s := _situation({"order": _order("idle"), "objective": GOAL, "objective_radius": 5.0})
	s["directives"]["leash"] = TankBrain.IDLE_LEASH
	assert_eq(_choice(s), "ADVANCE", "63 m from its post with nothing around: regroup")


func test_an_option_on_cooldown_gives_way() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"aiming_at_me": false, "threatens_me": false})],
			"cover_fire": {"hide": Vector3(8, 0, 4), "peek": Vector3(10, 0, -2), "target": "Rust_A_1", "score": 0.9}})
	var before := _choice(s)
	assert_eq(before, "COVER_FIRE Rust_A_1", "setup: fighting from cover is its favorite")
	s["cooldowns"] = {"COVER_FIRE": 1100}
	var current := {"option": "COVER_FIRE", "target": "Rust_A_1", "since": 400}
	assert_true(_choice(s, current) != "COVER_FIRE Rust_A_1", "timed out: something else gets a turn")
	s["cooldowns"] = {"COVER_FIRE": 900}
	assert_eq(_choice(s), "COVER_FIRE Rust_A_1", "the cooldown ends")


func test_order_feed_reads_k1_orders() -> void:
	assert_eq(OrderFeed.normalize({}), {}, "no order")
	assert_eq(OrderFeed.normalize({"verb": "dance"}), {}, "an unknown verb is no order")
	var move := OrderFeed.normalize({"verb": "move", "to": [10, -20], "issued_tick": 7, "queue": false})
	assert_eq(move["goal"], Vector3(10, 0, -20), "to [x, z]")
	assert_eq(move["issued_tick"], 7, "issued_tick")
	# Control's shape (K1 as built): `goal` is this unit's world destination; `slot` is [right, back] in the group frame.
	var slotted := OrderFeed.normalize({"id": 4, "verb": "move", "to": [10, -20], "slot": [10, 10], "goal": [14, -12],
			"issued_tick": 7, "started_tick": 7, "units": ["A", "B"]})
	assert_eq(slotted["goal"], Vector3(14, 0, -12), "the per-unit goal, not the group's `to` or the slot")
	assert_true(OrderFeed.key(move) != OrderFeed.key(slotted), "different orders have different keys")
	var follow := {"id": 5, "verb": "follow", "target": "Green_B_1", "slot": [0, 10], "issued_tick": 9, "started_tick": 9}
	assert_eq(OrderFeed.normalize(follow)["goal"], null, "a follow has no fixed goal (the source's goal_position is live)")
	assert_eq(OrderFeed.key(OrderFeed.normalize(follow)), OrderFeed.key(OrderFeed.normalize(follow.duplicate())), "stable key")
