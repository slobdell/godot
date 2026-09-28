class_name AirshipSight
extends RefCounted
## Where the airship's hull is in the player's view, as geometry: one pure function shared by the instrument that
## measures the lead's complaint (`airship_view.gd`, round 14 A1) and the pilot's term that avoids it (A2), so the
## thing that is measured is the thing that is avoided.
##
## His words (2026-09-27): *"frequently when we're playing the airship flies right in front of the camera and
## disrupting the game"*. What disrupts is the hull HIDING THE FIGHT, so that is what is measured: sight lines from the
## camera to a grid of points over the ground it is aimed at (`FIGHT_HALF_M` each way, at a vehicle's height), and the
## share of them the hull's drawn box cuts (`hidden`). `between` is "hides any of it". Two first definitions were
## wrong and are kept as the reason this one is not them: "in the frustum and nearer than the aimed ground" counted a
## hull 20 m BEYOND the fight (its 29 m top is nearer in camera depth than the ground point) and a tail clipping the
## frame's side edge on a flank; neither hides anything he is looking at.

## The screen centre's ray is aimed at a vehicle's height, not the floor (BlockCutaway.AIM_HEIGHT_M, read not copied).
const AIM_HEIGHT_M := BlockCutaway.AIM_HEIGHT_M
const NEAR_M := 0.1
## The fight he is looking at: a square this far each way round the aimed ground point, sampled GRID x GRID.
const FIGHT_HALF_M := 15.0
const GRID := 3


## `camera` is the camera's global transform, `fov_deg` its VERTICAL field of view (Godot's KEEP_HEIGHT default),
## `screen` the viewport size, `box` a hull box (`AirshipFlight.hull_box`: centre Vector2, half Vector2 (across,
## along), yaw, bottom, top). Returns {in_frame, between, cover (0..1 of the screen the projected box's rectangle
## spans: an upper bound), hidden (0..1 of the fight's sight lines the hull cuts), between (hidden > 0), near_m (camera-depth of the nearest part in front), focus_m (depth of the aimed ground)}.
static func measure(camera: Transform3D, fov_deg: float, screen: Vector2, box: Dictionary) -> Dictionary:
	var out := {"in_frame": false, "between": false, "hidden": 0.0, "cover": 0.0, "near_m": INF, "focus_m": focus_depth(camera)}
	var tan_v := tan(deg_to_rad(fov_deg) * 0.5)
	var tan_h := tan_v * screen.x / maxf(screen.y, 1.0)
	var to_camera := camera.affine_inverse()
	var corners: Array[Vector3] = []
	for world: Vector3 in corners_of(box):
		corners.append(to_camera * world)
	# The part of the box in front of the near plane: the corners there, plus where its edges cross that plane.
	var front: Array[Vector3] = []
	for c: Vector3 in corners:
		if -c.z > NEAR_M:
			front.append(c)
	for edge: Vector2i in EDGES:
		var a := corners[edge.x]
		var b := corners[edge.y]
		var da := -a.z - NEAR_M
		var db := -b.z - NEAR_M
		if (da > 0.0) != (db > 0.0):
			front.append(a.lerp(b, da / (da - db)))
	if front.is_empty():
		return out
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var nearest := INF
	for c: Vector3 in front:
		var depth := -c.z
		nearest = minf(nearest, depth)
		var ndc := Vector2(c.x / (depth * tan_h), c.y / (depth * tan_v))
		low = low.min(ndc)
		high = high.max(ndc)
	var lo := low.max(Vector2(-1.0, -1.0))
	var hi := high.min(Vector2(1.0, 1.0))
	if lo.x >= hi.x or lo.y >= hi.y:
		return out
	out["in_frame"] = true
	out["near_m"] = nearest
	out["cover"] = (hi.x - lo.x) * (hi.y - lo.y) / 4.0
	out["hidden"] = hidden(camera, box)
	out["between"] = float(out["hidden"]) > 0.0
	return out


## The share of the fight grid (above) whose sight line from the camera the hull box cuts. 0 when the camera does not
## look down at the ground.
static func hidden(camera: Transform3D, box: Dictionary) -> float:
	var forward := -camera.basis.z.normalized()
	if forward.y > -0.01:
		return 0.0
	var eye := camera.origin
	var aim := eye + forward * ((AIM_HEIGHT_M - eye.y) / forward.y)
	var right := Vector3(camera.basis.x.x, 0.0, camera.basis.x.z).normalized()
	var ahead := Vector3(forward.x, 0.0, forward.z).normalized()
	var centre2: Vector2 = box["centre"]
	# Every sight line runs from the eye to a point within FIGHT_HALF_M of the aim, so every point on one lies within
	# FIGHT_HALF_M * sqrt(2) of the eye->aim segment on the ground: a hull whose footprint is further off than that
	# cannot cut any of them. Most poses end here, which is what lets the pilot price several cameras a tick.
	var near := Geometry2D.get_closest_point_to_segment(centre2, Vector2(eye.x, eye.z), Vector2(aim.x, aim.z))
	if near.distance_to(centre2) > (box["half"] as Vector2).length() + FIGHT_HALF_M * 1.415:
		return 0.0
	var bottom := float(box["bottom"])
	var top := float(box["top"])
	var centre := Vector3(centre2.x, (bottom + top) * 0.5, centre2.y)
	var half := Vector3((box["half"] as Vector2).x, (top - bottom) * 0.5, (box["half"] as Vector2).y)
	var yaw := float(box["yaw"])
	var cut := 0
	for i in GRID:
		for j in GRID:
			var u := (float(i) / (GRID - 1) * 2.0 - 1.0) * FIGHT_HALF_M
			var v := (float(j) / (GRID - 1) * 2.0 - 1.0) * FIGHT_HALF_M
			if RtsCamera.segment_hits_box(eye, aim + right * u + ahead * v, centre, half, yaw):
				cut += 1
	return float(cut) / float(GRID * GRID)


## How far along the camera's forward the aimed ground point is (INF when it does not look down).
static func focus_depth(camera: Transform3D) -> float:
	var forward := -camera.basis.z.normalized()
	if forward.y > -0.01:
		return INF
	return (AIM_HEIGHT_M - camera.origin.y) / forward.y


## The eight corners of a hull box, world space.
static func corners_of(box: Dictionary) -> Array[Vector3]:
	var centre: Vector2 = box["centre"]
	var half: Vector2 = box["half"]
	var yaw := float(box["yaw"])
	var axis_x := Vector2(cos(yaw), -sin(yaw))
	var axis_z := Vector2(sin(yaw), cos(yaw))
	var out: Array[Vector3] = []
	for y: float in [float(box["bottom"]), float(box["top"])]:
		for sz: float in [-1.0, 1.0]:
			for sx: float in [-1.0, 1.0]:
				var at := centre + axis_x * half.x * sx + axis_z * half.y * sz
				out.append(Vector3(at.x, y, at.y))
	return out


## Corner index pairs of the box's 12 edges (bit 0: x, bit 1: z, bit 2: y, per `corners_of`).
const EDGES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7),
	Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 6), Vector2i(5, 7),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
]
