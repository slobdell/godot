class_name CinematicCamera
extends Node
## Control stretch: a camera that finds the fighting by itself, for spectating and trailers.
##
## It works in SHOTS, not in continuous drift, because a camera that chases the highest-scoring point every frame
## reads as a nervous mess. Each shot frames one cluster of vehicles and is held for SHOT_SECONDS; a new cluster
## only interrupts it when it is clearly better (SCORE_MARGIN) and the current shot has had MIN_SHOT_SECONDS.
## Moving a long way is a CUT (the pose snaps) rather than a glide across dead ground, the way a broadcast would.
##
## Scenes are scored on what makes a shot worth watching: both sides in the same place (a fight, not a drive),
## vehicles that have just been hit, and how many are in frame. It watches both teams, so it deliberately does
## not go through the L4 vision cap - nobody is earning this view, it is the spectator's.
##
##   --cinematic in skirmish, or set `rig` and `game_match` and add it to the tree.

## How long a shot is held before the camera is free to look elsewhere.
const SHOT_SECONDS := 6.0
## …and the shortest a shot can be, even when something much better happens.
const MIN_SHOT_SECONDS := 2.5
## A new scene has to beat the current one by this much to interrupt it.
const SCORE_MARGIN := 1.6
## Scenes are clustered on a grid this many meters across.
const CELL_M := 40.0
## A vehicle hit within this many ticks counts as "in the action".
const HIT_TICKS := SimClock.TICK_RATE * 2
## Further than this and the camera cuts instead of gliding.
const CUT_DISTANCE_M := 70.0
## Shots frame no closer than this, so a lone duel doesn't jam the lens into a hull.
const MIN_ZOOM := 0.14
## Framing adds this much ground around the vehicles in shot.
const MARGIN_M := 10.0

var rig: RtsCamera
var game_match: Match

var _age := 0.0
var _shot := {}
## Round 27 (orders O2): `--end-shots=<dir>` saves the end of the match as the recording shows it (frames after the
## result, then quits), and prints how much of each frame looks past the arena. Read from the command line here
## because it is a measuring flag of this camera's own, not a mode's.
var end_shots_dir := ""
## `--cinematic-keep-angle`: round 26's director (never turns to keep the camera inside the arena), the A/B's other arm.
var keep_angle := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var flags := LaunchFlags.from_environment()
	end_shots_dir = flags.text("end-shots")
	keep_angle = flags.has("cinematic-keep-angle")
	if end_shots_dir != "" and game_match != null:
		game_match.finished.connect(func(_result: Dictionary) -> void: _shoot_the_end())


## Start directing. Takes the camera off the player's vision framing: this view is the spectator's.
func start() -> void:
	if rig == null:
		return
	rig.vision = Callable()
	rig.vision_zoom = 1.0
	rig.vision_region = null
	rig.stop_tracking("replaced")
	rig.follow_target = null
	# Round 27 (O2): the director owns the angle. The rig's yaw-follow turned the view toward a selection's facing,
	# which fought the director's turns away from the wall (seed 202 Docks: 139 jumps of 60 deg+ in 201 s).
	if not keep_angle:
		rig.yaw_follow = false
	_age = SHOT_SECONDS  # the first frame picks a shot


## The shot the camera is holding: {"at": Vector3, "score", "units": int, "why"} ({} before the first).
func shot() -> Dictionary:
	return _shot


func _process(delta: float) -> void:
	if rig == null or game_match == null:
		return
	_age += delta
	var best := best_scene()
	if best.is_empty():
		return
	var current := float(_shot.get("score", -1.0))
	var take := _shot.is_empty() or _age >= SHOT_SECONDS \
			or (_age >= MIN_SHOT_SECONDS and float(best["score"]) > current * SCORE_MARGIN)
	if take and not _same_place(best):
		_cut_to(best)
	elif take:
		_shot = best  # the action stayed put: keep rolling, but re-score it
		_age = 0.0
	_frame(_shot)
	if end_shots_dir != "":
		_sample_whole_match(delta)


## With `--end-shots`, every second of the match: how much of the frame shows under the arena (CINEMATIC_FRAME lines),
## so the A/B reads every shot of a match, not only the last.
var _sampled := 0.0


func _sample_whole_match(delta: float) -> void:
	_sampled += delta
	if _sampled < 1.0 or rig.camera == null:
		return
	_sampled = 0.0
	var off := CinematicCamera.off_arena(rig.camera, rig.camera.get_viewport().get_visible_rect().size)
	print("CINEMATIC_FRAME under=%.3f bottom_under=%.3f near=%.2f yaw=%.0f" % [off["under"], off["bottom_under"],
			rig.camera.near, rad_to_deg(rig.yaw)])


