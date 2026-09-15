extends Node3D
## The `prop.container_20` / `prop.container_40` visual (assets X1): a stack of shipping containers drawn by the viewport's
## ContainerYard (one MultiMesh per kind), so the prop itself holds no mesh. Visual only; the collision box is gameplay's.
##
## Layout obstacle keys it reads through `setup(obstacle)` (combat's Arena passes the obstacle, as it does for hazards):
##   stack (1..), faction, paint, stencil, rust, doors: see ContainerYard.look. Without setup, a visual scaled in
##   height by the Arena (size / default size) reads as that many stacked containers, never a stretched one.

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
	var rng := RandomNumberGenerator.new()
	for level in levels():
		rng.seed = hash([snappedf(base.origin.x, 0.01), snappedf(base.origin.z, 0.01), level])
		# Real stacks never line up perfectly: a few centimeters and a fraction of a degree per level, inside the footprint.
		var jitter := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.03, 0.03)) if level > 0 else Vector3.ZERO
		var yaw := deg_to_rad(rng.randf_range(-0.6, 0.6)) if level > 0 else 0.0
		var xform := base * Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, level * ContainerMesh.HEIGHT, 0.0) + jitter)
		_ids.append(_yard.add(kind, xform, ContainerYard.look(base.origin, level, options)))


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
