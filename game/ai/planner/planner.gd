class_name Planner
extends RefCounted
## Round 30 (planner P2): **a local motion planner for long wheeled hulls in tight space** — the design in
## `_agents/streams/references/round30/planner/design.md`, the problem in `problem.md`.
##
## A hybrid-A* search over (x, z, heading, gear) whose primitives are the legs the drive executes: one-metre arcs on
## the plant's own yaw law (`turn / R` per metre in either gear, `TankMotion.turn_heading`'s step) at five locks and
## two gears. Cost in SECONDS (forward metres at the leg speed, reverse metres at the reverse cap, a cusp's braking
## and spin-up, a lock change, a clearance band near walls); an admissible heuristic (the fastest metre, over the
## longer of the distance and the turning the heading still needs); the hull's outline against a lazy clearance field
## and its box against every other hull's (PlannerWorld); a goal that is a POSE with a tolerance; a budget in
## EXPANSIONS. Deterministic by construction: a fixed successor order, integer cell keys, a heap with id tie-breaks,
## no wall clock, trig only once per plan (the start and goal headings).
##
## Nothing in play reaches this file this round (C30.4). The seam manoeuvre would add is one call:
##   Planner.plan(PlanRequest.for_unit(tank.unit_id).at(...).to(...).in_world(world)) -> PackedPlan

## A primitive is a whole LEG: one gear, one lock, swept in SUB_M steps up to LEG_MAX_M, a successor emitted at each
## of LEG_ENDS_M (and wherever the sweep meets the goal pose). The search decides a cusp per leg, not per metre: on a
## one-metre lattice an IFV turned round in fourteen one-metre legs, the lead's N-point shuffle found by a planner.
const SUB_M := 0.5
const LEG_ENDS_M: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 16.0, 20.0, 24.0]
const LEG_MAX_M := 24.0
const HEADING_BINS := 24        # 15 degrees (the coarse lattice; the fine retry uses FINE_BINS)
const FINE_BINS := 36           # 10 degrees
const FINE_CELL_M := 0.5
const STEERS: Array[float] = [-1.0, 0.0, 1.0]  # full lock either way, or straight: the legs the lead asked for
const MARGIN_M := 0.4           # the k-turn's KTURN_MARGIN_M: outline points this far from a face, so bars compare
const EPSILON := 1.5            # weighted A*: the first plan is within 1.5x the lattice's best; PlanRequest.epsilon overrides
## Anytime: after the first plan the search goes on while the budget lasts and the open list's best UNWEIGHTED
## f = g + h is under the plan's cost, taking any cheaper plan it pops; when that bound is reached the plan is the
## lattice's best (the first plan popped at epsilon 2 was a 7-leg wedge exit and a 4-leg slot arrival; the search had
## used 31 and 74 expansions, and the better plans were a few hundred more).
const STEER_CHANGE_S := 0.8     # a lock change on the same gear: fewer, longer legs (0.3 bought 2 m nudges before an arc)
const BAND_M := 1.5             # a leg closer than this to a wall is penalised (the margin itself is hard)
const BAND_S_PER_M := 0.5
const ROLL_SLACK_M := 0.5       # the roll past a leg's end at the executor's throttle must be clear too
const CELL_M := 1.0             # the lattice cell (the clearance field's is PlannerWorld.CELL_M); the fine retry halves it
const TRACE_SUB_M := 0.25       # the poses handed back are this far apart

## Measurement only (tests and the lab): the last plan's expansions and nodes.
static var last_expansions := 0
static var last_nodes := 0

## Round 31 (CP-P0): the SAME search in C++ (native/src/planner_native.cpp, `PlannerNative`), the same bits
## (tests/test_native_planner.gd holds every fixture to it). Taken when the library is loaded, `BrainSwitches.native`
## and its `native_planner` sub-switch are on, and `native_on` (this file's own switch: the tests flip it to plan both
## ways; `--planner-gdscript` on the command line clears it for an A/B of the GDScript search in play).
static var native_on := not OS.get_cmdline_user_args().has("--planner-gdscript")
static var _impl: Object = ClassDB.instantiate("PlannerNative") if ClassDB.class_exists("PlannerNative") else null
## Measurement: plans taken by each path.
static var native_plans := 0
static var gdscript_plans := 0


