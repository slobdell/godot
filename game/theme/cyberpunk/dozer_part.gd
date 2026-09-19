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
## The model's meshes wearing the shared unit materials (UnitSkin swaps them when team, paint or heat change).
var skinned: Array[MeshInstance3D] = []


func _ready() -> void:
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		model.name = "Model"
		add_child(model)
		_prepare_model()
		bounds = _model_bounds()
		if part == "hull":
			_fit_to_hull()
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
	# The base class's accent mesh is empty on a generated part: hidden, it isn't culled or counted every frame
	# (render X5: 3 objects per vehicle, 180 at 60 vehicles).
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		mesh_instance.visible = false
	_apply_skin()
	if part != "hull" and model != null:
		_fit_to_hull.call_deferred()  # after the tank has placed and scaled its turret


## Round 6 (feel; the lead: "our semi truck for the gang that was supposed to be a huge tank is tiny ... everything
## drawn to scale"). The new factions' models were generated at 3-4 m whatever the unit, and a unit with its own hull
## art is not scaled by the tank, so the gang's 5.6 m semi drew smaller than a scout while its collision box (from
## hull_size) was full size. Every part of a unit now takes one uniform scale: the unit's hull_size length over its hull
## model's natural length (FactionArt.hull_length). Uniform, so a truck stays truck-shaped; where a model's proportions
## disagree with hull_size, that is a finding for combat's data, not something to stretch away. Turret and weapon parts
## undo the scale the tank already gave their parent and rise with the hull's roof. Outside a Tank (the galleries)
## nothing changes.
func _fit_to_hull() -> void:
	var tank := _tank()
	if tank == null or model == null or not is_instance_valid(model):
		return
	var unit_id := String(tank.get("unit_id"))
	var natural := bounds.size.z if part == "hull" else FactionArt.hull_length(unit_id)
	var size: Variant = Units.stat(unit_id, "hull_size")
	if natural <= 0.01 or not (size is Array):
		return
	var fit := float(size[2]) / natural
	var inherited := _scale_below(tank)
	model.scale = Vector3.ONE * (fit / inherited)
	if part != "hull":
		# The turret pivot was placed for the model's natural roof; the roof is now `fit` times as high.
		var pivot := _height_below(tank)
		model.position.y += (fit - 1.0) * pivot / inherited
	if part == "hull":
		bounds = _model_bounds()


func _tank() -> Node3D:
	var node := get_parent()
	while node != null and not (node is Tank):
		node = node.get_parent()
	return node as Node3D


## The uniform scale the nodes between this part and the tank apply (the tank scales its turret per hull class).
func _scale_below(tank: Node3D) -> float:
	var result := 1.0
	var node := get_parent()
	while node != null and node != tank:
		if node is Node3D:
			result *= (node as Node3D).scale.x
		node = node.get_parent()
	return maxf(result, 0.001)


## This part's height above the tank's origin, in tank space.
func _height_below(tank: Node3D) -> float:
	return (tank.global_transform.affine_inverse() * global_transform).origin.y


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
			_apply_skin()
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
	var paint := Color(paint_color, paint_strength) if paint_color.a > 0.0 else Color(1, 1, 1, 0)
	UnitSkin.dress(skinned, team_color, paint, heat if part == "cannon" else 0.0)


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
