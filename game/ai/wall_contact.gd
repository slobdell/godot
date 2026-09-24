class_name WallContact
extends RefCounted
## Round 10 (nav, item 1): **what a wall contact IS**, counted per unit per tick, with its cause.
##
## The lead: *"Units are still driving into walls."* Until this file nothing on the tree counted it. The plant
## (`Tank._drive` → `move_and_slide`, combat's) knows when a hull collided; `Movement` knows the route, the steering
## point and whether ORCA deflected it; neither published *"this hull touched a wall on this tick while doing X"*.
## This is that sentence, as a number with a cause split, read by `Movement.state()` and summed for the probes.
##
## **What counts as a contact:** a slide collision from the hull's last `move_and_slide` whose collider is NOT another
## vehicle (a `Tank` is a hull contact, counted apart) and whose normal is horizontal (`WALL_NORMAL_MAX_Y`). It is
## read at the top of the controller's NEXT tick, before the stride skip (so a strided brain is still observed every
## tick), and only when the plant really slid that tick (`Tank.is_parked` on the command it consumed is false: a
## parked hull skips `move_and_slide`, and its slide list would be the previous slide's, stale).
##
## **The cause, first match wins, in this order** (one class per contact tick, so the classes sum to the total):
##
## | cause | means | whose |
## |---|---|---|
## | `bake`  | the contact point lies ON the navmesh's clearance band: the thing touched is not in the bake (a prop the baker never saw, lesson R3) | arena |
## | `route` | the ROUTE itself runs within the hull's half-width (+ slack) of the contact: driving the path exactly would scrape | nav (routing) |
## | `avoid` | ORCA deflected the steering point this tick and the deflected heading points into the wall | nav (avoidance) |
## | `steer` | the commanded motion (throttle's sign along the hull's facing) points into the wall | nav (steering), or whoever issued a `drive` |
## | `plant` | none of the above: the hull touched the wall while NOT being driven into it (a yaw sweeping the hull through it, a slide, momentum) | combat (the plant) |
##
## The relay rule from the brief is the split between the last two: a hull DRIVEN into a wall by its desired velocity
## is nav's; a hull ROTATING through one is combat's. `driver` records WHICH layer produced the motion (the seam item:
## `direct` is CombatMotion's short hops, `route` the navmesh drive), so each contact is attributable to a layer AND a
## mechanism.
##
## **Measurement only. Never read by a decision** (nothing in the sim may branch on it; it is wall-clock free and
## reads only physics state already produced, so it cannot move the sim baseline).

const CAUSES: Array[String] = ["bake", "route", "avoid", "steer", "plant"]
## A slide normal steeper than this is floor or roof, not a wall (the hulls float, `MOTION_MODE_FLOATING`, so this is
## a guard rather than a filter that fires).
const WALL_NORMAL_MAX_Y := 0.5
## A contact point closer to the navmesh than `bake_radius - BAKE_SLACK_M` is on ground the bake called clear, so the
## thing touched was not baked. The slack covers the bake's own cell quantisation (0.5 m cells) and rounded corners.
const BAKE_SLACK_M := 1.0
## The route is the cause when the path runs within the hull's half-width plus this of the contact point.
const ROUTE_SLACK_M := 0.25
## "Points into the wall": the heading's component against the wall normal exceeds this (cos 84°).
const INTO_COS := 0.1
## Throttle below this is "not being driven" (a pure turn or a coast).
const THROTTLE_MIN := 0.05
## The per-contact detail kept for the probes (the first LOG_CAP contact ticks of a run; the counts are never capped).
const LOG_CAP := 600

