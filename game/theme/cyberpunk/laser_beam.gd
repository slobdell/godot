extends Node3D
## `fx.laser_beam` for the cyberpunk theme: no mesh of its own. `setup(from, to)` (world space, called
## once right after the slot enters the tree; Match frees it 0.2 s later) hands the pulse to the
## shared BeamSystem, which draws every beam in one batched pass, lights the floor along it, lends it
## pooled lights, and sparks both ends. Optional `set_team_color(color)` tints it; otherwise lasers
## are a hot violet-white that no team owns.

const DEFAULT_COLOR := Color(0.85, 0.45, 1.0)

var color := DEFAULT_COLOR


func set_team_color(new_color: Color) -> void:
	color = new_color


func setup(from: Vector3, to: Vector3) -> void:
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.laser(self, from, to, color)


func _exit_tree() -> void:
	var fx := FxWorld.existing()
	if fx != null:
		fx.beams.remove(self)
