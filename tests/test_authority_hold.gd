extends TestCase
## Round 45 (engage E2, his Gorge playtest): a squad HE tells to hold, holds. On his replay the hold of his last scout ran
## react_to_contact ("return fire, take cover, report"), whose plan sent the crew attack-moving 15 m toward the enemy every
## update: 30 m into the gap he was keeping it out of. Under his hold no drill runs; the crews stand, turn and fire (the
## brain's HOLD). The CPU's holds keep their drills (C45.5: the CPU gives no player orders). `--player-authority=off` is
## the escape.


func teardown() -> void:
	Drills.PLAYER_AUTHORITY = true
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	return DoctrineTable.load_table("gangs").get("table")


## `count` of our crews round the origin, one enemy `distance` m north of them, seen just now and shooting.
func _situation(count: int, distance: float) -> Dictionary:
	var members: Array = []
	for i in count:
		members.append({"name": "Green_%d" % (i + 1), "position": Vector3(i * 8.0, 0.0, 0.0), "forward": Vector3.FORWARD,
				"role": "scout", "unit": "gang_scout", "speed": 15.0, "range": 45.0, "effective_range": 40.0,
				"sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": true})
	var contact := {"name": "Rust_Guns_2", "position": Vector3(0.0, 0.0, -distance), "role": "tank", "unit": "tank",
			"visible": true, "age": 300, "distance": distance, "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0}
	return {"tick": 3000, "team": 0, "center": Vector3.ZERO, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": [contact], "terrain": "open",
			"threat": ElementSituation.threat_from([contact], true), "composition": "light", "strength": 100.0 * count,
			"enemy_strength": 200.0, "taking_fire": true, "arrived": true}


func _state(player: bool) -> Dictionary:
	return {"task": {"verb": "hold"}, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": true, "heading": Vector3.FORWARD, "seats": {},
			"player": player}


## Metres each crew's order would take it from where it stands (0 for an order with no point).
func _moves(plan: Dictionary, situation: Dictionary) -> Dictionary:
	var result := {}
	for member: Dictionary in situation["members"]:
		var order: Dictionary = plan["orders"].get(String(member["name"]), {})
		var to: Variant = order.get("to")
		result[String(member["name"])] = (to as Vector3).distance_to(member["position"]) if to is Vector3 else 0.0
	return result


func test_his_lone_scout_on_hold_under_fire_stands_and_fires_instead_of_driving_at_the_enemy() -> void:
	var situation := _situation(1, 60.0)
	var state := _state(true)
	assert_eq(String(Drills.select(situation, state, _table())["drill"]), "", "his hold runs no contact drill")
	var plan := ElementPlan.build(situation, state, _table())
	var order: Dictionary = plan["orders"]["Green_1"]
	assert_eq(String(order["verb"]), "hold", "the crew is told to hold (the brain turns it and fires), not %s" % order)
	assert_true(float(_moves(plan, situation)["Green_1"]) <= 2.0, "and it is sent nowhere: %s" % _moves(plan, situation))


func test_his_whole_squad_on_hold_does_not_advance_on_contact_either() -> void:
	# Every task does what its name says (round 6, X5): a hold that sends crews 15 m at the enemy is not a hold.
	var situation := _situation(4, 60.0)
	var plan := ElementPlan.build(situation, _state(true), _table())
	for unit_name: String in plan["orders"]:
		var verb := String(plan["orders"][unit_name]["verb"])
		assert_true(verb != "attack_move" and verb != "attack", "%s is not sent at the enemy (%s)" % [unit_name, verb])
	var moved := _moves(plan, situation)
	for unit_name: String in moved:
		# A halt may square a crew onto its halt seat; it never takes one toward the contact by the drill's 15 m.
		assert_true(float(moved[unit_name]) < 15.0, "%s stays at its halt (%s)" % [unit_name, moved])


func test_the_cpus_hold_still_returns_fire_and_takes_cover() -> void:
	# C45.5: the computer gives no player orders; its holds keep the drill exactly as before.
	assert_eq(String(Drills.select(_situation(1, 60.0), _state(false), _table())["drill"]), "react_to_contact",
			"a CPU squad on hold still reacts to contact")


func test_the_switch_off_is_the_old_game() -> void:
	Drills.PLAYER_AUTHORITY = false
	assert_eq(String(Drills.select(_situation(1, 60.0), _state(true), _table())["drill"]), "react_to_contact",
			"--player-authority=off: his hold runs the contact drill as it did in round 44")


func test_an_order_he_gave_himself_is_marked_his_and_a_pointless_hold_is_where_it_stands() -> void:
	var his := OrderFeed.normalize({"id": 1, "verb": "hold", "source": "player", "goal": [3.0, 4.0]})
	assert_true(bool(his["player"]), "his own hold carries `player`")
	assert_true(bool(his["here"]), "a hold he gave no point holds where the crew comes to rest")
	var element := OrderFeed.normalize({"id": 2, "verb": "move", "source": "element", "to": [1.0, 2.0]})
	assert_true(not bool(element["player"]) and not bool(element["here"]), "an element's move is neither")
	var pointed := OrderFeed.normalize({"id": 3, "verb": "hold", "source": "player", "to": [1.0, 2.0]})
	assert_true(not bool(pointed["here"]), "a hold on a point he clicked holds that point")
