extends Node3D
## The `prop.container_20` / `prop.container_40` visual (assets X1): a stack of shipping containers drawn by the viewport's
## ContainerYard (one MultiMesh per kind), so the prop itself holds no mesh. Visual only; the collision box is gameplay's.
##
## Layout obstacle keys it reads through `setup(obstacle)` (combat's Arena passes the obstacle, as it does for hazards):
##   stack (1..), faction, paint, stencil, rust, doors: see ContainerYard.look. Without setup, a visual scaled in
##   height by the Arena (size / default size) reads as that many stacked containers, never a stretched one.

## THE TWO AMOUNTS (yard, round 17: the lead, *"rotate them just slightly so that it doesn't look synthetic"*). His
## "too much" / "too little" on the frames page is a change to one of these two lines.
## - GROUND_SKEW_DEG: the most a 40 ft container on the ground turns off its authored angle (a 20 ft one turns up to
##   GROUND_SKEW_20_SCALE times as far, so both move a corner about as much). This is LAYOUT TRUTH: `make arenas` reads
##   it into arenas/*.json `rotation_deg`, the collider turns with the picture, and changing it moves the sim of every
##   map with containers (not foundry's: the sim baseline holds none).
## - STACK_OFFSET_M: the most a drawn upper level's corner sits off its stack's collider (turn + shift together).
##   Visual only; the stack's collider stays one box. 0.45 m is ~15 px at his pose (21 deg, FOV 35, 49 m, 1080p).
## Set by his taps on the frames page (2026-10-03): B on every dealt map and both stack close frames (4.0 / 0.45; A was
## 2.0 / 0.25 -- https://claude.ai/artifact/929eYAkRdDCMXArwc7Rja5).
const GROUND_SKEW_DEG := 4.0
const GROUND_SKEW_20_SCALE := 1.6
const STACK_OFFSET_M := 0.45
## How far an upper level's END may reach past its collider's end plane: runs sit end to end with 6-19 cm of collider
## overlap, so more than this pokes one stack's upper box into the next one's at the seam.
const STACK_END_M := 0.10

@export_enum("container_20", "container_40") var kind := "container_20"

var stack := 1
var options := {}
## The side of a building this stack stands flush against, in its own frame (layout key `wall`; ZERO = none).
var wall := Vector2.ZERO
var _ids: Array[int] = []
var _yard: ContainerYard


func _ready() -> void:
	_register()


func setup(obstacle: Dictionary) -> void:
	stack = maxi(1, int(obstacle.get("stack", 1)))
	options = {}
	for key in ["faction", "paint", "stencil", "rust", "doors"]:
		if obstacle.has(key):
			options[key] = obstacle[key]
	var side: Variant = obstacle.get("wall")
	wall = Vector2(float(side[0]), float(side[1])) if side is Array and (side as Array).size() == 2 else Vector2.ZERO
	if is_inside_tree():
		_register()


func _exit_tree() -> void:
	_unregister()


## How many containers this prop draws.
func levels() -> int:
	return maxi(stack, roundi(global_basis.get_scale().y))


func _register() -> void:
	_unregister()
	_yard = ContainerYard.for_node(self)
	var base := Transform3D(global_basis.orthonormalized(), global_position)
	var placed := stack_levels(kind, base.origin, levels(), wall)
	for level in placed.size():
		_ids.append(_yard.add(kind, base * (placed[level] as Transform3D), ContainerYard.look(base.origin, level, options)))


