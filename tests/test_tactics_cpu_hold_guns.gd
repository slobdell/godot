extends "res://tests/tactics/cpu_hold_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in cpu_hold_case.gd.


## Stretch (a): the holding CPU's artillery is REGISTERED on the ambush's kill zone: once there is contact, its support
## task aims where the ambush springs, not at the nearest contact.
func test_the_holding_cpus_guns_are_registered_on_the_kill_zone() -> void:
	var nearest: Dictionary = await _stage(true, true, false)
	var on: Dictionary = await _stage(true, true, true)
	print("MEASURE cpu_hold guns parade: on the nearest contact %s | registered %s" % [nearest, on])
	assert_true(float(on["sprung_s"]) >= 0.0, "the ambush is sprung (%s)" % on)
	assert_true(bool(on["guns_on_kill_zone"]), "the guns' task is the kill zone once it is sprung (%s)" % on)
	assert_true(not bool(nearest["guns_on_kill_zone"]), "control: unregistered, they aim at the nearest contact (%s)" % nearest)