## ---- The run's totals (statics, like every nav arm counter; `reset()` between runs) ------------------------------
## Unit-ticks observed: the DENOMINATOR. Zero means the instrument never ran, which is not "no contacts".
static var observed := 0
## Unit-ticks with at least one wall contact.
static var ticks := 0
static var by_cause := {}
## Which layer produced the motion on each contact tick (route / direct / yield / unstick / face / drive / stop).
static var by_driver := {}
## Round 11 (nav R1): contact ticks by the GEAR commanded ("forward" / "reverse" / "none"): backing blind into a
## second wall is the failure a planned reverse must not add, so reverse contacts are counted apart.
static var by_gear := {}
## Contact ticks per unit name, and per lane name ("" = off every declared lane).
static var by_unit := {}
static var by_lane := {}
## Unit-ticks touching another hull (not a wall): reported beside, never inside, the wall count.
static var hull_ticks := 0
static var log: Array = []
## Every (unit, cause, collider) episode, UNCAPPED: its tick count and the first contact's detail. The log above keeps
## only the first LOG_CAP ticks of a run, which is the start of the drive and nothing after it.
static var episodes := {}
## `plant` split by what moved the contact point into the wall: `sweep` = the commanded YAW (the hull's end swinging
## through it: combat's constraint row), `drift` = neither yaw nor throttle (a slide, momentum, a depenetration).
static var plant_kind := {}
## cause -> {collider -> unit-ticks}: WHICH geometry each cause presses into, not only how often.
static var by_cause_collider := {}


static func reset() -> void:
	observed = 0
	ticks = 0
	by_cause = {}
	by_driver = {}
	by_gear = {}
	by_unit = {}
	by_lane = {}
	hull_ticks = 0
	log = []
	episodes = {}
	plant_kind = {}
	by_cause_collider = {}


static func report() -> Dictionary:
	return {"observed_unit_ticks": observed, "contact_unit_ticks": ticks, "by_cause": by_cause.duplicate(),
			"by_driver": by_driver.duplicate(), "by_gear": by_gear.duplicate(), "by_unit": by_unit.duplicate(), "by_lane": by_lane.duplicate(),
			"hull_contact_unit_ticks": hull_ticks, "plant_kind": plant_kind.duplicate(),
			"top_colliders": top_colliders(5)}


## Per cause, the `limit` colliders with the most contact unit-ticks, as [[collider, ticks], ...], most first.
static func top_colliders(limit: int) -> Dictionary:
	var out := {}
	for cause: String in by_cause_collider:
		var rows: Array = []
		for name: String in by_cause_collider[cause]:
			rows.append([name, int(by_cause_collider[cause][name])])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
		out[cause] = rows.slice(0, limit)
	return out


## ---- One mover's reading ----------------------------------------------------------------------------------------
## Did the hull touch a wall on its last slide, why, what, and where.
var touching := false
var cause := ""
var driver := ""
var collider := ""
var lane := ""
var count := 0
var mine_by_cause := {}
## The last contact's point and wall normal (flat, from the wall toward the hull): what an escape backs away from.
var point := Vector3.ZERO
var normal := Vector3.ZERO

## What the controller decided on the tick whose motion is being judged (set by `Movement.note_decision`).
var decided := {}


func reading() -> Dictionary:
	return {"wall_contact": touching, "wall_contact_cause": cause, "wall_contact_driver": driver,
			"wall_contact_collider": collider, "wall_contact_lane": lane, "wall_contacts": count,
			"wall_contacts_by_cause": mine_by_cause.duplicate()}


