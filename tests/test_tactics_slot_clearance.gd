extends TestCase
## Round 10 (nav's Terminus drive rows): a formation slot is grounded with the HULL's own clearance, not the bake
## radius. nav's examples, from its miss list: slots 4-10 m inside Terminus blocks for an ifv, a lancer and a rig.
## `standable()` moved them onto the mesh's EDGE (2 m from the wall), so a hull centred there had its nose in the block.

const CASES := [
	[Vector3(-23.9, 0.0, 18.0), "ifv"],
	[Vector3(-87.3, 0.0, 0.3), "lancer"],
	[Vector3(29.8, 0.0, -47.3), "ifv"],
]


## How many of 16 probes at `reach` from `at` fall off the mesh (0 = the hull's reach is clear all round).
static func _off_mesh_probes(node: Node3D, at: Vector3, reach: float) -> int:
	var map := node.get_world_3d().navigation_map
	var off := 0
	for k in 16:
		var angle := TAU * float(k) / 16.0
		var probe := Vector3(at.x + cos(angle) * reach, 0.0, at.z + sin(angle) * reach)
		var closest := NavigationServer3D.map_get_closest_point(map, probe)
		if Vector2(closest.x - probe.x, closest.z - probe.z).length() > SlotGround.TOLERANCE_M:
			off += 1
	return off


func test_a_slot_by_a_terminus_block_is_grounded_where_the_hull_fits() -> void:
	var lab := TacticsLab.create(self, 1, "terminus")
	await lab.start()
	var node := lab.arena as Node3D
	var rows: Array = []
	for row: Array in CASES:
		var wanted: Vector3 = row[0]
		var envelope := SlotGround.envelope_of(String(row[1]))
		var reach := envelope - SlotGround.bake_radius()
		var edge := SlotGround.standable(node, wanted)
		var fitted := SlotGround.standable_for(node, wanted, envelope)
		assert_eq(SlotGround.for_unit(node, wanted, String(row[1])), fitted, "for_unit is standable_for at the unit's envelope")
		var before := _off_mesh_probes(node, edge, reach)
		var after := _off_mesh_probes(node, fitted, reach)
		rows.append("%s %s: edge %s off %d/16 -> fitted %s off %d/16 (moved %.1f m, reach %.1f m)" % [row[1], wanted, edge,
				before, fitted, after, Vector2(fitted.x - wanted.x, fitted.z - wanted.z).length(), reach])
		assert_true(SlotGround.is_standable(node, fitted), "%s: the fitted slot is on the mesh" % row[1])
		# The positive control: the old edge point leaves the hull's reach off the mesh (its nose in the block).
		assert_true(before > 0, "setup: at the mesh edge the %s's reach crosses into the block (%d/16)" % [row[1], before])
		assert_true(after < before, "the %s's fitted slot has more of its reach on the mesh (%d -> %d of 16)" \
				% [row[1], before, after])
		assert_eq(after, 0, "and all of it, where the street is wider than the hull's envelope (%s)" % row[1])
	print("MEASURE slot_clearance " + " | ".join(rows))
	lab.dispose()



func test_a_crew_holding_an_element_slot_sends_its_leash_with_every_move() -> void:
	# nav's item 6: a move_to carries `leash [x, z, r]` (the element slot and TankBrain.slot_leash) while the crew has a
	# slot, so the mover can clamp its goal into the leash.
	var scenario := AiScenario.create(self)
	var names: Array = []
	for i in 3:
		names.append(String(scenario.brain_tank(Match.Team.GREEN, "Green_L_%d" % (i + 1),
				Vector3(-10.0 + i * 10.0, 0.0, 60.0), 0.0, {}, "tank").name))
	var elements := Elements.install(scenario.game_match, scenario.orders())
	await scenario.start()
	var alpha := elements.form(names, "Alpha")
	alpha.assign({"verb": "move", "to": [0, 20], "drills": false})
	var leashed := 0
	for i in SimClock.TICK_RATE * 3:
		await scenario.step()
	for unit_name: String in names:
		var brain := scenario.brain_of(scenario.game_match.tanks.get_node(unit_name) as Tank)
		var order: Dictionary = brain.move_order
		if String(order.get("type", "")) == "move_to" and order.has("leash"):
			var leash: Array = order["leash"]
			assert_eq(leash.size(), 3, "%s: the leash is [x, z, r]" % unit_name)
			assert_true(float(leash[2]) >= TankBrain.SLOT_LEASH - 0.001, "%s: its radius is the slot leash" % unit_name)
			leashed += 1
	assert_true(leashed >= 1, "at least one crew driving to its slot carries the leash (%d of 3)" % leashed)
	scenario.dispose()
