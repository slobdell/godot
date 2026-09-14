class_name TankBrain
extends OrderController
## An autonomous tank: it senses through its team's shared intel, scores every
## option with its directives ("weights in a tree"), commits to the best, and
## turns that into standing orders that OrderController executes.
##
## DETERMINISM (see _agents/tank_brain.md "Determinism contract"):
##   - thinks on physics ticks (Match.tick), staggered by think_offset: never wall-clock
##   - build_situation() is the only impure step (physics queries); everything in it
##     is ordered by tank name
##   - decide(situation, current) is a pure static function: same input → same output
##   - ties go to the earlier option in OPTIONS order, then earlier target name

const THINK_EVERY_TICKS := 6
## The current choice gets this multiplier, so near-equal options don't flip-flop...
const COMMIT_BONUS := 1.15
## ...and it's kept at least this long unless something is EMERGENCY_MARGIN× better.
const MIN_COMMIT_TICKS := 45
const EMERGENCY_MARGIN := 1.6
## Contacts older than this are investigated rather than engaged.
const CONTACT_FRESH_TICKS := 120
const COVER_RING_RADIUS := 10.0
const COVER_SAMPLES := 8
const ARENA_LIMIT := Match.DRIVABLE_LIMIT
const OPTIONS := ["RETREAT", "TAKE_COVER", "ENGAGE", "FLANK", "INVESTIGATE", "REGROUP", "ADVANCE", "KEEP_SLOT", "HOLD"]
## Within this distance of its formation slot a tank counts as "in position".
const SLOT_TOLERANCE := 4.0
## KEEP_SLOT's score under move/bound/hold orders (see decide()).
const ORDER_WEIGHT := 0.95
## Under orders (not assault), RETREAT only below this health fraction, scaled by caution.
const CRITICAL_HP_MIN := 0.08
const CRITICAL_HP_MAX := 0.25
## A remembered contact's position is extrapolated along its last velocity for at most this long.
const WATCH_PREDICT_SECONDS := 1.5

var game_match: Match
## Fully resolved directives (Directives.resolve).
var directives: Dictionary = Directives.DEFAULTS.duplicate(true)
var squad_name := ""
var think_offset := 0
## {"option": String, "target": String, "since": int}; empty before the first think.
var choice := {}
## Top scored options from the last think: [{"option", "target", "score"}], best first.
var ranked: Array = []
## The squad order_serial this brain last acted on.
var _order_serial := 0


func think(_delta: float) -> void:
	if game_match == null or tank == null:
		return
	if not tank.is_alive():
		choice = {}
		tank.intent = ""
		return
	# A new squad order is thought about on the very next tick and breaks commitment (G3).
	var squad := game_match.squad_for(tank)
	var serial := squad.order_serial if squad != null else 0
	var fresh_order := serial != _order_serial
	_order_serial = serial
	if not fresh_order and (game_match.tick + think_offset) % THINK_EVERY_TICKS != 0:
		return
	var situation := build_situation()
	var decision := TankBrain.decide(situation, {} if fresh_order else choice)
	ranked = decision["ranked"]
	var best: Dictionary = decision["choice"]
	var same: bool = best["option"] == choice.get("option") and best["target"] == choice.get("target")
	best["since"] = choice["since"] if same else game_match.tick
	choice = best
	_act(situation)
	watch_point = TankBrain.watch_for(situation, choice)
	tank.intent = TankBrain.label(choice)


static func label(option: Dictionary) -> String:
	if option.is_empty():
		return ""
	return option["option"] + ("" if option["target"] == "" else " " + option["target"])


# ---- The pure part ----------------------------------------------------------------

