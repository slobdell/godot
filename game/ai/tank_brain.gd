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
## Tactical queries (TacticalQuery) are re-run at most this often per tank unless the situation changed.
const QUERY_EVERY_TICKS := 30
## ...or this far from where the last one was asked (meters).
const QUERY_MOVED := 6.0
## Hiding places are searched this far around a tank (meters)...
const COVER_SEARCH_RADIUS := 30.0
## ...and only by tanks that might use them: worn below this fraction of hull + shield, or shield down.
const COVER_QUERY_TOUGHNESS := 0.8
## A brain reasons about its nearest this-many contacts (plus its current target and any artillery): the
## situation's cost grows with contacts, and a far enemy never outranks a near one anyway.
const MAX_CONTACTS := 8
## A retreating tank that's in a gun's sight first breaks line of sight at cover this close (meters), then withdraws.
const RETREAT_COVER_DISTANCE := 25.0
## COVER_FIRE (A3): hide and peek spots count as reached within this distance (meters).
const SPOT_ARRIVE := 1.0
## ...peek when the gun will be loaded by the time the tank gets there, driving at about this speed (m/s),
const PEEK_SPEED := 5.0
## ...and only with at least this much shield left (fraction).
const PEEK_SHIELD := 0.35
## A COVER_FIRE query stays valid while the tank is this close to its hide spot and the target this close to
## where it was (meters), and the target still can't see the hide spot.
const COVER_FIRE_KEEP := 12.0
## A4: a gun held this many ticks for a friend in the line of fire makes the brain move to clear the lane.
const LANE_BLOCKED_TICKS := 20
## How far CLEAR_LANE looks for a new firing spot (meters).
const LANE_SEARCH := 10.0
## A6 squad tactics: how much more a brain wants the squad's focus, an enemy shooting a retreating squad-mate
## it was asked to cover, and an enemy near the team's artillery or Lancers.
const FOCUS_BONUS := 1.25
const COVER_TEAMMATE_BONUS := 1.4
const FRAGILE_THREAT_BONUS := 1.15
## The flanker's FLANK floor (× confidence × firepower) on the squad's focus.
const FLANKER_APPETITE := 0.72
const ARENA_LIMIT := Match.DRIVABLE_LIMIT
const OPTIONS := ["RETREAT", "RESUPPLY", "TAKE_COVER", "RECHARGE", "SPOT", "BOMBARD", "SHADOW", "CONTEST", "CLEAR_LANE", "COVER_FIRE", "ENGAGE", "FLANK", "INVESTIGATE", "REGROUP", "ADVANCE", "KEEP_SLOT", "HOLD"]
## Within this distance of its formation slot a tank counts as "in position".
const SLOT_TOLERANCE := 4.0
## Shield down, a gun on me, and the hull below this fraction: break contact to recharge (G6).
const SHIELD_DOWN_BREAK_HP := 0.75
## RECHARGE continues until the shield is back to this fraction.
const RECHARGED := 0.6
## How far RECHARGE backs off when there's no cover nearby.
const RECHARGE_BACKOFF := 25.0
## A tank at base stays until its hull is back to this fraction (G6 repair).
const REPAIR_TOP_UP := 0.9
## A tank at full heat fights with this fraction of its usual appetite (scaled in from 70% heat).
const HOT_FIREPOWER := 0.75
## A tank in its base's resupply zone stays until its ammo is back to this fraction.
const RESUPPLY_TOP_UP := 0.8
## Scouts keep known enemies about this far away: outside a cannon's 70 m, inside their own 110 m sight.
const SCOUT_STANDOFF := 85.0
## Artillery keeps visible enemies at least this far away (outside a cannon's 70 m reach).
const ARTILLERY_SAFE_DISTANCE := 80.0
## With nothing to shell, artillery trails this far behind the nearest friendly gun, toward home.
const ARTILLERY_TRAIL := 35.0
## A scout's appetite for attacking enemy artillery, relative to a tank's normal appetite.
const SCOUT_HUNT := 1.6
const SCOUT_HUNT_FLOOR := 0.8
## A scout's appetite for a straight fight, relative to a tank's.
const SCOUT_FIGHT := 0.6
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
## The last cover query: {"tick", "position", "threats" (count), "result" [Vector3]}.
var _cover_cache := {}
## CLEAR_LANE's chosen spot and when it was chosen (kept until reached or stale, so the tank settles to fire).
var _lane_goal: Variant = null
var _lane_goal_tick := 0
## The last COVER_FIRE query: {"tick", "target" (name), "target_position", "result" ({hide, peek, target} or {})}.
var _cover_fire_cache := {}