static func native_usable() -> bool:
	if _impl == null or not native_on or not BrainSwitches.native:
		return false
	# `native_planner` is native's sub-switch (BrainSwitches); read by name so this file parses on a tree without it.
	var sub: Variant = (BrainSwitches as Script).get("native_planner")
	return sub == null or bool(sub)


## The C++ search's answer as a PackedPlan: the legs, code, cost and counts are the library's; `why` is composed here
## from its numbers with this file's own format strings; the trace (poses, metres, cusps, the end pose) is GDScript's
## `trace` over the same legs, as on the GDScript path.
static func _plan_native(req: PlanRequest) -> PackedPlan:
	if req.world == null:
		var out := PackedPlan.new()
		out.throttle_fwd = req.throttle_fwd
		out.throttle_rev = req.throttle_rev
		out.why = "no world"
		return out
	return _from_native(req, _impl.plan(req.to_native()))


# ---- P6: the per-tick slice (a SESSION on the C++ planner: begin, step N expansions a tick, result) -------------------
## One session at a time (the library holds one; PlannerSeam's queue is one deep). `begin_session` takes the request's
## view (`PlanRequest.to_native()`, so a seam can hold and replay it); `step_session(n)` runs at most n expansions and
## answers true when the plan is final; `session_result(req)` is the PackedPlan. Without the library the whole plan is
## made at `begin_session` in GDScript (the twin path: correct, slow, for a tree without the .so) and `step_session`
## answers true at once. Proven in tests/test_native_planner.gd: the sliced plan is the whole plan.
## The session's own library instance (a whole plan on `_impl` while a session is live would clobber it: native's
## review note); the free-space tables are one static cache inside the library, shared by both.
static var _session_impl: Object = ClassDB.instantiate("PlannerNative") if ClassDB.class_exists("PlannerNative") else null
static var _session_req: PlanRequest = null
static var _session_plan: PackedPlan = null
static var _session_stepped := 0


static func begin_session(req: PlanRequest) -> void:
	_session_req = req
	_session_plan = null
	_session_stepped = 0
	if native_usable():
		_session_impl.begin(req.to_native())
	else:
		_session_plan = plan(req)


static func step_session(expansions: int) -> bool:
	if _session_plan != null:
		return true
	if _session_req == null or _session_impl == null or not _session_impl.live():
		return true
	_session_stepped += maxi(expansions, 1)
	if _session_impl.step(expansions):
		native_plans += 1
		_session_plan = _from_native(_session_req, _session_impl.result())
		return true
	return false


static func session_done() -> bool:
	return _session_plan != null


static func session_result() -> PackedPlan:
	return _session_plan


## The expansions handed to `step_session` so far (a seam's snapshot replays a pending session by stepping this many).
static func session_stepped() -> int:
	return _session_stepped


static func cancel_session() -> void:
	_session_req = null
	_session_plan = null
	_session_stepped = 0
	if _session_impl != null and _session_impl.live():
		_session_impl.cancel()