static func decide(s: Dictionary, current: Dictionary) -> Dictionary:
	var me: Dictionary = s["self"]
	var d: Dictionary = s["directives"]
	var weapon: Dictionary = me["weapon"]
	var hp := float(me["health"]) / float(me["max_health"])
	var confidence := lerpf(0.35, 1.0, hp)
	var contacts: Array = s["contacts"]
	var objective: Variant = s["objective"]
	var leash := float(d["leash"])
	var my_position: Vector3 = me["position"]
	## Squad orders (tactical map): null when this tank's squad has no drill.
	var squad: Variant = s.get("squad")
	var commanded: bool = squad != null and squad["slot"] != null

	var visible_threats := 0
	var threats_on_me := 0
	for c in contacts:
		if c["visible"]:
			visible_threats += 1
			if c["aiming_at_me"]:
				threats_on_me += 1

	var candidates: Array = []
	var add := func(option: String, target: String, score: float) -> void:
		candidates.append({"option": option, "target": target, "score": score})

	# RETREAT: hurt past the caution-derived threshold with enemies in sight, or badly outnumbered.
	var retreat_threshold := lerpf(0.15, 0.55, float(d["caution"]))
	var retreat := 0.0
	if commanded and String(squad["verb"]) != "assault":
		# Player intent dominates (G3): a tank under orders only saves itself when it's about to die.
		if hp < lerpf(CRITICAL_HP_MIN, CRITICAL_HP_MAX, float(d["caution"])) and visible_threats > 0:
			retreat = 0.99
	elif hp < retreat_threshold and visible_threats > 0:
		retreat = 0.85 + 0.1 * float(d["caution"])
	elif visible_threats >= 3 and hp < 0.6:
		retreat = 0.45 * float(d["caution"])
	add.call("RETREAT", "", retreat)

	# TAKE_COVER: guns on me, hurt, cautious, and somewhere hidden is close by.
	var cover := 0.0
	if not (s["cover"] as Array).is_empty() and threats_on_me > 0:
		cover = float(d["caution"]) * minf(1.0, threats_on_me / 2.0) * (1.0 - hp) * 1.6
	add.call("TAKE_COVER", "", cover)

	var engages: Array = []
	var flanks: Array = []
	var investigates: Array = []
	for c in contacts:
		var distance := my_position.distance_to(c["position"])
		var in_leash: bool = objective == null or leash <= 0.0 \
				or (objective as Vector3).distance_to(c["position"]) <= leash + float(weapon["range"])
		var leash_factor := 1.0 if in_leash else 0.15
		if int(c["age"]) <= CONTACT_FRESH_TICKS:
			var reach := 1.0
			if distance > float(weapon["range"]):
				reach = clampf(1.0 - (distance - float(weapon["range"])) / 80.0, 0.15, 1.0)
			var priority := TankBrain._priority(String(d["target_priority"]), c, distance)
			var engage := (0.3 + 0.7 * float(d["aggression"])) * reach * (0.55 + 0.45 * priority) \
					* confidence * leash_factor * (1.0 if c["visible"] else 0.75)
			engages.append([c["name"], engage])
			# FLANK pays when the target is busy facing a teammate; pointless if I already see its side.
			var flank := float(d["flanking"]) * (1.0 if c["facing_ally"] else 0.55) * confidence * reach * leash_factor
			if c["exposed_face"] != "front":
				flank *= 0.35
			flanks.append([c["name"], flank])
		else:
			var staleness := clampf(float(c["age"]) / float(s["memory_ticks"]), 0.0, 1.0)
			# A last-known position beats marching blindly at the enemy base (ADVANCE's 0.3).
			investigates.append([c["name"], (0.25 + 0.4 * float(d["aggression"])) * (1.0 - staleness) * leash_factor])
	for pair in engages:
		add.call("ENGAGE", pair[0], pair[1])
	for pair in flanks:
		add.call("FLANK", pair[0], pair[1])
	for pair in investigates:
		add.call("INVESTIGATE", pair[0], pair[1])

	# REGROUP: drifted away from the squad, weighted by cohesion (formations do this job when commanded).
	var regroup := 0.0
	if s["squad_center"] != null and not commanded:
		var gap := my_position.distance_to(s["squad_center"])
		regroup = float(d["cohesion"]) * clampf((gap - 15.0) / 30.0, 0.0, 1.0) * 0.8
	add.call("REGROUP", "", regroup)

	# ADVANCE toward the objective (or, with none, toward the enemy base so matches progress).
	var advance := 0.0
	var at_objective := false
	if objective != null:
		var to_objective := my_position.distance_to(objective)
		at_objective = to_objective <= float(s["objective_radius"])
		if leash > 0.0 and to_objective > leash:
			advance = 0.95
		elif not at_objective:
			advance = 0.45 if visible_threats == 0 else 0.25
	elif visible_threats == 0 and hp >= retreat_threshold:
		# Hurt tanks don't go looking for a fight: without this, a damaged tank (no repairs in
		# squad-vs-squad) yo-yoed between its base and the enemy forever.
		advance = 0.3
	if commanded:
		advance = 0.0  # the squad's destination replaces free advancing
	add.call("ADVANCE", "", advance)

	# KEEP_SLOT: be where the squad's formation and drill want me. The player's order dominates
	# (G3): it beats even a committed ENGAGE (~0.8 x COMMIT_BONUS), and only a tank about to die
	# (RETREAT 0.99) overrides it. "Move" means return fire on the move (the turret tracks threats,
	# G5) rather than stopping for every fight. Assault deliberately lets brains hunt.
	var keep_slot := 0.0
	var in_position := false
	if commanded:
		var gap := my_position.distance_to(squad["slot"])
		in_position = gap <= SLOT_TOLERANCE and not squad["moving"]
		match String(squad["verb"]):
			"move":
				keep_slot = 0.0 if in_position else ORDER_WEIGHT
			"bound":
				keep_slot = ORDER_WEIGHT if squad["moving"] and gap > 3.0 else 0.0
				in_position = not squad["moving"]
			"hold":
				keep_slot = 0.0 if gap <= SLOT_TOLERANCE else ORDER_WEIGHT
			"assault":
				keep_slot = 0.0 if in_position else (0.5 if visible_threats == 0 else 0.15)
			"break_contact":
				keep_slot = 0.0 if gap <= SLOT_TOLERANCE else 0.97
	add.call("KEEP_SLOT", "", keep_slot)

	# HOLD: the fallback, and the anchor's job once at its objective.
	var hold := 0.1
	if at_objective:
		hold = 0.3 + 0.35 * (1.0 - float(d["aggression"]))
	if in_position:
		hold = maxf(hold, 0.72)  # in formation and halted: fight from here
	add.call("HOLD", "", hold)

	# Commitment: favor the current choice; keep it through MIN_COMMIT_TICKS unless beaten decisively.
	var committed: Dictionary = {}
	# An order the tank isn't carrying out yet outranks commitment to anything but itself or survival.
	var order_pending := keep_slot > 0.0 and not ["KEEP_SLOT", "RETREAT"].has(current.get("option", ""))
	for candidate in candidates:
		if order_pending:
			break
		if not current.is_empty() and candidate["option"] == current["option"] and candidate["target"] == current["target"]:
			candidate["score"] *= COMMIT_BONUS
			committed = candidate
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if candidate["score"] > best["score"]:
			best = candidate
	if not committed.is_empty() and committed != best and int(s["tick"]) - int(current["since"]) < MIN_COMMIT_TICKS \
			and committed["score"] > 0.0 and best["score"] < committed["score"] * EMERGENCY_MARGIN:
		best = committed

	return {"choice": {"option": best["option"], "target": best["target"]},
			"ranked": TankBrain._top(candidates, 3)}


