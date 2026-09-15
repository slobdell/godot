class_name SquadTactics
extends RefCounted
## Squad coordination (_agents/unit_ai.md §7, after F.E.A.R.'s squad behaviors): a small blackboard per squad,
## recomputed every PLAN_EVERY_TICKS, that brains read as considerations (target priority, a flanking role),
## never as commands. The player's order still wins: nothing here moves a tank off its KEEP_SLOT.
##
##   focus        the enemy the squad should pile onto: most squad damage per second it can take, per point of
##                toughness, with bonuses for guns on a squad-mate and threats to fragile friends
##   flanker      one member sent to hit the focus from the side while the rest keep it busy (≥ 3 members,
##                the focus holding still)
##   cover_for    {member: enemy}: the healthy member nearest a retreating/recharging squad-mate targets the
##                enemy shooting at it
##   fragile_threats  enemies within FRAGILE_RADIUS of the team's artillery or Lancers
##
## plan() is pure (hand-built members and contacts in tests); for_squad() gathers them from a Match and caches
## per squad per planning bucket (deterministic: every brain in a bucket reads the same plan, computed from the
## state at the bucket's first query).

const PLAN_EVERY_TICKS := 30
## A focus needs at least this many members able to shoot it (otherwise everyone just fights).
const FOCUS_MIN_SHOOTERS := 2
## Suppress-and-flank needs this many living members, and the focus moving slower than FLANK_MAX_SPEED.
const FLANK_MIN_MEMBERS := 3
const FLANK_MAX_SPEED := 3.0
## The flank position: this far to the focus's side.
const FLANK_STANDOFF := 30.0
const FRAGILE_ROLES := ["artillery", "lancer"]
const FRAGILE_RADIUS := 45.0
## Options that mean "I'm pulling out of the fight" (a squad-mate should cover me).
const WITHDRAWING := ["RETREAT", "RECHARGE", "TAKE_COVER"]
## A gun counts as aimed at a tank within this angle.
const AIMED_DEG := 12.0

static var _cache := {}
static var _cache_match := 0


## members: [{"name", "position", "forward", "weapon" (profile), "toughness" 0..1, "option", "role"}] (living)
## contacts: [{"name", "position", "velocity", "forward", "turret_forward", "health", "shield", "visible"}]
## fragile: [Vector3] positions of the team's fragile units. previous: the last plan (for sticky roles).
static func plan(members: Array, contacts: Array, fragile: Array, map: CoverMap, previous: Dictionary = {}) -> Dictionary:
	var result := {"focus": "", "flanker": "", "cover_for": {}, "fragile_threats": []}
	var visible: Array = contacts.filter(func(c: Dictionary) -> bool: return c["visible"])
	for c: Dictionary in visible:
		for spot: Vector3 in fragile:
			if spot.distance_to(c["position"]) <= FRAGILE_RADIUS:
				(result["fragile_threats"] as Array).append(c["name"])
				break
	# Focus fire.
	var best_value := 0.0
	for c: Dictionary in visible:
		var shooters := 0
		var dps := 0.0
		var aimed_at_member := false
		for m: Dictionary in members:
			if FRAGILE_ROLES.has(m.get("role", "")) and m["weapon"]["kind"] == Weapons.Kind.ARC:
				continue  # artillery joins in on its own; it doesn't shape the squad's focus
			var distance: float = (m["position"] as Vector3).distance_to(c["position"])
			if distance <= 80.0 and _aimed(c, m["position"]):
				aimed_at_member = true
			if distance > float(m["weapon"]["range"]) + 10.0 or not map.clear_line(m["position"], c["position"]):
				continue
			shooters += 1
			dps += _damage_rate(m["weapon"], c, m["position"])
		if shooters < FOCUS_MIN_SHOOTERS:
			continue
		var toughness := maxf(float(c["health"]) + float(c.get("shield", 0.0)), 1.0)
		var value := dps / toughness * (1.2 if aimed_at_member else 1.0) \
				* (1.3 if (result["fragile_threats"] as Array).has(c["name"]) else 1.0)
		# Stickiness: switching focus costs the damage already dealt, so the current one gets a margin.
		if c["name"] == previous.get("focus", ""):
			value *= 1.25
		if value > best_value + 1e-9:
			best_value = value
			result["focus"] = c["name"]
	# Suppress and flank.
	if result["focus"] != "" and members.size() >= FLANK_MIN_MEMBERS:
		var focus := _contact(visible, result["focus"])
		if (focus["velocity"] as Vector3).length() < FLANK_MAX_SPEED:
			var best_cost := INF
			for m: Dictionary in members:
				if m.get("role", "tank") in ["artillery", "scout"] or WITHDRAWING.has(m.get("option", "")):
					continue
				var cost := (m["position"] as Vector3).distance_to(flank_point(focus, m["position"]))
				if m["name"] == previous.get("flanker", ""):
					cost *= 0.7
				if cost < best_cost - 1e-6:
					best_cost = cost
					result["flanker"] = m["name"]
	# Cover a squad-mate pulling out.
	for retreating: Dictionary in members:
		if not WITHDRAWING.has(retreating.get("option", "")):
			continue
		var shooter: Dictionary = {}
		for c: Dictionary in visible:
			if _aimed(c, retreating["position"]) and (shooter.is_empty() or (retreating["position"] as Vector3).distance_to(c["position"])
					< (retreating["position"] as Vector3).distance_to(shooter["position"])):
				shooter = c
		if shooter.is_empty():
			continue
		var helper: Dictionary = {}
		for m: Dictionary in members:
			if m["name"] == retreating["name"] or WITHDRAWING.has(m.get("option", "")) or float(m.get("toughness", 1.0)) < 0.5:
				continue
			if (result["cover_for"] as Dictionary).has(m["name"]):
				continue
			if helper.is_empty() or (m["position"] as Vector3).distance_to(retreating["position"]) \
					< (helper["position"] as Vector3).distance_to(retreating["position"]):
				helper = m
		if not helper.is_empty():
			result["cover_for"][helper["name"]] = shooter["name"]
	return result


