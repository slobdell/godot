class_name BridgeStage
extends RefCounted
## Round 24 (brains R0/R1): HIS BRIDGE CASE, measured. "I told all my units to go and attack at the remote location
## across the bridge, and a whole bunch of them got stuck seemingly trying to drive through the river." (2026-10-08,
## the Locks, seed 15833; recording streams/references/round24/his/.) One squad on one bank of a map with water,
## an attack-move (an element task with drills ON, the path his attack-move takes) to a point on the far bank, and a
## few guns on the far bank that it meets on the way. Every tick, each crew is sampled against the arena's own water
## (`Arena.contains`: water and pits minus the bridge decks). Shared by tests/tactics/bridge_probe.gd (the series)
## and tests/test_tactics_bridge.gd.
##
## The report's fields (seconds from the order; -1 = never):
##   rim_s        per crew, the seconds it spent pressed at the water: within RIM_M of water, moved under STILL_MPS
##                metres over the last second, throttle on, held by the water's rim/pan (or by nothing, off a crossing); rim_total_s the sum, rim_crews how many crews spent >= RIM_STUCK_S there
##   deck_jam_s   the same, summed, where another HULL held it (or nothing, on a crossing): traffic, not the river
##   wet_hops     ticks a crew drove a straight-line (`direct`) move whose straight leg crosses water
##   crossed      crews that reached the far bank (past the water's far edge); crossed_s when the last one did
##   arrived_s    the element's arrival; alive the crews alive at the end

const RIM_M := 6.0
const STILL_MPS := 0.5
const RIM_STUCK_S := 3.0
const ROW_M := 8.0

## The stages (map, the squad's centre, the click, the guns' spots on the far bank). His Locks: the squad on the
## north quay (where his crews pressed), the click on the far quay, three lancers south of the canal.
const STAGES := {
	"locks": {"from": Vector3(-62.0, 0.0, 30.0), "to": Vector3(-59.0, 0.0, -55.0),
			"guns": [Vector3(-50.0, 0.0, -28.0), Vector3(-62.0, 0.0, -32.0), Vector3(-74.0, 0.0, -28.0)]},
	"locks_dry": {"from": Vector3(-62.0, 0.0, 30.0), "to": Vector3(-59.0, 0.0, -55.0),
			"guns": [Vector3(-50.0, 0.0, -28.0), Vector3(-62.0, 0.0, -32.0), Vector3(-74.0, 0.0, -28.0)]},
}


## Any other map with water or pits: across its first carving's middle, 30 m off each long side (the guns 12 m past the
## far side), so `make bridge-series BRIDGE_CASES=crossing,green,0` drives a squad over every wet map.
static func _derived(data: Dictionary) -> Dictionary:
	for entry: Dictionary in data.get("terrain", []):
		if not ArenaTerrain.carves(String(entry["kind"])):
			continue
		var box := ArenaTerrain.bounds(entry)
		var c := Vector3((box[0] + box[2]) / 2.0, 0.0, (box[1] + box[3]) / 2.0)
		var wide: bool = box[2] - box[0] >= box[3] - box[1]
		var n := Vector3(0.0, 0.0, 1.0) if wide else Vector3(1.0, 0.0, 0.0)
		var half := (box[3] - box[1]) / 2.0 if wide else (box[2] - box[0]) / 2.0
		# Toward the map's centre on the near side, so the squad starts inside the map's shape.
		if c.dot(n) < 0.0:
			n = -n
		var from := c + n * (half + 30.0)
		var to := c - n * (half + 30.0)
		var across := Vector3(n.z, 0.0, n.x)
		return {"from": from, "to": to, "guns": [to + n * 12.0, to + n * 12.0 + across * 10.0, to + n * 12.0 - across * 10.0]}
	return STAGES["locks"]


