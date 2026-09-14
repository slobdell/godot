class_name VisualSlot
extends Node3D
## A placeholder that the active GameTheme fills with art. Gameplay scenes contain slots,
## never meshes, so art can change (a new theme, a generated model) without touching gameplay.
## Visual scenes may implement optional methods; `invoke()` calls them if present:
##   set_team_color(color: Color)     setup(data: Dictionary)     set_firing(firing: bool)

@export var slot := ""

var visual: Node


func _ready() -> void:
	if slot != "" and visual == null:
		fill(slot)


func fill(new_slot: String) -> void:
	slot = new_slot
	if visual != null:
		visual.free()
		visual = null
	var packed := GameTheme.scene(slot)
	if packed != null:
		visual = packed.instantiate()
		add_child(visual)


func invoke(method: String, args: Array = []) -> void:
	if visual != null and visual.has_method(method):
		visual.callv(method, args)