## Each level's transform in its stack's frame (x along the length): level 0 is the collider exactly; each level above
## is turned and shifted as a crane leaves it -- a random walk from the level below (never back to square), so a
## level steps at most ~1.3 x STACK_OFFSET_M off the one under it, and no corner ends up more than STACK_OFFSET_M off the collider. Seeded by
## position and level: the same picture every launch and in every screenshot test. Static so tests read it directly.
## `wall`: the side of a building the stack stands flush against (its own frame, a unit axis), or ZERO: every level is
## slid off it, so no drawn corner goes into the building, and scaled back onto the budget if the slide needs it.
static func stack_levels(container_kind: String, origin: Vector3, count: int, wall := Vector2.ZERO) -> Array[Transform3D]:
	var length: float = ContainerYard.KINDS[container_kind]
	var half := Vector2(length / 2.0, ContainerMesh.WIDTH / 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([snappedf(origin.x, 0.01), snappedf(origin.z, 0.01), "doors"])
	var flips: Array[bool] = []
	for level in count:
		flips.append(rng.randf() < 0.5)
	var out: Array[Transform3D] = [_doors(Transform3D.IDENTITY, flips[0])]
	var turn := 0.0  # metres the yaw swings a long side's corner (signed)
	var across := 0.0  # metres the level slides across the stack (signed)
	for level in range(1, count):
		rng.seed = hash([snappedf(origin.x, 0.01), snappedf(origin.z, 0.01), level])
		var swing := rng.randf_range(0.3, 0.6) * STACK_OFFSET_M * (1.0 if rng.randf() < 0.5 else -1.0)
		turn = turn + swing if absf(turn + swing) <= 0.6 * STACK_OFFSET_M else turn - swing
		if absf(turn) < 0.25 * STACK_OFFSET_M:  # a level that walks back to square reads as square: keep it turned
			turn = 0.25 * STACK_OFFSET_M * (signf(turn) if turn != 0.0 else signf(swing))
		across = clampf(across + rng.randf_range(-0.4, 0.4) * STACK_OFFSET_M, -0.4 * STACK_OFFSET_M, 0.4 * STACK_OFFSET_M)
		var along := rng.randf_range(-0.03, 0.03)
		# The turn alone pushes the ends out by (W/2)|sin| - (L/2)(1 - cos); the slide along may only use what is left.
		var psi := asin(turn / half.x)
		var room := maxf(STACK_END_M - (half.y * absf(sin(psi)) - half.x * (1.0 - cos(psi))), 0.0)
		along = clampf(along, -room, room)
		var xform := Transform3D(Basis(Vector3.UP, asin(turn / half.x)), Vector3(along, level * ContainerMesh.HEIGHT, across))
		# Against a building: slide the level off the wall until no corner is in it; then turn and shift together can
		# put a corner past the budget, so scale this level back onto it (twice: the scale moves the slide).
		for attempt in 3:
			xform = _off_wall(xform, half, wall)
			var worst := 0.0
			for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var corner := xform * Vector3(s.x * half.x, 0.0, s.y * half.y)
				worst = maxf(worst, Vector2(corner.x, corner.z).distance_to(Vector2(s.x * half.x, s.y * half.y)))
			if worst <= STACK_OFFSET_M + 0.001:
				break
			var k := STACK_OFFSET_M / worst
			turn *= k
			across *= k
			along *= k
			xform = Transform3D(Basis(Vector3.UP, asin(turn / half.x)), Vector3(along, level * ContainerMesh.HEIGHT, across))
		xform = _off_wall(xform, half, wall)
		if wall != Vector2.ZERO:
			across = xform.origin.z  # the walk continues from where the wall left this level
		out.append(_doors(xform, flips[level]))
	return out


## A level drawn end for end (doors at the other end): the same footprint, a different face.
static func _doors(xform: Transform3D, flip: bool) -> Transform3D:
	return Transform3D(xform.basis * Basis(Vector3.UP, PI), xform.origin) if flip else xform


## `xform` slid along -wall until none of its corners is past the collider's face on the wall's side.
static func _off_wall(xform: Transform3D, half: Vector2, wall: Vector2) -> Transform3D:
	if wall == Vector2.ZERO:
		return xform
	var face := absf(wall.x) * half.x + absf(wall.y) * half.y
	var reach := -INF
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner := xform * Vector3(s.x * half.x, 0.0, s.y * half.y)
		reach = maxf(reach, Vector2(corner.x, corner.z).dot(wall))
	if reach <= face:
		return xform
	var moved := xform
	moved.origin -= Vector3(wall.x, 0.0, wall.y) * (reach - face)
	return moved


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
