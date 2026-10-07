class_name AirshipReport
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
##
## Round 21 (V0): the default list is the LIVE rotation (`Arena.ROTATION`), read at run time. It was a constant of the
## round-11 nine, and six maps he is dealt (locks, parade, gorge, archipelago, cut, docks) were never measured until
## 2026-10-06 (lesson 265). A per-map line, then a POOLED line (the plain mean over the maps, and the worst map's seen %),
## so one number says whether the airship is seen on the maps he plays.


var _done := false


# On the first frame, not in _init: a node added before the tree runs is not ready, and an unready airship has not
# loaded what it flies around (the first version of this report measured an empty map).
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	run()
	return true


## The maps measured when `--maps=` is not given: every map he plays today -- whatever `random` deals him
## (`Arena.ROTATION`) and the map a fight lands on with no `--arena` (`Arena.DEFAULT_LAYOUT`: the garage's fights).
## Round 21: the map he had just played when he said he never saw it was foundry, the default, in neither list.
static func default_maps() -> Array:
	var maps: Array = Arena.ROTATION.duplicate()
	if not maps.has(Arena.DEFAULT_LAYOUT):
		maps.append(Arena.DEFAULT_LAYOUT)
	return maps


func run() -> void:
	var maps: Array = AirshipReport.default_maps()
	var seconds := 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maps="):
			maps = arg.trim_prefix("--maps=").split(",")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	print("AIRSHIP_REPORT map          inside%  cruise%  seen%   worst intrusion")
	var rows := {}
	for name: String in maps:
		var loaded := Arena.load_layout(name)
		if loaded.has("error"):
			print("AIRSHIP_REPORT %s: %s" % [name, loaded["error"]])
			continue
		var row := measure(loaded["layout"], seconds)
		rows[name] = row
		print("AIRSHIP_REPORT %-12s %6.1f  %7.1f  %5.1f   %s" % [name, row["inside_pct"], row["cruise_pct"], row["seen_pct"],
				row["worst"]])
	var pool := AirshipReport.pooled(rows)
	print("AIRSHIP_REPORT %-12s %6.1f  %7.1f  %5.1f   %d maps; least seen %s %.1f %%" % ["POOLED", pool["inside_pct"],
			pool["cruise_pct"], pool["seen_pct"], pool["maps"], pool["least_map"], pool["least_seen_pct"]])
	print("AIRSHIP_REPORT_DONE")


## The pooled line: the plain mean of each column over the measured maps (every map one vote, as he is dealt them
## evenly), and the map he would see it on least. Pure.
static func pooled(rows: Dictionary) -> Dictionary:
	var out := {"maps": rows.size(), "inside_pct": 0.0, "cruise_pct": 0.0, "seen_pct": 0.0, "least_map": "-",
			"least_seen_pct": 0.0}
	if rows.is_empty():
		return out
	var least := INF
	for name: String in rows:
		var row: Dictionary = rows[name]
		for key: String in ["inside_pct", "cruise_pct", "seen_pct"]:
			out[key] += float(row[key]) / rows.size()
		if float(row["seen_pct"]) < least:
			least = float(row["seen_pct"])
			out["least_map"] = name
			out["least_seen_pct"] = least
	return out


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
