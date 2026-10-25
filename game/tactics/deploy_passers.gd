class_name DeployPassers
## Round 39 (settle S1, C39.2): WHO STILL HAS TO DRIVE PAST A SQUAD THAT IS DEPLOYING, AND WHERE THE OTHER SQUADS ARE PARKED.
## Traced (round 38: terminus 5 route s4410 and s4505, crossing 5 route s3958; R38.40, R38.43): a deploying squad laid a
## halt seat on the route a squad of the same order still had to drive (along the street, at a junction, in a lane mouth,
## at a bridge mouth) or inside another squad's parked halt, the crews there never moved again and the squad behind never
## got in. `of` reads, once, the ground the deploy must keep clear of: every other element of the team still driving a
## move (its remaining route from where its crews stand, then its queued legs, on the navmesh) and every other element
## parked (its seats). `blocking` / `clear_seat` are the pure halves ElementPlan's deploy uses (ElementPlan.SEAT_ROUTE_CLEAR).

## The half-width of a route still to be driven that no halt seat may stand in: the group lay's travel clearance between
## two squads (SelectionSquads.PACK_TRAVEL_CLEAR_M), measured from the route's centre line to the GROUNDED seat.
const ROUTE_CLEAR_M := 7.0
## No halt seat within this of a seat of another squad's parked halt: the group lay's halt-to-halt clearance
## (SelectionSquads.HALT_CLEAR_M).
const HALT_CLEAR_M := 9.0
## The search for a clear seat: steps of CLEAR_STEP_M out to CLEAR_MAX_M, first straight out of what blocks it, then back
## along the squad's own arrival leg.
const CLEAR_STEP_M := 2.0
const CLEAR_MAX_M := 24.0
const CLEAR_RING := 16
## A moved seat keeps at least this share of the halt's spacing from the squad's other seats.
const CLEAR_OWN_GAP := 0.75


## The ground a deploy of the element led by `leader` (team `team`) must keep clear of, read now:
## {"routes": [[Vector3, ...], ...] (each a remaining drive, flat), "halts": [[Vector3, ...], ...] (each a parked squad's
## seats)}. Elements are read in id order; empty without an Elements node.
static func of(game_match: Match, team: int, leader: String) -> Dictionary:
	var out := {"routes": [], "halts": []}
	var elements := Elements.of_match(game_match) if game_match != null else null
	if elements == null:
		return out
	var by_name := AiTickCache.tanks_by_name(game_match)
	var node := game_match.tanks.get_child(0) as Node3D if game_match.tanks != null \
			and game_match.tanks.get_child_count() > 0 else null
	for element: Element in elements.of_team(team):
		if element.roster.has(leader) or element.leader == leader:
			continue
		var centre := Vector3.ZERO
		var crews: Array = []
		for unit_name in element.roster:
			var tank := by_name.get(unit_name) as Tank
			if tank != null and tank.is_alive():
				crews.append(Vector3(tank.global_position.x, 0.0, tank.global_position.z))
				centre += crews[crews.size() - 1]
		if crews.is_empty():
			continue
		centre /= float(crews.size())
		var route := remaining_route(element, centre, node)
		if route.size() >= 2 and CREW_CORRIDORS:
			# v3 (round 40, cause A): each crew's own drive, not the squad's centre line.
			out["routes"].append_array(crew_routes(element, _crews_by_name(element, by_name), centre, node))
		elif route.size() >= 2:
			out["routes"].append(route)
			# The drive starts from every crew, not the squad's centre: the rear crews still have the ground behind it to
			# cover (traced s4505: a seat cleared 6 m behind Alpha's centre stood on its rear crews' lane).
			for crew: Vector3 in crews:
				if crew.distance_to(route[0]) > 1.0:
					out["routes"].append([crew, route[0]])
		elif element.arrived and element.queued_tasks.is_empty():
			var seats: Array = []
			for unit_name: String in _sorted(element.slots.keys()):
				var seat: Variant = element.slots[unit_name]
				if seat is Vector3:
					seats.append(Vector3((seat as Vector3).x, 0.0, (seat as Vector3).z))
			if not seats.is_empty():
				out["halts"].append(seats)
	return out


