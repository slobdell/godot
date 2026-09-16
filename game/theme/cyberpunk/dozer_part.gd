extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## A generated vehicle part (the Meshy "prison dozer", art_direction.md) wearing the cyberpunk theme's team
## identity. The model brings the body and its own neon; UnitSkin (unit_body.gdshader) makes that neon the
## accent lights, so no extra geometry is needed (art X1, 2026-09-14: the added strips read as slabs):
##   friend or foe by ACCENT LIGHTS: the model's cyan/magenta light bars glow in the team color
##   paint: set_paint coats the body over the grime (the garage's full-body color), never the accents
##   heat: weapons glow orange-white (set_heat)
##   hull only: the team underglow and the energy shield shell (set_shield)

@export var model_scene: PackedScene
## "hull", "turret", or "cannon".
@export var part := "hull"
## How strongly paint recolors the model's body (its grime and neon survive).
@export_range(0.0, 1.0) var paint_strength := 0.45
## Hulls only: the engine loop this vehicle runs (EngineSystem; "" = silent).
@export var engine_sound := "engine_diesel"

var model: Node3D
## The model's bounds in this node's space (the shield is sized from it).
var bounds := AABB(Vector3(-1.2, 0, -1.8), Vector3(2.4, 1.6, 3.6))
var shield: ShieldEffect
## The model's meshes wearing the shared unit material (they carry the per-vehicle instance uniforms).
var skinned: Array[MeshInstance3D] = []


func _ready() -> void:
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		model.name = "Model"
		add_child(model)
		_prepare_model()
		bounds = _model_bounds()
		skinned = UnitSkin.apply(model)
	if part == "hull":
		shield = ShieldEffect.new(bounds.size + Vector3(0.6, 0.7, 0.8))
		add_child(shield)
		shield.position.y = bounds.get_center().y
		shield.set_tint(team_color)
		var fx := FxWorld.get_instance()
		if fx != null:
			fx.underglow.add(self, team_color)
			if engine_sound != "":
				fx.engines.add(self, engine_sound)
	super._ready()
	_apply_skin()


## Subclasses change the instantiated model before it is measured and skinned (artillery_part.gd cuts its legs loose).
func _prepare_model() -> void:
	pass


func set_team_color(color: Color) -> void:
	super.set_team_color(color)
	if shield != null:
		shield.set_tint(team_color)
		var fx := FxWorld.existing()
		if fx != null and is_inside_tree():
			fx.underglow.add(self, team_color)
	_apply_skin()


func set_paint(color: Color) -> void:
	super.set_paint(color)
	_apply_skin()


func set_heat(ratio: float) -> void:
	if not is_equal_approx(ratio, heat):
		super.set_heat(ratio)
		if part == "cannon":  # barrels heat up; hull and turret stay cold
			UnitSkin.set_heat(skinned, heat)
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
			fx.engines.remove(self)


## No added geometry: the model's own neon is the team accent. (The base class keeps an empty accent mesh.)
func build(_builder: ColorMeshBuilder) -> void:
	pass


func _apply_skin() -> void:
	UnitSkin.set_team(skinned, team_color)
	UnitSkin.set_paint(skinned, paint_color, paint_strength if paint_color.a > 0.0 else 0.0)


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
