extends Node3D
## A kit prop's visual (`prop.barricade`, `prop.floodlight`, `prop.sign`, `prop.wreck`): registers its instances with the
## viewport's KitYard (one MultiMesh per kind) and holds no mesh itself. `setup(prop)` reads the layout's look keys
## (`sign`, `color`). Visual only: the collision box is Arena's (ArenaKit.PROPS sizes).

@export_enum("barricade", "floodlight", "sign", "wreck") var kind := "barricade"

var options := {}
var _ids: Array[int] = []
var _yard: KitYard


func _ready() -> void:
	_register()


func setup(prop: Dictionary) -> void:
	options = {}
	for key in ArenaKit.LOOK_KEYS:
		if prop.has(key):
			options[key] = prop[key]
	if is_inside_tree():
		_register()


func _exit_tree() -> void:
	_unregister()


func _register() -> void:
	_unregister()
	_yard = KitYard.for_node(self)
	var base := Transform3D(global_basis.orthonormalized(), global_position)
	match kind:
		"barricade":
			_ids.append(_yard.add("barricade", base))
		"floodlight":
			_ids.append(_yard.add("floodlight", base))
			# The lamp's light on the floor in front of the tower (toward -Z), and a little at its foot.
			_ids.append(_yard.add("pool", base * Transform3D(Basis.from_scale(Vector3(24.0, 1.0, 30.0)), Vector3(0, 0.05, -14.0)),
					Color(KitYard.LAMP.r, KitYard.LAMP.g, KitYard.LAMP.b, 0.32)))
		"sign":
			_ids.append(_yard.add("sign_post", base))
			var tint: Color = Color(str(options.get("color", "#ffb13b")))
			var cell := KitYard.sign_cell(str(options.get("sign", "")))
			_ids.append(_yard.add("sign", base * Transform3D(Basis(Vector3.UP, PI), Vector3(0, KitYard.SIGN_HEIGHT + KitYard.SIGN_SIZE.y / 2.0, -0.02)),
					Color(tint.r, tint.g, tint.b, cell)))
			_ids.append(_yard.add("pool", base * Transform3D(Basis.from_scale(Vector3(9.0, 1.0, 6.0)), Vector3(0, 0.05, -1.5)),
					Color(tint.r, tint.g, tint.b, 0.22)))
		"wreck":
			# Wrecks placed by a layout face whichever way it says; a seeded half-turn keeps rows of them from matching.
			var flip := PI if hash([snappedf(base.origin.x, 0.1), snappedf(base.origin.z, 0.1)]) % 2 == 0 else 0.0
			_ids.append(_yard.add("wreck", base * Transform3D(Basis(Vector3.UP, flip), Vector3.ZERO)))


func _unregister() -> void:
	if _yard != null and is_instance_valid(_yard):
		for id in _ids:
			_yard.remove(id)
	_ids.clear()
