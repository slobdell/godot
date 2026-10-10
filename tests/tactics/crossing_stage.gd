class_name CrossingStage
extends RefCounted
## Round 25 (brains F0): HIS CROSSING, counted. "I click a point for my army to move to (across a bridge). Not all of
## them make it to the other side ... trying to maintain formation (i.e. a wedge) while trying to cross a bridge. The
## formation is wider than the bridge ... a vehicle further back (the presumable point man) was trying to get to the
## front." (2026-10-10, the Crossing, seed 35967; recording streams/references/round25/his/.)
##
## His Guns (five Assault Guns) at 15.7 s stood north of the east reach, ~40 m west of the east bridge, and he
## right-clicked (a plain move) to (80, -51), across it: the route runs EAST along the quay to the bridge, then SOUTH
## over it. Here the same five stand where his census put them (jittered by `seed`), get the same plain move in a
## given shape (wedge, column), and run with no enemy (the crossing is the question). `side` "rust" mirrors the stage
## through the map's centre (the CPU's squads cross the same way). The Locks: the same squad shape about the R1 stage's
## start, to its far quay (the west swing bridge).
##
## Report (seconds from the order; -1 = never):
##   crossed / crossed_s     crews past the water, and when the LAST one got there (-1 unless all did)
##   cross_s                 per crew, when it got past the water
##   arrived_s               the element's arrival
##   point_passes            squadmates the crew seated on the shape's POINT (its frontmost slot) started AHEAD of,
##                           along the route, by more than PASS_MARGIN_M: how many it has to drive past to get there
##   seat_passes             every pair of crews whose order along the route is inverted by their seats (a crew seated
##                           ahead of one that starts ahead of it, both by more than PASS_MARGIN_M)
##   overtakes               pairs whose order along the route really flipped on the way (progress along the route,
##                           at the start and when the first crew crosses, apart by more than PASS_MARGIN_M each way)
##   stall_s / stall_at      per crew, its longest stretch moving under STILL_MPS while its element had not arrived
##                           (and where); stall_why what held it there: "rail" (a deck rail or the water's rim),
##                           "tank" (a hull), "" (nothing: waiting, or driving into nothing)
##   wet_station_s           per crew, seconds the travelling shape put its station (ElementPlan.stations_along, before
##                           grounding) over the water, or on the water's rim beside the deck (the arena's clamp pulls a
##                           station laid over the water back to the rim): holding a slot it cannot reach
##   reseats                 fresh seatings the element took (Element.reseats_taken)

const PASS_MARGIN_M := 6.0
const STILL_MPS := 0.5
const JITTER_M := 1.5

## His Guns at 15.7 s (census), and the click.
const HIS := {"at": [[44.0, 64.0], [51.0, 87.0], [56.0, 66.0], [36.0, 83.0], [66.0, 72.0]], "to": [80.0, -51.0]}
const STAGES := {
	"crossing": {"center": Vector3(50.6, 0.0, 74.4), "to": Vector3(80.0, 0.0, -51.0)},
	"crossing_dry": {"center": Vector3(50.6, 0.0, 74.4), "to": Vector3(80.0, 0.0, -51.0)},
	# The R1 stage's quay (BridgeStage "locks"): north of the canal, the far quay south of it.
	"locks": {"center": Vector3(-62.0, 0.0, 34.0), "to": Vector3(-59.0, 0.0, -55.0)},
	"locks_dry": {"center": Vector3(-62.0, 0.0, 34.0), "to": Vector3(-59.0, 0.0, -55.0)},
}


## The stage for `arena`: STAGES, or for any other map with water or pits BridgeStage's derived crossing (across its first
## carving's middle, 30 m off each long side), with his squad's shape about its near end. Needs Arena.active.
static func stage_of(arena: String) -> Dictionary:
	if STAGES.has(arena):
		return STAGES[arena]
	var derived := BridgeStage._derived(Arena.active)
	return {"center": derived["from"], "to": derived["to"]}