## Whether a scene is close enough to the one on screen that moving there isn't a new shot.
func _same_place(scene: Dictionary) -> bool:
	if _shot.is_empty():
		return false
	return (_shot["at"] as Vector3).distance_to(scene["at"]) < CELL_M * 0.5


func _cut_to(scene: Dictionary) -> void:
	var far := _shot.is_empty() or (_shot["at"] as Vector3).distance_to(scene["at"]) > CUT_DISTANCE_M
	_shot = scene
	_age = 0.0
	_frame(scene)
	if far:
		rig.snap()  # a cut, not a three-second glide over empty ground


func _frame(scene: Dictionary) -> void:
	if scene.is_empty():
		return
	var points: Array = scene["points"]
	if points.is_empty():
		return
	var heading := rig.yaw if keep_angle else CinematicCamera.heading_for(points, rig.yaw, _aspect(), rig.pitch)
	var turned := not is_equal_approx(heading, rig.yaw)
	rig.yaw = heading
	var goal := RtsCamera.frame_pose(points, heading, _aspect(), MIN_ZOOM, RtsCamera.FRAME_INSET, rig.pitch)
	rig.focus = goal[0]
	rig.zoom = float(goal[1])
	if turned:
		rig.snap()  # a new angle is a cut, never a swing round the arena


## Round 27 (orders O2; round 26's showmatch end frame, seed 43496 Docks: the bottom third of the shot was the purple
## floor under the arena). A shot of vehicles near the wall on the CAMERA's side puts the camera out past the wall, and
## the rig's cutaway (RtsCamera.cutaway_near) then moves the near plane up to the wall to clear the stands: that plane
## slices off the ground in front of it too, and the bottom of the frame shows what is under the arena. The player's
## camera keeps that trade (he chose the angle, and a vehicle against the wall stays in view); the director picks its
## own angle, so it films from INSIDE the arena: the heading it has if that needs no cut, else the turn round, else a
## quarter turn that does not (the least cut when every one does). Pure, for tests.
static func heading_for(points: Array, yaw: float, aspect: float, pitch_deg: float) -> float:
	var best := yaw
	var least := INF
	# The turn round first: the camera then looks AT the wall it was behind, the crowd as the backdrop (a broadcast
	# shoots across the action toward the stands), then the quarter turns.
	for quarter in [0, 2, 1, -1]:
		var heading := wrapf(yaw + quarter * PI * 0.5, -PI, PI)
		var near := CinematicCamera.cut_at(points, heading, aspect, pitch_deg)
		if near <= RtsCamera.NEAR_DEFAULT:
			return heading if quarter != 0 else yaw
		if near < least:
			least = near
			best = heading
	return best


## The near plane the rig would cut at, framing `points` from `heading` (RtsCamera.NEAR_DEFAULT = no cut).
static func cut_at(points: Array, heading: float, aspect: float, pitch_deg: float) -> float:
	var goal := RtsCamera.frame_pose(points, heading, aspect, MIN_ZOOM, RtsCamera.FRAME_INSET, pitch_deg)
	var distance := RtsCamera.distance_for(float(goal[1]))
	return RtsCamera.cutaway_near(goal[0], heading, distance, RtsCamera.tilt_at(pitch_deg, distance), RtsCamera.perimeter_half())


func _aspect() -> float:
	if rig.camera == null or rig.camera.get_viewport() == null:
		return 16.0 / 9.0
	var view := rig.camera.get_viewport().get_visible_rect().size
	return view.x / maxf(view.y, 1.0)


## The best scene right now, or {} when nothing is alive. Pure enough to test: it reads the match and nothing else.
func best_scene() -> Dictionary:
	var ranked := scenes()
	return ranked[0] if not ranked.is_empty() else {}


