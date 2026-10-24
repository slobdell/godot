extends "res://tests/orders_probe.gd"
## Round 39 (manoeuvre, M1's G5 fail), measurement only: orders' multi-squad probe (tests/orders_probe.gd, unchanged) with
## wedge_trace's partner read on every crew still under way. A crew is STILL on a tick when it is under way and moved less
## than WEDGE_STILL_M over the last second. On each still tick its partner (the friendly hull it touches, else the nearest friend
## within WEDGE_PARTNER_M inside WEDGE_PARTNER_DEG of its travel, as wedge_trace.gd) is classed "<state>/<way>/<seat>":
##   state  parked / yielding / slow (pace < 0.5) / driving (wedge_trace's)
##   way    same / head_on / cross / none (the two travel directions)
##   seat   home (partner within SEAT_OFF_M of its seat: Movement.yield_seat) / off (farther; under way and not yielding = driving
##          BACK to it: settle's S1 drive-back)
## At quit, one PROBE_WEDGE row per crew with still ticks: crew, squad, its partners (class -> ticks), the top partner and its
## squad, and the run's give-way counters (chain_refusals, parked_refusals, yields_started).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/probe_wedge.gd -- --arena=terminus --seed=6117 \
##     --probe-squads=5 --probe-route=route --probe-arm=chain --giveway-chain

const WEDGE_STILL_M := 0.3
const WEDGE_PARTNER_M := 8.0
const WEDGE_PARTNER_DEG := 60.0
const SEAT_OFF_M := 8.0

var _hist := {}  # crew -> ring of positions, one a tick, the last second
var _still := {}  # crew -> {class: ticks}
var _mates := {}  # crew -> {partner: ticks}
var _last_tick := -1


func _initialize() -> void:
	super()
	_trace.call_deferred()


func _trace() -> void:
	while true:
		await physics_frame
		if _match == null or not is_instance_valid(_match) or _squads.is_empty() or _order_tick <= 0:
			continue
		if _match.tick == _last_tick:
			continue
		_last_tick = _match.tick
		_observe()


func _squad_of(crew: String) -> int:
	for squad: Dictionary in _squads:
		if (squad["units"] as Array).has(crew):
			return int(squad["number"])
	return 0


func _observe() -> void:
	var alive: Array[Tank] = []
	for node in _match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == Match.Team.GREEN:
			alive.append(tank)
	var travel := {}
	for tank in alive:
		var mover := Movement.of(tank)
		var way := Vector2.ZERO
		if mover != null and mover.is_under_way() and mover._goal != Vector3.INF:
			way = mover._travel_direction(mover._goal, false)
		travel[String(tank.name)] = way
	for tank in alive:
		var crew := String(tank.name)
		var ring: Array = _hist.get_or_add(crew, [])
		ring.append(tank.global_position)
		if ring.size() > SimClock.TICK_RATE:
			ring.pop_front()
		var mover := Movement.of(tank)
		if mover == null or not mover.is_under_way() or ring.size() < SimClock.TICK_RATE:
			continue
		var moved := Vector2(ring[-1].x - ring[0].x, ring[-1].z - ring[0].z).length()
		if moved >= WEDGE_STILL_M:
			continue
		var mate := ""
		for i in tank.get_slide_collision_count():
			var hit := tank.get_slide_collision(i).get_collider() as Tank
			if hit != null and hit.team == tank.team:
				mate = String(hit.name)
				break
		if mate == "":
			var best := WEDGE_PARTNER_M
			var way: Vector2 = travel[crew]
			for other in alive:
				if other == tank:
					continue
				var off := Vector2(other.global_position.x - tank.global_position.x, other.global_position.z - tank.global_position.z)
				var d := off.length()
				if d >= best or d < 0.01:
					continue
				if way != Vector2.ZERO and absf(rad_to_deg(way.angle_to(off))) > WEDGE_PARTNER_DEG:
					continue
				best = d
				mate = String(other.name)
		var label := "none"
		if mate != "":
			var other := _match.tanks.get_node_or_null(NodePath(mate)) as Tank
			var om := Movement.of(other) if other != null else null
			if om == null:
				label = "player_or_gone"
			else:
				var state := "driving"
				if not om.is_under_way():
					state = "parked"
				elif om.yield_to != "":
					state = "yielding"
				elif om.pace_now < 0.5:
					state = "slow"
				var a: Vector2 = travel.get(crew, Vector2.ZERO)
				var b: Vector2 = travel.get(mate, Vector2.ZERO)
				var rel := "none"
				if a != Vector2.ZERO and b != Vector2.ZERO:
					var dot := a.dot(b)
					rel = "same" if dot > 0.5 else ("head_on" if dot < -0.5 else "cross")
				var seat := om.yield_seat()
				var home := "home"
				if seat.is_finite() and Vector2(seat.x - other.global_position.x, seat.z - other.global_position.z).length() > SEAT_OFF_M:
					home = "off"
				label = "%s/%s/%s" % [state, rel, home]
		var counts: Dictionary = _still.get_or_add(crew, {})
		counts[label] = int(counts.get(label, 0)) + 1
		if mate != "":
			var by: Dictionary = _mates.get_or_add(crew, {})
			by[mate] = int(by.get(mate, 0)) + 1


func _finalize() -> void:
	for crew: String in _still:
		var by: Dictionary = _mates.get(crew, {})
		var top := ""
		for m: String in by:
			if top == "" or int(by[m]) > int(by[top]):
				top = m
		print("PROBE_WEDGE " + JSON.stringify({"crew": crew, "squad": _squad_of(crew), "still_ticks": _sum(_still[crew]),
				"partners": _still[crew], "partner_top": top, "partner_top_squad": _squad_of(top),
				"partner_top_ticks": int(by.get(top, 0)), "seed": int(_flag("seed", "0")), "arena": _flag("arena", ""),
				"arm": _flag("probe-arm", ""), "chain_refusals": Movement.chain_refusals,
				"parked_refusals": Movement.parked_refusals, "yields_started": Movement.yields_started}))


static func _sum(counts: Dictionary) -> int:
	var total := 0
	for k: String in counts:
		total += int(counts[k])
	return total