static func positions(stage: Dictionary) -> Array:
	var mid := Vector3.ZERO
	for p: Array in HIS["at"]:
		mid += Vector3(p[0], 0.0, p[1])
	mid /= float((HIS["at"] as Array).size())
	var out: Array = []
	for p: Array in HIS["at"]:
		out.append(Vector3(p[0], 0.0, p[1]) - mid + (stage["center"] as Vector3))
	return out


## `drills` true: the order runs drills (his attack-move's path and every CPU element's move: legs, the leader pinned
## to the point, armour to the front); false: his right-click (a plain move: one shape travelling along the route).
## `unit_id` may be a ":"-joined list, one per crew (a mixed squad).
static func run(case: TestCase, seed_value: int, arena: String, formation: String, side: String, seconds: float,
		unit_id := "law_tank", trace := false, drills := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	var mine := Match.Team.GREEN if side == "green" else Match.Team.RUST
	game_match.set_meta("player_team", mine)
	var flip := 1.0 if side == "green" else -1.0
	var stage := stage_of(arena)
	var to: Vector3 = (stage["to"] as Vector3) * flip
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	var prefix := "Green" if mine == Match.Team.GREEN else "Rust"
	var spots := positions(stage)
	for i in spots.size():
		var at: Vector3 = (spots[i] as Vector3) * flip \
				+ Vector3(jitter.randf_range(-JITTER_M, JITTER_M), 0.0, jitter.randf_range(-JITTER_M, JITTER_M))
		# His crews faced every which way after the last fight; here they face where they were last sent (roughly east).
		var face := Vector3(flip, 0.0, 0.0)
		var yaw := atan2(-face.x, -face.z) + deg_to_rad(jitter.randf_range(-20.0, 20.0))
		var ids := unit_id.split(":")
		names.append(String(lab.unit(mine, "%s_S_%d" % [prefix, i + 1], at, yaw, ids[i % ids.size()]).name))
	await lab.start()
	for unit_name: String in names:
		var t := lab.tank_of(unit_name)
		var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
		t.global_position = Vector3(at.x, 0.0, at.z)
		t.velocity = Vector3.ZERO
	for i in 3:
		await lab.step()
	var starts := {}
	for unit_name: String in names:
		var t := lab.tank_of(unit_name)
		starts[unit_name] = Vector3(t.global_position.x, 0.0, t.global_position.z)
	var element := lab.elements.form(names, "Alpha")
	var task := {"verb": "move", "to": [to.x, to.z], "drills": drills}
	if formation != "auto":
		task["formation"] = formation
	element.assign(task)
	var water := BridgeStage._water_rows(Arena.active)
	var given: int = game_match.tick
	var crossed := {}
	var crossed_at := -1
	var arrived := -1
	var trails := {}
	var still := {}
	var stall := {}
	var wet_station := {}
	var route: Array = []
	var seat_report := {}
	var progress_start := {}
	var progress_cross := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var now: int = game_match.tick - given
		if trace and route.is_empty() and not element.transit.is_empty():
			print("CROSSING_PROFILE " + JSON.stringify({"route": (element.transit.get("route", []) as Array).map(BridgeStage._xz),
					"profile": (element.transit.get("profile", []) as Array).map(func(p: Array) -> Array:
						return [snappedf(float(p[0]), 0.1), snappedf(float(p[1]), 0.1) if is_finite(float(p[1])) else -1.0,
								snappedf(float(p[2]), 0.1)])}))
		if route.is_empty() and not element.seats.is_empty() and (not element.transit.is_empty() or drills):
			# A drill move has no travelling anchor: its route is the navmesh's from the squad's centre to the click.
			route = element.transit.get("route", []) if not element.transit.is_empty() \
					else Array(Pathing.find_path(lab.tank_of(names[0]), lab.center_of(names), to))
			seat_report = seat_passes(element, starts, route)
			for unit_name: String in names:
				progress_start[unit_name] = progress_on(route, starts[unit_name])
		if arrived < 0 and element.arrived:
			arrived = now
		var raw := {}
		var squeeze := 0.0
		if element.in_transit():
			raw = ElementPlan.stations_along({"seats": element.seats, "formation": element.formation,
					"pitch": element.pitch}, element.transit)
			var shape := TacticsFormation.centered(TacticsFormation.offsets_at(element.formation, names.size(), element.pitch))
			squeeze = float(ElementPlan.funnel(shape, element.pitch, element.transit)["weight"])
		for unit_name: String in names:
			var t := lab.tank_of(unit_name)
			if t == null or not t.is_alive():
				continue
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			if not crossed.has(unit_name) and BridgeStage._past_water(here, starts[unit_name], water):
				crossed[unit_name] = now
				crossed_at = now
				if progress_cross.is_empty() and not route.is_empty():
					for other: String in names:
						var o := lab.tank_of(other)
						if o != null:
							progress_cross[other] = progress_on(route, Vector3(o.global_position.x, 0.0, o.global_position.z))
			var trail: Array = trails.get_or_add(unit_name, [])
			trail.append(here)
			if trail.size() > SimClock.TICK_RATE:
				trail.pop_front()
			var crept := (trail[0] as Vector3).distance_to(here) if trail.size() >= SimClock.TICK_RATE else INF
			if crept < STILL_MPS and arrived < 0 and not crossed.has(unit_name):
				var run_ticks := int(still.get(unit_name, 0)) + 1
				still[unit_name] = run_ticks
				var best: Dictionary = stall.get(unit_name, {"ticks": 0})
				if run_ticks > int(best["ticks"]):
					var held := BridgeStage._held_by(t)
					stall[unit_name] = {"ticks": run_ticks, "at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)],
							"why": "rail" if held == "terrain" else held}
			else:
				still[unit_name] = 0
			var station: Variant = element.stations.get(unit_name)
			# The SHAPE's own station, recomputed before Element.ground moves it to dry land (shape_along is grounded in
			# place): over the water = the shape asks for a place no crew can stand; grounded, that place lands on a quay
			# beside the deck and the crew parks in the mouth.
			var shaped: Variant = raw.get(unit_name)
			if shaped is Vector3 and _unreachable(shaped, water):
				wet_station[unit_name] = int(wet_station.get(unit_name, 0)) + 1
			if trace and now % (SimClock.TICK_RATE / 2) == 0:
				print("CROSSING_TRACK " + JSON.stringify({"t": BridgeStage._s(now), "n": unit_name,
						"at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)], "v": snappedf(t.estimated_velocity.length(), 0.1),
						"seat": element.seats.get(unit_name), "station": BridgeStage._xz(station),
						"slot": BridgeStage._xz(element.slots.get(unit_name)), "phase": String(Movement.state(t).get("phase", "")),
						"blocked": Movement.state(t).get("blocked_by"), "anchor": BridgeStage._xz(element.transit.get("anchor")),
						"pace": element.paces.get(unit_name), "falling_in": element.falling_in.has(unit_name),
						"raw": BridgeStage._xz(raw.get(unit_name)), "funnel": snappedf(squeeze, 0.01),
						"rim": raw.get(unit_name) is Vector3 and _unreachable(raw[unit_name], water),
						"s": snappedf(float(element.transit.get("s", 0.0)), 0.1),
						"progress": snappedf(progress_on(route, here), 0.1) if not route.is_empty() else null}))
		if crossed.size() == names.size() and arrived >= 0:
			break
	var overtakes := 0
	if not progress_cross.is_empty():
		for a: String in names:
			for b: String in names:
				if a < b and progress_cross.has(a) and progress_cross.has(b):
					var before := float(progress_start[a]) - float(progress_start[b])
					var after := float(progress_cross[a]) - float(progress_cross[b])
					if absf(before) > PASS_MARGIN_M and absf(after) > PASS_MARGIN_M and signf(before) != signf(after):
						overtakes += 1
	var cross_s := {}
	var stall_s := {}
	var stall_at := {}
	var stall_why := {}
	var wet_s := {}
	for unit_name: String in names:
		cross_s[unit_name] = BridgeStage._s(int(crossed.get(unit_name, -1)))
		var best: Dictionary = stall.get(unit_name, {"ticks": 0, "at": null, "why": ""})
		stall_s[unit_name] = BridgeStage._s(int(best["ticks"]))
		stall_at[unit_name] = best["at"]
		stall_why[unit_name] = best["why"]
		wet_s[unit_name] = BridgeStage._s(int(wet_station.get(unit_name, 0)))
	var report := {"seed": seed_value, "arena": arena, "side": side, "formation": formation, "unit": unit_id,
			"drills": drills,
			"crews": names.size(), "crossed": crossed.size(),
			"crossed_s": BridgeStage._s(crossed_at) if crossed.size() == names.size() else -1.0,
			"arrived_s": BridgeStage._s(arrived), "cross_s": cross_s,
			"point_passes": int(seat_report.get("point_passes", -1)), "seat_passes": int(seat_report.get("seat_passes", -1)),
			"point": seat_report.get("point", ""), "seats": seat_report.get("seats", {}), "overtakes": overtakes,
			"stall_s": stall_s, "stall_at": stall_at, "stall_why": stall_why, "wet_station_s": wet_s,
			"reseats": element.reseats, "swaps": element.swaps,
			"route_m": snappedf(ElementPlan.route_length(route), 0.1) if not route.is_empty() else -1.0}
	lab.dispose()
	return report


## The seating's passes along the route: where each crew STARTED (metres along `route`) against where its seat puts it
## in the shape (its slot's place along the heading). Pure. {"point", "point_passes", "seat_passes", "seats"}.
static func seat_passes(element: Element, starts: Dictionary, route: Array) -> Dictionary:
	var count := 0
	for unit_name: String in element.seats:
		count = maxi(count, int((element.seats[unit_name] as Array)[1]))
	var formation := String((element.seats.values()[0] as Array)[0])
	var shape := TacticsFormation.centered(TacticsFormation.offsets_at(formation, count, element.pitch))
	var ahead := {}  # unit -> its slot's place along the heading (metres; larger = further forward)
	var started := {}
	var seats := {}
	for unit_name: String in element.seats:
		var index := int((element.seats[unit_name] as Array)[2])
		ahead[unit_name] = -shape[index].y if index < shape.size() else 0.0
		started[unit_name] = progress_on(route, starts[unit_name])
		seats[unit_name] = index
	var point := ""
	for unit_name: String in ahead:
		if point == "" or float(ahead[unit_name]) > float(ahead[point]) + 1e-6:
			point = unit_name
	var point_passes := 0
	var seat_passes := 0
	for a: String in ahead:
		if a != point and float(started[a]) > float(started[point]) + PASS_MARGIN_M:
			point_passes += 1
		for b: String in ahead:
			if float(started[a]) < float(started[b]) - PASS_MARGIN_M and float(ahead[a]) > float(ahead[b]) + PASS_MARGIN_M:
				seat_passes += 1
	return {"point": point, "point_passes": point_passes, "seat_passes": seat_passes, "seats": seats}


## How far along `route` (metres from its start) the point nearest `p` is. Pure.
static func progress_on(route: Array, p: Vector3) -> float:
	var best := INF
	var best_s := 0.0
	var walked := 0.0
	for i in range(1, route.size()):
		var a := Vector3(route[i - 1].x, 0.0, route[i - 1].z)
		var b := Vector3(route[i].x, 0.0, route[i].z)
		var leg := a.distance_to(b)
		var u := 0.0 if leg < 1e-6 else clampf((p - a).dot(b - a) / (leg * leg), 0.0, 1.0)
		var d := p.distance_to(a.lerp(b, u))
		if d < best:
			best = d
			best_s = walked + u * leg
		walked += leg
	return best_s


## A station no crew should be given: over the water, or on its rim beside a deck rather than on it (the arena clamps a
## station laid over the water back to the rim: the flank crew's parking place beside the mouth). RIM_STATION_M.
const RIM_STATION_M := 3.0
static func _unreachable(station: Vector3, water: Dictionary) -> bool:
	return BridgeStage._wet(station, water) or (BridgeStage._near_water(station, RIM_STATION_M, water)
			and not BridgeStage._at_a_crossing(station, 0.0, water))
