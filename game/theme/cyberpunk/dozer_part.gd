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
## A model generated facing +Z instead of the engine's -Z is turned round here (tools/assets/build_faction_parts.py
## MODEL_YAW_DEG; round 7: the gang IFV drove backwards). Degrees about +Y.
@export var model_yaw_deg := 0.0
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
		model.rotation.y = deg_to_rad(model_yaw_deg)
		add_child(model)
		_prepare_model()
		if part == "hull":
			_cut_gun()
			_cut_trailer()
		elif part == "turret" and _tank() != null and not FactionArt.gun_cut(String(_tank().get("unit_id"))).is_empty():
			model.visible = false  # the nub that stood in for a turret: the real gun is cut out of the hull
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
	set_process(gun_pivot != null or trailer_pivot != null)  # only a cut gun or a trailer has anything to do per frame


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
	# The approved model's own length, before a baked gun is cut out and turned to its rest (FactionArt.GUN_CUTS): measured
	# after, the War Rig's gun poked past its nose and the whole truck drew at 80% of its box (round 8's finding).
	var natural := FactionArt.hull_length(unit_id)
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


## Round 7: a hull whose gun was generated into its mesh (FactionArt.GUN_CUTS) gives the gun to a pivot of its own,
## which follows the tank's turret yaw every frame. The hull and gun keep the approved model's exact geometry.
var gun_pivot: Node3D
var _gun_rest_yaw := 0.0


func _cut_gun() -> void:
	var tank := _tank()
	if tank == null:
		return
	var cut := FactionArt.gun_cut(String(tank.get("unit_id")))
	if cut.is_empty():
		return
	var box: AABB = cut["box"]
	var pivot: Vector3 = cut["pivot"]
	_gun_rest_yaw = deg_to_rad(float(cut.get("rest_yaw_deg", 0.0)))
	gun_pivot = Node3D.new()
	gun_pivot.name = "GunPivot"
	gun_pivot.position = pivot
	model.add_child(gun_pivot)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or gun_pivot.is_ancestor_of(instance):
			continue
		var to_model := _relative_to(instance, model)
		var pieces := FactionArt.split_mesh(instance.mesh, to_model, box)
		if pieces[1] == null:
			continue
		instance.mesh = pieces[0]
		instance.visible = pieces[0] != null
		var gun := MeshInstance3D.new()
		gun.name = "Gun"
		gun.mesh = pieces[1]
		# The gun's own frame: its pivot at the origin, then turned to point ahead at rest.
		gun.transform = Transform3D(Basis(Vector3.UP, _gun_rest_yaw), Vector3.ZERO) * Transform3D(Basis(), -pivot) * to_model
		gun_pivot.add_child(gun)


## Round 9, contract S2 (the lead, twice: "the semi trucks ... are still one long box itself of a truck / trailer
## combination"). The trailer is cut out of the approved hull mesh at the fifth wheel exactly the way the gun is
## (FactionArt.TRAILER_CUTS) and yawed per frame by tractor-trailer kinematics. The tractor is still the whole
## simulated body and the collider is still the one hull_size box: this file never touches the simulation.
var trailer_pivot: Node3D
var _trailer_wheelbase := 0.0  # model space; scaled to world by the hull's fit on first use
var _trailer_wheelbase_world := 0.0
var _trailer_limit := 0.0
var _trailer_yaw := 0.0  # the trailer's heading in WORLD yaw, integrated per drawn frame
var _trailer_drawn := Vector3.ZERO
var _trailer_started := false


