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
##   Visual only; the stack's collider stays one box. 0.25 m is ~9 px at his pose (21 deg, FOV 35, 49 m, 1080p).
const GROUND_SKEW_DEG := 2.0
const GROUND_SKEW_20_SCALE := 1.6
const STACK_OFFSET_M := 0.25

@export_enum("container_20", "container_40") var kind := "container_20"

var stack := 1
var options := {}
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
	var placed := stack_levels(kind, base.origin, levels())
	for level in placed.size():
		_ids.append(_yard.add(kind, base * (placed[level] as Transform3D), ContainerYard.look(base.origin, level, options)))


## Each level's transform in its stack's frame (x along the length): level 0 is the collider exactly; each level above
## is turned and shifted as a crane leaves it -- a random walk from the level below (never back to square), so a
## level steps at most ~1.3 x STACK_OFFSET_M off the one under it, and no corner ends up more than STACK_OFFSET_M off the collider. Seeded by
## position and level: the same picture every launch and in every screenshot test. Static so tests read it directly.
static func stack_levels(container_kind: String, origin: Vector3, count: int) -> Array[Transform3D]:
	var length: float = ContainerYard.KINDS[container_kind]
	var half := Vector2(length / 2.0, ContainerMesh.WIDTH / 2.0)
	var out: Array[Transform3D] = [Transform3D.IDENTITY]
	var rng := RandomNumberGenerator.new()
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
		var xform := Transform3D(Basis(Vector3.UP, asin(turn / half.x)), Vector3(along, level * ContainerMesh.HEIGHT, across))
		# Turn and shift together can put a corner past the budget: scale this level back onto it.
		var worst := 0.0
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner := xform * Vector3(s.x * half.x, 0.0, s.y * half.y)
			worst = maxf(worst, Vector2(corner.x, corner.z).distance_to(Vector2(s.x * half.x, s.y * half.y)))
		if worst > STACK_OFFSET_M:
			var k := STACK_OFFSET_M / worst
			turn *= k
			across *= k
			xform = Transform3D(Basis(Vector3.UP, asin(turn / half.x)), Vector3(along * k, level * ContainerMesh.HEIGHT, across))
		out.append(xform)
	return out


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
