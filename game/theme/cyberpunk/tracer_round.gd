extends Node3D
## `fx.tracer` for the cyberpunk theme: one hitscan machine-gun round (round 2's scout gun is a "beam" weapon drawn by
## this slot). No mesh of its own: `setup(from, to)` (world space, called once right after the slot enters the tree,
## Match frees it 0.2 s later) hands the round to the shared TracerSystem as a fast tracer flying from the muzzle to
## where it stopped, and the hit to the stream effect family. Once K2 is live, rounds are drawn from weapon events and
## this slot does nothing.


func setup(from: Vector3, to: Vector3) -> void:
	var fx := FxWorld.get_instance()
	if fx == null or fx.link.live:
		return
	if not fx.link.stub_hitscan(from, to):
		fx.tracers.shoot(from, to, WeaponFx.NEUTRAL_GLOW, "stream", fx.now)