## `side` "green" puts his squad north and the guns south; "rust" mirrors both through the centre (the CPU's side,
## ordered the same way). `guns` 0 = no enemy (a plain crossing).
static func run(case: TestCase, seed_value: int, arena: String, unit_ids: PackedStringArray, side: String,
		guns: int, gun_id: String, seconds: float, trace := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena)
	var stage: Dictionary = STAGES[arena] if STAGES.has(arena) else _derived(Arena.active)
	var game_match := lab.game_match
	var mine := Match.Team.GREEN if side == "green" else Match.Team.RUST
	var theirs := Match.Team.RUST if side == "green" else Match.Team.GREEN
	game_match.set_meta("player_team", mine)
	var flip := 1.0 if side == "green" else -1.0
	var from: Vector3 = stage["from"] * flip
	var to: Vector3 = stage["to"] * flip
	var axis := (to - from).normalized()
	var right := Vector3(-axis.z, 0.0, axis.x)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	var prefix := "Green" if mine == Match.Team.GREEN else "Rust"
	for i in unit_ids.size():
		var at := from + right * ((i - (unit_ids.size() - 1) * 0.5) * ROW_M) \
				+ right * jitter.randf_range(-1.5, 1.5) + axis * jitter.randf_range(-1.5, 1.5)
		var yaw := atan2(-axis.x, -axis.z) + deg_to_rad(jitter.randf_range(-6.0, 6.0))
		names.append(String(lab.unit(mine, "%s_S_%d" % [prefix, i + 1], at, yaw, String(unit_ids[i])).name))
	var gun_names: Array = []
	var spots: Array = stage["guns"]
	for i in mini(guns, spots.size()):
		var spot: Vector3 = spots[i] * flip
		var face := (from - spot).normalized()
		gun_names.append(String(lab.gun(theirs, "%s_G_%d" % ["Rust" if theirs == Match.Team.RUST else "Green", i + 1],
				spot, atan2(-face.x, -face.z), gun_id).name))
	await lab.start()
	# Every hull stood where a hull can stand (the first version laid two crews inside the warehouse at (-30, 42); the
	# physics pushed them out DOWNWARD and they drove under the floor, into the water's pan).
	for unit_name: String in names + gun_names:
		var t := lab.tank_of(unit_name)
		var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
		t.global_position = Vector3(at.x, 0.0, at.z)
		t.velocity = Vector3.ZERO
	for i in 3:
		await lab.step()
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "move", "to": [to.x, to.z]})
	var water := _water_rows(Arena.active)
	var given: int = game_match.tick
	var rim_ticks := {}
	var trails := {}
	var deck_ticks := {}
	var wet_hops := 0
	var crossed := {}
	var crossed_at := -1
	var arrived := -1
	var ticks := int(seconds * SimClock.TICK_RATE)
	for tick in ticks:
		await lab.step()
		var now: int = game_match.tick - given
		if arrived < 0 and element.arrived:
			arrived = now
		for unit_name: String in names:
			var t := lab.tank_of(unit_name)
			if t == null or not t.is_alive():
				continue
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			if not crossed.has(unit_name) and _past_water(here, from, water):
				crossed[unit_name] = now
				crossed_at = now
			var mover := Movement.of(t)
			var order: Dictionary = mover.ctl.move_order if mover != null and "move_order" in mover.ctl else {}
			if bool(order.get("direct", false)):
				var hop := Vector3(float(order.get("x", here.x)), 0.0, float(order.get("z", here.z)))
				if _leg_wet(here, hop, water):
					wet_hops += 1
			var throttle := float(t.command.throttle) if t.command != null else 0.0
			# Pressed at the water: over the last second it moved under STILL_MPS (its own speed reading is the wheels',
			# which spin at full speed against a rim), throttle forward, within RIM_M of water.
			var trail: Array = trails.get_or_add(unit_name, [])
			trail.append(here)
			if trail.size() > SimClock.TICK_RATE:
				trail.pop_front()
			var crept := (trail[0] as Vector3).distance_to(here) if trail.size() >= SimClock.TICK_RATE else INF
			if crept < STILL_MPS and absf(throttle) > 0.2 and _near_water(here, RIM_M, water):
				# What holds it: the water's rim or pan (the bug), or another hull (traffic at the crossing).
				var held := _held_by(t)
				if held == "tank" or (held == "" and _at_a_crossing(here, RIM_M, water)):
					deck_ticks[unit_name] = int(deck_ticks.get(unit_name, 0)) + 1
				else:
					rim_ticks[unit_name] = int(rim_ticks.get(unit_name, 0)) + 1
			if trace and now % (SimClock.TICK_RATE / 2) == 0:
				var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
				print("BRIDGE_TRACK " + JSON.stringify({"t": _s(now), "n": unit_name,
						"at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)], "y": snappedf(t.global_position.y, 0.01),
						"v": snappedf(t.estimated_velocity.length(), 0.1), "thr": snappedf(throttle, 0.01),
						"order": {"type": order.get("type", ""), "x": snappedf(float(order.get("x", 0.0)), 0.1),
							"z": snappedf(float(order.get("z", 0.0)), 0.1), "direct": order.get("direct", false)},
						"why": brain.why if brain != null and "why" in brain else "",
						"phase": String(Movement.state(t).get("phase", "")),
						"yaw": snappedf(rad_to_deg(t.global_rotation.y), 1.0), "speed": snappedf(t.speed(), 0.1),
						"steer": _xz(Movement.state(t).get("steer_to")), "reach": Movement.state(t).get("reachable"),
						"path": Array((Movement.state(t).get("path_points", PackedVector3Array()) as PackedVector3Array).slice(0, 4)).map(BridgeStage._xz),
						"wedged": Movement.state(t).get("wedged"),
						"stalled": Movement.state(t).get("stalled_s"), "blocked": Movement.state(t).get("blocked_by"),
						"slot": _xz(element.slots.get(unit_name)), "drill": element.drill, "formation": element.formation,
						"anchor": _xz(element.anchor), "heading": _xz(element.heading),
						"k1": lab.orders.call("current", unit_name), "hits": _hits(t),
						"feed": _feed(brain), "task": element.task.get("verb", ""), "transit": element.in_transit(),
						"arrived": element.arrived, "repaired": Movement.state(t).get("repaired_m")}))
		if crossed.size() == names.size() and arrived >= 0:
			break
	var rim_s := {}
	var rim_total := 0
	var rim_crews := 0
	for unit_name: String in names:
		var n := int(rim_ticks.get(unit_name, 0))
		rim_s[unit_name] = _s(n)
		rim_total += n
		if n >= int(RIM_STUCK_S * SimClock.TICK_RATE):
			rim_crews += 1
	var deck_total := 0
	for unit_name: String in deck_ticks:
		deck_total += int(deck_ticks[unit_name])
	var report := {"deck_jam_s": _s(deck_total),"seed": seed_value, "arena": arena, "side": side, "units": ":".join(unit_ids), "guns": gun_names.size(),
			"gun_id": gun_id, "crews": names.size(), "rim_s": rim_s, "rim_total_s": _s(rim_total), "rim_crews": rim_crews,
			"wet_hops": wet_hops, "crossed": crossed.size(), "crossed_s": _s(crossed_at) if crossed.size() == names.size() else -1.0,
			"arrived_s": _s(arrived), "alive": lab.alive(names), "guns_alive": lab.alive(gun_names)}
	lab.dispose()
	return report


