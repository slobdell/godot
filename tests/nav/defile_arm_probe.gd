extends "res://tests/tactics/defile_probe.gd"
## nav's view of squad's defile probe (read-only; the pattern of nav_probe.gd over arena's maze probe): the same run,
## plus the arm counters of every opt-in nav row at exit, so an A/B arm is PROVEN applied (lesson 147) rather than
## inferred from a flag.


func _finalize() -> void:
	print("DEFILE_ARM oriented_on=%s oriented_pairs=%d press_on=%s press_escapes=%d inflate_on=%s corners_inflated=%d nosestop_on=%s nose_stops=%d wall_contact_ticks=%d" % [
			Avoidance.oriented_on(), Avoidance.oriented_pairs, Movement.press_on(), Movement.press_escapes,
			Movement.inflate_on(), Movement.corners_inflated, Movement.nose_stop_on(), Movement.nose_stops, WallContact.ticks])
