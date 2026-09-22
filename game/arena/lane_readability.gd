class_name LaneReadability
extends RefCounted
## Arena item 3 (round 10; research C11): does a lane READ passable from the lead's camera? `ArenaLanes` proves a
## street is wide enough; this asks whether he can SEE that it is. At his pose (21° pitch, FOV 35, 49 m boom) a gap
## across the screen is foreshortened by sin 21° ≈ 0.36, and anything standing between the camera and a throat hides
## the ground a hull would drive on. So, per lane: take its narrowest cross-section (the throat), project it to a
## 1920 x 1080 frame from his pose looking at it, trace every point of its ground-contact line back to the camera
## through the colliders, and print the throat's VISIBLE width in pixels minus the widest hull's projected width
## there. Positive = a hull visibly fits through what he can see; <= 0 = the throat reads shut even though it is not.
##
## Pure geometry over the layout's STATIC FOOTPRINTS extruded to their heights, with the camera where the game puts
## it (`clear_pose`) and the buildings it cuts away removed (`BlockCutaway`); no renderer, so it runs headless in
## `make check`. The approximation, stated: a city block is its 40 x 24 x 40 prism (the art steps in above the
## shopfronts, so real occlusion from a high camera can only be LESS than this); decoration (signs) and the show's
## light are not modelled.

const FRAME := Vector2(1920.0, 1080.0)
const DISTANCE_M := 49.0
## Points sampled along a throat's ground-contact line.
const SAMPLES := 64


## Per lane: {name, heading_deg, throat_m, throat_px, visible_fraction, visible_px, hull_px, margin_px}.
## `heading_deg` 0 is his default camera (behind green, looking north: -Z); `along` looks down the lane instead.
static func measure(data: Dictionary, heading_deg: float = 0.0, along := false) -> Array:
	var the_bar := ArenaLanes.bar()
	var hull := float(the_bar["widest_hull_m"])
	var boxes := _boxes(data)
	var out: Array = []
	for lane: Dictionary in ArenaLanes.measure(data, the_bar):
		var throat: Dictionary = lane["throat"]
		if throat.is_empty():
			continue
		var at: Vector2 = lane["at"]
		var n: Vector2 = throat["normal"]
		var a := at + n * float(throat["left_m"])
		var b := at - n * float(throat["right_m"])
		var heading := deg_to_rad(heading_deg)
		if along:
			# Look down the lane: the boom points back along it, so the camera sits behind the throat on the lane.
			var dir: Vector2 = throat["along"]
			heading = atan2(-dir.x, -dir.y)
		var focus := Vector3(at.x, 0.0, at.y)
		# What the game actually shows: the camera is never left inside a building (`RtsCamera.clear_pose`), and a
		# building between the camera and what it looks at is not drawn (`BlockCutaway`: solids at least
		# MIN_HEIGHT_M tall crossing the sight line to AIM_HEIGHT_M over the focus). Cover is never cut.
		var pose := RtsCamera.clear_pose(focus, heading, DISTANCE_M, RtsCamera.DEFAULT_PITCH_DEG, data)
		var cam := RtsCamera.pose_at(focus, heading, float(pose["distance"]), float(pose["pitch_deg"]))
		var aim := focus + Vector3.UP * BlockCutaway.AIM_HEIGHT_M
		var drawn := boxes.filter(func(box: Dictionary) -> bool:
				return (box["size"] as Vector3).y < BlockCutaway.MIN_HEIGHT_M or not _segment_hits(box, cam.origin, aim))
		var visible := 0
		for k in SAMPLES:
			var t := (float(k) + 0.5) / SAMPLES
			var g := a.lerp(b, t)
			if not _occluded(drawn, cam.origin, Vector3(g.x, 0.0, g.y)):
				visible += 1
		var fraction := float(visible) / SAMPLES
		var throat_px := _screen(cam, Vector3(a.x, 0.0, a.y)).distance_to(_screen(cam, Vector3(b.x, 0.0, b.y)))
		var hull_px := _screen(cam, focus + Vector3(n.x, 0.0, n.y) * hull / 2.0).distance_to(
				_screen(cam, focus - Vector3(n.x, 0.0, n.y) * hull / 2.0))
		out.append({"name": lane["name"], "heading_deg": snappedf(rad_to_deg(heading), 0.1),
				"pitch_deg": float(pose["pitch_deg"]), "distance_m": float(pose["distance"]),
				"throat_m": lane["narrowest_physical_m"], "throat_px": throat_px, "visible_fraction": fraction,
				"visible_px": throat_px * fraction, "hull_px": hull_px, "margin_px": throat_px * fraction - hull_px})
	return out


## Where a world point lands in a FRAME-sized image from a camera at `cam` (vertical FOV, as Camera3D keeps height).
static func _screen(cam: Transform3D, world: Vector3) -> Vector2:
	var proj := Projection.create_perspective(RtsCamera.FOV_DEG, FRAME.x / FRAME.y, 0.3, 2000.0)
	var clip: Vector4 = proj * Vector4((cam.affine_inverse() * world).x, (cam.affine_inverse() * world).y,
			(cam.affine_inverse() * world).z, 1.0)
	var ndc := Vector2(clip.x, clip.y) / clip.w
	return Vector2((ndc.x * 0.5 + 0.5) * FRAME.x, (0.5 - ndc.y * 0.5) * FRAME.y)


## Whether anything solid stands between the camera and a ground point.
static func _occluded(boxes: Array, from: Vector3, to: Vector3) -> bool:
	for box: Dictionary in boxes:
		if _segment_hits(box, from, to):
			return true
	return false


static func _segment_hits(box: Dictionary, from: Vector3, to: Vector3) -> bool:
	var angle := deg_to_rad(float(box["rotation_deg"]))
	var c := cos(angle)
	var s := sin(angle)
	var center: Vector2 = box["center"]
	var size: Vector3 = box["size"]
	var p := _local(from, center, c, s)
	var q := _local(to, center, c, s)
	var d := q - p
	var lo := Vector3(-size.x / 2.0, 0.0, -size.z / 2.0)
	var hi := Vector3(size.x / 2.0, size.y, size.z / 2.0)
	var t0 := 0.0
	var t1 := 0.999  # stop short of the ground point itself: it lies ON the face of the box that bounds the throat
	for axis in 3:
		if absf(d[axis]) < 1e-9:
			if p[axis] < lo[axis] or p[axis] > hi[axis]:
				return false
			continue
		var ta := (lo[axis] - p[axis]) / d[axis]
		var tb := (hi[axis] - p[axis]) / d[axis]
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


static func _local(point: Vector3, center: Vector2, c: float, s: float) -> Vector3:
	var dx := point.x - center.x
	var dz := point.z - center.y
	# Basis(UP, angle): the same local frame as ArenaKit.distance_to_footprint.
	return Vector3(dx * c - dz * s, point.y, dx * s + dz * c)


static func _boxes(data: Dictionary) -> Array:
	var out: Array = []
	for obstacle: Dictionary in data.get("obstacles", []):
		out.append({"center": Vector2(obstacle["position"][0], obstacle["position"][1]),
				"size": Arena.obstacle_size(obstacle), "rotation_deg": float(obstacle.get("rotation_deg", 0.0))})
	return out
