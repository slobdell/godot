class_name PlannerFixtures
extends RefCounted
## Round 30 (planner P2): the fixtures from problem.md section 4, as worlds and requests the tests and the lab share.
## Coordinates are the arena's: x east, z south, forward north is (0, -1); a heading given as (fx, fz).

const STREET_LEN := 80.0
const WALL_THICK := 5.0


## A north-south street `width` metres wall to wall, centred on x = 0.
static func street(width: float) -> PlannerWorld:
	var w := PlannerWorld.new()
	var h := width * 0.5
	w.add_wall_box(-h - WALL_THICK, -STREET_LEN * 0.5, -h, STREET_LEN * 0.5)
	w.add_wall_box(h, -STREET_LEN * 0.5, h + WALL_THICK, STREET_LEN * 0.5)
	return w


## F6: a turn-round in a street: heading north at the middle, wanted heading south within 2 m of the spot.
static func turn_round(unit: String, width: float) -> PlanRequest:
	return PlanRequest.for_unit(unit).at(0.0, 0.0, 0.0, -1.0).to(0.0, 0.0, 0.0, 1.0, 2.0, 8.0).in_world(street(width))


## A T-junction of 20 m streets: the north-south street (x in [-10, 10]) and a side street east (z in [-10, 10],
## x >= 10). Start 10 m short of the junction heading north; goal 25 m into the side street heading east.
static func t_junction(unit: String) -> PlanRequest:
	var w := PlannerWorld.new()
	w.add_wall_box(-15.0, -40.0, -10.0, 40.0)
	w.add_wall_box(10.0, -40.0, 15.0, -10.0)
	w.add_wall_box(10.0, 10.0, 15.0, 40.0)
	w.add_wall_box(10.0, -15.0, 45.0, -10.0)
	w.add_wall_box(10.0, 10.0, 45.0, 15.0)
	return PlanRequest.for_unit(unit).at(0.0, 10.0, 0.0, -1.0).to(25.0, 0.0, 1.0, 0.0, 1.5, 8.0).in_world(w)


## F5: a 20 m street with a War Rig stopped ACROSS its west half (heading east, centre x = -2.5: it spans x -9.5..4.5),
## leaving a 5.5 m gap on the east side. The hull comes from 20 m south in the gap's lane and wants the street beyond.
static func mouth_with_hull(unit: String) -> PlanRequest:
	var w := street(20.0)
	var rig: Array = Units.stat("gang_tank", "hull_size", [3.32, 5.24, 14.0])
	w.add_hull(-2.5, 0.0, 1.0, 0.0, float(rig[0]) * 0.5, float(rig[2]) * 0.5, "parked rig")
	return PlanRequest.for_unit(unit).at(7.0, 20.0, 0.0, -1.0).to(7.0, -6.0, 0.0, -1.0, 2.0, 10.0).in_world(w)


## The yard corner: a 30 m lane running south (x in [-15, 15]) that ends on a cross-piece at z = 15 and turns EAST
## into a 15 m lane (z in [0, 15]). Start 25 m up the lane heading south; goal 30 m into the east lane heading east.
static func yard_corner(unit: String) -> PlanRequest:
	var w := PlannerWorld.new()
	w.add_wall_box(-20.0, -40.0, -15.0, 15.0)   # west face of the lane
	w.add_wall_box(-20.0, 15.0, 45.0, 20.0)     # the cross-piece (and the east lane's south face)
	w.add_wall_box(15.0, -40.0, 20.0, 0.0)      # the east face, up to the corner
	w.add_wall_box(15.0, -5.0, 45.0, 0.0)       # the east lane's north face
	return PlanRequest.for_unit(unit).at(0.0, -5.0, 0.0, 1.0).to(25.0, 7.5, 1.0, 0.0, 1.5, 8.0).in_world(w)


## F4: a slot 9 m ahead with a facing 180 degrees from the approach. `width` > 0 puts it on a causeway that wide
## (the Sumps' 14 m, B5c's scene: a loop does not fit); 0 is open ground (a scout's fastest answer there IS a loop).
static func slot_180(unit: String, width := 0.0) -> PlanRequest:
	var w := street(width) if width > 0.0 else PlannerWorld.new()
	return PlanRequest.for_unit(unit).at(0.0, 20.0, 0.0, -1.0).to(0.0, 11.0, 0.0, 1.0, 1.0, 8.0).in_world(w)


## F2: the hull's front-right CORNER 0.2 m from a wall face, the hull 30 degrees to the face (nose toward it); the goal
## 20 m back down the street heading south.
static func wedge(unit: String) -> PlanRequest:
	var w := PlannerWorld.new()
	w.add_wall_box(5.0, -40.0, 10.0, 40.0)
	var req := PlanRequest.for_unit(unit)
	var fx := 0.5
	var fz := -sqrt(0.75)
	var rx := -fz
	var rz := fx
	# corner = centre + f * half_l + r * half_w, wanted at x = 4.8
	var cx := 4.8 - fx * req.half_l - rx * req.half_w
	var cz := 0.0 - fz * req.half_l - rz * req.half_w
	return req.at(cx, cz, fx, fz).to(-6.0, 20.0, 0.0, 1.0, 2.0, 10.0).in_world(w)


## F3: four hulls line abreast at `pitch`, all heading north; the request is for hull `index` (0..3) to face EAST
## within `stay` of its spot, the other three as obstacles where they stand.
static func packed_line(unit: String, pitch: float, index: int, stay: float) -> PlanRequest:
	var w := PlannerWorld.new()
	var box: Array = Units.stat(unit, "hull_size", [3.32, 5.24, 14.0])
	var xs: Array[float] = []
	for i in 4:
		xs.append((float(i) - 1.5) * pitch)
	for i in 4:
		if i != index:
			w.add_hull(xs[i], 0.0, 0.0, -1.0, float(box[0]) * 0.5, float(box[2]) * 0.5, "hull %d" % i)
	return PlanRequest.for_unit(unit).at(xs[index], 0.0, 0.0, -1.0).to(xs[index], 0.0, 1.0, 0.0, stay, 8.0).in_world(w)


## The ground truth over a plan's poses: the least exact outline clearance to a wall and whether any pose overlaps
## another hull. {"least_m", "overlaps", "worst_pose"}.
static func audit(req: PlanRequest, out: PackedPlan) -> Dictionary:
	var least := INF
	var overlaps := 0
	var worst: Array = []
	for pose: Array in out.poses:
		var c := req.world.exact_outline_clearance(float(pose[0]), float(pose[1]), float(pose[2]), float(pose[3]), req.half_w, req.half_l)
		if c < least:
			least = c
			worst = pose
		if req.world.exact_hull_overlap(float(pose[0]), float(pose[1]), float(pose[2]), float(pose[3]), req.half_w, req.half_l):
			overlaps += 1
	return {"least_m": least, "overlaps": overlaps, "worst_pose": worst}


## The plan's end against the request's goal: metres off and degrees off.
static func miss(req: PlanRequest, out: PackedPlan) -> Vector2:
	var d := Vector2(out.end_x - req.goal_x, out.end_z - req.goal_z).length()
	var deg := rad_to_deg(absf(Vector2(out.end_fx, out.end_fz).angle_to(Vector2(req.goal_fx, req.goal_fz))))
	return Vector2(d, deg)
