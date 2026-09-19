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

## Per cell: the refresh epoch in which a viewer last saw it (0 = never).
var _seen_epoch := PackedInt32Array()
var _epoch := 1
var _tick := 0


func _ready() -> void:
	var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
	origin = Vector2(-half, -half)
	cells = ceili(half * 2.0 / CELL_SIZE)
	_seen_epoch.resize(cells * cells)
	_seen_epoch.fill(0)
	image = Image.create(cells, cells, false, Image.FORMAT_L8)
	texture = ImageTexture.create_from_image(image)


func _physics_process(_delta: float) -> void:
	if game_match == null:
		return
	_tick += 1
	var viewers := game_match.sorted_team_tanks(team)
	if viewers.is_empty():
		return
	# Spread viewers over the refresh interval: at most a few rays' worth of work per tick.
	var slot_ticks := maxi(1, REFRESH_TICKS / viewers.size())
	if _tick % slot_ticks == 0:
		var index := (_tick / slot_ticks) % viewers.size()
		look_from(viewers[index])
		if index == viewers.size() - 1:
			_finish_refresh(viewers)


## Recompute everything now (tests, and the first frame).
func refresh_all() -> void:
	var viewers := game_match.sorted_team_tanks(team)
	for viewer in viewers:
		look_from(viewer)
	_finish_refresh(viewers)


func state_at(world: Vector3) -> State:
	var cell := world_to_cell(world)
	if cell.x < 0 or cell.y < 0 or cell.x >= cells or cell.y >= cells:
		return State.NEVER
	var epoch := _seen_epoch[cell.y * cells + cell.x]
	if epoch == 0:
		return State.NEVER
	return State.VISIBLE if epoch >= _epoch else State.SEEN


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x - origin.x) / CELL_SIZE), floori((world.z - origin.y) / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(origin.x + (cell.x + 0.5) * CELL_SIZE, 0.0, origin.y + (cell.y + 0.5) * CELL_SIZE)


## One viewer's view: a fan of rays out to its sight radius, then every cell inside the fan is marked.
func look_from(viewer: Tank) -> void:
	var viewer_name := String(viewer.name)
	if not viewer.is_alive():
		fans_by_viewer.erase(viewer_name)
		return
	var radius := viewer.sight_radius
	var eye := viewer.global_position + Vector3.UP * Perception.EYE_HEIGHT
	var space := viewer.get_world_3d().direct_space_state
	var ray_count := ceili(TAU * radius / CELL_SIZE)
	var reach := PackedFloat32Array()
	reach.resize(ray_count)
	var fan := PackedVector2Array([Vector2(eye.x, eye.z)])
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Perception.WORLD_MASK
	query.from = eye
	for r in ray_count:
		var angle := TAU * r / ray_count
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		query.to = eye + direction * radius
		var hit := space.intersect_ray(query)
		var distance := radius
		if not hit.is_empty():
			distance = eye.distance_to(hit.position)
		reach[r] = distance
		fan.append(Vector2(eye.x + direction.x * distance, eye.z + direction.z * distance))
	fans_by_viewer[viewer_name] = fan
	_mark(Vector2(eye.x, eye.z), radius, reach)


func _mark(center: Vector2, radius: float, reach: PackedFloat32Array) -> void:
	var ray_count := reach.size()
	var per_radian := ray_count / TAU
	var lo := world_to_cell(Vector3(center.x - radius, 0.0, center.y - radius))
	var hi := world_to_cell(Vector3(center.x + radius, 0.0, center.y + radius))
	var x0 := maxi(lo.x, 0)
	var x1 := mini(hi.x, cells - 1)
	var y0 := maxi(lo.y, 0)
	var y1 := mini(hi.y, cells - 1)
	# A cell counts as seen when its center is within reach along the nearest ray. Cells a whole
	# cell past an obstacle's face stay dark; the obstacle's own face cell is lit.
	var slack := CELL_SIZE * 0.75
	for y in range(y0, y1 + 1):
		var dz := origin.y + (y + 0.5) * CELL_SIZE - center.y
		var row := y * cells
		for x in range(x0, x1 + 1):
			var dx := origin.x + (x + 0.5) * CELL_SIZE - center.x
			var distance := sqrt(dx * dx + dz * dz)
			if distance > radius:
				continue
			var angle := atan2(dz, dx)
			if angle < 0.0:
				angle += TAU
			var ray := int(angle * per_radian + 0.5) % ray_count
			if distance <= reach[ray] + slack:
				_seen_epoch[row + x] = _epoch + 1


func _finish_refresh(viewers: Array[Tank]) -> void:
	_epoch += 1
	fans.clear()
	for viewer in viewers:
		if fans_by_viewer.has(String(viewer.name)) and viewer.is_alive():
			fans.append(fans_by_viewer[String(viewer.name)])
	var pixels := PackedByteArray()
	pixels.resize(cells * cells)
	for i in pixels.size():
		var epoch := _seen_epoch[i]
		pixels[i] = 0 if epoch == 0 else (255 if epoch >= _epoch else SEEN_VALUE)
	image.set_data(cells, cells, false, Image.FORMAT_L8, pixels)
	texture.update(image)
	updated.emit()
