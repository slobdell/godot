extends TestCase
## Overnight item 3 (brains, the War Rig 4-of-5 case): AN ELEMENT'S DESTINATION IS INSET FROM THE ARENA EDGE BY ITS
## SHAPE. Traced (builder0, foundry faced drag s8, pinned, n 1): a 4-crew War Rig element's destination (6, 116) sat on
## the arena's north edge; clamp_to_arena pulled its two outer seats onto the edge, so the seats' centroid sat 17-20 m
## off the anchor and the centre could never come within ARRIVE_M (12 m): it never arrived. ElementPlan.inset_anchor moves
## the destination inland until every nominal seat is inside the arena (clamp_to_arena stays as the backstop).
## `--anchor-inset=off` is main's rule.


func teardown() -> void:
	ElementPlan.ANCHOR_INSET = true
	super.teardown()


func _members(n: int) -> Array:
	var members: Array = []
	for i in n:
		members.append({"name": "Guns_%d" % i, "unit": "gang_tank", "role": "tank", "position": Vector3(i * 10.0, 0, 0),
				"speed": 9.0})
	return members


## A point on the arena's edge: far out clamped in.
func _edge() -> Vector3:
	return ElementPlan.clamp_to_arena(Vector3(0, 0, 10000.0))


func test_on_the_edge_the_destination_moves_in_until_every_seat_is_inside() -> void:
	var edge := _edge()
	var heading := Vector3(-1, 0, 0)
	var members := _members(4)
	var plain := TacticsFormation.place(members, "swarm", edge, heading, 18.0, {"corridor_m": INF})
	var clipped := 0
	for entry in plain:
		if (entry["to"] as Vector3).distance_to(ElementPlan.clamp_to_arena(entry["to"])) > 0.5:
			clipped += 1
	assert_true(clipped > 0, "setup: laid on the edge, some seats fall outside the arena")
	var inset := ElementPlan.inset_anchor(members, "swarm", edge, 18.0)
	assert_true(inset.distance_to(edge) > 1.0, "the destination moved in (%s from %s)" % [inset, edge])
	for facing: Vector3 in [heading, Vector3.FORWARD, Vector3(1, 0, 0), Vector3.BACK]:
		for entry in TacticsFormation.place(members, "swarm", inset, facing, 18.0, {"corridor_m": INF}):
			assert_true((entry["to"] as Vector3).distance_to(ElementPlan.clamp_to_arena(entry["to"])) < 0.5,
					"every seat inside the arena, facing %s (%s)" % [facing, entry["to"]])


func test_inland_the_destination_is_unchanged() -> void:
	var inland := ElementPlan.clamp_to_arena(Vector3.ZERO)
	var members := _members(4)
	assert_eq(ElementPlan.inset_anchor(members, "swarm", inland, 18.0), inland, "nothing to move")


func test_the_switch_off_is_mains_rule() -> void:
	ElementPlan.ANCHOR_INSET = false
	var edge := _edge()
	assert_eq(ElementPlan.inset_anchor(_members(4), "swarm", edge, 18.0), edge,
			"--anchor-inset=off: the destination stands")


## An element already standing on the inset destination keeps its shape and heading (the plan's `holding`): built twice
## with the first plan's anchor, formation and heading as its state, the second keeps the first's anchor.
func test_an_element_on_its_inset_destination_is_holding() -> void:
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var edge := _edge()
	var members: Array = []
	for i in 4:
		members.append({"name": "Guns_%d" % i, "unit": "gang_tank", "role": "tank", "speed": 9.0, "range": 60.0,
				"effective_range": 45.0, "sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false,
				"forward": Vector3.FORWARD, "position": edge + Vector3(i * 8.0 - 12.0, 0, -40.0)})
	var situation := {"tick": 1000, "team": 0, "center": edge + Vector3(0, 0, -40), "heading": Vector3.FORWARD,
			"leader": "Guns_0", "members": members, "contacts": [], "terrain": "open", "threat": "none",
			"composition": "heavy", "strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}
	var task := {"verb": "move", "to": [edge.x, edge.z]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	var first := ElementPlan.build(situation, state, table)
	assert_true(float(first.get("inset_m", 0.0)) > 1.0, "setup: the destination on the edge was inset (%s m)" % first.get("inset_m"))
	var again := state.duplicate()
	again["anchor"] = first["anchor"]
	again["formation"] = first["formation"]
	again["heading"] = first["heading"]
	again["seats"] = first["seats"]
	var second := ElementPlan.build(situation, again, table)
	assert_true((second["anchor"] as Vector3).distance_to(first["anchor"]) < 0.5, "the inset anchor holds")
	assert_eq(second["formation"], first["formation"], "its shape is kept")
