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


func test_on_the_edge_the_destination_moves_in_by_at_most_one_pitch() -> void:
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
	assert_true(inset.distance_to(edge) <= ElementPlan.INSET_CAP_M + 0.01,
			"by at most INSET_CAP_M (%.1f m)" % inset.distance_to(edge))


## A small shape fits inside the cap: every seat stands inside the arena whichever way it faces.
func test_a_shape_that_fits_inside_the_cap_stands_wholly_inside() -> void:
	var edge := _edge()
	var members := _members(2)
	var inset := ElementPlan.inset_anchor(members, "line", edge, 10.0)
	for facing: Vector3 in [Vector3(-1, 0, 0), Vector3.FORWARD, Vector3(1, 0, 0), Vector3.BACK]:
		for entry in TacticsFormation.place(members, "line", inset, facing, 10.0, {"corridor_m": INF}):
			assert_true((entry["to"] as Vector3).distance_to(ElementPlan.clamp_to_arena(entry["to"])) < 0.5,
					"every seat inside the arena, facing %s (%s)" % [facing, entry["to"]])


## Inland the laid shape's centroid IS the anchor and nothing is clamped: arrival there is measured as before.
func test_inland_the_laid_centroid_is_the_anchor() -> void:
	var inland := ElementPlan.clamp_to_arena(Vector3.ZERO)
	var laid := ElementPlan.laid_centroid(_members(5), "swarm", inland, Vector3(-1, 0, 0), 18.0)
	assert_true(not bool(laid["clipped"]), "nothing clamped inland")
	assert_true((laid["centroid"] as Vector3).distance_to(inland) < 0.01, "the centroid is the anchor (%s)" % laid["centroid"])


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



## Cap + fold: an element sent to the edge whose shape still reaches past it arrives at its LAID seats' centroid, so a
## centre standing there reads arrived though it is more than ARRIVE_M from the (capped) anchor.
func test_a_folded_element_arrives_at_its_laid_seats() -> void:
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
	var task := {"verb": "move", "to": [edge.x, edge.z], "facing": [-1.0, 0.0]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	var first := ElementPlan.build(situation, state, table)
	assert_true(first.get("arrive_point") is Vector3, "setup: capped at %s m, the shape still reaches past the edge: folded"
			% first.get("inset_m"))
	var point: Vector3 = first["arrive_point"]
	var at_point := situation.duplicate(true)
	at_point["center"] = point
	var arrived := ElementPlan.build(at_point, state, table)
	assert_true(bool(arrived["arrived"]), "standing on its laid seats' centroid it has arrived")
	if (first["anchor"] as Vector3).distance_to(point) > ElementPlan.ARRIVE_M:
		print("MEASURE fold: the laid centroid is %.1f m from the anchor" % (first["anchor"] as Vector3).distance_to(point))


## C34.9 (brains B3): the War Rig trace logs the inset's ENGAGE distance: the plan says how far out the element stood when
## the inset moved its spot, and an Element latches the first one per task (later, closer updates don't overwrite it).
func test_the_inset_engage_distance_is_logged_once_per_task() -> void:
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
	assert_true(float(first.get("inset_m", 0.0)) > 1.0, "setup: inset (%s m)" % first.get("inset_m"))
	assert_true(absf(float(first.get("inset_from_m", -1.0)) - 40.0) < 0.01, "engaged 40 m out (%s)" % first.get("inset_from_m"))
	var element := Element.new()
	element.task_seq = 3
	element._latch_inset(first)
	assert_eq(element.inset_engaged[0], 3, "latched for this task")
	assert_true(absf(float(element.inset_engaged[1]) - 40.0) < 0.01, "at 40 m")
	element._latch_inset({"inset_m": 9.0, "inset_from_m": 12.0})
	assert_true(absf(float(element.inset_engaged[1]) - 40.0) < 0.01, "a closer update keeps the first")
	element.task_seq = 4
	element._latch_inset({"inset_m": 0.2, "inset_from_m": 30.0})
	assert_eq(element.inset_engaged[0], 3, "no inset (<= 0.5 m) on the new task: nothing latched")
	element._latch_inset({"inset_m": 6.0, "inset_from_m": 30.0})
	assert_eq(element.inset_engaged[0], 4, "the next task latches its own")