## S1 v3 (round 40, settle; round 39's time trace, cause A: terminus 5 click s6003, Alpha's crews drove x -7..-1 while the
## one centre line the clear protected ran at x 4..8, and seats cleared off it landed on the crews' real lanes): the ground a
## driving squad still needs is EACH CREW'S drive, from where it stands to the squad's spot shifted by the crew's place in
## the squad (its slot less the squad's centre, at most CREW_OFFSET_MAX_M), then each queued leg's spot shifted the same,
## on the navmesh. ON with ElementPlan.SEAT_ROUTE_CLEAR_V3 (`--seat-route-clear=v3`).
static var CREW_CORRIDORS := OS.get_cmdline_user_args().has("--seat-route-clear=v3") \
		or OS.get_environment("SEAT_ROUTE_CLEAR") == "v3"
const CREW_OFFSET_MAX_M := 15.0


static func _crews_by_name(element: Element, by_name: Dictionary) -> Dictionary:
	var crews := {}
	for unit_name in element.roster:
		var tank := by_name.get(unit_name) as Tank
		if tank != null and tank.is_alive():
			crews[String(unit_name)] = Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	return crews


## Each crew's remaining drive (name order), as above: [[Vector3, ...], ...]; a crew with no move left gives none.
static func crew_routes(element: Element, crews: Dictionary, centre: Vector3, node: Node3D) -> Array:
	var out: Array = []
	var verb := String(element.task.get("verb", ""))
	var moving := (verb == "move" or verb == "attack_move") and not element.arrived
	var spot: Variant = ElementTask.destination(element.task)
	for unit_name: String in _sorted(crews.keys()):
		var at: Vector3 = crews[unit_name]
		var slot: Variant = element.slots.get(unit_name)
		var offset := Vector3((slot as Vector3).x - centre.x, 0.0, (slot as Vector3).z - centre.z) if slot is Vector3 else Vector3.ZERO
		offset = offset.limit_length(CREW_OFFSET_MAX_M)
		var points: Array = []
		var last := at
		if moving and spot is Vector3:
			points = _path(node, at, (spot as Vector3) + offset)
			last = (spot as Vector3) + offset
		for queued: Dictionary in element.queued_tasks:
			var to: Variant = ElementTask.destination(queued)
			if not (to is Vector3):
				continue
			var leg := _path(node, last, (to as Vector3) + offset)
			points.append_array(leg if points.is_empty() else leg.slice(1))
			last = (to as Vector3) + offset
		if points.size() >= 2:
			out.append(points)
	return out


## S1 v3 (b) (cause B: crossing 5 route s6009, Echo_4's cleared seat 25 m across the junction, its leg met Delta head-on):
## a crew's leg from `from` to `to` is fit when it is at most `short_m` long, or when every point of it past its first
## `short_m` stands ROUTE_CLEAR_M clear of every route in `passers` (a crew may pull out of a corridor, not drive along or
## across one). Pure.
static func leg_clear(from: Vector3, to: Vector3, passers: Dictionary, short_m: float) -> bool:
	var leg := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := leg.length()
	if length <= short_m:
		return true
	var d := short_m
	while d <= length + 0.001:
		var p := Vector3(from.x, 0.0, from.z) + leg * (minf(d, length) / length)
		for route: Array in passers.get("routes", []):
			for i in range(1, route.size()):
				if p.distance_to(_closest_on(p, route[i - 1], route[i])) < ROUTE_CLEAR_M:
					return false
		d += CLEAR_STEP_M
	return true


## The drive `element` still has to make from `centre`: the rest of its travelling anchor's route (a plain move in
## transit), else a navmesh path to its move's spot (not yet arrived), then every queued leg's path. [] when it has none.
static func remaining_route(element: Element, centre: Vector3, node: Node3D) -> Array:
	var points: Array = []
	var verb := String(element.task.get("verb", ""))
	var moving := (verb == "move" or verb == "attack_move") and not element.arrived
	var spot: Variant = ElementTask.destination(element.task)
	var last: Vector3 = centre
	if moving and spot is Vector3:
		var transit: Dictionary = element.transit
		var route: Array = transit.get("route", []) if typeof(transit.get("route")) == TYPE_ARRAY else []
		if not route.is_empty() and not bool(transit.get("arrived", true)):
			points.append(centre)
			points.append_array(route_from(route, float(transit.get("s", 0.0))))
		else:
			points.append_array(_path(node, centre, spot))
		if not points.is_empty():
			last = points[points.size() - 1]
	for queued: Dictionary in element.queued_tasks:
		var at: Variant = ElementTask.destination(queued)
		if not (at is Vector3):
			continue
		var leg := _path(node, last, at)
		if points.is_empty():
			points.append_array(leg)
		elif leg.size() >= 2:
			points.append_array(leg.slice(1))
		last = at
	return points