static func _from_native(req: PlanRequest, r: Dictionary) -> PackedPlan:
	var out := PackedPlan.new()
	out.throttle_fwd = req.throttle_fwd
	out.throttle_rev = req.throttle_rev
	out.code = String(r["code"])
	out.expansions = int(r["expansions"])
	if out.code == PackedPlan.OK or out.code == PackedPlan.NO_PATH or out.code == PackedPlan.BUDGET:
		# As `_search` does: the measurement statics move only when a search ran (a blocked request returns before them).
		last_expansions = int(r["last_expansions"])
		last_nodes = int(r["nodes"])
	match out.code:
		PackedPlan.OK:
			out.legs.assign(r["legs"])
			out.cost_s = float(r["cost_s"])
			out.why = "%d legs, %.1f s, %d expansions (first plan at %d)" % [out.legs.size(), out.cost_s, last_expansions, int(r["first_at"])]
		PackedPlan.BUDGET:
			out.why = "budget of %d expansions spent" % req.budget
		PackedPlan.NO_PATH:
			out.why = "no pose within %.0f m reaches the goal on the %.1f m / %d-bin lattice (%d expansions, %d nodes)" % [
					req.horizon_m, float(r["cell_m"]), int(r["bins"]), last_expansions, last_nodes]
		PackedPlan.START_BLOCKED:
			out.why = "the start pose overlaps another hull"
		PackedPlan.GOAL_BLOCKED:
			out.why = "the goal pose is not clear by %.1f m" % MARGIN_M
		PackedPlan.ALREADY_THERE:
			out.end_x = req.start_x
			out.end_z = req.start_z
			out.end_fx = req.start_fx
			out.end_fz = req.start_fz
	if int(r["coarse_expansions"]) >= 0:
		out.why += " (after %d coarse expansions)" % int(r["coarse_expansions"])
	if out.code == PackedPlan.OK:
		trace(req, out)
	return out


## The plan: the coarse lattice first (1 m, 15 degrees), and on NO_PATH or BUDGET the fine one (0.5 m, 10 degrees)
## with the same budget again — a corridor the coarse cells cannot thread (an IFV turning round in 12 m: the coarse
## search exhausted its window and said NO_PATH to a manoeuvre that exists) is found by the fine one at ~4x the cost.
## The expansions reported are the sum. `req.fine_retry` false skips it.
static func plan(req: PlanRequest) -> PackedPlan:
	if native_usable():
		native_plans += 1
		return _plan_native(req)
	gdscript_plans += 1
	var out := _search(req, CELL_M, HEADING_BINS)
	if (out.code == PackedPlan.NO_PATH or out.code == PackedPlan.BUDGET) and req.fine_retry:
		var coarse := out.expansions
		out = _search(req, FINE_CELL_M, FINE_BINS)
		out.expansions += coarse
		out.why += " (after %d coarse expansions)" % coarse
	return out


