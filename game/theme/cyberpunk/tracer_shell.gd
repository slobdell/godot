extends Node3D
## `fx.shell` for the cyberpunk theme: no mesh of its own. It registers with the shared
## TracerSystem, which draws every shell in one batched tracer + ground-splat pass, flashes the
## muzzle, and lends it a pooled light when it deserves one. Colored by the shell's team.


func _ready() -> void:
	var fx := FxWorld.get_instance()
	if fx == null:
		return
	fx.add_tracer(self, GameTheme.team_glow(_team()))


func _exit_tree() -> void:
	var fx := FxWorld.existing()
	if fx != null:
		fx.remove_tracer(self)


## The shell this visual belongs to (VisualSlot → Shell) knows its team; read-only duck typing.
func _team() -> int:
	var node := get_parent()
	while node != null:
		var team: Variant = node.get("team")
		if team is int:
			return team
		node = node.get_parent()
	return 0