## Where a flanker hits `focus` from: beside it (the side nearer `from`), a little behind its front.
static func flank_point(focus: Dictionary, from: Vector3) -> Vector3:
	var forward := Vector3(focus["forward"].x, 0.0, focus["forward"].z)
	forward = forward.normalized() if forward.length_squared() > 1e-6 else Vector3.FORWARD
	var side := Vector3(-forward.z, 0.0, forward.x)
	var center: Vector3 = focus["position"]
	if side.dot(from - center) < 0.0:
		side = -side
	var point := center + side * FLANK_STANDOFF - forward * (FLANK_STANDOFF * 0.3)
	return Vector3(clampf(point.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0, clampf(point.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))


## Hull damage per second `weapon` would do to `contact` from `from`, shields and armor facing included (a rough,
## deterministic estimate for comparing targets).
static func _damage_rate(weapon: Dictionary, contact: Dictionary, from: Vector3) -> float:
	var reload := maxf(float(weapon.get("reload", 1.0)), 0.05)
	var damage := float(weapon.get("damage", weapon.get("damage_per_second", 0.0) * reload))
	var attack := Vector3(contact["position"].x - from.x, 0.0, contact["position"].z - from.z)
	var face: String = Armor.FACING_NAMES[Armor.facing(contact["forward"], attack)]
	var multiplier := 1.0
	if float(contact.get("shield", 0.0)) > 0.0:
		multiplier = float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face])
	elif weapon.has("armor"):
		multiplier = float(weapon["armor"][face])
	return damage / reload * multiplier


static func _aimed(contact: Dictionary, at: Vector3) -> bool:
	return contact.has("turret_forward") and Ballistics.aim_error(contact["position"], contact["turret_forward"], at) <= deg_to_rad(AIMED_DEG)


static func _contact(contacts: Array, contact_name: String) -> Dictionary:
	for c: Dictionary in contacts:
		if c["name"] == contact_name:
			return c
	return {}


## The squad's current plan (cached per squad per PLAN_EVERY_TICKS bucket).
static func for_squad(game_match: Match, squad: Squad) -> Dictionary:
	if squad == null:
		return {}
	if _cache_match != game_match.get_instance_id():
		_cache = {}
		_cache_match = game_match.get_instance_id()
	var key := "%d/%s" % [squad.team, squad.squad_name]
	var bucket := game_match.tick / PLAN_EVERY_TICKS
	var cached: Dictionary = _cache.get(key, {})
	if not cached.is_empty() and int(cached["bucket"]) == bucket:
		return cached["plan"]
	var by_name := AiTickCache.tanks_by_name(game_match)
	var members: Array = []
	for member in squad.alive_members(by_name):
		var tank: Tank = by_name[member]
		var brain := game_match.brains.get_node_or_null("Brain_" + member) as TankBrain
		members.append({"name": member, "position": tank.global_position, "forward": -tank.global_basis.z,
				"weapon": tank.weapon, "role": TankBrain.role_of(tank),
				"toughness": (tank.health + tank.shield) / maxf(tank.max_health + tank.max_shield, 1.0),
				"option": brain.choice.get("option", "") if brain != null else ""})
	var contacts: Array = []
	var intel: Dictionary = game_match.intel[squad.team]
	var names := intel.keys()
	names.sort()
	for contact_name in names:
		var known: Dictionary = intel[contact_name]
		contacts.append({"name": contact_name, "position": known["position"], "velocity": known["velocity"],
				"forward": known["forward"], "turret_forward": known["turret_forward"], "health": known["health"],
				"shield": known.get("shield", 0), "visible": known["visible"]})
	var fragile: Array = []
	for tank: Tank in AiTickCache.team_tanks(game_match, squad.team):
		if tank.is_alive() and FRAGILE_ROLES.has(TankBrain.role_of(tank)):
			fragile.append(tank.global_position)
	var result := plan(members, contacts, fragile, CoverMap.of(game_match), cached.get("plan", {}))
	_cache[key] = {"bucket": bucket, "plan": result}
	return result