## Where the turret covers when nothing is in this tank's own sights (G5): the chosen target,
## else the most pressing known contact: visible before remembered, guns on me first, then nearest.
## Null with no contacts (the turret holds its heading).
static func watch_for(s: Dictionary, current: Dictionary) -> Variant:
	var my_position: Vector3 = s["self"]["position"]
	var best: Variant = null
	var best_score := INF
	for c in s["contacts"]:
		# Where it probably is now: last known position plus a short dead-reckoning.
		var seconds := minf(float(c["age"]) / 60.0, WATCH_PREDICT_SECONDS)
		var predicted: Vector3 = c["position"] + (c["velocity"] as Vector3) * seconds
		if c["name"] == current.get("target", ""):
			return predicted
		var score := my_position.distance_to(c["position"]) * (0.6 if c["aiming_at_me"] else 1.0)
		if not c["visible"]:
			score += 1000.0 + float(c["age"])
		if score < best_score:
			best_score = score
			best = predicted
	return best


static func _priority(rule: String, contact: Dictionary, distance: float) -> float:
	match rule:
		"weakest":
			return 1.0 - clampf(float(contact["health"]) / 100.0, 0.0, 1.0)
		"most_exposed":
			return {"rear": 1.0, "side": 0.7, "front": 0.3}[contact["exposed_face"]]
		"threatening_allies":
			return 1.0 if contact["facing_ally"] else 0.3
	return 1.0 - clampf(distance / 150.0, 0.0, 1.0)  # nearest