## `route` (flat) from `s` metres along it: the point there, then every later vertex. Pure.
static func route_from(route: Array, s: float) -> Array:
	var out: Array = [ElementPlan.route_pose(route, s)["point"]]
	var walked := 0.0
	for i in range(1, route.size()):
		walked += Vector2(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z).length()
		if walked > s:
			out.append(Vector3(route[i].x, 0.0, route[i].z))
	return out


static func _path(node: Node3D, from: Vector3, to: Vector3) -> Array:
	var path := Pathing.find_path(node, from, to) if node != null else PackedVector3Array()
	if path.size() < 2:
		return [Vector3(from.x, 0.0, from.z), Vector3(to.x, 0.0, to.z)]
	var out: Array = []
	for p: Vector3 in path:
		out.append(Vector3(p.x, 0.0, p.z))
	return out


static func _sorted(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort()
	return out


## What blocks a seat standing at `point`: {} when nothing does, else {"from": the nearest blocking point (on a route's
## centre line, or a parked seat)}. Pure.
static func blocking(point: Vector3, passers: Dictionary) -> Dictionary:
	var p := Vector3(point.x, 0.0, point.z)
	var best := INF
	var from: Variant = null
	for route: Array in passers.get("routes", []):
		for i in range(1, route.size()):
			var near := _closest_on(p, route[i - 1], route[i])
			var d := p.distance_to(near)
			if d < ROUTE_CLEAR_M and d < best:
				best = d
				from = near
	for halt: Array in passers.get("halts", []):
		for seat: Vector3 in halt:
			var d := p.distance_to(seat)
			if d < HALT_CLEAR_M and d < best:
				best = d
				from = seat
	return {} if from == null else {"from": from}


static func _closest_on(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length_sq := ab.length_squared()
	if length_sq < 1e-9:
		return Vector3(a.x, 0.0, a.z)
	var t := clampf(Vector3(p.x - a.x, 0.0, p.z - a.z).dot(ab) / length_sq, 0.0, 1.0)
	return Vector3(a.x, 0.0, a.z) + ab * t


## The nearest seat to `seat` that nothing in `passers` blocks: stepped CLEAR_STEP_M at a time out to CLEAR_MAX_M, at each
## distance first straight away from what blocks it (the shortest way out), then along `back` (the squad's arrival leg,
## reversed), then round the ring (CLEAR_RING directions from `away`; traced s4505: Bravo_1's seat asked off Alpha's lane
## grounded onto it both ways, and stayed there). Each candidate is judged where it will stand, `ground.call(candidate)`, must pass `ok.call(candidate)` (dry,
## on the squad's own bank) and stand CLEAR_OWN_GAP x `spacing` from every seat in `others`. `seat` itself when it is
## clear; null when no clear seat is found. Pure but for the callables.
static func clear_seat(seat: Vector3, back: Vector3, passers: Dictionary, others: Array, spacing: float,
		ground: Callable, ok: Callable) -> Variant:
	var stands: Vector3 = ground.call(seat)
	var hit := blocking(stands, passers)
	if hit.is_empty():
		return seat
	var away := Vector3(stands.x - (hit["from"] as Vector3).x, 0.0, stands.z - (hit["from"] as Vector3).z)
	if away.length() < 0.01:
		away = Vector3(-back.z, 0.0, back.x)  # on the centre line: out to one side of the arrival leg
	var ways: Array = [away.normalized()]
	var flat_back := Vector3(back.x, 0.0, back.z)
	if flat_back.length() > 0.01:
		ways.append(flat_back.normalized())
	for k in range(1, CLEAR_RING):
		ways.append(TacticsFormation.rotate(away.normalized(), TAU * float(k) / float(CLEAR_RING)))
	var gap := CLEAR_OWN_GAP * spacing
	for step in range(1, int(CLEAR_MAX_M / CLEAR_STEP_M) + 1):
		for way: Vector3 in ways:
			var candidate := seat + way * CLEAR_STEP_M * float(step)
			if not bool(ok.call(candidate)):
				continue
			var at: Vector3 = ground.call(candidate)
			if not blocking(at, passers).is_empty():
				continue
			if others.any(func(o: Vector3) -> bool: return Vector2(o.x - at.x, o.z - at.z).length() < gap):
				continue
			return candidate
	return null
