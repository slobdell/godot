extends TestCase
## Yard (round 17, Y3): a wall of containers stays a wall after its containers turn. The lead asked for every container
## turned "just slightly"; two neighbours in a run turned different ways open a wedge at their ends, and a 6 cm wedge
## is invisible to him and wide open to `Perception.has_line_of_sight`'s physics ray and to a shell. So at every joint
## (two colliders that overlap, one of them a container) rays are fired across the wall through the seam, in both
## directions, at eye and muzzle height, in the real physics space the match uses. None may pass.
##
## tools/container_skew.py keeps every joint that overlapped in the square layout overlapping by >= 3 cm (or what it
## had); the mutation test below opens one joint by 30 cm and proves these rays would see it.

## Eye height (Perception.EYE_HEIGHT 1.3) and a low muzzle (hull guns sit 1.05-1.27 m).
const HEIGHTS := [1.3, 1.05]
## Ray ends either side of the seam, along the wall: a ray that crosses within this of a seam crosses at the seam.
const ALONG := [-1.5, -0.75, -0.25, 0.0, 0.25, 0.75, 1.5]
const ACROSS := 6.0


## Every footprint in a layout that collides: [{centre: Vector2, half: Vector2, angle: float, container: bool}].
func _boxes(layout: Dictionary) -> Array:
	var out: Array = []
	for obstacle: Dictionary in layout.get("obstacles", []):
		if obstacle.has("kit"):
			continue
		var size := Arena.obstacle_size(obstacle)
		out.append({"centre": Vector2(obstacle["position"][0], obstacle["position"][1]), "half": Vector2(size.x, size.z) / 2.0,
				"angle": deg_to_rad(float(obstacle.get("rotation_deg", 0.0))), "container": false})
	for prop: Dictionary in layout.get("props", []):
		if not ArenaKit.collides(prop["type"]):
			continue
		var size := ArenaKit.size_of(prop)
		out.append({"centre": Vector2(prop["position"][0], prop["position"][1]), "half": Vector2(size.x, size.z) / 2.0,
				"angle": deg_to_rad(float(prop.get("rotation_deg", 0.0))), "container": String(prop["type"]).begins_with("container")})
	return out


## Basis(UP, a): local x -> world (cos a, -sin a), local z -> (sin a, cos a), in (x, z).
func _axes(box: Dictionary) -> Array[Vector2]:
	var a: float = box["angle"]
	return [Vector2(cos(a), -sin(a)), Vector2(sin(a), cos(a))]


func _corners(box: Dictionary) -> Array[Vector2]:
	var ax := _axes(box)
	var h: Vector2 = box["half"]
	var out: Array[Vector2] = []
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(box["centre"] + ax[0] * s.x * h.x + ax[1] * s.y * h.y)
	return out


## Separating-axis overlap depth (> 0 overlapping, < 0 apart).
func _depth(a: Dictionary, b: Dictionary) -> float:
	var best := INF
	for axis: Vector2 in _axes(a) + _axes(b):
		var lo_a := INF
		var hi_a := -INF
		var lo_b := INF
		var hi_b := -INF
		for c in _corners(a):
			lo_a = minf(lo_a, c.dot(axis))
			hi_a = maxf(hi_a, c.dot(axis))
		for c in _corners(b):
			lo_b = minf(lo_b, c.dot(axis))
			hi_b = maxf(hi_b, c.dot(axis))
		best = minf(best, minf(hi_a, hi_b) - maxf(lo_a, lo_b))
	return best


## Distance from a box's centre to its edge along `dir` (unit).
func _reach(box: Dictionary, dir: Vector2) -> float:
	var ax := _axes(box)
	var h: Vector2 = box["half"]
	var lx := absf(dir.dot(ax[0]))
	var lz := absf(dir.dot(ax[1]))
	return minf(h.x / lx if lx > 1e-6 else INF, h.y / lz if lz > 1e-6 else INF)


func _layout(layout_name: String) -> Dictionary:
	return Arena.load_layout(layout_name)["layout"]


## The joints of a layout: [seam point, wall direction] for every overlapping pair with a container in it.
func _joints(layout: Dictionary) -> Array:
	var boxes := _boxes(layout)
	var out: Array = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			if not (a["container"] or b["container"]):
				continue
			if (a["centre"] as Vector2).distance_to(b["centre"]) > (a["half"] as Vector2).length() + (b["half"] as Vector2).length():
				continue
			if _depth(a, b) < 0.0:
				continue
			var d: Vector2 = (b["centre"] - a["centre"]).normalized()
			var seam: Vector2 = ((a["centre"] + d * _reach(a, d)) + (b["centre"] - d * _reach(b, d))) / 2.0
			out.append([seam, d])
	return out