## Highest scores first; ties keep candidate order (stable, unlike sort_custom).
static func _top(candidates: Array, count: int) -> Array:
	var remaining := candidates.duplicate()
	var result: Array = []
	while result.size() < count and not remaining.is_empty():
		var best_index := 0
		for i in remaining.size():
			if remaining[i]["score"] > remaining[best_index]["score"]:
				best_index = i
		var picked: Dictionary = remaining.pop_at(best_index)
		result.append({"option": picked["option"], "target": picked["target"], "score": snappedf(picked["score"], 0.001)})
	return result


# ---- Sensing (the only impure part) -----------------------------------------------

func build_situation() -> Dictionary:
	var team := tank.team
	var my_position := tank.global_position
	var allies: Array = []
	var squad_positions: Array = []
	for ally in game_match.sorted_team_tanks(team):
		if ally == tank or not ally.is_alive():
			continue
		allies.append({"name": String(ally.name), "position": ally.global_position})
		if game_match.squad_of(ally) == squad_name:
			squad_positions.append(ally.global_position)

	var contacts: Array = []
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	for contact_name in names:
		var known: Dictionary = intel[contact_name]
		var offset: Vector3 = known["position"] - my_position
		contacts.append({
			"name": contact_name,
			"position": known["position"],
			"velocity": known["velocity"],
			"forward": known["forward"],
			"health": known["health"],
			"weapon": known["weapon"],
			"visible": known["visible"],
			"age": game_match.tick - int(known["seen_tick"]),
			"exposed_face": Armor.FACING_NAMES[Armor.facing(known["forward"], offset)],
			"facing_ally": _faces_any(known["position"], known["forward"], allies),
			"aiming_at_me": known["visible"] and Ballistics.aim_error(known["position"], known["turret_forward"],
					my_position) <= deg_to_rad(12.0),
		})

	var objective: Variant = null
	var objective_radius := 0.0
	if typeof(directives["objective"]) == TYPE_DICTIONARY:
		var o: Dictionary = directives["objective"]
		objective = Directives.to_world(team, float(o["right"]), float(o["forward"]))
		objective_radius = float(o["radius"])

	var squad_center: Variant = null
	if not squad_positions.is_empty():
		var sum := Vector3.ZERO
		for p in squad_positions:
			sum += p
		squad_center = sum / squad_positions.size()

	var threat_positions: Array = []
	for c in contacts:
		if c["visible"]:
			threat_positions.append(c["position"])

	var squad_context: Dictionary = game_match.squad_context(tank)
	var effective_directives := directives
	if squad_context.get("slot") != null:
		effective_directives = Squad.drill_directives(directives, squad_context)

	return {
		"tick": game_match.tick,
		"self": {"name": String(tank.name), "team": team, "position": my_position, "forward": -tank.global_basis.z,
				"health": tank.health, "max_health": tank.max_health, "weapon": tank.weapon},
		"directives": effective_directives,
		"squad": squad_context if squad_context.get("slot") != null else null,
		"contacts": contacts,
		"allies": allies,
		"objective": objective,
		"objective_radius": objective_radius,
		"squad_center": squad_center,
		"cover": _find_cover(threat_positions) if not threat_positions.is_empty() else [],
		"rally": Match.spawn_position(team, tank.slot),
		"enemy_base": Match.spawn_position(1 - team, 0),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}


static func _faces_any(position: Vector3, forward: Vector3, allies: Array) -> bool:
	for ally in allies:
		var offset: Vector3 = ally["position"] - position
		if offset.length() < 80.0 and Ballistics.aim_error(position, forward, ally["position"]) <= deg_to_rad(30.0):
			return true
	return false


## Nearby reachable points that no visible threat can see, nearest first.
func _find_cover(threat_positions: Array) -> Array:
	var space := tank.get_world_3d().direct_space_state
	var map := tank.get_world_3d().navigation_map
	var eye := Vector3.UP * Perception.EYE_HEIGHT
	var found: Array = []
	for i in COVER_SAMPLES:
		var angle := TAU * i / COVER_SAMPLES
		var point := tank.global_position + Vector3(cos(angle), 0.0, sin(angle)) * COVER_RING_RADIUS
		if absf(point.x) > ARENA_LIMIT or absf(point.z) > ARENA_LIMIT:
			continue
		if Pathing.is_ready(tank):
			var snapped := NavigationServer3D.map_get_closest_point(map, point)
			if Vector2(snapped.x - point.x, snapped.z - point.z).length() > 1.0:
				continue  # inside an obstacle
		var hidden := true
		for threat in threat_positions:
			var query := PhysicsRayQueryParameters3D.create(threat + eye, point + eye, Perception.WORLD_MASK)
			if space.intersect_ray(query).is_empty():
				hidden = false
				break
		if hidden:
			found.append(point)
	return found


