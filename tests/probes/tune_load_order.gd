extends SceneTree
## A FRESH PROCESS, which is the only place the load-order bug is reachable.
##
## `TUNE=` is read by `Units._static_init()` at class-load time. The bug this probe exists for was that the spec
## was APPLIED there too, writing statics on `Tank`, `Armor`, `SwitchingCost` and `Weapons` -- and a write to
## another class's static at class load is undone by that class's own initialiser whenever the load order puts it
## second. Measured both ways in round 9: the write landed in a bare script and was GONE under the test runner,
## and feel's builder0 bench saw `--tune=match.no_damage=1` accepted with no error while `Armor.no_damage` read
## false in 13 of 13 phases and the census walked 90 -> 77 with units dying.
##
## A test method cannot reproduce that: by the time one runs, the harness has loaded every script in `tests/` and
## everything they reference, so every class is long since initialised. Hence a child process.
##
## It prints the TUNE it actually SAW as well as the predicate's value, so a probe reading the parent's environment
## instead of its own cannot pass for the right reason.
func _init() -> void:
	print("TUNE_PROBE saw TUNE='%s' no_damage_on=%s yaw_fit_on=%s" % [
			OS.get_environment("TUNE"), Armor.no_damage_on(), Tank.yaw_fit_on()])
	quit()
