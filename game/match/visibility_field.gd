class_name VisibilityField
extends Node
## What ONE team can see, as a grid a UI can draw (G1): every 2 m cell of the arena is NEVER seen,
## SEEN before, or VISIBLE now. It's the union of each living tank's view: inside its sight radius
## and not blocked by obstacles (rays at eye height on the world layer, like Perception).
##
## Presentation only: brains never read it (they use Match.intel, built from the same rays), so it
## can't change the simulation. Created by modes that show fog (skirmish), never on a server.
##
## API (the "Visibility / radar data" contract in _agents/workstreams.md):
##   state_at(world: Vector3) -> State
##   image / texture   one pixel per cell, L8: 0 never, SEEN_VALUE seen, 255 visible now
##   fans              one PackedVector2Array per viewer: [viewer xz, ray end xz, ...] (a triangle fan)
##   cell_to_world / world_to_cell, CELL_SIZE, cells (per side), origin (world xz of cell 0,0's corner)
##   signal updated    after each refresh
##
## S1 (round 16): the same answer, cheaper. It ran only in the game he plays (no headless instrument saw it) and cost,
## per tick, one viewer's ~346 rays (1.6 ms on his laptop) and a `sqrt` + `atan2` over every cell of the viewer's box
## (~15 600 cells at 125 m, 4.2 ms), plus a GDScript pass over all 19 600 cells to rebuild the image every refresh
## (3.3 ms) -- `tests/scale/visfield_bench.gd`. Now:
##   - a viewer whose eye and sight radius are EXACTLY what they were at its last look reuses that look whole (rays,
##     fan and marked cells): the world layer is static after the arena loads, so the rays could not answer
##     differently. A quantised key would change the picture; an exact one cannot.
##   - the cell mark is a quadtree over the box: a block whose every cell is provably lit (its farthest cell centre is
##     within the shortest limit of every ray it could map to) or provably dark is decided whole; only blocks on a
##     lit/dark edge go down to single cells, which run the original test unchanged (same expression, same `atan2`).
##   - marks are spans filled natively into images (`fill_rect`, `blit_rect_mask`), so a refresh is three native blits.
## `tests/test_match_visfield_parity.gd` runs this beside the pre-S1 field (`tests/scale/visfield_reference.gd`) on the
## same match and compares the image, every cell's state and every fan, tick by tick.

signal updated

enum State { NEVER, SEEN, VISIBLE }

const CELL_SIZE := 2.0
## X3 (round 7): the world xz of cell (0,0)'s corner, sized to the ACTIVE arena rather than to the bound. It was a
## const off Match.ARENA_HALF_SIZE, which stopped being a size when that became a ceiling: a 120 m map would have
## carried a 280 x 280 field, 36% more cells to fill and upload every refresh, all of it outside the walls. A var,
## because the answer now depends on which layout is loaded. Readers that took it statically (`VisibilityField.ORIGIN`)
## must take it from the instance.
var origin := Vector2(-Match.ARENA_HALF_SIZE, -Match.ARENA_HALF_SIZE)
## A full refresh this often (ticks); viewers are spread across the interval to keep frames smooth.
const REFRESH_TICKS := SimClock.TICK_RATE / 2
const SEEN_VALUE := 90

var game_match: Match
var team := Match.Team.GREEN
var cells := 0
var image: Image
var texture: ImageTexture
## Tank name → its latest fan (so the fans of staggered viewers stay current).
var fans_by_viewer := {}
var fans: Array[PackedVector2Array] = []
## S1: false stops the field computing (the picture holds); `--sim-off=visfield` sets it for a whole run.
var enabled := true
## S1: a look's cell marks run on a WorkerThreadPool thread (native builds with more than one core; the web build has
## no threads). False computes them inline, as before.
var threaded := OS.has_feature("threads") and not OS.has_feature("web") and OS.get_processor_count() > 1
## [task id, viewer name, [eye, radius, fan] + rects when done] for looks computing off the main thread.
var _pending: Array = []
## Looks answered from the memo (a viewer that had not moved): a positive control for tests and the bench.
var reused_looks := 0

## Cells marked in the refresh being built (`_cur`) and the one before it (`_prev`), alpha 255 = marked: together
## they are what is VISIBLE now (a cell stays visible until a whole refresh has passed without it). `_ever` is the
## L8 picture of everything seen before (0 or SEEN_VALUE).
var _cur: Image
var _prev: Image
var _ever: Image
var _seen_src: Image
var _lit_src: Image
var _full: Rect2i
var _tick := 0
## Tank name → [eye: Vector3, radius: float, fan: PackedVector2Array, rects: PackedInt32Array (x, y, w, h)...].
var _memo := {}
## ray count → PackedVector3Array of ray directions (the same cos/sin of the same angle, computed once).
var _directions := {}

const _MARK := Color(1, 1, 1, 1)
const _CLEAR := Color(0, 0, 0, 0)


