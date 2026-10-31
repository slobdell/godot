class_name NoProgressWatch
extends RefCounted
## Round 47 (manoeuvre M2, `--traffic-on=noprogress` until its bar; C47.3): **A CREW THAT MAKES NO PROGRESS NOTICES AND ASKS FOR A NEW
## ROUTE.** His words (2026-10-30): a crew "drove straight forward into a building and got stuck", "vehicles getting stuck behind
## containers". The staged case it is built on (tests/test_manoeuvre_noprogress.gd, the CPU's Rust_Hunters on his Crossing recording):
## a crew whose navmesh path ends 2.9 m from it (a sliver between a block and a container) sat `blocked: no_path` creeping at throttle
## 0.2 for 15 s, below every unstick trigger (the stall clock reads a press at > 0.5 throttle), while a squadmate 2 m off drove out.
##
## Every SAMPLE_TICKS, for every live crew with a `move_to` order that is driving or blocked by TERRAIN (never by a hull: see
## _hull_involved; never one that is yielding, held at a
## street mouth (Traffic.holding), under a planner leg, in a k-turn leg or an escape, or in a short halt to shoot; a crew he HOLDs has
## no move order): when for WINDOW_TICKS on the same goal (within GOAL_SAME_M) it stayed more than FAR_M from the goal, moved less than
## MOVED_M net, and got less than CLOSER_M closer, it ASKS ROUTE for a new route (`Pathing.reroute(crew, &"noprogress")`, the one door,
## C47.3: route owns what comes back; this never plans or drives) and waits COOLDOWN_TICKS before it may ask again. Measurement of its
## own (`trips`, by phase) for the bar.
##
## Outside the drive on purpose: the native execute owns the drive and unstick (a C++ path), and a reroute is already a door into its
## state (it marks the mover stale). So the rule needs no twin of its own: it is GDScript on every path.

const SWITCH := "noprogress"
const SAMPLE_TICKS := SimClock.TICK_RATE / 2
const WINDOW_TICKS := SimClock.TICK_RATE * 3
const COOLDOWN_TICKS := SimClock.TICK_RATE * 3
const NO_PATH_WINDOW_TICKS := SimClock.TICK_RATE
const FAR_M := 6.0
const MOVED_M := 1.5
const CLOSER_M := 1.0
const GOAL_SAME_M := 3.0
const KEEP := 512

static var trips := 0
static var trips_by_phase := {}
## Tank instance id -> [goal, position, distance, tick] the window started at; and the tick it may ask again.
static var _since := {}
static var _cool := {}
static var _installed := false
## Measurement only: NOPROGRESS_WATCH_TRACE=on prints a WATCH line per trip.
static var trace := OS.get_environment("NOPROGRESS_WATCH_TRACE") == "on"
static var _last := -1


static func on() -> bool:
	return not Traffic.off(SWITCH)


static func report() -> Dictionary:
	return {"trips": trips, "by_phase": trips_by_phase.duplicate(), "off_island": Pathing.off_island_routes}


static func reset() -> void:
	trips = 0
	trips_by_phase.clear()
	_since.clear()
	_cool.clear()


## Movement._init calls this (GDScript on every path); the sampler then runs once a physics frame for the process.
static func install() -> void:
	if _installed:
		return
	_installed = true
	(Engine.get_main_loop() as SceneTree).physics_frame.connect(_sample)


static func _sample() -> void:
	var now := Engine.get_physics_frames()
	if now == _last or now % SAMPLE_TICKS != 0 or not on():
		return
	_last = now
	if _since.size() > KEEP:
		_since.clear()
		_cool.clear()
	for id: int in Movement._registry:
		var mover: Movement = Movement._registry[id]
		if mover != null and is_instance_valid(mover.ctl) and mover.ctl.tank != null:
			observe(mover, now)


static func _hull_involved(mover: Movement) -> bool:
	if mover.blocked_by == "no_path":
		return false  # the path is the cause, whoever stands beside it (the staged sliver: two crews on it, each "ahead" of the other)
	if mover.blocked_by != "" and mover.blocked_by != "terrain":
		return true
	var tank := mover.ctl.tank
	for i in tank.get_slide_collision_count():
		if tank.get_slide_collision(i).get_collider() is Tank:
			return true
	return mover._hull_ahead(mover._goal, bool(mover.ctl.move_order.get("direct", false))) != ""


static func observe(mover: Movement, now: int) -> void:
	var tank := mover.ctl.tank
	var key := tank.get_instance_id()
	var name := String(tank.name)
	var eligible: bool = tank.is_alive() and String(mover.ctl.move_order.get("type", "")) == "move_to" \
			and (mover.phase == "driving" or mover.phase == "blocked") and mover._goal != Vector3.INF \
			and not Traffic.holding(name) and not (PlannerSeam.on() and PlannerSeam.live(name)) and mover._kturn_left_m <= 0.0 \
			and mover._esc_stage == Movement.ESC_NONE and tank.short_halt_seconds <= 0.0
	if not eligible:
		_since.erase(key)
		return
	var here := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var goal := Vector3(mover._goal.x, 0.0, mover._goal.z)
	var to_go := here.distance_to(goal)
	var start: Array = _since.get(key, [])
	if start.is_empty() or (start[0] as Vector3).distance_to(goal) > GOAL_SAME_M or to_go <= FAR_M \
			or (start[1] as Vector3).distance_to(here) >= MOVED_M or float(start[2]) - to_go >= CLOSER_M:
		_since[key] = [goal, here, to_go, now]
		return
	# A crew `blocked: no_path` is going nowhere by its own reading: asked after NO_PATH_WINDOW_TICKS (its element re-deals seats, and
	# each new seat re-plans it from the sliver it stands on: the staged case, a seat moved every ~3 s).
	var window := NO_PATH_WINDOW_TICKS if mover.blocked_by == "no_path" else WINDOW_TICKS
	if now - int(start[3]) < window or now < int(_cool.get(key, -1)):
		return
	# Never a jam among hulls (a friend or a foe in the way is traffic's: the yield, the give-way, the wait). The dev read that
	# found it (Crossing, seed 7001, never a bar): 87 reroutes of four crews blocked by squadmates at their destination, and the
	# re-plans every 3 s made the jam worse (no-progress 618 -> 737 crew-s). Only terrain: blocked by nothing named, `no_path` or
	# `terrain`, touching no hull, no hull ahead.
	if _hull_involved(mover):
		_since[key] = [goal, here, to_go, now]
		return
	if trace:
		print("WATCH %d %s at (%.1f, %.1f) goal (%.1f, %.1f) to_go %.1f phase %s by %s path %d reachable %s v %.2f thr %.2f" % [now, name,
				here.x, here.z, goal.x, goal.z, to_go, mover.phase, mover.blocked_by, mover._path.size(), str(mover._reachable),
				tank.real_velocity.length(), tank.command.throttle])
	if Pathing.reroute(tank, &"noprogress"):
		trips += 1
		trips_by_phase[mover.phase] = int(trips_by_phase.get(mover.phase, 0)) + 1
	_cool[key] = now + (NO_PATH_WINDOW_TICKS if mover.blocked_by == "no_path" else COOLDOWN_TICKS)
	_since[key] = [goal, here, to_go, now]
