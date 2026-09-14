extends "res://game/theme/default/tinted_visual.gd"
## Default flamethrower: a stubby barrel plus a translucent cone sized from the weapon profile.

@onready var flame: MeshInstance3D = $Flame


func setup(weapon: Dictionary) -> void:
	var length: float = weapon.get("range", 20.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = tan(deg_to_rad(float(weapon.get("cone_deg", 30.0)) / 2.0)) * length
	cone.height = length
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.45, 0.1, 0.35)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = material
	flame.mesh = cone
	# Cylinder axis is +Y; rotate it to point along -Z (forward), narrow end at the muzzle.
	flame.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 0.05, -1.2 - length / 2.0))


func set_firing(firing: bool) -> void:
	flame.visible = firing