func _ready() -> void:
	var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
	origin = Vector2(-half, -half)
	cells = ceili(half * 2.0 / CELL_SIZE)
	image = Image.create(cells, cells, false, Image.FORMAT_L8)
	texture = ImageTexture.create_from_image(image)
	_full = Rect2i(0, 0, cells, cells)
	_cur = Image.create(cells, cells, false, Image.FORMAT_LA8)
	_prev = Image.create(cells, cells, false, Image.FORMAT_LA8)
	_ever = Image.create(cells, cells, false, Image.FORMAT_L8)
	# Built from bytes, not a Color: L8 stores a colour through a float multiply that need not land on 90 exactly.
	var bytes := PackedByteArray()
	bytes.resize(cells * cells)
	bytes.fill(SEEN_VALUE)
	_seen_src = Image.create_from_data(cells, cells, false, Image.FORMAT_L8, bytes)
	bytes.fill(255)
	_lit_src = Image.create_from_data(cells, cells, false, Image.FORMAT_L8, bytes)
	if SimProfile.switched_off("visfield"):
		enabled = false
	if SimProfile.switched_off("visfield_thread"):
		threaded = false


func _physics_process(_delta: float) -> void:
	if game_match == null or not enabled:
		return
	var started := _profile_start()
	_tick += 1
	var viewers := game_match.sorted_team_tanks(team)
	if viewers.is_empty():
		_profile("visfield", started)
		return
	# Spread viewers over the refresh interval: at most a few rays' worth of work per tick.
	var slot_ticks := maxi(1, REFRESH_TICKS / viewers.size())
	if _tick % slot_ticks == 0:
		var index := (_tick / slot_ticks) % viewers.size()
		look_from(viewers[index], index == viewers.size() - 1)
		if index == viewers.size() - 1:
			_finish_refresh(viewers)
	_profile("visfield", started)


## Recompute everything now (tests, and the first frame).
func refresh_all() -> void:
	var viewers := game_match.sorted_team_tanks(team)
	for viewer in viewers:
		look_from(viewer, false)
	_finish_refresh(viewers)