## The water's rectangles [min_x, min_z, max_x, max_z] and the decks', from the arena's own layout (Invariant 0).
static func _water_rows(data: Dictionary) -> Dictionary:
	var out := {"water": [], "decks": []}
	for entry: Dictionary in data.get("terrain", []):
		var box := ArenaTerrain.bounds(entry)
		if ArenaTerrain.carves(String(entry["kind"])):
			(out["water"] as Array).append(box)
		elif String(entry["kind"]) == "bridge":
			(out["decks"] as Array).append(box)
	return out


## A crew is past the water when the water lies between where it started and where it is now (some rectangle's
## band, across its narrow axis, separates the two). With no water at all (the dry map) the band is the wet map's.
static func _past_water(here: Vector3, start: Vector3, water: Dictionary) -> bool:
	var rows: Array = water["water"]
	if rows.is_empty():
		rows = [[-150.0, -7.0, 150.0, 7.0]]  # locks_dry: the canal's band, for the same question
	for box: Array in rows:
		var wide: bool = float(box[2]) - float(box[0]) >= float(box[3]) - float(box[1])
		if wide and ((start.z < float(box[1]) and here.z > float(box[3])) or (start.z > float(box[3]) and here.z < float(box[1]))):
			return true
		if not wide and ((start.x < float(box[0]) and here.x > float(box[2])) or (start.x > float(box[2]) and here.x < float(box[0]))):
			return true
	return false


