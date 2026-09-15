extends TestCase
## Feel X6: vehicles in motion. Dust kicked up behind moving treads and tires, drift marks where a wheeled unit slides
## (K3 lateral_grip makes wheels drift), a lurch on hard braking, all measured from how the art moves (never the
## simulation), budgeted to the vehicles nearest the camera, cheap on the low tier.


func _vehicle(unit_id: String, at := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.set_meta("unit_id", unit_id)
	node.name = "%s_%d" % [unit_id, randi() % 100000]
	var slot := VisualSlot.new()
	slot.name = "HullVisual"
	node.add_child(slot)
	add_to_tree(node)
	node.global_position = at
	return node


## Drive `nodes` for `seconds`: each frame `step(node, dt)` moves it; MotionFx watches.
func _drive(fx: FxWorld, nodes: Array, seconds: float, step: Callable) -> void:
	var dt := 1.0 / 60.0
	var frames := roundi(seconds / dt)
	for frame in frames:
		for node: Node3D in nodes:
			step.call(node, dt)
		fx.now += dt
		fx.motion.update(nodes, Vector3(0, 40, 30), fx.now, dt)


func test_moving_vehicles_kick_up_dust_and_parked_ones_dont() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var mover := _vehicle("tank", Vector3(0, 0, 0))
	var parked := _vehicle("tank", Vector3(20, 0, 0))
	_drive(fx, [mover, parked], 1.0, func(node: Node3D, dt: float) -> void:
		if node == mover:
			node.global_position += Vector3.FORWARD * 9.0 * dt)
	assert_true(fx.motion.dust_from(mover) >= 3, "a tank driving 9 m/s for a second leaves a dust trail (%d puffs)" % fx.motion.dust_from(mover))
	assert_eq(fx.motion.dust_from(parked), 0, "a parked tank raises no dust")


func test_a_sliding_wheeled_unit_leaves_drift_marks_a_straight_one_doesnt() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var drifter := _vehicle("scout", Vector3(0, 0, 0))
	var straight := _vehicle("scout", Vector3(40, 0, 0))
	var pivot := _vehicle("tank", Vector3(-40, 0, 0))
	_drive(fx, [drifter, straight, pivot], 1.0, func(node: Node3D, dt: float) -> void:
		if node == drifter:
			node.rotation.y += 1.2 * dt
			node.global_position += (-node.global_basis.z * 10.0 + node.global_basis.x * 5.0) * dt
		elif node == straight:
			node.global_position += -node.global_basis.z * 12.0 * dt
		else:
			node.rotation.y += 1.5 * dt)
	assert_true(fx.motion.skids_from(drifter) >= 4, "a scout sliding sideways at 5 m/s lays drift marks (%d)" % fx.motion.skids_from(drifter))
	assert_eq(fx.motion.skids_from(straight), 0, "driving straight leaves none")
	assert_eq(fx.motion.skids_from(pivot), 0, "a tank pivoting on its tracks isn't drifting")


func test_hard_braking_lurches_the_nose_down() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var braker := _vehicle("ifv", Vector3(0, 0, 0))
	var speed := [12.0]
	_drive(fx, [braker], 0.5, func(node: Node3D, dt: float) -> void:
		node.global_position += -node.global_basis.z * speed[0] * dt)
	assert_eq(fx.jolts.active_count(), 0, "cruising doesn't rock")
	_drive(fx, [braker], 0.3, func(node: Node3D, dt: float) -> void:
		speed[0] = maxf(0.0, speed[0] - 30.0 * dt)
		node.global_position += -node.global_basis.z * speed[0] * dt)
	assert_true(fx.motion.lurches >= 1, "stopping from 12 m/s in 0.4 s lurches")
	fx.jolts.update(fx.motion.last_lurch_at + 0.12)
	var hull := braker.get_node("HullVisual") as Node3D
	assert_true(hull.transform.basis.get_euler().x < -0.005, "the nose dips (%.3f)" % hull.transform.basis.get_euler().x)


func test_only_the_nearest_vehicles_spend_the_motion_budget() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var fleet: Array = []
	for i in 50:
		fleet.append(_vehicle("scout", Vector3((i % 10) * 12.0 - 54.0, 0, (i / 10) * 20.0 - 40.0)))
	var nodes := fx.get_child_count()
	var before := fx.motion.puffs_started
	_drive(fx, fleet, 1.0, func(node: Node3D, dt: float) -> void:
		node.global_position += Vector3.FORWARD * 12.0 * dt)
	var emitting := 0
	for node in fleet:
		emitting += 1 if fx.motion.dust_from(node) > 0 else 0
	assert_true(emitting <= MotionFx.EMITTERS[FxQuality.tier()], "50 vehicles on the move: only the nearest %d kick up dust (%d did)" % [MotionFx.EMITTERS[FxQuality.tier()], emitting])
	assert_true(fx.motion.puffs_started - before < 50 * 12, "a bounded number of puffs (%d)" % (fx.motion.puffs_started - before))
	assert_eq(fx.get_child_count(), nodes, "no nodes added")


func test_the_low_tier_raises_less_dust() -> void:
	var previous := FxQuality.tier()
	var counts := {}
	for tier in [FxQuality.Tier.LOW, FxQuality.Tier.HIGH]:
		FxQuality.set_tier(tier, "test")
		var fx: FxWorld = add_to_tree(FxWorld.new())
		var mover := _vehicle("ifv")
		_drive(fx, [mover], 1.0, func(node: Node3D, dt: float) -> void:
			node.global_position += Vector3.FORWARD * 10.0 * dt)
		counts[tier] = fx.motion.puffs_started
	FxQuality.set_tier(previous, "test")
	assert_true(counts[FxQuality.Tier.LOW] < counts[FxQuality.Tier.HIGH], "phones get fewer dust puffs (%s)" % [counts])


func test_a_jump_isnt_driving() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var jumper := _vehicle("scout")
	var flip := [false]
	_drive(fx, [jumper], 0.5, func(node: Node3D, _dt: float) -> void:
		flip[0] = not flip[0]
		node.global_position = Vector3(12.0 if flip[0] else 0.0, 0.0, 0.0))
	assert_eq(fx.motion.dust_from(jumper), 0, "a node snapping back and forth 12 m a frame (smoothing, respawns) raises no dust")
