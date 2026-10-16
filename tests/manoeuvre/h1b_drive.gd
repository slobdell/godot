extends "res://tests/nav/terminus_drive.gd"
## Round 32 (manoeuvre H1b, C32.2): the Terminus drive exactly as `make nav-terminus-drive` runs it, plus one line at
## the end with H1b's counters (`H1B_DRIVE <json>`: ManoeuvreCensus.h1b_report() and the escape's arms). Nothing it adds
## touches the sim. `make manoeuvre-h1b-drive` runs it in two arms.


func _report() -> void:
	print("H1B_DRIVE %s" % JSON.stringify({"seed": int(_flag("seed", "1")), "squad": squad_kind, "h1b_on": Movement.h1b_on(),
			"h1b": ManoeuvreCensus.h1b_report(), "escape": Movement.escape_arms()}))
	super()
