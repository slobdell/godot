class_name Impact
extends Node3D
## A hit effect. Purely visual: never created on a headless server (Match.show_impact checks).
## It forwards to the pooled BurstSystem in FxWorld (flipbook fireball, flash, ground glow, light
## pulse) and frees itself, so a hit no longer allocates a mesh and a material.

## Destroyed-tank explosions are bigger than ordinary hits.
var big := false


func _process(_delta: float) -> void:
	# Match sets global_position after add_child, so fire on the first frame, not in _ready.
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.explosion(global_position, big)
	queue_free()
	set_process(false)