## For each ray across each joint: whether it reaches the far side without touching anything.
func _clear(arena: Arena, joints: Array) -> Array[bool]:
	var space := arena.get_world_3d().direct_space_state
	var out: Array[bool] = []
	for joint: Array in joints:
		var seam: Vector2 = joint[0]
		var along: Vector2 = joint[1]
		var across := Vector2(-along.y, along.x)
		for h: float in HEIGHTS:
			for t0: float in ALONG:
				for t1: float in ALONG:
					var p := seam + along * t0 + across * ACROSS
					var q := seam + along * t1 - across * ACROSS
					for pair: Array in [[p, q], [q, p]]:
						var query := PhysicsRayQueryParameters3D.create(Vector3(pair[0].x, h, pair[0].y), Vector3(pair[1].x, h, pair[1].y), Perception.WORLD_MASK)
						out.append(space.intersect_ray(query).is_empty())
	return out


## The square truth of a layout (round 17's launch tree), frozen in tests/arena/before/square/.
func _square_path(layout_name: String) -> String:
	return "res://tests/arena/before/square/%s.json" % layout_name


## Rays through `layout`'s square joints that the square wall blocked and `arena` lets through, and the reverse.
func _compare(square: Array[bool], turned: Array[bool]) -> Vector2i:
	var opened := 0
	var closed := 0
	for k in square.size():
		if turned[k] and not square[k]:
			opened += 1
		elif square[k] and not turned[k]:
			closed += 1
	return Vector2i(opened, closed)


func test_no_ray_passes_between_containers_that_the_square_wall_blocked() -> void:
	var joints_total := 0
	var layouts := 0
	for layout_name in Arena.layout_names():
		if not FileAccess.file_exists(_square_path(layout_name)):
			continue  # never turned (no containers, or a fixture kept square)
		var square_layout := _layout(_square_path(layout_name))
		var joints := _joints(square_layout)
		if joints.is_empty():
			continue
		var before := await ArenaFixture.build(self, _square_path(layout_name))
		await tree.physics_frame
		var square := _clear(before, joints)
		before.queue_free()
		await tree.process_frame
		var after := await ArenaFixture.build(self, layout_name)
		await tree.physics_frame
		var turned := _clear(after, joints)
		after.queue_free()
		await tree.process_frame
		var diff := _compare(square, turned)
		print("CONTAINER_JOINTS %s: %d joints, %d rays; square let %d through, turned lets %d through (opened %d, closed %d)"
				% [layout_name, joints.size(), square.size(), square.count(true), turned.count(true), diff.x, diff.y])
		assert_eq(diff.x, 0, "%s: no ray the square wall blocked gets through the turned one" % layout_name)
		joints_total += joints.size()
		layouts += 1
	assert_true(layouts >= 8 and joints_total > 40, "the joints were found (%d in %d layouts): a test that finds none proves nothing" % [joints_total, layouts])


func test_the_rays_would_see_a_joint_opened_by_sixty_centimetres() -> void:
	# The mutation check: slide one container of a yard run 60 cm along its wall so a joint opens; the same rays must
	# now get through where the turned yard blocks them. If they don't, the test above is blind. (30 cm at A; at B a
	# 4 deg turn swings the boxes' corners across a 30 cm opening, so the opening has to be wider to be one.)
	var layout := _layout("yard").duplicate(true)
	var joints := _joints(_layout(_square_path("yard")))
	var props: Array = layout["props"]
	var victim := -1
	for i in props.size():
		var p: Dictionary = props[i]
		if p["type"] == "container_40" and absf(float(p["position"][0]) + 17.0) < 1.0 and float(p["position"][1]) > 0.0:
			victim = i
			break
	assert_true(victim >= 0, "found a run container in yard's x = -17 column")
	var box: Dictionary = props[victim]
	var at := Vector2(box["position"][0], box["position"][1])
	var seam_joint: Array = []
	for joint: Array in joints:
		if (joint[0] as Vector2).distance_to(at) < 7.0:
			seam_joint = [joint]
			break
	assert_true(not seam_joint.is_empty(), "the victim has a joint")
	var away := (at - (seam_joint[0][0] as Vector2)).normalized() * 0.6
	for i in props.size():
		var m: Dictionary = props[i]
		if m["type"] != box["type"]:
			continue
		var mp := Vector2(m["position"][0], m["position"][1])
		if mp.distance_to(at) < 0.01:
			m["position"] = [at.x + away.x, at.y + away.y]
		elif mp.distance_to(-at) < 0.01:
			m["position"] = [-at.x - away.x, -at.y - away.y]  # its mirror, so the layout still validates
	var intact := await ArenaFixture.build(self, "yard")
	await tree.physics_frame
	var closed := _clear(intact, seam_joint)
	intact.queue_free()
	await tree.process_frame
	var opened_arena := await ArenaFixture.build_layout(self, layout)
	await tree.physics_frame
	var opened := _clear(opened_arena, seam_joint)
	opened_arena.queue_free()
	await tree.process_frame
	assert_eq(closed.count(true), 0, "the turned yard's joint blocks every ray")
	assert_true(opened.count(true) > 0, "a joint opened by 60 cm lets rays through (%d of %d)" % [opened.count(true), opened.size()])


