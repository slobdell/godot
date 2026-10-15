class_name PlanRequest
extends RefCounted
## Round 30 (planner P2): one request to the planner: a hull, where it is, where it should end up (a POSE), what is in
## the way, and how much search it may spend. Built by hand in the tests and the lab; `for_unit` fills the hull from
## the catalog so a seam needs one call.

var start_x := 0.0
var start_z := 0.0
var start_fx := 0.0
var start_fz := -1.0  # north
var goal_x := 0.0
var goal_z := 0.0
var goal_fx := 0.0
var goal_fz := -1.0
## Reached when within this of the goal position and heading.
var tol_m := 1.0
var tol_deg := 8.0
## +1: arrive nose first (the last leg forward), -1: tail first, 0: either.
var arrive_gear := 0
## Round 31 (the k-turn's goal): reached also when the hull POINTS at the goal within tol_deg from farther than tol_m
## with a clear straight run to it (Planner._at_goal); the pursuit law drives from there.
var aim := false
## Round 31 (CP-P1's first judged series, the face's KEEP circle = manoeuvre's slot law, rounds 30 M1b / 31 M1b(2)):
## every pose the search expands lies within `keep_all_m` of (keep_x, keep_z) and the goal pose within `keep_end_m`;
## INF = no circle. A rig that arrived 4.5 m from its slot and was then faced on a 3.5 m reverse chord sat 7.4 m from
## the slot for the rest of the leg (seed 134, the plaza): a face at rest keeps its spot.
var keep_x := 0.0
var keep_z := 0.0
var keep_all_m := INF
var keep_end_m := INF
## The hull: half extents (m), the minimum turning radius (m), the speeds the legs will be driven at (m/s), the
## acceleration and braking (m/s^2) for the cusp cost, and the yaw cap (deg/s).
var half_w := 1.0
var half_l := 2.0
var radius := 6.0
var v_fwd := 6.0
var v_rev := 2.5
var accel := 8.0
var brake := 10.0
var omega_max_deg := 80.0
## The throttles the legs will be driven at (the executor reads them from the plan): the k-turn's 0.7, lowered for a
## hull whose yaw at that speed would exceed its cap on full lock (the plant clamps the yaw and the arc widens).
var throttle_fwd := 0.7
var throttle_rev := 0.7
var unit_id := ""
var world: PlannerWorld = null
## The search budget in EXPANSIONS (never milliseconds: a decision that read the clock would differ between machines).
var budget := 1500
## The window round the start the search may use (m).
var horizon_m := 30.0
## The weighted-A* epsilon (0 = Planner.EPSILON): tests and the lab probe with it; the seam leaves it at 0.
var epsilon := 0.0
## On NO_PATH or BUDGET from the coarse lattice, search again on the fine one (the same budget again).
var fine_retry := true


## A request for a catalog unit driven at the executor's throttles (the k-turn's KTURN_THROTTLE 0.7 both gears).
static func for_unit(id: String, throttle_fwd := 0.7, throttle_rev := 0.7) -> PlanRequest:
	var r := PlanRequest.new()
	r.unit_id = id
	var box: Array = Units.stat(id, "hull_size", [2.4, 1.6, 3.8])
	r.half_w = float(box[0]) * 0.5
	r.half_l = float(box[2]) * 0.5
	r.radius = maxf(float(Units.stat(id, "min_turn_radius_m", 0.0)), 0.5)
	r.v_fwd = float(Units.stat(id, "max_forward_speed", 9.0)) * throttle_fwd
	r.v_rev = float(Units.stat(id, "max_reverse_speed", 4.0)) * throttle_rev
	r.accel = float(Units.stat(id, "acceleration_mps2", 14.0))
	r.brake = float(Units.stat(id, "braking_mps2", 14.0))
	r.omega_max_deg = float(Units.stat(id, "hull_turn_rate_deg", 80.0))
	# The yaw cap: v / R must stay under omega_max on full lock, or the plant turns a wider arc than the plan.
	var cap_v := deg_to_rad(r.omega_max_deg) * r.radius
	var top_fwd := float(Units.stat(id, "max_forward_speed", 9.0))
	var top_rev := float(Units.stat(id, "max_reverse_speed", 4.0))
	r.throttle_fwd = throttle_fwd
	r.throttle_rev = throttle_rev
	if r.v_fwd > cap_v:
		r.v_fwd = cap_v * 0.98
		r.throttle_fwd = r.v_fwd / maxf(top_fwd, 0.1)
	if r.v_rev > cap_v:
		r.v_rev = cap_v * 0.98
		r.throttle_rev = r.v_rev / maxf(top_rev, 0.1)
	return r


func at(x: float, z: float, fx: float, fz: float) -> PlanRequest:
	start_x = x
	start_z = z
	var f := Vector2(fx, fz).normalized()
	start_fx = f.x
	start_fz = f.y
	return self


func to(x: float, z: float, fx: float, fz: float, p_tol_m := 1.0, p_tol_deg := 8.0) -> PlanRequest:
	goal_x = x
	goal_z = z
	var f := Vector2(fx, fz).normalized()
	goal_fx = f.x
	goal_fz = f.y
	tol_m = p_tol_m
	tol_deg = p_tol_deg
	return self


## The KEEP circle (see keep_all_m): every pose within `all_m` of (x, z), the goal pose within `end_m`.
func keep(x: float, z: float, all_m: float, end_m: float) -> PlanRequest:
	keep_x = x
	keep_z = z
	keep_all_m = all_m
	keep_end_m = end_m
	return self


func in_world(w: PlannerWorld) -> PlanRequest:
	world = w
	return self


## The seconds a cusp costs this hull at its leg speeds: brake to rest from the forward speed, spin up again.
func cusp_seconds() -> float:
	return v_fwd / maxf(brake, 0.1) + v_fwd / maxf(accel, 0.1)


## A copy (the world shared: it is a snapshot nobody mutates but `refresh_hulls`, which a seam calls before a search).
func copy() -> PlanRequest:
	var r := PlanRequest.new()
	for prop: Dictionary in get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			r.set(String(prop["name"]), get(String(prop["name"])))
	return r


## Round 31 (CP-P0): the request as the C++ planner reads it (PlannerNative.parse_request): every field the search
## uses, as the doubles they are here, plus the world's view and the tick (SimClock.TICK_SECONDS, so the plant's lag
## model is the same number on both paths). `cusp_s` is computed here once, for both the cost and the table's key.
func to_native() -> Dictionary:
	return {
		"start_x": start_x, "start_z": start_z, "start_fx": start_fx, "start_fz": start_fz,
		"goal_x": goal_x, "goal_z": goal_z, "goal_fx": goal_fx, "goal_fz": goal_fz,
		"tol_m": tol_m, "tol_deg": tol_deg, "arrive_gear": arrive_gear, "aim": aim,
		"keep_x": keep_x, "keep_z": keep_z, "keep_all_m": keep_all_m, "keep_end_m": keep_end_m,
		"half_w": half_w, "half_l": half_l, "radius": radius, "v_fwd": v_fwd, "v_rev": v_rev,
		"cusp_s": cusp_seconds(), "budget": budget, "horizon_m": horizon_m, "epsilon": epsilon,
		"fine_retry": fine_retry, "tick_s": SimClock.TICK_SECONDS,
		"world": world.native_view() if world != null else {},
	}