static func _search(req: PlanRequest, cell_m: float, bins: int) -> PackedPlan:
	var out := PackedPlan.new()
	out.throttle_fwd = req.throttle_fwd
	out.throttle_rev = req.throttle_rev
	var world := req.world
	if world == null:
		out.why = "no world"
		return out
	var half_w := req.half_w
	var half_l := req.half_l
	var radius := maxf(req.radius, 0.5)
	world.prepare(req.start_x, req.start_z, req.horizon_m + half_l + 2.0)
	var start_offs := world.side_clearances(req.start_x, req.start_z, req.start_fx, req.start_fz, half_w, half_l, MARGIN_M)
	var strict := PackedFloat32Array()
	strict.resize(4)
	strict.fill(INF)
	# The plant turns the heading by the speed at a tick's START and moves at its END, so in cruise the heading lags
	# the arc by v·dt/R (a War Rig at 8.4 m/s: 1.3 degrees) and the position drifts inside the ideal arc; modelled
	# here as a constant lag of the MOVE direction per gear (test_planner_model measures the residual: < 1 % a leg).
	var lag_fwd := req.v_fwd * SimClock.TICK_SECONDS / radius
	var lag_rev := req.v_rev * SimClock.TICK_SECONDS / radius
	# The plant's heading step is the small-angle one (`turn_heading`: forward + right·δ, renormalised: a rotation by
	# atan δ, short by δ³/3 a tick), so at speed it turns a hair less per metre: an effective radius per gear.
	var radius_fwd := _effective_radius(radius, req.v_fwd)
	var radius_rev := _effective_radius(radius, req.v_rev)
	var theta0 := atan2(req.start_fz, req.start_fx)
	var goal_theta := atan2(req.goal_fz, req.goal_fx)
	var tol_rad := deg_to_rad(req.tol_deg)
	if world.exact_hull_overlap(req.start_x, req.start_z, req.start_fx, req.start_fz, half_w, half_l):
		out.code = PackedPlan.START_BLOCKED
		out.why = "the start pose overlaps another hull"
		return out
	if world.footprint(req.goal_x, req.goal_z, req.goal_fx, req.goal_fz, half_w, half_l, MARGIN_M, strict) < 0.0:
		out.code = PackedPlan.GOAL_BLOCKED
		out.why = "the goal pose is not clear by %.1f m" % MARGIN_M
		return out
	if _at_goal(req, req.start_x, req.start_z, theta0, goal_theta, tol_rad, 0):
		out.code = PackedPlan.ALREADY_THERE
		out.end_x = req.start_x
		out.end_z = req.start_z
		out.end_fx = req.start_fx
		out.end_fz = req.start_fz
		return out
	# ---- node storage (parallel arrays; a node is an index) ----
	var nx := PackedFloat32Array()
	var nz := PackedFloat32Array()
	var nfx := PackedFloat32Array()
	var nfz := PackedFloat32Array()
	var nth := PackedFloat32Array()   # the accumulated heading (the sum of the commanded steps; the key and the heuristic)
	var ng := PackedFloat32Array()
	var nparent := PackedInt32Array()
	var ngear := PackedInt32Array()
	var nsteer := PackedFloat32Array()
	var nlen := PackedFloat32Array()   # the leg's metres from the parent
	nx.append(req.start_x); nz.append(req.start_z); nfx.append(req.start_fx); nfz.append(req.start_fz); nth.append(theta0)
	ng.append(0.0); nparent.append(-1); ngear.append(0); nsteer.append(0.0); nlen.append(0.0)
	# ---- the open heap (f, id) and the closed / best-g tables keyed by cell ----
	var heap_f := PackedFloat32Array()
	var heap_id := PackedInt32Array()
	var closed := {}
	var best_g := {}
	var roll_ok := {}  # node id -> whether the roll past this node in its own gear is clear (asked once)
	var cusp_s := req.cusp_seconds()
	var epsilon := req.epsilon if req.epsilon > 0.0 else EPSILON
	var table := PlannerHeuristic.table_for(req)
	# The goal's frame for the table: a point's (dx, dz) along and across the goal heading, its heading relative.
	var gfx := req.goal_fx
	var gfz := req.goal_fz
	# The room the heuristic's cusp term assumes: the lateral room at the START (one number for the whole plan, so the
	# estimate is consistent: read per node it rose beside every wall, which is exactly where a turn's cusps are).
	var room := world.clearance(req.start_x, req.start_z)
	var swing := _swing_per_leg(room, radius, half_l, half_w)
	_heap_push(heap_f, heap_id, epsilon * _heuristic(req, req.start_x, req.start_z, theta0, goal_theta, radius, cusp_s, swing,
			table, gfx, gfz, 0), 0)
	best_g[_key(req.start_x, req.start_z, theta0, 0, cell_m, bins)] = 0.0
	var v_fwd := maxf(req.v_fwd, 0.1)
	var v_rev := maxf(req.v_rev, 0.1)
	var horizon2 := req.horizon_m * req.horizon_m
	var expansions := 0
	var goal_id := -1
	var best_cost := INF
	var first_at := 0
	var gears: Array[int] = [1, -1]
	var heap_f_last := 0.0
	while heap_f.size() > 0:
		heap_f_last = heap_f[0]
		var cur := _heap_pop(heap_f, heap_id)
		if goal_id >= 0:
			# Anytime: the popped f is weighted; its unweighted bound is g + (f - g) / epsilon. Stop when no cheaper plan can follow.
			var bound := ng[cur] + (heap_f_last - ng[cur]) / epsilon
			if bound >= best_cost:
				break
		var ckey := _key(nx[cur], nz[cur], nth[cur], ngear[cur], cell_m, bins)
		if closed.has(ckey):
			continue
		closed[ckey] = true
		if expansions >= req.budget:
			if goal_id < 0:
				out.code = PackedPlan.BUDGET
				out.why = "budget of %d expansions spent" % req.budget
			break
		expansions += 1
		if _at_goal(req, nx[cur], nz[cur], nth[cur], goal_theta, tol_rad, ngear[cur]):
			# The last leg's roll past its end must be clear too.
			if _roll_clear(world, req, start_offs, nx[cur], nz[cur], nfx[cur], nfz[cur], ngear[cur], nsteer[cur], radius, lag_fwd, lag_rev):
				if ng[cur] < best_cost:
					best_cost = ng[cur]
					goal_id = cur
					if first_at == 0:
						first_at = expansions
			continue
		var px := nx[cur]
		var pz := nz[cur]
		var pfx := nfx[cur]
		var pfz := nfz[cur]
		var pth := nth[cur]
		var pg := ng[cur]
		var pgear := ngear[cur]
		var psteer := nsteer[cur]
		for gear in gears:
			var cusp := pgear != 0 and gear != pgear
			if cusp:
				# A gear change here: the parent's leg ends at the parent, and its roll must be clear.
				var ok: Variant = roll_ok.get(cur)
				if ok == null:
					ok = _roll_clear(world, req, start_offs, px, pz, pfx, pfz, pgear, psteer, radius, lag_fwd, lag_rev)
					roll_ok[cur] = ok
				if not bool(ok):
					continue
			var v := v_fwd if gear > 0 else v_rev
			var lag := lag_fwd if gear > 0 else lag_rev
			var r_gear := radius_fwd if gear > 0 else radius_rev
			for steer in STEERS:
				# Sweep the leg: SUB_M steps, each turning then moving (Movement._fill_step's order), the move direction
				# lagging the heading by the plant's v*dt/R on an arc; a successor at every LEG_ENDS_M and at the goal.
				var x := px
				var z := pz
				var fx := pfx
				var fz := pfz
				var th := pth
				var dth := SUB_M * steer / r_gear
				var dth_t := _tan(dth)  # the small-angle step that rotates by exactly dth (step-size independent)
				# The move direction: the mid-step tangent (the heading is ahead of it by dth / 2) less the plant's lag
				# (its heading is v*dt/R behind the arc; it moves along the heading at a tick's END, so its move sits
				# half a lag behind the arc's tangent). Step-size independent, so the search and the trace agree.
				var lagged := _tan(-dth * 0.5 - steer * lag * 0.5)
				var swept := 0.0
				var band := 0.0
				var next_end := 0
				var g_leg := pg
				if cusp:
					g_leg += cusp_s
				elif pgear != 0 and steer != psteer:
					g_leg += STEER_CHANGE_S
				while swept < LEG_MAX_M - 0.001:
					var mx := fx
					var mz := fz
					if steer != 0.0:
						# TankMotion.turn_heading: forward + right * radians, renormalised (right = (-fz, fx)).
						var tx := fx - fz * dth_t
						var tz := fz + fx * dth_t
						var inv := 1.0 / sqrt(tx * tx + tz * tz)
						fx = tx * inv
						fz = tz * inv
						th += dth
						var lx := fx - fz * lagged
						var lz := fz + fx * lagged
						var linv := 1.0 / sqrt(lx * lx + lz * lz)
						mx = lx * linv
						mz = lz * linv
					x += mx * SUB_M * gear
					z += mz * SUB_M * gear
					swept += SUB_M
					var c := world.footprint(x, z, fx, fz, half_w, half_l, MARGIN_M, start_offs)
					if c < 0.0:
						break
					if c < BAND_M:
						band += BAND_S_PER_M * (BAND_M - c) * SUB_M
					var ddx := x - req.start_x
					var ddz := z - req.start_z
					if ddx * ddx + ddz * ddz > horizon2:
						break
					var at_end := next_end < LEG_ENDS_M.size() and swept >= LEG_ENDS_M[next_end] - 0.001
					if at_end:
						next_end += 1
					if not at_end and (swept < 1.0 - 0.001 or not _at_goal(req, x, z, th, goal_theta, tol_rad, gear)):
						continue
					var g := g_leg + swept / v + band
					var key := _key(x, z, th, gear, cell_m, bins)
					if closed.has(key):
						continue
					var known: Variant = best_g.get(key)
					if known != null and float(known) <= g:
						continue
					best_g[key] = g
					var id := nx.size()
					nx.append(x); nz.append(z); nfx.append(fx); nfz.append(fz); nth.append(th)
					ng.append(g); nparent.append(cur); ngear.append(gear); nsteer.append(steer); nlen.append(swept)
					_heap_push(heap_f, heap_id, g + epsilon * _heuristic(req, x, z, th, goal_theta, radius, cusp_s, swing, table, gfx, gfz, gear), id)
	last_expansions = expansions
	last_nodes = nx.size()
	out.expansions = expansions
	if goal_id < 0:
		if out.code != PackedPlan.BUDGET:
			out.code = PackedPlan.NO_PATH
			out.why = "no pose within %.0f m reaches the goal on the %.1f m / %d-bin lattice (%d expansions, %d nodes)" % [req.horizon_m, cell_m, bins, expansions, nx.size()]
		return out
	# ---- the path, merged into legs ----
	var chain: Array[int] = []
	var at := goal_id
	while at > 0:
		chain.append(at)
		at = nparent[at]
	chain.reverse()
	var legs: Array[Vector3] = []
	for id in chain:
		var gear := ngear[id]
		var steer := nsteer[id]
		if not legs.is_empty() and int(legs[-1].x) == gear and legs[-1].y == steer:
			legs[-1].z += nlen[id]
		else:
			legs.append(Vector3(float(gear), steer, nlen[id]))
	out.legs = legs
	out.code = PackedPlan.OK
	out.cost_s = ng[goal_id]
	out.why = "%d legs, %.1f s, %d expansions (first plan at %d)" % [legs.size(), ng[goal_id], expansions, first_at]
	trace(req, out)
	return out


