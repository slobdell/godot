extends "res://tests/orders_probe.gd"
## Round 41 (orders O1), measurement only: his group order. "When I'm controlling a large set of squads at once and commanding
## all of them to go somewhere, a bunch of units block other units ... a scout is pointed north and thus blocking a unit
## that's trying to go West." The orders probe (unchanged) with every squad's crews turned to mixed headings just before he
## selects them all and clicks once, as they stand after a fight, and a start census:
##   `--probe-headings=crew` (default) every crew a seeded random heading; `squad` one per squad; `formed` untouched.
## Per crew, once its own route exists (within FIRST_PATH_S of the click):
##   nose_off_deg   the angle between its hull's facing at the click and its route's first leg (the first corner
##                  NOSE_LEG_M or more away); > 90 deg = it starts pointed away from where it must go
##   first leg      its route's first FIRST_LEG_M, as a polyline
## Per run: `crossing_pairs` crew pairs of DIFFERENT squads whose first legs cross at more than CROSS_DEG (merging onto
## one road is not a crossing), `squads_crossing` squads with any such crew, and every second a crew under way (its
## squad not in, its own drive not arrived) spends `blocked` (Movement.phase blocked, by a friend), `yielding`, or `slow`
## (any other under-way tick below SLOW_MPS; its own turn on the spot counts here). ORDERS_GROUP_CREW {...} a crew; the
## census also rides on the ORDERS_PROBE line (`group`). Run with `make orders-group` (mk/command.mk).

const FIRST_PATH_S := 3.0
const NOSE_LEG_M := 4.0
const FIRST_LEG_M := 40.0
const CROSS_DEG := 30.0
const SLOW_MPS := 1.0

var _heading_at := {}  # crew -> its hull's flat facing at the click
var _start_at := {}  # crew -> where it stood at the click
var _crew_squad := {}  # crew -> squad number
var _crew := {}  # crew -> {nose_off_deg, leg: PackedVector2Array, blocked, yielding, slow (ticks)}


## `--probe-target=across` (default): his order across the map, to the point opposite his army through the arena's middle,
## halfway to the far edge (`ACROSS_SHARE` of the way), on ground his first crew can stand on; `deck` is the base probe's click.
const ACROSS_SHARE := 0.5


func _pick_click(map: String, army: Vector3, forward: Vector3) -> Vector3:
	if _flag("probe-target", "across") != "across" or _flag("probe-click", "") != "":
		return super(map, army, forward)
	var ground: Tank = null
	for squad: Dictionary in _squads:
		ground = _tank(String(squad["units"][0]))
		if ground != null:
			break
	var across := Orders.clamp_to_arena(Vector3(-army.x, 0.0, -army.z) * ACROSS_SHARE)
	if ground != null:
		across = SlotGround.standable(ground, across)
	return _jitter(Vector3(across.x, 0.0, across.z))


func _before_order(units: Array) -> void:
	var mode := _flag("probe-headings", "crew")
	if mode == "formed":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_flag("seed", "34")) * 7919 + 41
	for squad: Dictionary in _squads:
		var squad_yaw := rng.randf() * TAU
		for n: String in squad["units"]:
			var t := _tank(n)
			if t == null:
				continue
			t.rotation.y = rng.randf() * TAU if mode == "crew" else squad_yaw


func _after_order(units: Array) -> void:
	for squad: Dictionary in _squads:
		for n: String in squad["units"]:
			var t := _tank(n)
			if t == null:
				continue
			var facing := -t.global_basis.z
			_heading_at[n] = Vector2(facing.x, facing.z).normalized()
			_start_at[n] = Vector2(t.global_position.x, t.global_position.z)
			_crew_squad[n] = int(squad["number"])
			_crew[n] = {"nose_off_deg": -1.0, "leg": PackedVector2Array(), "blocked": 0, "yielding": 0, "slow": 0, "turn_s": -1.0}


func _watch_extra() -> void:
	var since := _match.tick - _order_tick
	for squad: Dictionary in _squads:
		var squad_in := int(squad["arrived_tick"]) >= 0
		for n: String in squad["units"]:
			var t := _tank(n)
			if t == null or not t.is_alive() or not _crew.has(n):
				continue
			var row: Dictionary = _crew[n]
			var mover := Movement.of(t)
			if mover == null:
				continue
			if float(row["nose_off_deg"]) < 0.0 and since <= int(FIRST_PATH_S * SimClock.TICK_RATE):
				_read_first_leg(n, mover, row)
			var facing := -t.global_basis.z
			var leg := row["leg"] as PackedVector2Array
			# Turned toward its first leg: the first tick its hull is within 30 deg of it (how long its turn took).
			if float(row["turn_s"]) < 0.0 and leg.size() >= 2:
				var want := (leg[1] - leg[0]).normalized()
				if want != Vector2.ZERO and absf(rad_to_deg(Vector2(facing.x, facing.z).normalized().angle_to(want))) <= 30.0:
					row["turn_s"] = snappedf(since / float(SimClock.TICK_RATE), 0.1)
			if squad_in or since < 2 or mover.phase == "arrived":
				continue
			if mover.phase == "blocked" and _tank(mover.blocked_by) != null:
				row["blocked"] = int(row["blocked"]) + 1
			elif mover.phase == "yielding":
				row["yielding"] = int(row["yielding"]) + 1
			elif Vector2(t.velocity.x, t.velocity.z).length() < SLOW_MPS:
				row["slow"] = int(row["slow"]) + 1


