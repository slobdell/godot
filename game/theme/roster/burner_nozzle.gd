extends "res://game/theme/cyberpunk/dozer_part.gd"
## Round 12 (fleet F1): the fire engine's flamethrower (`unit.burner.weapon`). The nozzle is the approved model's own
## (burner_r11_b, split out of the turntable head), drawn like every generated part; the FIRE is the theme's
## `weapon.flamethrower` (cone, ground glow, light, roar), carried as a child whose own nozzle and canister are hidden
## and whose flame starts at the drawn nozzle's tip. Before this the burner's flame left the stretched dozer's roof point.
##
## The flame keeps the length and cone the weapon profile gives it: the child undoes the turret's scale (as
## `_fit_to_hull` does for the model), so a wider hull does not draw a longer flame than the one that burns.

const FLAMETHROWER := preload("res://game/theme/cyberpunk/weapon_flamethrower.tscn")
## Where the child's flame begins, in its own frame (weapon_flamethrower.gd `setup`: the cone's narrow end).
const FLAME_START := Vector3(0.0, 0.05, -1.8)

var fire: Node3D


func _ready() -> void:
	fire = FLAMETHROWER.instantiate() as Node3D
	fire.name = "Fire"
	add_child(fire)
	super._ready()
	(fire.get("mesh_instance") as MeshInstance3D).visible = false  # the drawn nozzle is the model's
	_place_fire.call_deferred()  # after `_fit_to_hull`, which dozer_part defers the same way


## The drawn nozzle's tip in this part's frame: the front (-Z) end of the model, at the height of its middle.
func nozzle_tip() -> Vector3:
	var box := _model_bounds() if model != null else AABB()
	return Vector3(box.get_center().x, box.get_center().y, box.position.z)


func _place_fire() -> void:
	if not is_instance_valid(fire) or not is_inside_tree():
		return
	var undo := 1.0
	var tank := _tank()
	if tank != null:
		undo = 1.0 / _scale_below(tank) / scale.x
	fire.scale = Vector3.ONE * undo
	fire.position = nozzle_tip() - FLAME_START * undo
	# The ground glow sits on the ground, not 1.18 m under a nozzle that is 3-4 m up on the turntable.
	var glow := fire.get("ground_glow") as Node3D
	if glow != null and tank != null:
		# `fire` is drawn at scale 1 in the tank's frame (the undo above), so its local metres are the tank's.
		glow.position.y = 0.02 - (tank.global_transform.affine_inverse() * fire.global_transform).origin.y


func set_firing(firing: bool) -> void:
	if is_instance_valid(fire):
		fire.call("set_firing", firing)


func setup(weapon: Dictionary) -> void:
	if is_instance_valid(fire):
		fire.call("setup", weapon)
		_place_fire()


func set_heat(ratio: float) -> void:
	super.set_heat(ratio)
	if is_instance_valid(fire):
		fire.call("set_heat", ratio)
