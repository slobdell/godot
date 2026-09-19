class_name FlowField
extends RefCounted
## Round 8 (nav): one cost-to-goal field per shared goal, instead of every unit owning an A* route to the same place.
##
## A flow field (Emerson, "Crowd Pathfinding and Steering Using Flow Field Tiles", Game AI Pro 1, 2013) is a Dijkstra
## sweep OUT from the goal over a passability grid: every cell learns the distance to the goal around obstacles, and a
## unit steers by reading the cheapest neighbour. One sweep serves a whole army going to one place, and two units in
## the same street get the same answer, which is the part per-unit A* cannot promise.
##
## OFF by default. `--nav-off=flow` turns it ON (the polarity r5sidestep uses: the switch is the experiment, not an
## escape hatch), and it stays that way until it clears the bar pre-registered in _agents/streams/nav.md.
##
## The grid, not the navmesh polygons: Godot exposes a region's polygons only through the resource, not the RID, and a
## grid's cell is also the unit of caching and of the congestion term a flow field exists to carry later. CELL_M is
## two metres — a hull is 3-14 m long, so a cell is never wider than the narrowest gap a hull can use.

## Metres per cell, and the diagonal's cost in the sweep (√2, so diagonal travel isn't cheaper than it is).
const CELL_M := 2.0
const DIAGONAL := 1.4142135
## Goals within this distance share a field (the whole point: one sweep for an army).
const SAME_GOAL_M := CELL_M


static func on() -> bool:
	return Movement.switched_off("flow")


## goal -> FlowField, and the navigation map iteration the grid was built for (a re-bake invalidates everything).
static var _fields := {}
static var _passable := PackedByteArray()
static var _passable_for := -1
static var _origin := Vector3.ZERO
static var _wide := 0

var goal: Vector3
var ready := false
## Distance to the goal in metres, INF where the goal cannot be reached, indexed like _passable.
var _cost := PackedFloat32Array()


## The field for `goal`, built on first ask and reused while the navmesh and the goal's cell stay the same.
static func for_goal(node: Node3D, goal: Vector3) -> FlowField:
	_refresh_grid(node)
	var key := _index_of(goal)
	var have: Variant = _fields.get(key)
	if have is FlowField and (have as FlowField).goal.distance_to(goal) <= SAME_GOAL_M:
		return have
	var field := FlowField.new()
	field.goal = goal
	field._sweep(key)
	_fields[key] = field
	return field


## Forget every field (a new match, a re-bake, or a test that built another arena).
static func clear() -> void:
	_fields.clear()
	_passable = PackedByteArray()
	_passable_for = -1


## Can a unit standing at `from` reach this field's goal at all? False off the grid, in cover, or across a cut bridge.
func reachable(from: Vector3) -> bool:
	var index := _index_of(from)
	return index >= 0 and index < _cost.size() and _cost[index] < INF


## The next point to steer at from `from`: the centre of the cheapest neighbouring cell, or the goal itself once this
## cell is the goal's. `from` when the gradient says nothing (off the grid or walled in) — the caller falls back to A*.
func next_point(from: Vector3) -> Vector3:
	var index := _index_of(from)
	if index < 0 or index >= _cost.size() or _cost[index] == INF:
		return from
	if _cost[index] <= CELL_M:
		return goal
	var best := index
	var best_cost := _cost[index]
	var column := index % _wide
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var next_column := column + dx
			if next_column < 0 or next_column >= _wide:
				continue
			var neighbour := index + dz * _wide + dx
			if neighbour < 0 or neighbour >= _cost.size():
				continue
			if _cost[neighbour] < best_cost:
				best_cost = _cost[neighbour]
				best = neighbour
	if best == index:
		return from
	return _centre_of(best)


