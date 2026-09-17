class_name ElementSituation
extends RefCounted
## Everything an element's leader knows, as plain data (doctrine X1). Building it is the only impure step —
## it reads the match, its team's intel and the arena — and everything downstream (DoctrineTable.select,
## Drills.select, ElementPlan.build) is a pure function of this dictionary, so every decision has a unit test.
## Iteration is by unit name, never by node order, so two runs of the same seed decide identically.
##
##   {"tick", "team", "center", "heading", "leader", "members": [...], "contacts": [...],
##    "terrain": "open" | "lanes" | "dense", "threat": "none" | "possible" | "likely" | "contact",
##    "composition": "heavy" | "balanced" | "light" | "support", "strength", "enemy_strength",
##    "taking_fire": bool, "arrived": bool}
##
## members: {"name", "position", "forward", "role", "unit", "speed", "range", "sight", "health" (0..1),
##           "suppression" (0..1; combat's L2 when it lands, else recent hits), "taking_fire"}
## contacts: {"name", "position", "role", "unit", "visible", "age" (ticks since this element FIRST knew of it:
##           a small age means it appeared from nowhere, which is what makes an ambush an ambush), "distance"
##           (from the element's centre), "bearing_deg" (+ = right), "strength"}, nearest first.
## The situation also carries "known" (contact name -> the tick it was first seen), which the element stores
## and passes back in next time.

## A member hit within this many ticks counts as taking fire (1.5 s).
const FIRE_TICKS := SimClock.TICK_RATE * 3 / 2
## Threat bands, in meters from the element's centre.
const CONTACT_M := 75.0
const LIKELY_M := 130.0
const KNOWN_M := 190.0
## How far around the element terrain is judged, and how many cover features make it lanes / dense.
const TERRAIN_RADIUS := 45.0
const LANES_FEATURES := 2
const DENSE_FEATURES := 5
## Boxes this close (meters) are one piece of cover when terrain is judged.
const PIECE_GAP := 1.5
## Fallback suppression when combat's L2 field isn't in this build yet: a unit hit this recently reads as
## suppressed, fading to 0 over FIRE_TICKS.
const HIT_SUPPRESSION := 0.6


static func build(game_match: Match, team: int, member_names: PackedStringArray, leader: String,
		state: Dictionary = {}) -> Dictionary:
	var members: Array = []
	var center := Vector3.ZERO
	var heading: Vector3 = state.get("heading", Vector3.FORWARD)
	var strength := 0.0
	var taking_fire := false
	for unit_name in member_names:
		var tank := _tank(game_match, unit_name)
		if tank == null or not tank.is_alive():
			continue
		var hit_recently: bool = tank.ticks_since_hit < FIRE_TICKS
		taking_fire = taking_fire or hit_recently
		var hull := float(tank.health) / maxf(float(tank.max_health), 1.0)
		var shield := float(tank.shield) / maxf(float(tank.max_shield), 1.0) if tank.max_shield > 0.0 else 0.0
		members.append({"name": unit_name, "position": _flat(tank.global_position),
				"forward": TacticsFormation.flat(-tank.global_basis.z), "role": Units.role_of(tank.unit_id),
				"unit": tank.unit_id, "speed": tank.max_forward_speed, "range": float(tank.weapon.get("range", 60.0)),
				"sight": tank.sight_radius, "health": clampf((hull + shield) * 0.5 + hull * 0.5, 0.0, 1.0),
				"suppression": suppression_of(tank), "taking_fire": hit_recently})
		center += _flat(tank.global_position)
		strength += float(tank.health) + tank.shield
	if not members.is_empty():
		center /= float(members.size())
	if members.size() > 1:
		# The element's own facing: where its vehicles are pointed, averaged.
		var sum := Vector3.ZERO
		for member: Dictionary in members:
			sum += member["forward"]
		if sum.length_squared() > 1e-6:
			heading = TacticsFormation.flat(sum)

	var contacts: Array = []
	var enemy_strength := 0.0
	var tick: int = game_match.tick
	var was_known: Dictionary = state.get("known", {})
	var known := {}
	var intel: Dictionary = game_match.intel[team]
	for contact_name: String in intel:
		var contact: Dictionary = intel[contact_name]
		var position := _flat(contact["position"])
		var distance := center.distance_to(position)
		if distance > KNOWN_M:
			continue
		var first_seen: int = int(was_known.get(contact_name, tick))
		known[contact_name] = first_seen
		var contact_strength := float(contact.get("health", 0)) + float(contact.get("shield", 0))
		enemy_strength += contact_strength
		var velocity: Vector3 = contact.get("velocity", Vector3.ZERO)
		contacts.append({"name": contact_name, "position": position, "role": String(contact.get("role", "tank")),
				"unit": String(contact.get("unit", "")), "visible": bool(contact.get("visible", false)),
				"age": tick - first_seen, "distance": distance,
				"bearing_deg": bearing_deg(heading, position - center), "strength": contact_strength,
				"speed": Vector2(velocity.x, velocity.z).length()})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["distance"]) - float(b["distance"])) > 0.001:
			return float(a["distance"]) < float(b["distance"])
		return String(a["name"]) < String(b["name"]))

	return {"tick": tick, "team": team, "center": center, "heading": heading, "leader": leader,
			"members": members, "contacts": contacts, "known": known, "terrain": terrain_at(center),
			"threat": threat_from(contacts, taking_fire), "composition": composition_of(members),
			"strength": strength, "enemy_strength": enemy_strength, "taking_fire": taking_fire,
			"arrived": bool(state.get("arrived", false))}