## Read the hull's last slide. `mover` supplies the route and the decision; called once per physics tick.
func observe(mover: Movement) -> void:
	var tank := mover.ctl.tank
	touching = false
	if tank == null or not is_instance_valid(tank) or not tank.is_inside_tree() or not tank.is_alive():
		return
	if tank.command == null or tank.is_parked(tank.command):
		return  # no slide happened: the collision list is the previous slide's
	observed += 1
	var wall: KinematicCollision3D = null
	var hull_hit := false
	for i in tank.get_slide_collision_count():
		var hit := tank.get_slide_collision(i)
		if hit.get_collider() is Tank:
			hull_hit = true
			continue
		if absf(hit.get_normal().y) > WALL_NORMAL_MAX_Y:
			continue
		if wall == null or hit.get_depth() > wall.get_depth():
			wall = hit
	if hull_hit:
		hull_ticks += 1
	if wall == null:
		return
	touching = true
	point = wall.get_position()
	normal = Vector3(wall.get_normal().x, 0.0, wall.get_normal().z).normalized()
	driver = String(decided.get("driver", "?"))
	cause = _classify(mover, tank, point, normal)
	var other: Object = wall.get_collider()
	collider = String((other as Node).name) if other is Node else str(other)
	lane = lane_at(point)
	count += 1
	mine_by_cause[cause] = int(mine_by_cause.get(cause, 0)) + 1
	ticks += 1
	by_cause[cause] = int(by_cause.get(cause, 0)) + 1
	by_driver[driver] = int(by_driver.get(driver, 0)) + 1
	var throttle := float(decided.get("throttle", 0.0))
	var gear := "forward" if throttle > THROTTLE_MIN else ("reverse" if throttle < -THROTTLE_MIN else "none")
	by_gear[gear] = int(by_gear.get(gear, 0)) + 1
	by_unit[String(tank.name)] = int(by_unit.get(String(tank.name), 0)) + 1
	by_lane[lane] = int(by_lane.get(lane, 0)) + 1
	var colliders: Dictionary = by_cause_collider.get(cause, {})
	colliders[collider] = int(colliders.get(collider, 0)) + 1
	by_cause_collider[cause] = colliders
	if cause == "plant":
		var kind := "sweep" if _yaw_drives_into(tank, point, normal) else "drift"
		plant_kind[kind] = int(plant_kind.get(kind, 0)) + 1
	var episode_key := "%s|%s|%s" % [tank.name, cause, collider]
	if episodes.has(episode_key):
		episodes[episode_key]["ticks"] = int(episodes[episode_key]["ticks"]) + 1
		episodes[episode_key]["last_at"] = [snappedf(point.x, 0.01), snappedf(point.z, 0.01)]
	else:
		episodes[episode_key] = {"unit": String(tank.name), "unit_id": tank.unit_id, "cause": cause, "driver": driver,
				"collider": collider, "lane": lane, "ticks": 1, "first_tick": Engine.get_physics_frames(),
				"at": [snappedf(point.x, 0.01), snappedf(point.z, 0.01)], "last_at": [snappedf(point.x, 0.01), snappedf(point.z, 0.01)],
				"throttle": snappedf(float(decided.get("throttle", 0.0)), 0.01), "turn": snappedf(float(decided.get("turn", 0.0)), 0.01),
				"route_gap_m": snappedf(float(decided.get("_route_gap", -1.0)), 0.01),
				"mesh_gap_m": snappedf(float(decided.get("_mesh_gap", -1.0)), 0.01)}
	if log.size() < LOG_CAP:
		var tangent: Variant = mover.corridor()
		log.append({"unit": String(tank.name), "unit_id": tank.unit_id, "tick": Engine.get_physics_frames(),
				"cause": cause, "driver": driver, "collider": collider, "lane": lane,
				"at": [snappedf(point.x, 0.01), snappedf(point.z, 0.01)],
				"normal": [snappedf(normal.x, 0.01), snappedf(normal.z, 0.01)],
				"corridor": [snappedf((tangent as Vector3).x, 0.01), snappedf((tangent as Vector3).z, 0.01)] if tangent is Vector3 else null,
				"throttle": snappedf(float(decided.get("throttle", 0.0)), 0.01),
				"turn": snappedf(float(decided.get("turn", 0.0)), 0.01),
				"route_gap_m": snappedf(float(decided.get("_route_gap", -1.0)), 0.01),
				"mesh_gap_m": snappedf(float(decided.get("_mesh_gap", -1.0)), 0.01)})


