extends TestCase
## Round 34 (planner's O5 probe, the Terminus 3-squad route): an anchor laid on an obstacle is moved to standable ground
## reached from its squad's side; a standable anchor stands. Squad 3's first anchor (32.7, 67.4) was inside a block: its
## leader held at a seat pushed 19 m off and the squad never arrived.


func test_a_standable_anchor_stands_and_an_unstandable_one_is_grounded() -> void:
	var anchors: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0)]
	var blocks := [{"center": Vector3(0, 0, 50)}, {"center": Vector3(10, 0, 50)}]
	var blocked := func(p: Vector3) -> bool: return p.x < 5.0  # x >= 5 is a building
	var ground := func(p: Vector3, from: Vector3) -> Vector3: return Vector3(4.0, 0, from.z * 0.1)
	var out := SelectionSquads.ground_anchors(anchors, blocks, blocked, ground)
	assert_eq(out[0], anchors[0], "a standable anchor is untouched")
	assert_eq(out[1], Vector3(4, 0, 5), "an anchor on the building goes to the ground reached from its squad's side")


func test_on_the_terminus_the_squads_anchor_in_the_block_is_grounded_toward_it() -> void:
	var lab := TacticsLab.create(self, 1, "terminus")
	var probe := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(40, 0, 88), 0.0)
	await lab.start()
	var inside := Vector3(32.7388, 0, 67.3665)
	assert_true(not SlotGround.is_standable(probe, inside), "setup: the probe's anchor is not standable")
	var anchors: Array[Vector3] = [inside]
	var out := SelectionSquads.ground_anchors(anchors, [{"center": Vector3(40, 0, 88)}],
			func(p: Vector3) -> bool: return SlotGround.is_standable(probe, p),
			func(p: Vector3, from: Vector3) -> Vector3: return SlotGround.standable_from(probe, p, SlotGround.envelope_of("tank"), from))
	assert_true(SlotGround.is_standable(probe, out[0]), "grounded onto standable ground (%s)" % out[0])
	assert_true(out[0].distance_to(Vector3(40, 0, 88)) < inside.distance_to(Vector3(40, 0, 88)), "on its squad's side")