## Drive `out.legs` kinematically from the request's start (TRACE_SUB_M sub-steps): fills `poses`, `metres`, `cusps`
## and the end pose. The same arithmetic as the search, so the end pose is the goal node's.
static func trace(req: PlanRequest, out: PackedPlan) -> void:
	var x := req.start_x
	var z := req.start_z
	var fx := req.start_fx
	var fz := req.start_fz
	var radius := maxf(req.radius, 0.5)
	out.poses = [[x, z, fx, fz, 0]]
	out.metres = 0.0
	out.cusps = 0
	var last_gear := 0
	for leg in out.legs:
		var gear := int(leg.x)
		if last_gear != 0 and gear != last_gear:
			out.cusps += 1
		last_gear = gear
		var lag := (req.v_fwd if gear > 0 else req.v_rev) * SimClock.TICK_SECONDS / radius
		var r_gear := _effective_radius(radius, req.v_fwd if gear > 0 else req.v_rev)
		var gone := 0.0
		while gone < leg.z - 0.0001:
			var step := minf(TRACE_SUB_M, leg.z - gone)
			var mx := fx
			var mz := fz
			if leg.y != 0.0:
				var dth := step * leg.y / r_gear
				var lagged := _tan(-dth * 0.5 - leg.y * lag * 0.5)
				var dth_t := _tan(dth)
				var tx := fx - fz * dth_t
				var tz := fz + fx * dth_t
				var inv := 1.0 / sqrt(tx * tx + tz * tz)
				fx = tx * inv
				fz = tz * inv
				var lx := fx - fz * lagged
				var lz := fz + fx * lagged
				var linv := 1.0 / sqrt(lx * lx + lz * lz)
				mx = lx * linv
				mz = lz * linv
			x += mx * step * gear
			z += mz * step * gear
			gone += step
			out.poses.append([x, z, fx, fz, gear])
		out.metres += leg.z
	out.end_x = x
	out.end_z = z
	out.end_fx = fx
	out.end_fz = fz