## Its own route as Movement planned it (the corners from where it stands); its first leg is the first corner NOSE_LEG_M away.
func _read_first_leg(n: String, mover: Movement, row: Dictionary) -> void:
	var path: PackedVector3Array = mover.get("_path")
	var index := int(mover.get("_path_index"))
	if path.is_empty() or index >= path.size():
		return
	var from: Vector2 = _start_at[n]
	var points := PackedVector2Array([from])
	var left := FIRST_LEG_M
	var at := from
	for i in range(index, path.size()):
		var p := Vector2(path[i].x, path[i].z)
		var step := at.distance_to(p)
		if step < 0.01:
			continue
		if step >= left:
			points.append(at + (p - at) * (left / step))
			break
		points.append(p)
		left -= step
		at = p
	var first := Vector2.INF
	for p: Vector2 in points:
		if from.distance_to(p) >= NOSE_LEG_M:
			first = p
			break
	if first == Vector2.INF:
		return
	row["leg"] = points
	row["nose_off_deg"] = snappedf(absf(rad_to_deg((_heading_at[n] as Vector2).angle_to(first - from))), 0.1)


func _run_extra() -> Dictionary:
	var names: Array = _crew.keys()
	names.sort()
	var pairs := 0
	var squads_crossing := {}
	var squad_pairs := {}
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			if _crew_squad[a] == _crew_squad[b]:
				continue
			if _legs_cross(_crew[a]["leg"], _crew[b]["leg"]):
				pairs += 1
				squads_crossing[_crew_squad[a]] = true
				squads_crossing[_crew_squad[b]] = true
				squad_pairs["%d-%d" % [mini(_crew_squad[a], _crew_squad[b]), maxi(_crew_squad[a], _crew_squad[b])]] = true
	var tick_s := 1.0 / float(SimClock.TICK_RATE)
	var nose_away := 0
	var read := 0
	var blocked := 0
	var yielding := 0
	var slow := 0
	var turn_worst := 0.0
	for n: String in names:
		var row: Dictionary = _crew[n]
		if float(row["nose_off_deg"]) >= 0.0:
			read += 1
			if float(row["nose_off_deg"]) > 90.0:
				nose_away += 1
		blocked += int(row["blocked"])
		yielding += int(row["yielding"])
		slow += int(row["slow"])
		turn_worst = maxf(turn_worst, float(row["turn_s"]))
		print("ORDERS_GROUP_CREW " + JSON.stringify({"map": _flag("arena", "locks"), "seed": int(_flag("seed", "34")),
				"arm": _flag("probe-arm", ""), "crew": n, "squad": _crew_squad[n], "unit": _tank(n).unit_id if _tank(n) != null else "",
				"nose_off_deg": row["nose_off_deg"], "turn_s": row["turn_s"],
				"blocked_s": snappedf(int(row["blocked"]) * tick_s, 0.1), "yielding_s": snappedf(int(row["yielding"]) * tick_s, 0.1),
				"slow_s": snappedf(int(row["slow"]) * tick_s, 0.1)}))
	var keys: Array = squad_pairs.keys()
	keys.sort()
	return {"group": {"headings": _flag("probe-headings", "crew"), "crews": names.size(), "nose_read": read,
			"nose_away": nose_away, "crossing_pairs": pairs, "squads_crossing": squads_crossing.size(), "squad_pairs": keys,
			"blocked_s": snappedf(blocked * tick_s, 0.1), "yielding_s": snappedf(yielding * tick_s, 0.1),
			"slow_s": snappedf(slow * tick_s, 0.1), "turn_worst_s": turn_worst}}


## Two first legs cross: some segment of each intersects the other's at more than CROSS_DEG (shared roads merge, not cross).
static func _legs_cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in range(a.size() - 1):
		for j in range(b.size() - 1):
			var da := a[i + 1] - a[i]
			var db := b[j + 1] - b[j]
			if da.length() < 0.01 or db.length() < 0.01:
				continue
			var angle := absf(rad_to_deg(da.angle_to(db)))
			if angle < CROSS_DEG or angle > 180.0 - CROSS_DEG:
				continue
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1]) != null:
				return true
	return false