# ---- Acting: choice → standing orders ----------------------------------------------

func _act(s: Dictionary) -> void:
	var me: Dictionary = s["self"]
	var my_position: Vector3 = me["position"]
	var weapon: Dictionary = me["weapon"]
	var contact := _contact(s, choice["target"])
	match choice["option"]:
		"ENGAGE":
			var distance := my_position.distance_to(contact["position"])
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
			if not contact["visible"] or distance > float(weapon["preferred_max"]):
				_order_move(_move_to(contact["position"]))
			elif distance < float(weapon["preferred_min"]):
				var away: Vector3 = my_position + (my_position - contact["position"]).normalized() * 8.0
				_order_move(_move_to(away, true))
			else:
				_order_move({"type": "face", "x": contact["position"].x, "z": contact["position"].z})
		"FLANK":
			var side := Vector3(-contact["forward"].z, 0.0, contact["forward"].x)
			if side.dot(my_position - contact["position"]) < 0.0:
				side = -side
			var standoff := clampf((float(weapon["preferred_min"]) + float(weapon["preferred_max"])) / 2.0, 8.0, 45.0)
			var point: Vector3 = contact["position"] + side * standoff - contact["forward"] * (0.3 * standoff)
			_order_move(_move_to(point))
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"TAKE_COVER":
			var spot: Vector3 = s["cover"][0]
			_order_move(_move_to(spot, (spot - my_position).dot(me["forward"]) < 0.0))
			_order_weapon({"type": "fire_at_will"})
		"RETREAT":
			_order_move(_move_to(s["rally"], true))
			_order_weapon({"type": "fire_at_will"})
		"INVESTIGATE":
			_order_move(_move_to(contact["position"]))
			_order_weapon({"type": "fire_at_will"})
		"REGROUP":
			_order_move(_move_to(s["squad_center"]))
			_order_weapon({"type": "fire_at_will"})
		"ADVANCE":
			_order_move(_move_to(s["objective"] if s["objective"] != null else s["enemy_base"]))
			_order_weapon({"type": "fire_at_will"})
		"KEEP_SLOT":
			var squad: Dictionary = s["squad"]
			_order_move(_move_to(squad["slot"], squad["reverse"], squad["pace"]))
			_order_weapon({"type": "fire_at_will"})
		"HOLD":
			var nearest_visible: Variant = null
			for c in s["contacts"]:
				if c["visible"] and (nearest_visible == null
						or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible)):
					nearest_visible = c["position"]
			if nearest_visible != null:
				_order_move({"type": "face", "x": nearest_visible.x, "z": nearest_visible.z})
			elif s.get("squad") != null:
				var look: Vector3 = my_position + (s["squad"]["facing"] as Vector3) * 20.0
				_order_move({"type": "face", "x": look.x, "z": look.z})
			else:
				_order_move({"type": "stop"})
			_order_weapon({"type": "fire_at_will"})


func _contact(s: Dictionary, contact_name: String) -> Dictionary:
	for c in s["contacts"]:
		if c["name"] == contact_name:
			return c
	return {}


static func _move_to(point: Vector3, reverse := false, speed := 1.0) -> Dictionary:
	return {"type": "move_to", "x": clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT),
			"z": clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT), "reverse": reverse, "speed": snappedf(speed, 0.05)}


## Re-issuing an identical order would reset path following every think; skip near-duplicates.
func _order_move(order: Dictionary) -> void:
	if order["type"] == move_order.get("type") and order.get("reverse", false) == move_order.get("reverse", false) \
			and absf(float(order.get("speed", 1.0)) - float(move_order.get("speed", 1.0))) < 0.1:
		if not order.has("x"):
			return
		if Vector2(float(order["x"]) - float(move_order["x"]), float(order["z"]) - float(move_order["z"])).length() < 2.0:
			return
	set_orders(order, null)


func _order_weapon(order: Dictionary) -> void:
	if not order.recursive_equal(weapon_order, 2):
		set_orders(null, order)