static func _at_goal(req: PlanRequest, x: float, z: float, th: float, goal_theta: float, tol_rad: float, gear: int) -> bool:
	if req.arrive_gear != 0 and gear != req.arrive_gear:
		return false
	var dx := x - req.goal_x
	var dz := z - req.goal_z
	if dx * dx + dz * dz > req.tol_m * req.tol_m:
		return false
	return absf(_wrap(th - goal_theta)) <= tol_rad


## The estimate that orders the search. Its admissible core: the fastest metre is a forward one, and any drivable
## path is at least as long as the straight distance and at least R times the heading change it still needs (heading
## per metre <= 1 / R in either gear). Two informed terms on top, each the larger taken: (a) the free-space table
## (PlannerHeuristic: the lattice's own cost to the pose with no obstacles, so a turn that must end near where it
## began knows its cusps); (b) the cusps the heading change needs in the room the hull had at the START: one
## full-lock swing in that room is `swing` radians (_swing_per_leg), so ceil(turn / swing) legs and one cusp fewer.
## Neither is admissible (room grows along a path; the table is coarse); the epsilon bound already accepts that.
## Without them a rig's turn-round in a 20 m street was a 4000-expansion breadth search.
static func _heuristic(req: PlanRequest, x: float, z: float, th: float, goal_theta: float, radius: float, cusp_s: float,
		swing: float, table: PackedFloat32Array, gfx: float, gfz: float, gear: int) -> float:
	var dx := x - req.goal_x
	var dz := z - req.goal_z
	var d := sqrt(dx * dx + dz * dz)
	var turn := absf(_wrap(th - goal_theta))
	var h := maxf(d, radius * turn) / maxf(req.v_fwd, 0.1)
	# The goal's frame: along = d . goal_forward, across = d . goal_right; the heading relative to the goal's.
	var along := dx * gfx + dz * gfz
	var across := -dx * gfz + dz * gfx
	var tabled := PlannerHeuristic.lookup(table, along, across, th - goal_theta, gear, cusp_s)
	if tabled < INF and tabled > h:
		h = tabled
	if turn > 0.3 and swing < PI:
		var legs := ceilf(turn / swing)
		if legs > 1.0:
			h = maxf(h, maxf(d, radius * turn) / maxf(req.v_fwd, 0.1) + cusp_s * (legs - 1.0))
	return h


