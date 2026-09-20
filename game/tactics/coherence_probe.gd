class_name CoherenceProbe
extends Node
## Round 6, squad X6: "even smarter than StarCraft 2" as numbers instead of a mood. The lead's bar is legibility — a unit
## must look like it knows what it is doing — and each number below is one way a unit visibly does not:
##
##   idle_in_contact_s      standing still, not shooting, with a known enemy inside its weapon's reach
##   drill_switches_per_element_min   an element flip-flopping between drills
##   orders_per_unit_min    orders issued to a unit (thrash: every one resets what its brain was doing)
##   off_slot_s             an element member more than 2 x spacing from the slot its leader gave it
##   stale_order_s          a unit still carrying a move/attack/follow order issued more than 30 s ago
##
## Unit-seconds are also given per unit-minute alive (`*_share`), so a long match and a short one compare. Bookkeeping
## only: it reads the match every SAMPLE_TICKS and listens to K1/K2 signals; it never changes the fight.
##
##   SQUAD_COHERENCE {"sim_seconds", "green": {...}, "rust": {...}}

const SAMPLE_TICKS := SimClock.TICK_RATE / 2
## Standing still means slower than this (m/s).
const STILL_MPS := 0.5
## Not shooting means no shot for this long (seconds).
const QUIET_S := 2.0
## "In contact": a visible enemy within this multiple of the unit's weapon range.
const CONTACT_REACH := 1.2
## Off its slot means further than this many doctrine spacings from it. Round 9 (X1) deliberately kept measuring in
## the DOCTRINE's spacing rather than the hull-floored pitch the slots are now laid at, so every off-slot number
## from round 8 onwards stays comparable; `slot_pitch_m` in the report is the pitch that was actually used, per
## side, so a divergence between the two is visible rather than silent.
const OFF_SLOT_SPACINGS := 2.0
## An order older than this (seconds) that is still running is stale. Hold never completes on purpose: not counted.
const STALE_S := 30.0
const STALE_VERBS := ["move", "attack_move", "attack", "follow"]

var game_match: Match
var _last_fire := {}
var _sides: Array = []
var _last_drill := {}


static func attach(p_match: Match) -> CoherenceProbe:
	var probe := CoherenceProbe.new()
	probe.name = "CoherenceProbe"
	probe.game_match = p_match
	p_match.weapon_fired.connect(probe._on_fired)
	p_match.finished.connect(probe._on_finished)
	p_match.add_child(probe)
	return probe


func _ready() -> void:
	process_physics_priority = Elements.PRIORITY + 1
	for team in 2:
		_sides.append({"unit_seconds": 0.0, "idle_in_contact_s": 0.0, "off_slot_s": 0.0, "stale_order_s": 0.0,
				"orders": 0, "drill_switches": 0, "element_seconds": 0.0, "transitions": {}, "orders_by": {},
				"pitch_across_m": 0.0, "pitch_along_m": 0.0, "doctrine_spacing_m": 0.0,
				"goal_moves": {"task": 0, "leg": 0, "reseat": 0, "drift": 0}, "following_peak": 0})


func _physics_process(_delta: float) -> void:
	if game_match == null:
		return
	var orders := Orders.of(game_match)
	if orders != null and not orders.issued.is_connected(_on_issued):
		orders.issued.connect(_on_issued)
	if game_match.tick % SAMPLE_TICKS != 0:
		return
	var dt := SAMPLE_TICKS / float(SimClock.TICK_RATE)
	var elements := Elements.of_match(game_match)
	for team in 2:
		var side: Dictionary = _sides[team]
		for tank: Tank in game_match.sorted_team_tanks(team):
			if not tank.is_alive():
				continue
			var unit_name := String(tank.name)
			side["unit_seconds"] += dt
			if _idle_in_contact(tank):
				side["idle_in_contact_s"] += dt
			var element: Element = elements.of(unit_name) if elements != null else null
			if element != null and not element.is_detached(unit_name) and element.slots.get(unit_name) is Vector3:
				var spacing := element.table.spacing("open") if element.table != null else TacticsFormation.DEFAULT_SPACING
				# The widest pitch any element on this side laid its slots at (X1), reported beside the threshold.
				side["doctrine_spacing_m"] = maxf(float(side["doctrine_spacing_m"]), spacing)
				side["pitch_across_m"] = maxf(float(side["pitch_across_m"]), element.pitch.x)
				side["pitch_along_m"] = maxf(float(side["pitch_along_m"]), element.pitch.y)
				var slot: Vector3 = element.slots[unit_name]
				if Vector2(tank.global_position.x - slot.x, tank.global_position.z - slot.z).length() > spacing * OFF_SLOT_SPACINGS:
					side["off_slot_s"] += dt
			if orders != null:
				var current := orders.current(unit_name)
				if STALE_VERBS.has(String(current.get("verb", ""))) \
						and game_match.tick - int(current.get("issued_tick", game_match.tick)) > STALE_S * SimClock.TICK_RATE:
					side["stale_order_s"] += dt
	if elements != null:
		# Each element's `goal_moves` is CUMULATIVE, so the side's total is recomputed from scratch on every sample
		# rather than accumulated -- accumulating a running total every half second would multiply it by the sample
		# count. A dead element's contribution is lost with it, which is the honest answer: the counter belongs to the
		# element and the element is gone.
		for team in 2:
			for reason: String in (_sides[team]["goal_moves"] as Dictionary):
				(_sides[team]["goal_moves"] as Dictionary)[reason] = 0
		for element: Element in elements.all():
			if element.members().is_empty():
				continue
			var side: Dictionary = _sides[element.team]
			side["element_seconds"] += dt
			for reason: String in element.goal_moves:
				(side["goal_moves"] as Dictionary)[reason] = int((side["goal_moves"] as Dictionary)[reason]) \
						+ int(element.goal_moves[reason])
			side["following_peak"] = maxi(int(side["following_peak"]), element.following)
			var before: String = _last_drill.get(element.id, "")
			if element.drill != before:
				if before != "" or element.drill != "":
					side["drill_switches"] += 1
					var key := "%s>%s" % [before if before != "" else "-", element.drill if element.drill != "" else "-"]
					side["transitions"][key] = int(side["transitions"].get(key, 0)) + 1
				_last_drill[element.id] = element.drill