static func _wet(p: Vector3, water: Dictionary) -> bool:
	for box: Array in water["water"]:
		if p.x > float(box[0]) and p.x < float(box[2]) and p.z > float(box[1]) and p.z < float(box[3]):
			for deck: Array in water["decks"]:
				if p.x > float(deck[0]) and p.x < float(deck[2]) and p.z > float(deck[1]) and p.z < float(deck[3]):
					return false
			return true
	return false


## "terrain" when the hull touched the water's rim, pan or a deck rail in its last slide, "tank" when only hulls, "" when
## nothing.
static func _held_by(t: Tank) -> String:
	var held := ""
	for i in t.get_slide_collision_count():
		var who := t.get_slide_collision(i).get_collider() as Node
		if who == null:
			continue
		if String(who.name).begins_with("Terrain"):
			return "terrain"
		if who is Tank:
			held = "tank"
	return held


## On a bridge deck or in its mouth (the deck's rectangle grown by `reach`): a crew held there is in the crossing's
## traffic, not pressing into the water.
static func _at_a_crossing(here: Vector3, reach: float, water: Dictionary) -> bool:
	for deck: Array in water["decks"]:
		if here.x > float(deck[0]) - reach and here.x < float(deck[2]) + reach \
				and here.z > float(deck[1]) - reach and here.z < float(deck[3]) + reach:
			return true
	return false


static func _near_water(here: Vector3, reach: float, water: Dictionary) -> bool:
	for dx: float in [-reach, 0.0, reach]:
		for dz: float in [-reach, 0.0, reach]:
			if _wet(here + Vector3(dx, 0.0, dz), water):
				return true
	return false


## The straight leg from `a` to `b` crosses water (sampled every metre).
static func _leg_wet(a: Vector3, b: Vector3, water: Dictionary) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in steps + 1:
		if _wet(a.lerp(b, float(i) / steps), water):
			return true
	return false


## What the hull touched in its last move_and_slide: [collider path, point x, z, normal x, z].
static func _hits(t: Tank) -> Array:
	var out: Array = []
	for i in t.get_slide_collision_count():
		var hit := t.get_slide_collision(i)
		var who := hit.get_collider() as Node
		var shape := hit.get_collider_shape() as Node
		out.append([String(who.name) if who != null else "?", String(shape.name) if shape != null else "?",
				snappedf(hit.get_position().x, 0.1), snappedf(hit.get_position().y, 0.01), snappedf(hit.get_position().z, 0.1),
				snappedf(hit.get_normal().x, 0.01), snappedf(hit.get_normal().y, 0.01), snappedf(hit.get_normal().z, 0.01)])
	return out


## The element's word to this crew as its brain last read it (role, station, task), for the trace.
static func _feed(brain: TankBrain) -> Variant:
	if brain == null or not ("element" in brain) or not (brain.element is Dictionary):
		return null
	var out := {}
	for key: String in ["role", "task", "station", "pace", "firing_base", "drill", "hold"]:
		if (brain.element as Dictionary).has(key):
			var v: Variant = brain.element[key]
			out[key] = _xz(v) if v is Vector3 else v
	return out


static func _xz(v: Variant) -> Variant:
	return [snappedf((v as Vector3).x, 0.1), snappedf((v as Vector3).z, 0.1)] if v is Vector3 else null


static func _s(ticks: int) -> float:
	return snappedf(ticks / float(SimClock.TICK_RATE), 0.1) if ticks >= 0 else -1.0