## Round 17: what the lane validators can't see. Their bar is 2 x the widest hull (12.14 m physical), so a 14 cm
## intrusion into a 17.56 m street passes them while a 14 m rig loses the pocket it turned in. So turning is held to
## its own rule: on every turned layout, no declared lane's narrowest width or junction clearance may shrink by more
## than LANE_LOSS_M against the square layout, and nothing that passed may fail.
## Round 17 CP2: 0.20 at B (+-4 deg on a 40 ft box, the lead's tap); it was 0.10 at A (+-2). The losses it allows are
## listed in the yard brief's Status (the largest: 16 cm of a 16.78 m causeway on the Sumps' dry twin).
const LANE_LOSS_M := 0.20


func test_no_lane_or_junction_loses_width_to_the_turn() -> void:
	var checked := 0
	for layout_name in Arena.layout_names():
		if not FileAccess.file_exists(_square_path(layout_name)):
			continue
		var square := _layout(_square_path(layout_name))
		var turned := _layout(layout_name)
		var before := {}
		for lane: Dictionary in ArenaLanes.measure(square):
			before[lane["name"]] = lane
		for lane: Dictionary in ArenaLanes.measure(turned):
			var was: Dictionary = before[lane["name"]]
			var lost: float = float(was["narrowest_physical_m"]) - float(lane["narrowest_physical_m"])
			assert_true(lost <= LANE_LOSS_M, "%s / %s: %.2f m -> %.2f m (lost %.2f, allowed %.2f)" % [layout_name, lane["name"],
					was["narrowest_physical_m"], lane["narrowest_physical_m"], lost, LANE_LOSS_M])
			assert_true(lane["pass"] or not was["pass"], "%s / %s still passes the lane bar" % [layout_name, lane["name"]])
			checked += 1
		var corners_before := ArenaLanes.corners(square)
		var corners_after := ArenaLanes.corners(turned)
		assert_eq(corners_after.size(), corners_before.size(), "%s: the same junctions" % layout_name)
		for k in mini(corners_before.size(), corners_after.size()):
			var lost: float = float(corners_before[k]["clearance_m"]) - float(corners_after[k]["clearance_m"])
			# A junction with a quarter of its needed clearance to spare cannot lose its pocket to a turned corner
			# (boneyard and the crossing lose 12-14 cm at junctions with 4.7-8.6 m spare); a tight one may lose 10 cm.
			var spare: float = float(corners_after[k]["clearance_m"]) - float(corners_after[k]["r_eff_m"])
			assert_true(lost <= LANE_LOSS_M or spare >= 0.25 * float(corners_after[k]["r_eff_m"]), "%s: junction at %s lost %.2f m (%.2f -> %.2f, needs %.2f)" % [layout_name, corners_after[k]["where"], lost, corners_before[k]["clearance_m"], corners_after[k]["clearance_m"], corners_after[k]["r_eff_m"]])
			assert_true(corners_after[k]["pass"] or not corners_before[k]["pass"], "%s: junction at %s still passes" % [layout_name, corners_after[k]["where"]])
	assert_true(checked >= 30, "the lanes were found (%d)" % checked)


func test_a_container_against_a_building_keeps_the_building_s_angle() -> void:
	# A box pushed against a wall sits parallel to it; turned, it sinks a corner into the wall or swings into the street.
	var held := 0
	for layout_name in Arena.layout_names():
		if not FileAccess.file_exists(_square_path(layout_name)):
			continue
		var square := _layout(_square_path(layout_name))
		var turned := _layout(layout_name)
		var blocks: Array = _boxes(square).filter(func(b: Dictionary) -> bool: return not b["container"] and (b["half"] as Vector2).x >= 19.0)
		var props_before: Array = square["props"]
		var props_after: Array = turned["props"]
		for i in props_before.size():
			var p: Dictionary = props_before[i]
			if not String(p["type"]).begins_with("container"):
				continue
			var size := ArenaKit.size_of(p)
			var me := {"centre": Vector2(p["position"][0], p["position"][1]), "half": Vector2(size.x, size.z) / 2.0,
					"angle": deg_to_rad(float(p.get("rotation_deg", 0.0))), "container": true}
			if not blocks.any(func(b: Dictionary) -> bool: var d := _depth(me, b); return d >= -0.01 and d <= 1.0):
				continue
			var q: Dictionary = props_after[i]
			assert_eq(q["rotation_deg"], p["rotation_deg"], "%s: the %s against a block at %s keeps its angle" % [layout_name, p["type"], p["position"]])
			assert_eq(q["position"], p["position"], "%s: and its place" % layout_name)
			held += 1
	assert_true(held >= 10, "the kerb boxes were found (%d)" % held)