func _idle_in_contact(tank: Tank) -> bool:
	if tank.estimated_velocity.length() >= STILL_MPS:
		return false
	if game_match.tick - int(_last_fire.get(String(tank.name), -1_000_000)) < QUIET_S * SimClock.TICK_RATE:
		return false
	var reach := float(tank.weapon.get("range", 60.0)) * CONTACT_REACH
	var known: Dictionary = game_match.intel[tank.team]
	for contact_name: String in known:
		var contact: Dictionary = known[contact_name]
		if bool(contact.get("visible", false)) and (contact["position"] as Vector3).distance_to(tank.global_position) <= reach:
			return true
	return false


func _on_fired(event: Dictionary) -> void:
	_last_fire[String(event.get("shooter", ""))] = int(event.get("tick", game_match.tick))


func _on_issued(command: Dictionary) -> void:
	var tanks := AiTickCache.tanks_by_name(game_match)
	for unit: Variant in command.get("units", []):
		var tank := tanks.get(String(unit)) as Tank
		if tank != null:
			_sides[tank.team]["orders"] += 1
			var key := "%s/%s" % [String(command.get("verb", "")), String(command.get("source", ""))]
			_sides[tank.team]["orders_by"][key] = int(_sides[tank.team]["orders_by"].get(key, 0)) + 1


func report() -> Dictionary:
	var result := {"sim_seconds": snappedf(game_match.tick / float(SimClock.TICK_RATE), 0.1)}
	for team in 2:
		var side: Dictionary = _sides[team]
		var unit_minutes := maxf(float(side["unit_seconds"]) / 60.0, 1e-6)
		var element_minutes := float(side["element_seconds"]) / 60.0
		result[["green", "rust"][team]] = {
			"unit_minutes": snappedf(unit_minutes, 0.01),
			"idle_in_contact_s": snappedf(side["idle_in_contact_s"], 0.1),
			"idle_in_contact_share": snappedf(float(side["idle_in_contact_s"]) / 60.0 / unit_minutes, 0.001),
			"off_slot_s": snappedf(side["off_slot_s"], 0.1),
			"off_slot_share": snappedf(float(side["off_slot_s"]) / 60.0 / unit_minutes, 0.001),
			# X1: the threshold above is OFF_SLOT_SPACINGS x doctrine_spacing_m; slot_pitch_m is what the slots were
			# really laid at (across, along). They part company as soon as a squad's hulls need more room.
			"doctrine_spacing_m": snappedf(side["doctrine_spacing_m"], 0.01),
			"slot_pitch_m": [snappedf(side["pitch_across_m"], 0.01), snappedf(side["pitch_along_m"], 0.01)],
			"stale_order_s": snappedf(side["stale_order_s"], 0.1),
			"stale_order_share": snappedf(float(side["stale_order_s"]) / 60.0 / unit_minutes, 0.001),
			"orders_per_unit_min": snappedf(float(side["orders"]) / unit_minutes, 0.01),
			"element_minutes": snappedf(element_minutes, 0.01),
			"drill_switches_per_element_min": snappedf(float(side["drill_switches"]) / element_minutes, 0.01) \
					if element_minutes > 0.0 else 0.0,
			# Attribution: which drill changes and which orders (verb/source) make up those rates.
			"top_transitions": CoherenceProbe.top(side["transitions"], 8), "top_orders": CoherenceProbe.top(side["orders_by"], 8),
			# For nav (round 9): WHY the goals of element orders moved, summed over the side's elements. nav measured
			# its own repath cadence at ~3% of re-planning in a fight and the rest as "the goal moved" events, and
			# from its side of the seam a changed order and a jittering slot are one number. Here they are four, and
			# `following` counts the members whose goal slides with their leader every tick BY DESIGN (round 7 flow).
			"goal_moves": side["goal_moves"].duplicate(), "following_peak": int(side["following_peak"])}
	return result


## The `count` biggest entries of a {key: int} tally, as [[key, n], ...], biggest first (ties by key).
static func top(tally: Dictionary, count: int) -> Array:
	var keys: Array = tally.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(tally[a]) > int(tally[b]) or (int(tally[a]) == int(tally[b]) and a < b))
	return keys.slice(0, count).map(func(key: String) -> Array: return [key, int(tally[key])])


func _on_finished(_result: Dictionary) -> void:
	print("SQUAD_COHERENCE " + JSON.stringify(report()))