func think(_delta: float) -> void:
	if game_match == null or tank == null:
		return
	if not spotter.is_valid():
		# Indirect fire aims at anything the TEAM can see (directive set 2: spotting).
		spotter = func(other: Tank) -> bool: return game_match.is_visible_to(tank.team, other)
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
	# G6: confidence counts the shield (a fresh shield makes a fight winnable); retreat thresholds use
	# the hull alone, because the hull is what doesn't come back.
	var max_shield := float(me.get("max_shield", 0.0))
	var shield := float(me.get("shield", 0.0))
	var toughness := (float(me["health"]) + shield) / (float(me["max_health"]) + max_shield)
	var shield_down := max_shield > 0.0 and shield <= 0.0
	var confidence := lerpf(0.35, 1.0, toughness)
	var contacts: Array = s["contacts"]
	var objective: Variant = s["objective"]
	var leash := float(d["leash"])
	var my_position: Vector3 = me["position"]
	## Squad orders (tactical map): null when this tank's squad has no drill.
	var squad: Variant = s.get("squad")
	var commanded: bool = squad != null and squad["slot"] != null
	## Brain variant switches (BrainVariants): missing = on.
	var features: Dictionary = s.get("features", {})
	var tactics: Dictionary = s.get("tactics", {}) if features.get("squad_tactics", true) else {}
	var fragile_threats: Array = tactics.get("fragile_threats", [])

	var visible_threats := 0
	var threats_on_me := 0
	# G7: a gun with no shells can't fight; a laser at its heat cap has to wait.
	var max_ammo := int(me.get("max_ammo", -1))
	var ammo := int(me.get("ammo", -1))
	var out_of_ammo := max_ammo > 0 and ammo == 0
	var is_scout: bool = me.get("class", "tank") == "scout"
	var is_artillery: bool = me.get("class", "tank") == "artillery"
	var firepower := 0.1 if out_of_ammo else lerpf(1.0, HOT_FIREPOWER, clampf((float(me.get("heat", 0.0)) - 0.7) / 0.3, 0.0, 1.0))
	# Guns that can shoot me right now: in their reach with a clear line (A3). Hand-built situations may omit
	# it; then a gun aimed at me counts.
	var exposed_to := 0
	for c in contacts:
		if c["visible"]:
			visible_threats += 1
			if c["aiming_at_me"]:
				threats_on_me += 1
			if c.get("threatens_me", c["aiming_at_me"]):
				exposed_to += 1

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

	# RESUPPLY (G7): empty guns go home; tanks already at base top up; low tanks refill in quiet moments.
	# Under a player order it stays below ORDER_WEIGHT: the player sees ammo and decides.
	var resupply := 0.0
	if max_ammo > 0:
		var ammo_ratio := float(ammo) / max_ammo
		if out_of_ammo:
			resupply = 0.9
		elif bool(me.get("in_resupply_zone", false)) and ammo_ratio < RESUPPLY_TOP_UP:
			resupply = 0.9 if visible_threats == 0 else 0.5
		elif ammo_ratio <= OrderController.LOW_AMMO_FRACTION and visible_threats == 0:
			resupply = 0.5
	# G6 repair: the base also mends hulls. A worn tank at base stays until mended; a badly hurt one
	# with nobody in sight heads home (this replaced standing still, and fixes camping hurt tanks:
	# they go home, mend, and come back).
	if bool(me.get("in_resupply_zone", false)) and hp < REPAIR_TOP_UP and visible_threats == 0:
		resupply = maxf(resupply, 0.85)
	elif hp < retreat_threshold and visible_threats == 0 and not commanded:
		resupply = maxf(resupply, 0.6)
	add.call("RESUPPLY", "", resupply)

	# TAKE_COVER: guns on me, hurt, cautious, and somewhere hidden is close by.
	var cover := 0.0
	if not (s["cover"] as Array).is_empty() and maxi(threats_on_me, exposed_to) > 0:
		cover = float(d["caution"]) * minf(1.0, maxi(threats_on_me, exposed_to) / 2.0) * (1.0 - toughness) * 1.6

	add.call("TAKE_COVER", "", cover)

	# RECHARGE (G6): shield gone, a gun on me, hull already worn: break contact for a few seconds (the
	# nearest cover, or back off out of the line of fire) and come back when the shield is up. A short
	# hop, not a trip home: RETREAT to base (2026-09-14 first cut) cost the fight and lost T1 22 of 24.
	var recharge := 0.0
	if shield_down and threats_on_me > 0 and hp < SHIELD_DOWN_BREAK_HP:
		recharge = 0.4 + 0.3 * float(d["caution"])
	elif max_shield > 0.0 and current.get("option", "") == "RECHARGE" and shield < max_shield * RECHARGED and visible_threats > 0:
		recharge = 0.5  # keep ducking until the shield is mostly back
	add.call("RECHARGE", "", recharge)

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
					* confidence * leash_factor * (1.0 if c["visible"] else 0.75) * firepower
			# A6: the squad's plan tilts who to shoot (never whether to follow the player's order).
			var squad_bonus := 1.0
			if c["name"] == tactics.get("focus", ""):
				squad_bonus *= FOCUS_BONUS
			if c["name"] == tactics.get("cover_target", ""):
				squad_bonus *= COVER_TEAMMATE_BONUS
			if fragile_threats.has(c["name"]):
				squad_bonus *= FRAGILE_THREAT_BONUS
			if squad_bonus > 1.0:
				var boosted := engage * squad_bonus
				engage = minf(boosted, maxf(engage, ORDER_WEIGHT - 0.1)) if commanded else boosted
			engages.append([c["name"], engage])
			# FLANK pays when the target is busy facing a teammate; pointless if I already see its side.
			var flank := float(d["flanking"]) * (1.0 if c["facing_ally"] else 0.55) * confidence * reach * leash_factor * firepower
			if c["exposed_face"] != "front":
				flank *= 0.35
			elif tactics.get("flank_target", "") == c["name"] and (not commanded or String(squad["verb"]) == "assault"):
				# A6 suppress-and-flank: the squad sent me to its focus's side while the others keep it busy.
				flank = maxf(flank, FLANKER_APPETITE * confidence * firepower * leash_factor)
			flanks.append([c["name"], flank])
		else:
			var staleness := clampf(float(c["age"]) / float(s["memory_ticks"]), 0.0, 1.0)
			# A last-known position beats marching blindly at the enemy base (ADVANCE's 0.3).
			investigates.append([c["name"], (0.25 + 0.4 * float(d["aggression"])) * (1.0 - staleness) * leash_factor])
	# Artillery never brawls: it shells what the team spots (BOMBARD) and stays behind (SHADOW).
	var fight_scale := 0.0 if is_artillery else (SCOUT_FIGHT if is_scout else 1.0)
	var cover_fire: Dictionary = s.get("cover_fire", {}) if s.get("cover_fire") != null else {}
	for pair in engages:
		var score: float = pair[1] * fight_scale
		if is_scout and _is_artillery_contact(contacts, pair[0]):
			# Scouts hunt artillery (directive set 2 counter triangle): artillery is blind up close, can't
			# fire inside 35 m, and is fragile; a scout closing fast on it is its nightmare. Even a
			# cautious scout goes for it.
			score = maxf(pair[1] * SCOUT_HUNT, SCOUT_HUNT_FLOOR * confidence)
		add.call("ENGAGE", pair[0], score)
		# COVER_FIRE (A3): the same fight, from a hide/peek pair: hide while reloading, peek to shoot. Worth it
		# for slow-reloading direct-fire guns (a machine gun or laser gains little from ducking between
		# shots); cautious crews like it more. Considerations: fight appetite × reload × caution × spot quality.
		if features.get("cover_fire", true) and not cover_fire.is_empty() and cover_fire["target"] == pair[0] \
				and weapon["kind"] != Weapons.Kind.ARC:
			var slow_reload := UtilityCurves.linear(float(weapon["reload"]), 0.4, 2.0)
			var spot_quality := UtilityCurves.floor_at(float(cover_fire.get("score", 0.5)), 0.6)
			add.call("COVER_FIRE", pair[0], score * slow_reload * (1.08 + 0.3 * float(d["caution"])) * spot_quality)
	for pair in flanks:
		add.call("FLANK", pair[0], pair[1] * fight_scale)
	# CLEAR_LANE (A4): my gun is ready and aimed but a friend is in the way: step aside to a spot with a clear
	# line to the target instead of waiting (or shooting through it). Above the fight it serves, even when
	# that fight is committed (×COMMIT_BONUS).
	if features.get("hold_for_friends", true) and int(me.get("lane_blocked_ticks", 0)) >= LANE_BLOCKED_TICKS \
			and current.get("target", "") != "":
		for pair in engages:
			if pair[0] == current["target"]:
				add.call("CLEAR_LANE", pair[0], maxf(float(pair[1]) * fight_scale, 0.3) * COMMIT_BONUS * 1.15)
	if is_artillery:
		for c in contacts:
			if not c["visible"]:
				continue
			var reach := my_position.distance_to(c["position"])
			if reach > float(weapon["range"]) + 40.0:
				continue
			var bombard := (0.6 + 0.3 * TankBrain._priority(String(d["target_priority"]), c, reach)) * confidence * firepower
			add.call("BOMBARD", c["name"], bombard)
		var trail := 0.0
		if not (s["allies"] as Array).is_empty():
			trail = 0.55 if visible_threats == 0 else 0.3
		add.call("SHADOW", "", trail)

	# SPOT (scouts, directive set 2): be the team's eyes. Keep the nearest visible enemy at SCOUT_STANDOFF
	# (outside its guns, inside our sight); with nothing in sight, scout ahead.
	var spot := 0.0
	if is_scout:
		var nearest := INF
		for c in contacts:
			if c["visible"] and c.get("weapon", "") != "mortar":  # artillery isn't a threat up close: hunt it
				nearest = minf(nearest, my_position.distance_to(c["position"]))
		if nearest < SCOUT_STANDOFF - 10.0:
			spot = 0.88
		elif nearest < INF:
			spot = 0.7
		else:
			spot = 0.62
	add.call("SPOT", "", spot)
	for pair in investigates:
		add.call("INVESTIGATE", pair[0], pair[1] * (0.0 if is_artillery else 1.0))

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
			# Back to the post, unless the tank is breaking contact to recharge (G6): a hard leash kept
			# anchors from ever letting their shields come back.
			advance = 0.95 if recharge <= 0.0 else 0.3
		elif not at_objective:
			advance = 0.45 if visible_threats == 0 else 0.25
	elif visible_threats == 0 and hp >= retreat_threshold:
		# Hurt tanks don't go looking for a fight: without this, a damaged tank (no repairs in
		# squad-vs-squad) yo-yoed between its base and the enemy forever.
		advance = 0.3
	if commanded:
		advance = 0.0  # the squad's destination replaces free advancing
	add.call("ADVANCE", "", advance)

	# CONTEST (stretch, control point): take and hold the center when it isn't ours. Holding tanks stay
	# inside and fight from there. Artillery doesn't contest (it can't hold ground).
	var contest := 0.0
	var control: Variant = s.get("control")
	if control != null and not commanded and not is_artillery and hp >= retreat_threshold:
		var inside := my_position.distance_to(control["center"]) <= float(control["radius"]) * 0.8
		if int(control["owner"]) != int(me["team"]):
			contest = 0.72 if visible_threats == 0 else 0.5
		elif inside:
			contest = 0.4
		else:
			contest = 0.45 if visible_threats == 0 else 0.2
		contest *= 0.8 if is_scout else 1.0
	add.call("CONTEST", "", contest)

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