## The most one full-lock leg can swing a hull of half-length l, half-width w on radius R starting on the centreline of
## a corridor with `room` metres to the wall: the largest a with R(1 - cos a) + l sin a + w cos a <= room, by bisection
## on trig-free polynomials (exact enough to 60 degrees), at least 15 degrees; PI when the room is not a corridor.
static func _swing_per_leg(room: float, radius: float, half_l: float, half_w: float) -> float:
	if room >= radius + half_l:
		return PI
	var lo := 0.0
	var hi := PI * 0.5
	for i in 24:
		var a := (lo + hi) * 0.5
		var a2 := a * a
		var one_minus_cos := a2 * 0.5 - a2 * a2 / 24.0
		var sin_a := a - a2 * a / 6.0
		var cos_a := 1.0 - one_minus_cos
		var need := radius * one_minus_cos + half_l * sin_a + half_w * cos_a
		if need <= room:
			lo = a
		else:
			hi = a
	return maxf(lo, 0.26)


static func _wrap(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


## tan(a) by its series (trig-free; exact to 1e-7 up to 0.3 rad, the largest step here): the small-angle step
## `forward + right * t` renormalised rotates by atan(t), so t = tan(a) rotates by exactly `a` whatever the step size.
static func _tan(a: float) -> float:
	var a2 := a * a
	return a * (1.0 + a2 * (1.0 / 3.0 + a2 * (2.0 / 15.0 + a2 * 17.0 / 315.0)))


## The radius the plant drives at speed v on lock 1: its heading step a tick is atan(v·dt/R), short of v·dt/R by
## (v·dt/R)³/3, so it turns (1 − (v·dt/R)²/3) of the arc per metre.
static func _effective_radius(radius: float, v: float) -> float:
	var d := v * SimClock.TICK_SECONDS / radius
	return radius / maxf(1.0 - d * d / 3.0, 0.5)


static func _key(x: float, z: float, th: float, gear: int, cell_m: float, bins: int) -> int:
	var ix := int(floor(x / cell_m)) + 4096
	var iz := int(floor(z / cell_m)) + 4096
	var ib := int(floor(fposmod(th, TAU) / TAU * bins)) % bins
	return ((ix * 8192 + iz) * 64 + ib) * 2 + (1 if gear > 0 else 0)


## Is the hull still clear ROLL_SLACK_M further along the arc it is on (the executor's stop past a leg's end)?
static func _roll_clear(world: PlannerWorld, req: PlanRequest, start_offs: PackedFloat32Array,
		x: float, z: float, fx: float, fz: float, gear: int, steer: float, radius: float, lag_fwd: float, lag_rev: float) -> bool:
	if gear == 0:
		return true
	var mx := fx
	var mz := fz
	if steer != 0.0:
		var dth := ROLL_SLACK_M * steer / radius
		var dth_t := _tan(dth)
		var tx := fx - fz * dth_t
		var tz := fz + fx * dth_t
		var inv := 1.0 / sqrt(tx * tx + tz * tz)
		fx = tx * inv
		fz = tz * inv
		var lagged := _tan(-dth * 0.5 - steer * (lag_fwd if gear > 0 else lag_rev) * 0.5)
		var lx := fx - fz * lagged
		var lz := fz + fx * lagged
		var linv := 1.0 / sqrt(lx * lx + lz * lz)
		mx = lx * linv
		mz = lz * linv
	x += mx * ROLL_SLACK_M * gear
	z += mz * ROLL_SLACK_M * gear
	return world.footprint(x, z, fx, fz, req.half_w, req.half_l, MARGIN_M, start_offs) >= 0.0


# ---- a binary min-heap on (f, id); ties by the lower id (first pushed wins: deterministic) ----
static func _heap_push(hf: PackedFloat32Array, hid: PackedInt32Array, f: float, id: int) -> void:
	hf.append(f)
	hid.append(id)
	var i := hf.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hf[p] < hf[i] or (hf[p] == hf[i] and hid[p] < hid[i]):
			break
		var tf := hf[p]; hf[p] = hf[i]; hf[i] = tf
		var ti := hid[p]; hid[p] = hid[i]; hid[i] = ti
		i = p


static func _heap_pop(hf: PackedFloat32Array, hid: PackedInt32Array) -> int:
	var top := hid[0]
	var last := hf.size() - 1
	hf[0] = hf[last]
	hid[0] = hid[last]
	hf.resize(last)
	hid.resize(last)
	var n := last
	var i := 0
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		if l < n and (hf[l] < hf[m] or (hf[l] == hf[m] and hid[l] < hid[m])):
			m = l
		if r < n and (hf[r] < hf[m] or (hf[r] == hf[m] and hid[r] < hid[m])):
			m = r
		if m == i:
			break
		var tf := hf[m]; hf[m] = hf[i]; hf[i] = tf
		var ti := hid[m]; hid[m] = hid[i]; hid[i] = ti
		i = m
	return top
