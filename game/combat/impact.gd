class_name Impact
extends Node3D
## A hit effect. Purely visual: never created on a headless server (Match.show_impact checks).
## On the simulating peer the match's K2 projectile_impact drives the hit effects, so this does nothing there (hits never
## draw twice); on a peer that doesn't simulate (a networked client) it draws the pooled legacy explosion. Frees itself.

## Destroyed-tank explosions are bigger than ordinary hits.
var big := false


func _process(_delta: float) -> void:
	# Match sets global_position after add_child, so fire on the first frame, not in _ready.
	var fx := FxWorld.get_instance()
	if fx != null and not fx.link.live:
		fx.explosion(global_position, big)
	queue_free()
	set_process(false)