## Every cluster of vehicles worth pointing a camera at, best first:
## [{"at": Vector3, "score": float, "units": int, "why": String, "points": Array}].
func scenes() -> Array:
	var cells := {}
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var key := Vector2i(floori(tank.global_position.x / CELL_M), floori(tank.global_position.z / CELL_M))
		if not cells.has(key):
			cells[key] = {"teams": {}, "hit": 0, "points": [], "sum": Vector3.ZERO}
		var cell: Dictionary = cells[key]
		cell["teams"][tank.team] = int(cell["teams"].get(tank.team, 0)) + 1
		if tank.ticks_since_hit <= HIT_TICKS:
			cell["hit"] = int(cell["hit"]) + 1
		(cell["points"] as Array).append(Vector3(tank.global_position.x, 0.0, tank.global_position.z))
		cell["sum"] = (cell["sum"] as Vector3) + Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var result: Array = []
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	for key: Vector2i in keys:
		var cell: Dictionary = cells[key]
		var counts: Dictionary = cell["teams"]
		var units := 0
		var smaller := 1 << 30
		for team: int in counts:
			units += int(counts[team])
			smaller = mini(smaller, int(counts[team]))
		var contested := smaller if counts.size() > 1 else 0
		# Both sides in one place is a fight; vehicles taking hits are the moment inside it; size breaks ties.
		var score := contested * 3.0 + int(cell["hit"]) * 2.0 + units * 0.5
		var why := "a firefight" if contested > 0 else ("under fire" if int(cell["hit"]) > 0 else "on the move")
		result.append({"at": (cell["sum"] as Vector3) / float(units), "score": score, "units": units, "why": why,
				"points": cell["points"]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return result


# ---- Round 27 (orders O2): the end shot stays on the arena ---------------------------------------------------------

## Seconds after the result at which `--end-shots` saves a frame (the banner, the hold, the last frame of a recording).
const END_SHOT_SECONDS := [0.5, 2.5, 4.5]


func _shoot_the_end() -> void:
	DirAccess.make_dir_recursive_absolute(end_shots_dir)
	var view := rig.camera.get_viewport()
	var size := view.get_visible_rect().size
	var tag := "%dx%d" % [int(size.x), int(size.y)]
	var waited := 0.0
	for i in END_SHOT_SECONDS.size():
		await get_tree().create_timer(float(END_SHOT_SECONDS[i]) - waited, true, false, true).timeout
		waited = float(END_SHOT_SECONDS[i])
		await RenderingServer.frame_post_draw
		var path := end_shots_dir.path_join("end-%s-%d.png" % [tag, i + 1])
		view.get_texture().get_image().save_png(path)
		var off := CinematicCamera.off_arena(rig.camera, size)
		print("CINEMATIC_END_SHOT %s t=%.1f under=%.3f bottom_under=%.3f off=%.3f void=%.3f near=%.2f yaw=%.0f pitch=%.1f distance=%.1f focus=%s shot=%s" % [
				path.get_file(), waited, off["under"], off["bottom_under"], off["off"], off["void"], rig.camera.near,
				rad_to_deg(rig.yaw),
				rad_to_deg(-rig.camera.global_rotation.x), rig.camera.global_position.distance_to(rig.focus),
				rig.focus, _shot.get("why", "-")])
	get_tree().quit()


## Sample columns and rows of the frame for `off_arena`.
const OFF_SAMPLES := Vector2i(16, 18)


## How much of what `camera` shows (a `view`-sized frame) is not the arena: {"off": the share of the frame's ground
## past the arena's walls, "void": the share past the ground itself (the purple under the arena: the ground ends
## Arena.GROUND_MARGIN beyond the walls), "bottom_void": the same for the bottom third of the frame, "under": the share
## of the ground the near plane cuts away (the frame shows what is under the arena there: what the lead saw),
## "bottom_under": the same for the bottom third}. Shares are of the samples whose ray reaches the ground; the sky is neither.
static func off_arena(camera: Camera3D, view: Vector2, data: Dictionary = Arena.active) -> Dictionary:
	var bound := float(data.get("half_size", Match.ARENA_HALF_SIZE))
	var kind := String((data.get("shape", {}) as Dictionary).get("kind", ArenaShape.DEFAULT_KIND))
	var ground_half := bound + Arena.GROUND_MARGIN
	var counts := {"ground": 0, "off": 0, "void": 0, "bottom": 0, "bottom_void": 0, "under": 0, "bottom_under": 0}
	var forward := -camera.global_basis.z
	for row in OFF_SAMPLES.y:
		for col in OFF_SAMPLES.x:
			var at := Vector2((col + 0.5) / OFF_SAMPLES.x * view.x, (row + 0.5) / OFF_SAMPLES.y * view.y)
			var origin := camera.project_ray_origin(at)
			var normal := camera.project_ray_normal(at)
			var bottom := row >= OFF_SAMPLES.y * 2 / 3
			if normal.y >= -1e-4:
				continue  # the sky
			var hit := origin + normal * (-origin.y / normal.y)
			counts["ground"] += 1
			counts["bottom"] += int(bottom)
			if not ArenaShape.contains(kind, bound, Vector2(hit.x, hit.z)):
				counts["off"] += 1
			if (hit - camera.global_position).dot(forward) < camera.near:
				counts["under"] += 1  # the near plane cut this ground away: the frame shows what is under the arena
				counts["bottom_under"] += int(bottom)
			if absf(hit.x) > ground_half or absf(hit.z) > ground_half:
				counts["void"] += 1
				counts["bottom_void"] += int(bottom)
	return {"off": float(counts["off"]) / maxf(counts["ground"], 1.0),
			"void": float(counts["void"]) / maxf(counts["ground"], 1.0),
			"bottom_void": float(counts["bottom_void"]) / maxf(counts["bottom"], 1.0),
			"under": float(counts["under"]) / maxf(counts["ground"], 1.0),
			"bottom_under": float(counts["bottom_under"]) / maxf(counts["bottom"], 1.0)}