static func _is_artillery_contact(contacts: Array, contact_name: String) -> bool:
	for c in contacts:
		if c["name"] == contact_name:
			return c.get("weapon", "") == "mortar"
	return false


static func _priority(rule: String, contact: Dictionary, distance: float) -> float:
	match rule:
		"weakest":
			# Hull plus shield against a standard tank's full load (was health / 100, which rated every
			# tank above 100 HP as equally healthy).
			var full := float(Units.stat("tank", "max_health")) + float(Units.stat("tank", "max_shield"))
			return 1.0 - clampf((float(contact["health"]) + float(contact.get("shield", 0.0))) / full, 0.0, 1.0)
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
	for ally: Tank in AiTickCache.team_tanks(game_match, team):
		if ally == tank or not ally.is_alive():
			continue
		allies.append({"name": String(ally.name), "position": ally.global_position})
		if game_match.squad_of(ally) == squad_name:
			squad_positions.append(ally.global_position)

	var features := BrainVariants.for_team(team)
	hold_for_friends = features.get("hold_for_friends", true)
	var contacts: Array = []
	var cover_map := CoverMap.of(tank)
	var my_name := String(tank.name)
	var flank_reach := float(tank.weapon["range"]) + 30.0
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	var keep := {}
	if names.size() > MAX_CONTACTS:
		var by_distance: Array = []
		for contact_name in names:
			by_distance.append([my_position.distance_to(intel[contact_name]["position"]), contact_name])
		by_distance.sort()
		for i in by_distance.size():
			var contact_name: String = by_distance[i][1]
			if i < MAX_CONTACTS or contact_name == choice.get("target", "") or intel[contact_name]["weapon"] == "mortar":
				keep[contact_name] = true
	for contact_name in names:
		if not keep.is_empty() and not keep.has(contact_name):
			continue
		var known: Dictionary = intel[contact_name]
		var offset: Vector3 = known["position"] - my_position
		contacts.append({
			"name": contact_name,
			"position": known["position"],
			"velocity": known["velocity"],
			"forward": known["forward"],
			"health": known["health"],
			"shield": known.get("shield", 0),
			"weapon": known["weapon"],
			"visible": known["visible"],
			"age": game_match.tick - int(known["seen_tick"]),
			"exposed_face": Armor.FACING_NAMES[Armor.facing(known["forward"], offset)],
			# Only near enough to flank or prioritize matters (reach + 30 m); the check is contacts × allies.
			"facing_ally": offset.length() <= flank_reach and AiTickCache.faced_by(game_match, team, contact_name, known).any(
					func(faced: String) -> bool: return faced != my_name),
			"aiming_at_me": known["visible"] and Ballistics.aim_error(known["position"], known["turret_forward"],
					my_position) <= deg_to_rad(12.0),
			# In its weapon's reach with a clear line to me (CoverMap): it can shoot me right now.
			"threatens_me": known["visible"] and my_position.distance_to(known["position"]) <= float(Weapons.profile(known["weapon"])["range"]) + 5.0
					and cover_map.clear_line(known["position"], my_position),
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

	var squad_context: Dictionary = AiTickCache.squad_context(game_match, tank)
	var effective_directives := directives
	if squad_context.get("slot") != null:
		effective_directives = Squad.drill_directives(directives, squad_context)

	return {
		"tick": game_match.tick,
		"self": {"name": String(tank.name), "team": team, "position": my_position, "forward": -tank.global_basis.z,
				"health": tank.health, "max_health": tank.max_health, "weapon": tank.weapon,
				"ammo": tank.ammo, "max_ammo": tank.max_ammo, "heat": tank.sync_heat,
				"shield": tank.shield, "max_shield": tank.max_shield, "reload": tank.sync_reload,
				"lane_blocked_ticks": lane_blocked_ticks,
				"class": Units.PROFILES.get(tank.unit_id, {}).get("class", "tank"), "sight_radius": tank.sight_radius,
				"in_resupply_zone": Match.in_resupply_zone(team, my_position)},
		"directives": effective_directives,
		"squad": squad_context if squad_context.get("slot") != null else null,
		"contacts": contacts,
		"allies": allies,
		"objective": objective,
		"objective_radius": objective_radius,
		"squad_center": squad_center,
		"features": features,
		"tactics": _tactics(features),
		"cover": _cover_spots(contacts, allies, squad_context),
		"cover_fire": _cover_fire_spot(contacts, allies, squad_context, cover_map),
		"rally": Match.spawn_position(team, tank.slot),
		"resupply": Match.resupply_center(team),
		"enemy_base": Match.spawn_position(1 - team, 0),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"control": {"center": Match.CONTROL_CENTER, "radius": Match.CONTROL_RADIUS, "owner": game_match.control_owner}
				if game_match.control_point else null,
	}


## Nearby hiding places from the visible threats, best first (TacticalQuery.find_cover), for worn tanks.
## Cached for QUERY_EVERY_TICKS unless the tank moved QUERY_MOVED.
func _cover_spots(contacts: Array, allies: Array, squad_context: Dictionary) -> Array:
	var threats := TankBrain.threat_list(contacts, tank.global_position)
	var toughness := (tank.health + tank.shield) / maxf(tank.max_health + tank.max_shield, 1.0)
	var shield_down := tank.max_shield > 0.0 and tank.shield <= 0.0
	if threats.is_empty() or (toughness >= COVER_QUERY_TOUGHNESS and not shield_down):
		_cover_cache = {}
		return []
	if not _cover_cache.is_empty() and game_match.tick - int(_cover_cache["tick"]) < QUERY_EVERY_TICKS \
			and tank.global_position.distance_to(_cover_cache["position"]) < QUERY_MOVED:
		return _cover_cache["result"]
	var request := {"position": tank.global_position, "threats": threats, "search_radius": COVER_SEARCH_RADIUS,
			"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
	if squad_context.get("slot") != null:
		request["anchor"] = squad_context["slot"]
		request["anchor_radius"] = COVER_SEARCH_RADIUS * 0.6
	elif typeof(directives["objective"]) == TYPE_DICTIONARY and float(directives["leash"]) > 0.0:
		var o: Dictionary = directives["objective"]
		request["anchor"] = Directives.to_world(tank.team, float(o["right"]), float(o["forward"]))
		request["anchor_radius"] = float(directives["leash"])
	var result: Array = TacticalQuery.find_cover(CoverMap.of(tank), request).map(
			func(spot: Dictionary) -> Vector3: return spot["point"])
	_cover_cache = {"tick": game_match.tick, "position": tank.global_position, "threats": threats.size(), "result": result}
	return result


## A hide/peek pair for fighting the most pressing target from cover (TacticalQuery.find_cover_fire), or
## null. The target is the one this tank is already fighting, else the nearest visible enemy in reach. Cached
## while the tank stays near the hide spot, the target stays put, and the hide spot stays hidden from it.
func _cover_fire_spot(contacts: Array, allies: Array, squad_context: Dictionary, cover_map: CoverMap) -> Variant:
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		return null
	var reach := float(tank.weapon["range"])
	var target: Dictionary = {}
	for c: Dictionary in contacts:
		# A target that ducked out of sight a moment ago is still the fight (hiding breaks our own line of sight too).
		if int(c["age"]) > CONTACT_FRESH_TICKS or tank.global_position.distance_to(c["position"]) > reach + 15.0:
			continue
		if c["name"] == choice.get("target", ""):
			target = c
			break
		if not c["visible"]:
			continue
		if target.is_empty() or tank.global_position.distance_to(c["position"]) < tank.global_position.distance_to(target["position"]):
			target = c
	if target.is_empty():
		_cover_fire_cache = {}
		return null
	var cached: Dictionary = _cover_fire_cache.get("result", {})
	if not _cover_fire_cache.is_empty() and _cover_fire_cache["target"] == target["name"] \
			and game_match.tick - int(_cover_fire_cache["tick"]) < QUERY_EVERY_TICKS * 4 \
			and (target["position"] as Vector3).distance_to(_cover_fire_cache["target_position"]) < 6.0 \
			and (cached.is_empty() or (tank.global_position.distance_to(cached["hide"]) < COVER_FIRE_KEEP
				and TacticalQuery.hull_hidden(cover_map, target["position"], cached["hide"]))):
		return null if cached.is_empty() else cached
	if not _cover_fire_cache.is_empty() and _cover_fire_cache["target"] == target["name"] \
			and game_match.tick - int(_cover_fire_cache["tick"]) < QUERY_EVERY_TICKS:
		return null if cached.is_empty() else cached  # asked recently: don't re-run every think
	var request := {"position": tank.global_position, "target": target["position"],
			"threats": TankBrain.threat_list(contacts, tank.global_position), "search_radius": COVER_SEARCH_RADIUS,
			"range": [float(tank.weapon["preferred_min"]), float(tank.weapon["preferred_max"]), reach],
			"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
	if squad_context.get("slot") != null:
		request["anchor"] = squad_context["slot"]
		request["anchor_radius"] = COVER_SEARCH_RADIUS * 0.6
	var found := TacticalQuery.find_cover_fire(cover_map, request)
	if not found.is_empty():
		found["target"] = target["name"]
	_cover_fire_cache = {"tick": game_match.tick, "target": target["name"], "target_position": target["position"], "result": found}
	return null if found.is_empty() else found


## This tank's slice of its squad's plan (SquadTactics): {"focus", "flank_target" (if I'm the flanker),
## "cover_target" (if I'm covering a squad-mate), "fragile_threats"}.
func _tactics(features: Dictionary) -> Dictionary:
	if not features.get("squad_tactics", true):
		return {}
	var plan := SquadTactics.for_squad(game_match, game_match.squad_for(tank))
	if plan.is_empty():
		return {}
	var my_name := String(tank.name)
	return {"focus": plan["focus"], "flank_target": plan["focus"] if plan["flanker"] == my_name else "",
			"cover_target": (plan["cover_for"] as Dictionary).get(my_name, ""), "fragile_threats": plan["fragile_threats"]}


## A unit's role: catalog v2 "role", round 1 "class", else "tank".
static func role_of(unit: Tank) -> String:
	var profile: Dictionary = Units.PROFILES.get(unit.unit_id, {})
	return String(profile.get("role", profile.get("class", "tank")))


## Visible contacts as TacticalQuery threats: guns aimed at me first (weight 1), then the rest (0.6),
## nearest first within each group.
static func threat_list(contacts: Array, my_position: Vector3) -> Array:
	var ranked: Array = []
	for c: Dictionary in contacts:
		if c["visible"]:
			var aimed: bool = c["aiming_at_me"]
			ranked.append([0 if aimed else 1, my_position.distance_to(c["position"]), c["name"], c["position"], 1.0 if aimed else 0.6])
	ranked.sort()
	return ranked.map(func(entry: Array) -> Dictionary: return {"position": entry[3], "weight": entry[4]})


# ---- Acting: choice → standing orders ----------------------------------------------

func _act(s: Dictionary) -> void:
	if choice["option"] != "CLEAR_LANE":
		_lane_goal = null
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
			# Break line of sight first (A3): backing 100 m across open ground under fire is how hurt tanks died.
			var exposed := (s["contacts"] as Array).any(func(c: Dictionary) -> bool:
				return c["visible"] and c.get("threatens_me", c["aiming_at_me"]))
			var cover_spots: Array = s["cover"]
			if not s.get("features", {}).get("retreat_to_cover", true):
				_order_move(_move_to(s["rally"], true))
			elif exposed and not cover_spots.is_empty() and my_position.distance_to(cover_spots[0]) <= RETREAT_COVER_DISTANCE:
				var hide: Vector3 = cover_spots[0]
				_order_move(_move_to(hide, (hide - my_position).dot(me["forward"]) < 0.0, 1.0, SPOT_ARRIVE))
			else:
				_order_move(_move_to(TankBrain.withdraw_point(s), true))
			_order_weapon({"type": "fire_at_will"})
		"CLEAR_LANE":
			if _lane_goal == null or game_match.tick - _lane_goal_tick > 120:
				_lane_goal = _lane_spot(s, contact)
				_lane_goal_tick = game_match.tick
			var spot: Vector3 = _lane_goal
			if my_position.distance_to(spot) > SPOT_ARRIVE + 0.5:
				_order_move(_move_to(spot, false, 1.0, SPOT_ARRIVE))
			else:
				_order_move({"type": "face", "x": contact["position"].x, "z": contact["position"].z})
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"COVER_FIRE":
			var pair: Dictionary = s["cover_fire"]
			var hide: Vector3 = pair["hide"]
			var peek: Vector3 = pair["peek"]
			var travel := my_position.distance_to(peek) / PEEK_SPEED
			var loaded_by_then := float(me.get("reload", 1.0)) >= 1.0 - travel / maxf(float(weapon["reload"]), 0.01)
			var max_shield := float(me.get("max_shield", 0.0))
			var shield_ok := max_shield <= 0.0 or float(me.get("shield", 0.0)) >= max_shield * PEEK_SHIELD
			if loaded_by_then and shield_ok:
				_order_move(_move_to(peek, false, 1.0, SPOT_ARRIVE))
			else:
				# Back into cover with the front still toward the target.
				_order_move(_move_to(hide, true, 1.0, SPOT_ARRIVE))
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"BOMBARD":
			var target_position: Vector3 = contact["position"]
			var distance := my_position.distance_to(target_position)
			var nearest_threat := INF
			var threat_at := Vector3.ZERO
			for c in s["contacts"]:
				if c["visible"] and my_position.distance_to(c["position"]) < nearest_threat:
					nearest_threat = my_position.distance_to(c["position"])
					threat_at = c["position"]
			if nearest_threat < ARTILLERY_SAFE_DISTANCE:
				# Too close to someone's guns: back away from them, facing them.
				var away := (my_position - threat_at).normalized()
				_order_move(_move_to(my_position + away * (ARTILLERY_SAFE_DISTANCE - nearest_threat + 10.0), true))
			elif distance > float(weapon["preferred_max"]):
				_order_move(_move_to(target_position + (my_position - target_position).normalized() * float(weapon["preferred_max"])))
			else:
				_order_move({"type": "face", "x": target_position.x, "z": target_position.z})
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"CONTEST":
			var control: Dictionary = s["control"]
			var center: Vector3 = control["center"]
			# Spread out inside the zone: each tank takes its own spot on a ring (stable per tank).
			var angle := TAU * float(think_offset % 8) / 8.0
			var spot: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * float(control["radius"]) * 0.45
			var nearest_visible: Variant = null
			for c in s["contacts"]:
				if c["visible"] and (nearest_visible == null or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible)):
					nearest_visible = c["position"]
			if my_position.distance_to(spot) > 4.0:
				_order_move(_move_to(spot))
			elif nearest_visible != null:
				_order_move({"type": "face", "x": nearest_visible.x, "z": nearest_visible.z})
			else:
				_order_move({"type": "stop"})
			_order_weapon({"type": "fire_at_will"})
		"SHADOW":
			var nearest_ally: Variant = null
			for ally in s["allies"]:
				if nearest_ally == null or my_position.distance_to(ally["position"]) < my_position.distance_to(nearest_ally):
					nearest_ally = ally["position"]
			var home: Vector3 = s["rally"]
			var behind: Vector3 = nearest_ally + ((home - nearest_ally) as Vector3).normalized() * ARTILLERY_TRAIL
			_order_move(_move_to(behind))
			_order_weapon({"type": "fire_at_will"})
		"SPOT":
			var nearest_visible: Dictionary = {}
			for c in s["contacts"]:
				if c["visible"] and (nearest_visible.is_empty()
						or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible["position"])):
					nearest_visible = c
			if not nearest_visible.is_empty():
				var threat: Vector3 = nearest_visible["position"]
				var away := my_position - threat
				away.y = 0.0
				var post: Vector3 = threat + (away.normalized() if away.length() > 0.1 else -(me["forward"] as Vector3)) * SCOUT_STANDOFF
				if my_position.distance_to(post) > 6.0:
					# Back off facing the enemy, so it stays in sight.
					_order_move(_move_to(post, (post - my_position).dot(threat - my_position) < 0.0))
				else:
					_order_move({"type": "face", "x": threat.x, "z": threat.z})
			else:
				var goal: Vector3 = s["objective"] if s["objective"] != null else s["enemy_base"]
				var freshest: Dictionary = {}
				for c in s["contacts"]:
					if freshest.is_empty() or int(c["age"]) < int(freshest["age"]):
						freshest = c
				if not freshest.is_empty():
					var toward: Vector3 = (freshest["position"] as Vector3) - my_position
					goal = (freshest["position"] as Vector3) - toward.normalized() * SCOUT_STANDOFF * 0.8
				_order_move(_move_to(goal))
			_order_weapon({"type": "fire_at_will"})
		"RECHARGE":
			if not (s["cover"] as Array).is_empty():
				var hide: Vector3 = s["cover"][0]
				_order_move(_move_to(hide, (hide - my_position).dot(me["forward"]) < 0.0))
			else:
				var threat_center := Vector3.ZERO
				var seen := 0
				for c in s["contacts"]:
					if c["visible"]:
						threat_center += c["position"]
						seen += 1
				var away := (my_position - threat_center / maxf(seen, 1)).normalized() if seen > 0 else -(me["forward"] as Vector3)
				_order_move(_move_to(my_position + away * RECHARGE_BACKOFF, true))
			_order_weapon({"type": "fire_at_will"})
		"RESUPPLY":
			var depot: Vector3 = s.get("resupply", s["rally"])
			if bool(me.get("in_resupply_zone", false)) and my_position.distance_to(depot) < Match.RESUPPLY_RADIUS * 0.6:
				_order_move({"type": "stop"})
			elif s.get("features", {}).get("retreat_to_cover", true) and TankBrain.withdraw_point(s) != s["rally"]:
				# Enemies seen close by a moment ago: back straight away from them first (stays in cover's shadow).
				_order_move(_move_to(TankBrain.withdraw_point(s), true))
			else:
				# Back in with the front armor toward any threat, drive in when it's quiet.
				_order_move(_move_to(depot, not s["contacts"].filter(func(c: Dictionary) -> bool: return c["visible"]).is_empty()))
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


## CLEAR_LANE's destination: the nearest of 16 nearby spots (two rings) that stands clear of obstacles, sees the
## target, and has no friend in the new line of fire; otherwise a sidestep away from the blocking friend.
func _lane_spot(s: Dictionary, contact: Dictionary) -> Vector3:
	var me: Vector3 = s["self"]["position"]
	var target: Vector3 = contact["position"]
	var map := CoverMap.of(tank)
	var friends: Array = (s["allies"] as Array).map(func(ally: Dictionary) -> Dictionary:
			return {"name": ally["name"], "position": ally["position"]})
	var best: Variant = null
	for ring: float in [LANE_SEARCH * 0.6, LANE_SEARCH]:
		for i in 8:
			var angle := TAU * i / 8.0
			var spot := me + Vector3(cos(angle), 0.0, sin(angle)) * ring
			if absf(spot.x) > ARENA_LIMIT or absf(spot.z) > ARENA_LIMIT or map.inside_any(Vector2(spot.x, spot.z), 2.4):
				continue
			if not map.clear_line(spot, target) or not FireLanes.in_line(spot, target, friends).is_empty():
				continue
			# Keep the range: the spot whose distance to the target changes least.
			var range_change := absf(spot.distance_to(target) - me.distance_to(target))
			if best == null or range_change < absf((best as Vector3).distance_to(target) - me.distance_to(target)) - 0.01:
				best = spot
		if best != null:
			return best
	var blocker: Vector3 = me
	for ally: Dictionary in s["allies"]:
		if ally["name"] == lane_blocker:
			blocker = ally["position"]
	var lane := Vector3(target.x - me.x, 0.0, target.z - me.z).normalized()
	var side := Vector3(-lane.z, 0.0, lane.x)
	if side.dot(blocker - me) > 0.0:
		side = -side
	return me + side * 6.0


## Where a tank breaking contact heads next: straight away from the nearest recently seen enemy that could
## still reach it (moving directly away from a threat keeps an obstacle between us: shadows widen with
## distance), bent toward home when home is roughly that way; the rally point once clear.
static func withdraw_point(s: Dictionary) -> Vector3:
	var me: Vector3 = s["self"]["position"]
	var rally: Vector3 = s["rally"]
	var nearest: Dictionary = {}
	for c: Dictionary in s["contacts"]:
		if int(c["age"]) > CONTACT_FRESH_TICKS * 2:
			continue
		var distance := me.distance_to(c["position"])
		if distance > float(Weapons.profile(String(c.get("weapon", "cannon")))["range"]) + 25.0:
			continue
		if nearest.is_empty() or distance < me.distance_to(nearest["position"]):
			nearest = c
	if nearest.is_empty():
		return rally
	var away := Vector3(me.x - nearest["position"].x, 0.0, me.z - nearest["position"].z)
	away = away.normalized() if away.length() > 0.1 else -(s["self"]["forward"] as Vector3)
	var home := Vector3(rally.x - me.x, 0.0, rally.z - me.z)
	if home.length() > 0.1 and home.normalized().dot(away) > 0.3:
		away = (away * 0.6 + home.normalized() * 0.4).normalized()
	var point := me + away * 20.0
	return Vector3(clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT), 0.0, clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT))


static func _move_to(point: Vector3, reverse := false, speed := 1.0, arrive := OrderController.ARRIVE_RADIUS) -> Dictionary:
	return {"type": "move_to", "x": clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT),
			"z": clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT), "reverse": reverse, "speed": snappedf(speed, 0.05),
			"arrive": arrive}


## Re-issuing an identical order would reset path following every think; skip near-duplicates.
func _order_move(order: Dictionary) -> void:
	if order["type"] == move_order.get("type") and order.get("reverse", false) == move_order.get("reverse", false) \
			and absf(float(order.get("speed", 1.0)) - float(move_order.get("speed", 1.0))) < 0.1 \
			and is_equal_approx(float(order.get("arrive", 0.0)), float(move_order.get("arrive", 0.0))):
		if not order.has("x"):
			return
		if Vector2(float(order["x"]) - float(move_order["x"]), float(order["z"]) - float(move_order["z"])).length() < 2.0:
			return
	set_orders(order, null)


func _order_weapon(order: Dictionary) -> void:
	if not order.recursive_equal(weapon_order, 2):
		set_orders(null, order)