## 0..1. Combat's L2 `Tank.suppression` when this build has it (CP2); until then, how recently the unit was hit.
static func suppression_of(tank: Tank) -> float:
	if "suppression" in tank:
		return clampf(float(tank.get("suppression")), 0.0, 1.0)
	if tank.ticks_since_hit >= FIRE_TICKS:
		return 0.0
	return HIT_SUPPRESSION * (1.0 - float(tank.ticks_since_hit) / float(FIRE_TICKS))


## Degrees from `heading` to `offset`, + to the right, in [-180, 180].
static func bearing_deg(heading: Vector3, offset: Vector3) -> float:
	var forward := TacticsFormation.flat(heading)
	var right := Vector3(-forward.z, 0.0, forward.x)
	var flat_offset := _flat(offset)
	if flat_offset.length_squared() < 1e-6:
		return 0.0
	return rad_to_deg(atan2(flat_offset.dot(right), flat_offset.dot(forward)))


## How much cover is around the element: how doctrine picks a formation and a spacing.
static func terrain_at(center: Vector3, features: Variant = null) -> String:
	var list: Array = features if features is Array else _arena_features()
	var near := 0
	for feature: Dictionary in list:
		# A piece of cover (touching boxes, round 5) is near when any of its boxes is.
		for position: Vector3 in feature.get("positions", [feature.get("position", Vector3.INF)]):
			if _flat(position).distance_to(_flat(center)) <= TERRAIN_RADIUS:
				near += 1
				break
	if near >= DENSE_FEATURES:
		return "dense"
	return "lanes" if near >= LANES_FEATURES else "open"


## "none" (nothing known), "possible" (something is out there), "likely" (we can see it and it is close),
## "contact" (we are being shot at, or the enemy is inside fighting range).
static func threat_from(contacts: Array, taking_fire: bool) -> String:
	if taking_fire:
		return "contact"
	var level := "none"
	for contact: Dictionary in contacts:
		var distance := float(contact["distance"])
		var visible := bool(contact["visible"])
		if visible and distance <= CONTACT_M:
			return "contact"
		if visible and distance <= LIKELY_M:
			level = "likely"
		elif level != "likely":
			level = "possible"
	return level


## What the element is made of, which decides how it moves: heavy (armour leads), light (fast, spreads),
## support (artillery or Lancers to protect), balanced.
static func composition_of(members: Array) -> String:
	var counts := {"heavy": 0, "light": 0, "support": 0}
	for member: Dictionary in members:
		match String(member["role"]):
			"tank", "burner":
				counts["heavy"] += 1
			"scout":
				counts["light"] += 1
			"artillery", "lancer":
				counts["support"] += 1
	var total := members.size()
	if total == 0:
		return "balanced"
	if counts["support"] * 2 >= total:
		return "support"
	if counts["light"] * 2 > total:
		return "light"
	if counts["heavy"] * 2 >= total:
		return "heavy"
	return "balanced"


