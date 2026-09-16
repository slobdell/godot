extends Node3D
## `fx.tracer` for the cyberpunk theme: one hitscan machine-gun round (Match.show_beam invokes `setup(from, to)` once,
## world space, and frees the slot 0.2 s later). On the simulating peer WeaponFx already draws every hitscan round from
## K2 events, so this does nothing; on a peer that doesn't simulate (a networked client) it hands the round to the
## shared TracerSystem as a plain tracer. No mesh of its own.


func setup(from: Vector3, to: Vector3) -> void:
	var fx := FxWorld.get_instance()
	if fx != null and not fx.link.live:
		fx.tracers.shoot(from, to, WeaponFx.NEUTRAL_GLOW, "stream", fx.now)