func _cut_trailer() -> void:
	var tank := _tank()
	if tank == null:
		return
	var cut := FactionArt.trailer_cut(String(tank.get("unit_id")))
	if cut.is_empty():
		return
	var boxes: Array = cut["boxes"]
	var pivot: Vector3 = cut["pivot"]
	_trailer_wheelbase = float(cut.get("wheelbase", 1.0))
	_trailer_limit = deg_to_rad(float(cut.get("jackknife_deg", 60.0)))
	trailer_pivot = Node3D.new()
	trailer_pivot.name = "TrailerPivot"
	trailer_pivot.position = pivot
	model.add_child(trailer_pivot)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or trailer_pivot.is_ancestor_of(instance):
			continue
		if gun_pivot != null and gun_pivot.is_ancestor_of(instance):
			continue  # the gun came out first and rides the trailer as a whole (below)
		var to_model := _relative_to(instance, model)
		var pieces := FactionArt.split_mesh_boxes(instance.mesh, to_model, boxes)
		if pieces[1] == null:
			continue
		instance.mesh = pieces[0]
		instance.visible = pieces[0] != null
		var trailer := MeshInstance3D.new()
		trailer.name = "Trailer"
		trailer.mesh = pieces[1]
		# The trailer's own frame: the fifth wheel at the origin, geometry unmoved at zero articulation.
		trailer.transform = Transform3D(Basis(), -pivot) * to_model
		trailer_pivot.add_child(trailer)
	if gun_pivot != null:
		# The gun is mounted on the tanker, aft of the fifth wheel. Left on the hull it would hold the tractor's
		# heading while the trailer swung out from under it.
		model.remove_child(gun_pivot)
		trailer_pivot.add_child(gun_pivot)
		gun_pivot.position -= pivot


## The hinge, integrated from the DRAWN pose and the FRAME's delta -- never the physics tick. The simulation runs at
## 30 Hz with physics interpolation on (project.godot), so the pose a frame draws is not the pose the tank last
## simulated, and a trailer integrated from the tick would swim against the tractor it is bolted to.
func _drive_trailer(delta: float) -> void:
	var tank := _tank()
	if tank == null or delta <= 0.0:
		return
	var drawn: Transform3D = tank.get_global_transform_interpolated()
	# The hull's yaw about +Y. Forward is -Z and Basis(UP, yaw) sends +Z to (sin yaw, 0, cos yaw), so the yaw of the
	# drawn pose reads straight off that column (orientation.md trip-up 2).
	var heading := atan2(drawn.basis.z.x, drawn.basis.z.z)
	if _trailer_wheelbase_world <= 0.0:
		_trailer_wheelbase_world = _trailer_wheelbase * maxf(model.global_transform.basis.get_scale().x, 0.01)
	if not _trailer_started:
		_trailer_started = true
		_trailer_yaw = heading
		_trailer_drawn = drawn.origin
		_set_articulation(0.0)
		return
	var step := drawn.origin - _trailer_drawn
	_trailer_drawn = drawn.origin
	# A spawn or a respawn is a teleport -- Tank calls reset_physics_interpolation at both -- and a hinge that
	# integrated across one would draw the trailer as a streak from where the wreck was. Snap instead.
	var reach := (absf(float(tank.get("max_forward_speed"))) + 1.0) * delta * 3.0 + 0.5
	if step.length() > reach:
		_trailer_yaw = heading
		_set_articulation(0.0)
		return
	var forward := Vector3(-drawn.basis.z.x, 0.0, -drawn.basis.z.z)
	if forward.length_squared() < 0.0001:
		return
	var speed := Vector3(step.x, 0.0, step.z).dot(forward.normalized()) / delta
	_trailer_yaw = FactionArt.trailer_follow(_trailer_yaw, heading, speed, _trailer_wheelbase_world, delta, _trailer_limit)
	_set_articulation(wrapf(_trailer_yaw - heading, -PI, PI))


## `angle` is the trailer's yaw relative to the TRACTOR; the pivot lives under the model, which may itself be turned
## (model_yaw_deg), so that turn comes back out here.
func _set_articulation(angle: float) -> void:
	if trailer_pivot != null:
		trailer_pivot.rotation.y = angle - model.rotation.y


## The trailer's yaw relative to the tractor, radians. For tests and frames.
func articulation() -> float:
	return 0.0 if trailer_pivot == null else wrapf(trailer_pivot.rotation.y + model.rotation.y, -PI, PI)


func _process(delta: float) -> void:
	if trailer_pivot != null:
		_drive_trailer(delta)
	if gun_pivot != null:
		var tank := _tank()
		var turret: Variant = tank.get("turret") if tank != null else null
		if turret is Node3D:
			# Under the trailer the gun inherits its swing, so the turret's lay is taken back out: the gun points
			# where gunnery aims it whatever the trailer is doing.
			gun_pivot.rotation.y = (turret as Node3D).rotation.y - (trailer_pivot.rotation.y if trailer_pivot != null else 0.0)


func _relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


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
