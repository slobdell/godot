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
const HIT_TICKS := 120
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Start directing. Takes the camera off the player's vision framing: this view is the spectator's.
func start() -> void:
	if rig == null:
		return
	rig.vision = Callable()
	rig.vision_zoom = 1.0
	rig.vision_region = null
	rig.stop_tracking("replaced")
	rig.follow_target = null
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
	var goal := RtsCamera.frame_pose(points, rig.yaw, _aspect(), MIN_ZOOM)
	rig.focus = goal[0]
	rig.zoom = float(goal[1])


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
