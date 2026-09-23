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
