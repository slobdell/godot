extends TestCase
## Yard (round 17, Y2): a stack's upper levels sit the way a crane driver leaves them -- visibly turned and shifted at
## the lead's pose -- while every level stays on the one below and inside what the stack's single collider box makes
## believable. Visual only: the collider is one box (gameplay's), these are the drawn levels.
##
## His pose (21 deg pitch, FOV 35, 49 m) at 1080p is ~2.9 cm a pixel across the screen: the old jitter (+-0.6 deg,
## +-4 cm) moved a corner one or two pixels, which is what "stacked perfectly" means.

const PROP := preload("res://game/theme/arena_kit/containers/container_prop.gd")


## Corners of one drawn level in the stack's local frame (x along the length, z across), ground plane only.
func _corners(kind: String, xform: Transform3D) -> Array[Vector2]:
	var half := Vector2(ContainerYard.KINDS[kind] / 2.0, ContainerMesh.WIDTH / 2.0)
	var out: Array[Vector2] = []
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := xform * Vector3(s.x * half.x, 0.0, s.y * half.y)
		out.append(Vector2(p.x, p.z))
	return out


## How far `corner` is from the collider's footprint edge, as (outside, inside) >= 0 meters.
func _off_footprint(kind: String, corner: Vector2) -> float:
	var half := Vector2(ContainerYard.KINDS[kind] / 2.0, ContainerMesh.WIDTH / 2.0)
	var out := Vector2(maxf(absf(corner.x) - half.x, 0.0), maxf(absf(corner.y) - half.y, 0.0)).length()
	# Inside: the corner retreats from the nearest edge it belongs to (its own quadrant's corner of the box).
	var home := Vector2(signf(corner.x) * half.x, signf(corner.y) * half.y)
	return maxf(out, corner.distance_to(home))


func test_the_levels_are_the_same_picture_every_launch() -> void:
	for kind in ContainerYard.KINDS:
		var a: Array = PROP.stack_levels(kind, Vector3(12.5, 0, -40.25), 3)
		var b: Array = PROP.stack_levels(kind, Vector3(12.5, 0, -40.25), 3)
		assert_eq(a, b, "%s: the same spot always gets the same stack" % kind)
		var c: Array = PROP.stack_levels(kind, Vector3(18.5, 0, -40.25), 3)
		assert_true(a[1] != c[1], "%s: neighbours are stacked differently" % kind)


func test_the_ground_level_is_the_truth() -> void:
	for kind in ContainerYard.KINDS:
		for i in 50:
			var levels: Array = PROP.stack_levels(kind, Vector3(i * 7.3, 0, i * -3.1), 2)
			assert_eq(levels[0], Transform3D.IDENTITY, "%s: level 0 is drawn exactly on its collider" % kind)
			assert_near((levels[1] as Transform3D).origin.y, ContainerMesh.HEIGHT, 0.0001, "level 1 sits on level 0")


func test_upper_levels_read_at_his_pose_and_stay_on_the_stack() -> void:
	# Every number here is meters at a corner, measured over many stacks of both kinds.
	var budget: float = PROP.STACK_OFFSET_M
	for kind in ContainerYard.KINDS:
		var worst := 0.0
		var worst_step := 0.0
		var total := 0.0
		var samples := 0
		var still := 0
		for i in 400:
			var origin := Vector3(-120.0 + i * 0.61, 0, 80.0 - i * 0.37)
			var levels: Array = PROP.stack_levels(kind, origin, 3)
			for level in range(1, 3):
				var here := _corners(kind, levels[level])
				var below := _corners(kind, levels[level - 1])
				var moved := 0.0
				for k in 4:
					var off := _off_footprint(kind, here[k])
					worst = maxf(worst, off)
					moved = maxf(moved, off)
					worst_step = maxf(worst_step, here[k].distance_to(below[k]))
				total += moved
				samples += 1
				if moved < 0.06:
					still += 1
		var mean := total / samples
		print("STACK_OFFSET %s: worst corner off the collider %.3f m, worst level-to-level step %.3f m, mean %.3f m, under 6 cm %d/%d"
				% [kind, worst, worst_step, mean, still, samples])
		assert_true(worst <= budget + 0.01, "%s: no drawn corner is more than STACK_OFFSET_M (%.2f) off the collider (%.3f)" % [kind, budget, worst])
		# A zig-zag (one level turned left, the next right) is how real stacks look; 1.3 x the budget is ~33 cm of a
		# 2.44 m wide box, so each level's corner castings still sit on the one below.
		assert_true(worst_step <= 1.3 * budget + 0.01, "%s: each level stays on the one below (step %.3f m)" % [kind, worst_step])
		assert_true(mean >= 0.4 * budget, "%s: the offset reads -- a mean corner move of %.3f m is several pixels at his pose" % [kind, mean])
		assert_true(still <= samples / 20, "%s: almost no upper level sits square (%d of %d under 6 cm)" % [kind, still, samples])


func test_an_upper_level_never_reaches_past_the_end_of_its_collider_far_enough_to_clip_a_neighbour() -> void:
	# Containers in a run sit end to end with 6-19 cm of collider overlap; an upper level that pushes its end past the
	# collider's end plane by more than that pokes into the next stack's upper level.
	for kind in ContainerYard.KINDS:
		var half: float = ContainerYard.KINDS[kind] / 2.0
		var worst := 0.0
		for i in 400:
			var levels: Array = PROP.stack_levels(kind, Vector3(i * 1.37, 0, -i * 0.91), 3)
			for level in range(1, 3):
				for corner in _corners(kind, levels[level]):
					worst = maxf(worst, absf(corner.x) - half)
		print("STACK_END %s: an upper level's end reaches %.3f m past its collider" % [kind, worst])
		assert_true(worst <= 0.09, "%s: ends stay within 9 cm of the collider's end plane (%.3f)" % [kind, worst])
