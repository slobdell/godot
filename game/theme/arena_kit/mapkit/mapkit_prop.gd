extends Node3D
## `prop.tank_trap` (hedgehogs) and `prop.monorail` (the overpass) -- mapkit P4, round 47, the lead's picks. Registers its
## instances with the viewport's MapkitYard (one MultiMesh per kind) and holds no mesh itself. `setup(prop)` reads the
## `car` look key (a monorail span with a lit car parked on it). Visual only; the collision is Arena's.

@export_enum("hedgehog", "monorail") var kind := "hedgehog"

var _ids: Array[int] = []
var _car := false
var _yard: MapkitYard


func _ready() -> void:
	_register()


func setup(prop: Dictionary) -> void:
	_car = bool(prop.get("car", false))
	if is_inside_tree():
		_register()


func _exit_tree() -> void:
	_unregister()


func _register() -> void:
	_unregister()
	_yard = MapkitYard.for_node(self)
	var base := Transform3D(global_basis.orthonormalized(), global_position)
	_ids.append(_yard.add(kind, base))
	if kind == "monorail" and _car:
		_ids.append(_yard.add("monorail_car", base))


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