## The route the gradient gives from `from`: cell centres down the gradient, ending at the goal itself. Empty when the
## field says nothing here (off the grid, walled in, or the goal unreachable) — the caller then falls back to A*.
## `limit` bounds the walk; a 140 m arena at 2 m cells is at most ~200 steps corner to corner.
func walk(from: Vector3, limit := 300) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not reachable(from):
		return points
	points.append(from)
	var here := from
	for step in limit:
		var next := next_point(here)
		if next.distance_to(here) < 0.01:
			break
		points.append(next)
		here = next
		if here.distance_to(goal) <= CELL_M:
			break
	if points.size() < 2 or points[points.size() - 1].distance_to(goal) > 0.01:
		points.append(goal)
	return points


## Flat metres from `goal` to the navmesh (the one Pathing.query number a field cannot answer from its own grid).
static func goal_gap_m(node: Node3D, goal: Vector3) -> float:
	var nearest := NavigationServer3D.map_get_closest_point(node.get_world_3d().navigation_map, goal)
	return Vector2(nearest.x - goal.x, nearest.z - goal.z).length()


## Dijkstra out from the goal's cell over the passable grid (a bucket-free binary heap would be faster; a 140 m arena
## at 2 m is 14k cells and the sweep runs once per goal, so the simple queue is not worth optimising yet).
func _sweep(start: int) -> void:
	_cost = PackedFloat32Array()
	_cost.resize(_passable.size())
	_cost.fill(INF)
	ready = _passable.size() > 0
	if not ready or start < 0 or start >= _passable.size() or _passable[start] == 0:
		return
	_cost[start] = 0.0
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var next_frontier: Array[int] = []
		for index: int in frontier:
			var column := index % _wide
			var cost := _cost[index]
			for dz: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if dx == 0 and dz == 0:
						continue
					var next_column := column + dx
					if next_column < 0 or next_column >= _wide:
						continue
					var neighbour := index + dz * _wide + dx
					if neighbour < 0 or neighbour >= _passable.size() or _passable[neighbour] == 0:
						continue
					var step := CELL_M * (DIAGONAL if dx != 0 and dz != 0 else 1.0)
					if cost + step < _cost[neighbour] - 0.001:
						_cost[neighbour] = cost + step
						next_frontier.append(neighbour)
		frontier = next_frontier


## Which cells a unit can stand in, asked of the navmesh once per bake and shared by every field.
static func _refresh_grid(node: Node3D) -> void:
	var map := node.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if iteration == _passable_for and not _passable.is_empty():
		return
	_fields.clear()
	_passable_for = iteration
	var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE)) + CELL_M
	_origin = Vector3(-half, 0.0, -half)
	_wide = int(ceil(half * 2.0 / CELL_M))
	_passable = PackedByteArray()
	_passable.resize(_wide * _wide)
	for row in _wide:
		for column in _wide:
			var centre := Vector3(_origin.x + (column + 0.5) * CELL_M, 0.0, _origin.z + (row + 0.5) * CELL_M)
			var nearest := NavigationServer3D.map_get_closest_point(map, centre)
			# On the mesh means "the navmesh covers this cell's middle": half a cell of slack, so a cell whose centre
			# sits in the agent-radius erosion beside a wall still counts, and one inside cover does not.
			var gap := Vector2(nearest.x - centre.x, nearest.z - centre.z).length()
			_passable[row * _wide + column] = 1 if gap <= CELL_M * 0.5 else 0


static func _index_of(point: Vector3) -> int:
	if _wide <= 0:
		return -1
	var column := int(floor((point.x - _origin.x) / CELL_M))
	var row := int(floor((point.z - _origin.z) / CELL_M))
	if column < 0 or column >= _wide or row < 0 or row >= _wide:
		return -1
	return row * _wide + column


static func _centre_of(index: int) -> Vector3:
	var column := index % _wide
	var row := index / _wide
	return Vector3(_origin.x + (column + 0.5) * CELL_M, 0.0, _origin.z + (row + 0.5) * CELL_M)