## The live arena's cover as pieces, built once per layout (it is static for a match).
static func _arena_features() -> Array:
	var obstacles: Array = Arena.active.get("obstacles", [])
	var key := "%s|%d" % [Arena.active.get("name", ""), obstacles.size()]
	if key != _pieces_key:
		_pieces_key = key
		_pieces = cover_pieces(obstacles)
	return _pieces


static var _pieces_key := "-"
static var _pieces: Array = []


## Tests switch Arena.active between layouts with the same name and size: drop the cached pieces.
static func forget_terrain() -> void:
	_pieces_key = "-"


## Obstacles as pieces of cover, [{"positions": [Vector3 box centres]}] in layout order (round 5, arena's finding): boxes
## within PIECE_GAP of each other are one piece — a wall of containers is one thing to hide behind, not six — and low
## cover (below eye level, like a barricade) is not terrain at all, since it blocks neither sight nor fire.
static func cover_pieces(obstacles: Array) -> Array:
	var boxes: Array = []
	for obstacle: Dictionary in obstacles:
		var size := Arena.obstacle_size(obstacle)
		var type := String(obstacle.get("type", ""))
		var cover := ArenaKit.cover_of(type) if ArenaKit.is_kit(type) else ("hard" if size.y >= Perception.EYE_HEIGHT else "low")
		if cover != "hard":
			continue
		boxes.append({"center": Vector2(obstacle["position"][0], obstacle["position"][1]), "size": size,
				"rotation": float(obstacle.get("rotation_deg", 0.0))})
	# Union-find over touching pairs; each piece keeps its boxes in layout order.
	var parent: Array = range(boxes.size())
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if _box_gap(boxes[i], boxes[j]) <= PIECE_GAP:
				var a := _root(parent, i)
				var b := _root(parent, j)
				if a != b:
					parent[maxi(a, b)] = mini(a, b)
	var pieces: Array = []
	var index_of := {}
	for i in boxes.size():
		var root := _root(parent, i)
		if not index_of.has(root):
			index_of[root] = pieces.size()
			pieces.append({"positions": []})
		var center: Vector2 = boxes[i]["center"]
		(pieces[index_of[root]]["positions"] as Array).append(Vector3(center.x, 0.0, center.y))
	return pieces


static func _root(parent: Array, i: int) -> int:
	while int(parent[i]) != i:
		i = int(parent[i])
	return i


## The gap between two rotated rectangles (0 when they overlap): for convex shapes that don't overlap, the closest
## points include a corner of one of them.
static func _box_gap(a: Dictionary, b: Dictionary) -> float:
	var gap := INF
	for pair: Array in [[a, b], [b, a]]:
		var from: Dictionary = pair[0]
		var to: Dictionary = pair[1]
		for corner: Vector2 in _corners(from):
			gap = minf(gap, ArenaKit.distance_to_footprint(corner, to["center"], to["size"], to["rotation"]))
	if gap > 0.0 and ArenaKit.distance_to_footprint(a["center"], b["center"], b["size"], b["rotation"]) == 0.0:
		return 0.0
	return gap


static func _corners(box: Dictionary) -> Array:
	var angle := deg_to_rad(float(box["rotation"]))
	var size: Vector3 = box["size"]
	# ArenaKit's convention: local x maps to world (cos, -sin), local z to world (sin, cos).
	var along := Vector2(cos(angle), -sin(angle)) * (size.x / 2.0)
	var across := Vector2(sin(angle), cos(angle)) * (size.z / 2.0)
	var center: Vector2 = box["center"]
	return [center + along + across, center + along - across, center - along + across, center - along - across]


static func _tank(game_match: Match, unit_name: String) -> Tank:
	if game_match == null or game_match.tanks == null:
		return null
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
