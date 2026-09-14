extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## A generated vehicle part (the assets stream's Meshy "prison dozer", art_direction.md) wearing the
## cyberpunk theme's team identity. The model brings the body and its own baked neon; this part adds
## what the theme promises every vehicle (look_and_feel.md, the lead's rules):
##   friend or foe by ACCENT LIGHTS: team neon strips sized from the model's bounds (one batched mesh)
##   paint: set_paint tints the model's body (the garage's full-body color), never the accents
##   hull only: the team underglow and the energy shield shell (set_shield)
## Integration 2026-09-15: generated art in the default theme, keeping look & feel's FX contracts.

@export var model_scene: PackedScene
## "hull", "turret", or "cannon": which accents to draw.
@export var part := "hull"
## How strongly paint recolors the model's body (its grime and baked neon should survive).
@export_range(0.0, 1.0) var paint_strength := 0.45

var model: Node3D
## The model's bounds in this node's space (accents and the shield are sized from it).
var bounds := AABB(Vector3(-1.2, 0, -1.8), Vector3(2.4, 1.6, 3.6))
var shield: ShieldEffect


func _ready() -> void:
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		model.name = "Model"
		add_child(model)
		bounds = _model_bounds()
	if part == "hull":
		shield = ShieldEffect.new(bounds.size + Vector3(0.6, 0.7, 0.8))
		add_child(shield)
		shield.position.y = bounds.get_center().y
		shield.set_tint(team_color)
		var fx := FxWorld.get_instance()
		if fx != null:
			fx.underglow.add(self, team_color)
	super._ready()
	_apply_paint()


func set_team_color(color: Color) -> void:
	super.set_team_color(color)
	if shield != null:
		shield.set_tint(team_color)
		var fx := FxWorld.existing()
		if fx != null and is_inside_tree():
			fx.underglow.add(self, team_color)
	_apply_paint()


func set_paint(color: Color) -> void:
	super.set_paint(color)
	_apply_paint()


func set_heat(ratio: float) -> void:
	if not is_equal_approx(ratio, heat):
		super.set_heat(ratio)
		if model != null and model.has_method("set_heat"):
			model.call("set_heat", ratio)


func set_shield(ratio: float) -> void:
	if shield != null:
		shield.set_shield(ratio)


func set_firing(firing: bool) -> void:
	if model != null and model.has_method("set_firing"):
		model.call("set_firing", firing)


func setup(weapon: Dictionary) -> void:
	if model != null and model.has_method("setup"):
		model.call("setup", weapon)


func _exit_tree() -> void:
	if part == "hull":
		var fx := FxWorld.existing()
		if fx != null:
			fx.underglow.remove(self)


func build(b: ColorMeshBuilder) -> void:
	var neon := team_color
	var low := bounds.position
	var size := bounds.size
	var center := bounds.get_center()
	match part:
		"hull":
			for sx in [-1.0, 1.0]:
				# Side strips low on the body, and roof stripes that read from the tactical view.
				b.glow_box(Vector3(0.05, 0.07, size.z * 0.8), Vector3(center.x + sx * (size.x * 0.5 + 0.02), low.y + size.y * 0.28, center.z), neon * 0.9)
				b.glow_box(Vector3(0.12, 0.04, size.z * 0.55), Vector3(center.x + sx * size.x * 0.22, low.y + size.y + 0.02, center.z + size.z * 0.1), neon)
			b.glow_box(Vector3(size.x * 0.8, 0.1, 0.05), Vector3(center.x, low.y + size.y * 0.55, low.z + size.z + 0.03), neon)
		"turret":
			# A crest along the barrel so the turret heading reads from above.
			b.glow_box(Vector3(0.14, 0.04, size.z * 0.7), Vector3(center.x, low.y + size.y + 0.02, center.z), neon)
		"cannon":
			# A team ring just behind the muzzle (the barrel's -Z end); glows hotter with heat.
			var ring := maxf(minf(size.x, size.y) + 0.06, 0.2)
			b.glow_box(Vector3(ring, ring, 0.08), Vector3(center.x, center.y, low.z + 0.35), neon * 0.8, 1.0)


func _apply_paint() -> void:
	if model == null or not model.has_method("set_team_color"):
		return
	if paint_color.a > 0.0:
		model.set("tint_strength", paint_strength)
		model.call("set_team_color", Color(paint_color, 1.0))


## Union of the model's mesh AABBs, in this node's space.
func _model_bounds() -> AABB:
	var result := AABB()
	var first := true
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance_node := instance as MeshInstance3D
		if mesh_instance_node.mesh == null:
			continue
		# Parent-chain transforms, not global ones: the tank scales its hull slot per unit class.
		var box := _relative_transform(mesh_instance_node) * mesh_instance_node.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return bounds if first else result


func _relative_transform(node: Node3D) -> Transform3D:
	var transform_to_self := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			transform_to_self = (current as Node3D).transform * transform_to_self
		current = current.get_parent()
	return transform_to_self