func state_at(world: Vector3) -> State:
	_sync()
	var cell := world_to_cell(world)
	if cell.x < 0 or cell.y < 0 or cell.x >= cells or cell.y >= cells:
		return State.NEVER
	if _cur.get_pixel(cell.x, cell.y).a > 0.0 or _prev.get_pixel(cell.x, cell.y).a > 0.0:
		return State.VISIBLE
	return State.SEEN if _ever.get_pixel(cell.x, cell.y).r > 0.0 else State.NEVER


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x - origin.x) / CELL_SIZE), floori((world.z - origin.y) / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(origin.x + (cell.x + 0.5) * CELL_SIZE, 0.0, origin.y + (cell.y + 0.5) * CELL_SIZE)


## One viewer's view: a fan of rays out to its sight radius, then every cell inside the fan is marked.
func look_from(viewer: Tank, finishing := true) -> void:
	var viewer_name := String(viewer.name)
	if not viewer.is_alive():
		fans_by_viewer.erase(viewer_name)
		_memo.erase(viewer_name)
		return
	var radius := viewer.sight_radius
	var eye := viewer.global_position + Vector3.UP * Perception.EYE_HEIGHT
	var memo: Array = _memo.get(viewer_name, [])
	if not memo.is_empty() and memo[0] == eye and memo[1] == radius:
		fans_by_viewer[viewer_name] = memo[2]
		_fill(memo[3])
		reused_looks += 1
		return
	var started := _profile_start()
	var space := viewer.get_world_3d().direct_space_state
	var ray_count := ceili(TAU * radius / CELL_SIZE)
	var directions: PackedVector3Array = _directions.get(ray_count, PackedVector3Array())
	if directions.is_empty():
		directions.resize(ray_count)
		for r in ray_count:
			var angle := TAU * r / ray_count
			directions[r] = Vector3(cos(angle), 0.0, sin(angle))
		_directions[ray_count] = directions
	var reach := PackedFloat32Array()
	reach.resize(ray_count)
	var fan := PackedVector2Array([Vector2(eye.x, eye.z)])
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Perception.WORLD_MASK
	query.from = eye
	for r in ray_count:
		var direction := directions[r]
		query.to = eye + direction * radius
		var hit := space.intersect_ray(query)
		var distance := radius
		if not hit.is_empty():
			distance = eye.distance_to(hit.position)
		reach[r] = distance
		fan.append(Vector2(eye.x + direction.x * distance, eye.z + direction.z * distance))
	fans_by_viewer[viewer_name] = fan
	_profile("visfield/rays", started)
	started = _profile_start()
	if threaded and not finishing:
		# The marks are only READ at the next refresh (or by state_at), so they are computed off the main thread and
		# joined there (`_sync`). The look that ends a refresh is joined at once: the picture must not slip a tick.
		var holder: Array = [eye, radius, fan]
		var center := Vector2(eye.x, eye.z)
		var task := WorkerThreadPool.add_task(func() -> void: holder.append(_mark(center, radius, reach)))
		_pending.append([task, viewer_name, holder])
		_profile("visfield/dispatch", started)
		return
	var rects := _mark(Vector2(eye.x, eye.z), radius, reach)
	_profile("visfield/mark", started)
	_apply(viewer_name, [eye, radius, fan, rects])


## Join every look still computing on a worker and apply its marks (any order: a refresh's marks are a union).
func _sync() -> void:
	if _pending.is_empty():
		return
	var started := _profile_start()
	for entry: Array in _pending:
		WorkerThreadPool.wait_for_task_completion(entry[0])
		_apply(entry[1], entry[2])
	_pending.clear()
	_profile("visfield/join", started)


func _apply(viewer_name: String, look: Array) -> void:
	_fill(look[3])
	_memo[viewer_name] = look


func _exit_tree() -> void:
	_sync()


func _fill(rects: PackedInt32Array) -> void:
	for i in range(0, rects.size(), 4):
		_cur.fill_rect(Rect2i(rects[i], rects[i + 1], rects[i + 2], rects[i + 3]), _MARK)


## The cells one viewer lights, as row runs (x, y, w, 1). A cell counts as seen when its center is within reach along
## the nearest ray. Cells a whole cell past an obstacle's face stay dark; the obstacle's own face cell is lit.
##
## The per-cell rule is the pre-S1 one, expression for expression (`tests/scale/visfield_reference.gd` `_mark`): S1
## tried a quadtree that decides whole blocks without `atan2` and it LOST in GDScript (3.7 ms a look against the
## plain loop's 1.9 ms, same process, his spawn: a star of ~350 shadow spokes leaves few whole blocks, and a block
## costs ~4 us of interpreted bookkeeping). What is kept: each row walks only the columns that can be inside the
## sight radius (a cell more than a cell beyond the circle's chord is provably outside: `distance > radius` by
## >= 1 cm there, far past any rounding), and lit cells leave as runs for a native fill.
##
## Pure (reads only `origin`, `cells` and its arguments), so it may run on a worker thread (`_dispatch`).
func _mark(center: Vector2, radius: float, reach: PackedFloat32Array) -> PackedInt32Array:
	var ray_count := reach.size()
	var per_radian := ray_count / TAU
	var lo := world_to_cell(Vector3(center.x - radius, 0.0, center.y - radius))
	var hi := world_to_cell(Vector3(center.x + radius, 0.0, center.y + radius))
	var x0 := maxi(lo.x, 0)
	var x1 := mini(hi.x, cells - 1)
	var y0 := maxi(lo.y, 0)
	var y1 := mini(hi.y, cells - 1)
	var runs := PackedInt32Array()
	var slack := CELL_SIZE * 0.75
	for y in range(y0, y1 + 1):
		var dz := origin.y + (y + 0.5) * CELL_SIZE - center.y
		if absf(dz) > radius + CELL_SIZE:
			continue
		var chord := sqrt(maxf(radius * radius - dz * dz, 0.0)) + CELL_SIZE
		var row_x0 := maxi(x0, floori((center.x - chord - origin.x) / CELL_SIZE) - 1)
		var row_x1 := mini(x1, ceili((center.x + chord - origin.x) / CELL_SIZE) + 1)
		var run_start := -1
		for x in range(row_x0, row_x1 + 1):
			var dx := origin.x + (x + 0.5) * CELL_SIZE - center.x
			var distance := sqrt(dx * dx + dz * dz)
			var lit := false
			if distance <= radius:
				var angle := atan2(dz, dx)
				if angle < 0.0:
					angle += TAU
				var ray := int(angle * per_radian + 0.5) % ray_count
				lit = distance <= reach[ray] + slack
			if lit:
				if run_start < 0:
					run_start = x
			elif run_start >= 0:
				runs.append_array(PackedInt32Array([run_start, y, x - run_start, 1]))
				run_start = -1
		if run_start >= 0:
			runs.append_array(PackedInt32Array([run_start, y, row_x1 + 1 - run_start, 1]))
	return runs


func _finish_refresh(viewers: Array[Tank]) -> void:
	_sync()
	var started := _profile_start()
	fans.clear()
	for viewer in viewers:
		if fans_by_viewer.has(String(viewer.name)) and viewer.is_alive():
			fans.append(fans_by_viewer[String(viewer.name)])
	# Everything marked this refresh is now SEEN-or-better for good, and the picture is that, lit where marked.
	_ever.blit_rect_mask(_seen_src, _cur, _full, Vector2i.ZERO)
	image.copy_from(_ever)
	image.blit_rect_mask(_lit_src, _cur, _full, Vector2i.ZERO)
	texture.update(image)
	var swap := _prev
	_prev = _cur
	_cur = swap
	_cur.fill(_CLEAR)
	_profile("visfield/finish", started)
	updated.emit()


static func _profile_start() -> int:
	return Time.get_ticks_usec() if SimProfile.enabled else 0


static func _profile(section: String, started: int) -> void:
	if started > 0:
		SimProfile.add(section, started)
