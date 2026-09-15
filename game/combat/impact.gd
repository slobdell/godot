class_name Impact
extends Node3D
## A hit effect. Purely visual: never created on a headless server (Match.show_impact checks).
## It hands the hit to FxWorld's MatchFxLink, which turns it into a K2 projectile_impact for the effect families until
## combat's real K2 events land (then it's ignored, so hits never draw twice), and frees itself. Without a match
## driving effects (a networked client), it draws the pooled legacy explosion.

## Destroyed-tank explosions are bigger than ordinary hits.
var big := false


func _process(_delta: float) -> void:
	# Match sets global_position after add_child, so fire on the first frame, not in _ready.
	var fx := FxWorld.get_instance()
	if fx != null and not fx.link.stub_impact(global_position, big):
		fx.explosion(global_position, big)
	queue_free()
	set_process(false)