func _classify(mover: Movement, tank: Tank, at: Vector3, wall_normal: Vector3) -> String:
	var into := -wall_normal
	decided.erase("_route_gap")
	decided.erase("_mesh_gap")
	# bake: the contact point is on ground the navmesh called clear.
	var map := tank.get_world_3d().navigation_map if tank.get_world_3d() != null else RID()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var on_mesh := NavigationServer3D.map_get_closest_point(map, at)
		var mesh_gap := Vector2(at.x - on_mesh.x, at.z - on_mesh.z).length()
		decided["_mesh_gap"] = mesh_gap
		if mesh_gap < Movement.bake_radius(tank) - BAKE_SLACK_M:
			return "bake"
	# route: the path itself passes too close for this hull's width.
	if String(decided.get("driver", "")) == "route":
		var path: PackedVector3Array = decided.get("path", PackedVector3Array())
		if path.size() >= 1:
			var half_width := float(Movement.hull_box(tank.unit_id)[0]) * 0.5
			var gap := distance_to_polyline(at, path)
			decided["_route_gap"] = gap
			if gap < half_width + ROUTE_SLACK_M:
				return "route"
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var throttle := float(decided.get("throttle", 0.0))
	# avoid: ORCA moved the steering point, and the point it chose lies into the wall.
	if bool(decided.get("deflected", false)):
		var steer: Variant = decided.get("steer_to", null)
		if steer is Vector3:
			var toward := Vector3((steer as Vector3).x - tank.global_position.x, 0.0, (steer as Vector3).z - tank.global_position.z)
			if toward.length_squared() > 0.0001 and toward.normalized().dot(into) > INTO_COS:
				return "avoid"
	# steer: the commanded motion drives the hull into the wall.
	if absf(throttle) >= THROTTLE_MIN and (forward * signf(throttle)).dot(into) > INTO_COS:
		return "steer"
	return "plant"


## Does the commanded yaw move the contact point INTO the wall? `turn` is the hull's yaw in either gear, and a
## POSITIVE turn rotates the heading toward the hull's right (`TankMotion.turn_heading`: f + right·θ, right =
## (-f.z, f.x)), so a point r = (x, z) from the hull centre moves along (-z, x)·sign(turn). Its component along
## -normal says whether the swing presses it in.
static func _yaw_drives_into(tank: Tank, at: Vector3, wall_normal: Vector3) -> bool:
	var turn := float(tank.command.turn) if tank.command != null else 0.0
	if absf(turn) < 0.05:
		return false
	return swing_of(tank.global_position, at, turn).dot(Vector2(-wall_normal.x, -wall_normal.z)) > 0.0


## The direction a point at `at` moves when a hull centred at `centre` yaws with command `turn` (unnormalised).
static func swing_of(centre: Vector3, at: Vector3, turn: float) -> Vector2:
	var r := Vector2(at.x - centre.x, at.z - centre.z)
	return Vector2(-r.y, r.x) * signf(turn)


## The declared lane (`Arena.active`'s `lanes`) whose half-width covers `point`, or "". The lanes are converted once
## per layout (keyed on the layout dictionary itself, so a test that swaps `Arena.active` is never served stale lanes).
static var _lanes: Array = []
static var _lanes_of: Dictionary = {}


static func lane_at(at: Vector3) -> String:
	if not is_same(_lanes_of, Arena.active):
		_lanes_of = Arena.active
		_lanes = Arena.lanes_of(Arena.active)
	for entry: Dictionary in _lanes:
		if distance_to_polyline(at, entry["points"]) <= float(entry["width"]) * 0.5:
			return String(entry["name"])
	return ""


## Flat distance from `point` to the polyline `path` (a single point is a degenerate polyline).
static func distance_to_polyline(at: Vector3, path: PackedVector3Array) -> float:
	var p := Vector2(at.x, at.z)
	if path.size() == 1:
		return p.distance_to(Vector2(path[0].x, path[0].z))
	var best := INF
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
