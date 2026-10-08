extends TestCase
## Round 22 (brains B3, switch open_ground): SlotGround's open-ground certificate is an EQUALITY. On real arenas, every
## point it certifies is one the full grounding (`_standable_for`) answers with the point itself, for every hull the
## catalogue grounds; and it certifies a useful share of the floor (else it is dead weight). The arenas: his Sumps (the
## water), parade (container rows), foundry (the default scene), the Terminus (buildings).

const ARENAS := ["sumps", "parade", "foundry", "terminus"]
const UNITS := ["law_tank", "law_scout", "syn_ifv", "gang_scout"]
## A jittered grid this far apart (metres) over the arena's middle.
const STEP_M := 5.3
const HALF_M := 120.0


func test_every_certified_point_is_its_own_full_answer_on_four_arenas() -> void:
	for arena_name: String in ARENAS:
		var lab := TacticsLab.create(self, 1, arena_name)
		await lab.start()
		var map := lab.arena.get_world_3d().navigation_map
		var jitter := RandomNumberGenerator.new()
		jitter.seed = 22
		var asked := 0
		var certified := 0
		var on_mesh := 0
		var wrong: Array = []
		var x := -HALF_M
		while x <= HALF_M:
			var z := -HALF_M
			while z <= HALF_M:
				var point := Vector3(x + jitter.randf_range(-2.0, 2.0), 0.0, z + jitter.randf_range(-2.0, 2.0))
				# The movement sites' form (no clearance): certified on the mesh = its closest point within the bound.
				if SlotGround.on_open_mesh(map, point):
					on_mesh += 1
					var closest := NavigationServer3D.map_get_closest_point(map, point)
					if Vector2(closest.x - point.x, closest.z - point.z).length() > SlotGround.OPEN_LEVEL_ERR_M and wrong.size() < 5:
						wrong.append("on mesh %s -> %s" % [point, closest])
				for unit_id: String in UNITS:
					var clearance := SlotGround.envelope_of(unit_id)
					var need := maxf(clearance - SlotGround.bake_radius(), 0.0)
					asked += 1
					if not SlotGround.open_ground(map, point, need):
						continue
					certified += 1
					BrainSwitches.open_ground = false
					var full := SlotGround._standable_for(lab.arena, point, clearance)
					var centre := SlotGround.standable(lab.arena, point)
					BrainSwitches.open_ground = true
					if full != point and wrong.size() < 5:
						wrong.append("%s %s -> %s" % [unit_id, point, full])
					if centre != point and wrong.size() < 5:
						wrong.append("standable %s -> %s" % [point, centre])
				z += STEP_M
			x += STEP_M
		print("SLOT_OPEN %s certified %d of %d (%.0f%%), on mesh %d of %d" % [arena_name, certified, asked,
				100.0 * certified / maxf(asked, 1), on_mesh, asked / UNITS.size()])
		assert_true(wrong.is_empty(), "%s: a certified point the full grounding moves: %s" % [arena_name, wrong])
		assert_true(certified > asked / 10, "%s: the certificate covers a useful share (%d of %d)" % [arena_name, certified, asked])
		lab.dispose()


func test_the_switch_off_is_the_full_answer_and_a_point_inside_a_block_is_never_certified() -> void:
	var lab := TacticsLab.create(self, 3, "parade")
	await lab.start()
	var map := lab.arena.get_world_3d().navigation_map
	var env := SlotGround.envelope_of("law_tank")
	# Inside parade's bay row of containers (round 21's stretch d case).
	var inside := Vector3(75.4, 0.0, -26.5)
	assert_true(not SlotGround.open_ground(map, inside, env), "a point in a container row is never open ground")
	BrainSwitches.open_ground = false
	var off := SlotGround.standable_for(lab.arena, inside, env)
	BrainSwitches.open_ground = true
	assert_eq(SlotGround.standable_for(lab.arena, inside, env), off, "the same push with the switch on")
	lab.dispose()
