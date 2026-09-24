extends SceneTree
## `make airship-report`: how the broadcast airship actually flies each map, as three numbers per map, measured by
## flying the real node through its public surface (`fly_toward`, `advance_to`, `pilot`, `hull_centre_y`) so the same
## script measures any version of the flight:
##   * **inside %** -- share of the flight any part of the hull is inside something DRAWN (`AirshipTruth`: the kit's
##     own meshes and the hull's own mesh, not the flight's model). His complaint, as a number; it must be 0.
##   * **cruise %** -- share of the flight at its low cruise height rather than climbing over something.
##   * **seen %** -- share of the flight inside his frame (`SyndicateAdAirship.in_frame`, at the height it actually
##     flies, averaged over four camera yaws round the fight). An UPPER bound: it ignores occlusion.
## The flight is four one-minute legs: the fight in the middle, then pushed as far toward each side as the orbit is
## ever allowed to follow it (the same room `_read_action` clamps to).
##
## Headless and deterministic. `--maps=a,b` narrows it; `--seconds=S` sets each leg.

const MAPS := ["terminus", "yard", "pit", "boneyard", "boulevard", "crossing", "sumps", "maze", "barriers"]


var _done := false


# On the first frame, not in _init: a node added before the tree runs is not ready, and an unready airship has not
# loaded what it flies around (the first version of this report measured an empty map).
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	run()
	return true


func run() -> void:
	var maps: Array = MAPS
	var seconds := 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maps="):
			maps = arg.trim_prefix("--maps=").split(",")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	print("AIRSHIP_REPORT map        inside%  cruise%  seen%   worst intrusion")
	for name: String in maps:
		var loaded := Arena.load_layout(name)
		if loaded.has("error"):
			print("AIRSHIP_REPORT %s: %s" % [name, loaded["error"]])
			continue
		var row := measure(loaded["layout"], seconds)
		print("AIRSHIP_REPORT %-10s %6.1f  %7.1f  %5.1f   %s" % [name, row["inside_pct"], row["cruise_pct"], row["seen_pct"],
				row["worst"]])
	print("AIRSHIP_REPORT_DONE")


func measure(layout: Dictionary, seconds: float) -> Dictionary:
	var ship := SyndicateAdAirship.new(layout)
	root.add_child(ship)
	if not ship.is_node_ready():
		push_error("airship-report: the airship is not ready, so it has not loaded what it flies around")
	var solids := AirshipTruth.drawn_solids(layout)
	var half := float(layout.get("half_size", 120.0))
	var play := maxf(20.0, half - SyndicateAdAirship.BEAM * 0.5 - SyndicateAdAirship.WALL_MARGIN)
	var room := maxf(0.0, play - AirshipPilot.ORBIT_RADIUS - AirshipPilot.TRACK_MARGIN)
	var legs := [Vector2.ZERO, Vector2(room, 0.0), Vector2(-room, 0.0), Vector2(0.0, room)]
	var tick := 0
	var counts := {"n": 0, "inside": 0, "cruise": 0, "seen": 0}
	var worst := {"depth": 0.0, "text": "none"}
	for action: Vector2 in legs:
		ship.fly_toward(action)
		for i in int(seconds * SimClock.TICK_RATE):
			tick += 1
			ship.advance_to(tick)
			counts["n"] += 1
			var at: Vector2 = ship.pilot.position
			var centre_y: float = ship.hull_centre_y()
			var belly := centre_y + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH - SyndicateAdAirship.FLOAT_RISE_TOTAL
			if centre_y <= SyndicateAdAirship.ALTITUDE + 0.5:
				counts["cruise"] += 1
			for yaw: float in SyndicateAdAirship.SEEN_YAWS:
				counts["seen"] += int(SyndicateAdAirship.in_frame(at, belly + SyndicateAdAirship.FLOAT_RISE_TOTAL, action, yaw))
			var hit := false
			for solid: Dictionary in solids:
				var depth := AirshipTruth.intrusion(at, ship.pilot.heading, centre_y, solid)
				if depth <= 0.0:
					continue
				hit = true
				if depth > float(worst["depth"]):
					worst = {"depth": depth, "text": "%.1f m into a %s at (%.0f, %.0f), t=%.0f s" % [depth, solid["type"],
							(solid["centre"] as Vector2).x, (solid["centre"] as Vector2).y, float(tick) / SimClock.TICK_RATE]}
			counts["inside"] += int(hit)
	ship.free()
	var n := maxf(1.0, float(counts["n"]))
	return {"inside_pct": 100.0 * counts["inside"] / n, "cruise_pct": 100.0 * counts["cruise"] / n,
			"seen_pct": 100.0 * counts["seen"] / (n * SyndicateAdAirship.SEEN_YAWS.size()), "worst": worst["text"]}
