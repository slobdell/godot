class_name CpuCommander
extends Node
## Stretch: a CPU commander for one team. It plays the tactical map the way a player would: every
## THINK_TICKS it looks at its team's intel and issues SquadCommands (the same data the map, the agent
## bridge, and the network send) to its gun squads. Scout and artillery squads are left to their
## brains (SPOT, BOMBARD), which already do their jobs.
##
## Policy v2 (2026-09-15, ai stream; deterministic, thinks on Match.tick). v1 won 8 of 32 against plain brains:
## its MOVE/BOUND legs and early BREAK CONTACTs pulled tanks out of fights they were winning (KEEP_SLOT 15% of
## their time). v2 lets the brains fight inside ASSAULT and only drives when nothing is known:
##   enemies in sight      -> compare strength (hull + shield of our living tanks vs the enemies we know about):
##                            BREAK CONTACT only when clearly weaker AND the nearest enemy is still beyond
##                            DISENGAGE_RANGE (turning away up close gets you shot); otherwise ASSAULT their
##                            center (HOLD only on a control point we own)
##   a fresh contact       -> ASSAULT toward it (the brains hunt and use cover inside an assault)
##   nothing known         -> MOVE in a wedge toward the objective (the center if contested, else a point
##                            ahead), BOUND once within BOUND_RANGE of old contacts
## A command is only re-issued when the verb changes or the destination moves by REISSUE_METERS (ASSAULT:
## ASSAULT_REISSUE_METERS), because every new order resets the brains' commitment.
##
## Policy v3 (round 3 X5, _agents/unit_ai.md "A CPU that maneuvers"): the whole army, by squad role, in visible shapes.
## The lead: *"There's no action from the computer player to use different formations or flanking maneuvers … a V
## formation of scouts from the gang coming at you would be scary."* Squads are classed by their members: fast (mostly
## scouts), support (mostly artillery or Lancers), line (the rest). Every THINK_TICKS_V3:
##   muster    nothing known yet: gather at a rally point ahead of base (line in a wedge, scouts in a V beside it,
##             support in a column behind) until gathered or MUSTER_MAX_TICKS
##   advance   still nothing known: the main line pushes toward the objective in a wedge, other line squads beside it,
##             scouts screen ahead in a V, support trails
##   engage    fresh contacts: the strongest line squad assaults their center; every other line squad swings to a flank
##             point off the axis (alternating sides) in a wedge and assaults from there; scouts charge in a V at the
##             enemy's artillery or Lancers (else behind the enemy line) and assault inside CHARGE_RANGE; support trails
##             the main line
##   pull back a squad worn below PULL_BACK_TOUGHNESS breaks contact to the rally point until back above READY_TOUGHNESS
##   withdraw  clearly weaker (WITHDRAW_RATIO) with the enemy still beyond DISENGAGE_RANGE: everyone falls back to the rally
##             point until the odds recover (REENGAGE_RATIO) or the enemy comes close
## Selected with --green-commander=v3 / --rust-commander=v3 (read here, like brain variants).

const THINK_TICKS := SimClock.TICK_RATE * 2
const ASSAULT_RATIO := 1.25
const WITHDRAW_RATIO := 0.6
const BOUND_RANGE := 110.0
const REISSUE_METERS := 15.0
const ASSAULT_REISSUE_METERS := 30.0
## Don't break contact once the nearest enemy is this close (meters).
const DISENGAGE_RANGE := 45.0
## A contact seen within this many ticks is chased with ASSAULT rather than MOVE.
const FRESH_TICKS := SimClock.TICK_RATE * 10
## How far ahead of the squad a movement leg goes when there's nothing to go for.
const LEG := 50.0

## v3 (see the header).
const POLICIES := ["v2", "v3", "v4", "v5", "v6"]
## v6 since 2026-09-15: it beat plain x3 brains 45-19 over four same-army mirrors (unit_ai.md "A CPU that maneuvers").
const DEFAULT_POLICY := "v6"
const THINK_TICKS_V3 := 60
const RALLY_AHEAD := 40.0
const MUSTER_RADIUS := 25.0
const MUSTER_MAX_TICKS := SimClock.TICK_RATE * 12
const FLANK_OFFSET := 45.0
const FLANK_ARRIVE := 18.0
## A flanker still on its way assaults anyway when an enemy is this close to it (meters).
const FLANK_CONTACT := 30.0
const CHARGE_RANGE := 35.0
const SUPPORT_TRAIL := 40.0
const SCREEN_AHEAD := 40.0
const PULL_BACK_TOUGHNESS := 0.35
const READY_TOUGHNESS := 0.7
const REENGAGE_RATIO := 0.9
## v4 (v3 with three changes, measured against it): line squads flank only with this strength edge (else they all assault
## together), the advance spreads line squads ADVANCE_SPREAD_V4 apart, and scouts charge only artillery or Lancers
## (else they're left to spot, the lead's "scouts are spotters first").
const FLANK_EDGE_V4 := 1.15
const ADVANCE_SPREAD_V4 := 35.0
## v5 (v3 with one change): a line squad flanks only with at least this share of the main squad's strength; a lone IFV
## sent round the side just died (armor mirror: v3 4-12 against plain brains).
const FLANK_SHARE_V5 := 0.4
## v6 = v5's flanking rule + v4's wide advance and scout rule (the ladder: v5's flanking wins with tank-heavy armies, v4's
## scouts holding a firing screen win with light ones; see unit_ai.md "A CPU that maneuvers").

var game_match: Match
var team := Match.Team.RUST
## "v2" or "v3"; --<team>-commander=<policy> picks it at _ready.
var policy := DEFAULT_POLICY
## v3 state: the team's phase ("muster", "advance", "engage", "withdraw"), when it started, and squads resting.
var phase := "muster"
var _phase_tick := 0
var _resting := {}
## Squad name -> the last command sent.
var last_commands := {}
var _offset := 0


func _ready() -> void:
	# Lower priority runs first, like other deciders: commands are in place before brains think.
	process_physics_priority = -20
	_offset = 37 + team * 11  # stagger from the other team's commander
	var prefix := "--%s-commander=" % ["green", "rust"][team]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix) and POLICIES.has(arg.trim_prefix(prefix)):
			policy = arg.trim_prefix(prefix)


func _physics_process(_delta: float) -> void:
	var every := THINK_TICKS if policy == "v2" else THINK_TICKS_V3
	if game_match == null or (game_match.tick + _offset) % every != 0:
		return
	think()


func think() -> void:
	if policy != "v2":
		var by_name := game_match.tanks_by_name()
		var plans := plan_team(by_name)
		var names := plans.keys()
		names.sort()
		for squad_name: String in names:
			var command: Dictionary = plans[squad_name]
			if _worth_sending(squad_name, command) and game_match.command_squad(team, command) == "":
				last_commands[squad_name] = command
		return
	var by_name := game_match.tanks_by_name()
	for squad in game_match.team_squads(team):
		if not _is_gun_squad(squad, by_name):
			continue
		var command := plan_for(squad, by_name)
		if command.is_empty() or not _worth_sending(squad.squad_name, command):
			continue
		if game_match.command_squad(team, command) == "":
			last_commands[squad.squad_name] = command


static func _is_gun_squad(squad: Squad, by_name: Dictionary) -> bool:
	for member in squad.alive_members(by_name):
		var tank := by_name[member] as Tank
		return Units.PROFILES.get(tank.unit_id, {}).get("role", "tank") == "tank"
	return false


## The command this squad should be under right now ({} = leave it).
func plan_for(squad: Squad, by_name: Dictionary) -> Dictionary:
	var alive := squad.alive_members(by_name)
	if alive.is_empty():
		return {}
	var lead := by_name[squad.commander] as Tank
	var frame := Match.team_frame(team)
	var home := Match.spawn_position(team, 0)
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	var visible_sum := Vector3.ZERO
	var visible_count := 0
	var nearest_visible := INF
	var enemy_strength := 0.0
	var freshest: Variant = null
	var freshest_tick := -1
	for contact_name in names:
		var contact: Dictionary = intel[contact_name]
		enemy_strength += float(contact["health"]) + float(contact.get("shield", 0))
		if contact["visible"]:
			visible_sum += contact["position"]
			visible_count += 1
			nearest_visible = minf(nearest_visible, lead.global_position.distance_to(contact["position"]))
		if int(contact["seen_tick"]) > freshest_tick:
			freshest_tick = int(contact["seen_tick"])
			freshest = contact["position"]
	var our_strength := 0.0
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and Units.PROFILES.get(tank.unit_id, {}).get("role", "tank") != "artillery":
			our_strength += tank.health + tank.shield

	if visible_count > 0:
		var threat := visible_sum / visible_count
		var facing := threat - lead.global_position
		if our_strength <= enemy_strength * WITHDRAW_RATIO and nearest_visible > DISENGAGE_RANGE:
			return {"squad": squad.squad_name, "verb": "break_contact", "to": _clamp_xz(home)}
		if our_strength >= enemy_strength * ASSAULT_RATIO:
			return {"squad": squad.squad_name, "verb": "assault", "to": _clamp_xz(threat), "formation": "line"}
		# An even fight. v1 held here and lost 30 of 32 series matches to plain brains: with recharging
		# shields, standing still while the other side presses is how you lose. Hold only on the
		# objective; otherwise take the fight to them.
		if game_match.control_point and game_match.control_owner == team and Match.in_control_zone(lead.global_position):
			return {"squad": squad.squad_name, "verb": "hold", "to": _clamp_xz(lead.global_position),
					"facing": [facing.x, facing.z], "formation": "line"}
		return {"squad": squad.squad_name, "verb": "assault", "to": _clamp_xz(threat), "formation": "line"}

	if freshest != null and game_match.tick - freshest_tick <= FRESH_TICKS \
			and not (game_match.control_point and game_match.control_owner != team):
		return {"squad": squad.squad_name, "verb": "assault", "to": _clamp_xz(freshest), "formation": "line"}
	var goal: Vector3
	if game_match.control_point and game_match.control_owner != team:
		goal = Match.CONTROL_CENTER
	elif freshest != null:
		goal = freshest
	else:
		goal = lead.global_position + (frame["forward"] as Vector3) * LEG
	var verb := "bound" if freshest != null and lead.global_position.distance_to(goal) <= BOUND_RANGE else "move"
	return {"squad": squad.squad_name, "verb": verb, "to": _clamp_xz(goal), "formation": "wedge"}


func _worth_sending(squad_name: String, command: Dictionary) -> bool:
	var last: Dictionary = last_commands.get(squad_name, {})
	if last.is_empty() or last["verb"] != command["verb"] or last.get("formation", "") != command.get("formation", ""):
		return true
	var a := Vector2(float(last["to"][0]), float(last["to"][1]))
	var b := Vector2(float(command["to"][0]), float(command["to"][1]))
	return a.distance_to(b) >= (ASSAULT_REISSUE_METERS if command["verb"] == "assault" else REISSUE_METERS)


static func _clamp_xz(point: Vector3) -> Array:
	var limit := Squad.ARENA_LIMIT - 4.0
	return [clampf(point.x, -limit, limit), clampf(point.z, -limit, limit)]


# ---- Policy v3 ----------------------------------------------------------------------------------------------------

## "fast" (mostly scouts), "support" (mostly artillery or Lancers), or "line".
static func squad_class(squad: Squad, by_name: Dictionary) -> String:
	var counts := {"fast": 0, "support": 0, "line": 0}
	var alive := squad.alive_members(by_name)
	for member in alive:
		var role := Units.role_of((by_name[member] as Tank).unit_id)
		var kind := "fast" if role == "scout" else ("support" if role in ["artillery", "lancer"] else "line")
		counts[kind] += 1
	for kind: String in ["fast", "support"]:
		if counts[kind] * 2 >= alive.size() and counts[kind] > 0 and counts[kind] >= counts["line"]:
			return kind
	return "line"


## Every squad's command this think under policy v3 or v4: {squad name: SquadCommand}. Updates the team phase.
func plan_team(by_name: Dictionary) -> Dictionary:
	var v4 := policy == "v4"
	var wide_advance := policy == "v4" or policy == "v6"
	var flank_by_share := policy == "v5" or policy == "v6"
	var scouts_charge_fragile_only := policy == "v4" or policy == "v6"
	var frame := Match.team_frame(team)
	var forward: Vector3 = frame["forward"]
	var right: Vector3 = frame["right"]
	var home := Match.spawn_position(team, 0)
	var rally := home + forward * RALLY_AHEAD
	var squads: Array = []
	for squad in game_match.team_squads(team):
		if not squad.alive_members(by_name).is_empty():
			squads.append(squad)
	if squads.is_empty():
		return {}
	# What we know.
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	var fresh_sum := Vector3.ZERO
	var fresh_count := 0
	var enemy_strength := 0.0
	var fragile: Array = []
	for contact_name in names:
		var contact: Dictionary = intel[contact_name]
		enemy_strength += float(contact["health"]) + float(contact.get("shield", 0))
		if game_match.tick - int(contact["seen_tick"]) <= FRESH_TICKS:
			fresh_sum += contact["position"]
			fresh_count += 1
			if String(contact.get("role", Units.role_of(String(contact.get("unit", ""))))) in ["artillery", "lancer"]:
				fragile.append(contact["position"])
	var our_strength := 0.0
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive():
			our_strength += tank.health + tank.shield
	# The squads, by class; line squads strongest first (ties by name).
	var line: Array = []
	var fast: Array = []
	var support: Array = []
	for squad: Squad in squads:
		match CpuCommander.squad_class(squad, by_name):
			"fast":
				fast.append(squad)
			"support":
				support.append(squad)
			_:
				line.append(squad)
	line.sort_custom(func(a: Squad, b: Squad) -> bool:
		var sa := _strength(a, by_name)
		var sb := _strength(b, by_name)
		return sa > sb or (sa == sb and a.squad_name < b.squad_name))
	var main: Squad = line[0] if not line.is_empty() else squads[0]
	var main_center := _center(main, by_name)
	var enemy_center: Variant = fresh_sum / fresh_count if fresh_count > 0 else null
	var nearest_enemy := INF
	if enemy_center != null:
		nearest_enemy = main_center.distance_to(enemy_center)

	# The phase.
	var previous := phase
	if phase == "withdraw":
		if our_strength >= enemy_strength * REENGAGE_RATIO or nearest_enemy <= DISENGAGE_RANGE - 5.0:
			phase = "engage" if enemy_center != null else "advance"
	elif enemy_center != null and our_strength <= enemy_strength * WITHDRAW_RATIO and nearest_enemy > DISENGAGE_RANGE:
		phase = "withdraw"
	elif enemy_center != null:
		phase = "engage"
	elif phase == "muster":
		var gathered := true
		for squad: Squad in line:
			if _center(squad, by_name).distance_to(rally) > MUSTER_RADIUS:
				gathered = false
		if gathered or game_match.tick >= MUSTER_MAX_TICKS:
			phase = "advance"
	else:
		phase = "advance"
	if phase != previous:
		_phase_tick = game_match.tick

	var plans := {}
	# Worn squads rest first, whatever the phase.
	for squad: Squad in squads:
		var toughness := _toughness(squad, by_name)
		if _resting.has(squad.squad_name) and toughness >= READY_TOUGHNESS:
			_resting.erase(squad.squad_name)
		elif not _resting.has(squad.squad_name) and toughness < PULL_BACK_TOUGHNESS and phase == "engage" and squads.size() > 1:
			_resting[squad.squad_name] = true
		if _resting.has(squad.squad_name):
			plans[squad.squad_name] = _command(squad, "break_contact", rally, "column")

	var objective: Vector3 = Match.CONTROL_CENTER if game_match.control_point and game_match.control_owner != team \
			else Match.spawn_position(1 - team, 0)
	match phase:
		"muster":
			for squad: Squad in line:
				_plan(plans, squad, "move", rally + right * (float(line.find(squad)) * 20.0 * (1.0 if line.find(squad) % 2 == 0 else -1.0)), "wedge")
			for squad: Squad in fast:
				_plan(plans, squad, "move", rally + right * 30.0 + forward * 10.0, "vee")
			for squad: Squad in support:
				_plan(plans, squad, "move", rally - forward * 20.0, "column")
		"advance":
			var toward := _flat(objective - main_center)
			var direction := toward.normalized() if toward.length() > 1.0 else forward
			var across := Vector3(-direction.z, 0.0, direction.x)
			var goal := main_center + direction * minf(LEG, toward.length())
			_plan(plans, main, "move", goal, "wedge")
			for i in range(1, line.size()):
				var side := 1.0 if i % 2 == 1 else -1.0
				var spread := ADVANCE_SPREAD_V4 * float((i + 1) / 2) if wide_advance else 25.0
				_plan(plans, line[i], "move", goal + across * side * spread - direction * 5.0, "wedge")
			for i in fast.size():
				var side := -1.0 if i % 2 == 0 else 1.0
				_plan(plans, fast[i], "move", main_center + direction * SCREEN_AHEAD + across * side * 25.0, "vee")
			for squad: Squad in support:
				_plan(plans, squad, "move", main_center - direction * SUPPORT_TRAIL, "column")
		"engage":
			var target: Vector3 = enemy_center
			var axis := _flat(target - main_center)
			axis = axis.normalized() if axis.length() > 1.0 else forward
			var across := Vector3(-axis.z, 0.0, axis.x)
			_plan(plans, main, "assault", target, "line")
			var can_flank := not v4 or our_strength >= enemy_strength * FLANK_EDGE_V4
			for i in range(1, line.size()):
				var squad: Squad = line[i]
				var side := 1.0 if i % 2 == 1 else -1.0
				var flank_point := target + across * side * FLANK_OFFSET + axis * 10.0
				var at := _center(squad, by_name)
				var big_enough := not flank_by_share or _strength(squad, by_name) >= _strength(main, by_name) * FLANK_SHARE_V5
				if can_flank and big_enough and at.distance_to(flank_point) > FLANK_ARRIVE and _nearest_contact(at) > FLANK_CONTACT \
						and last_commands.get(squad.squad_name, {}).get("verb", "") != "assault":
					_plan(plans, squad, "move", flank_point, "wedge")
				else:
					_plan(plans, squad, "assault", target, "line")
			for squad: Squad in fast:
				if scouts_charge_fragile_only and fragile.is_empty():
					continue  # its last order stands: screening ahead of the line (it holds there and shoots)
				var at := _center(squad, by_name)
				var prey: Vector3 = target + axis * 20.0
				var best := INF
				for spot: Vector3 in fragile:
					if at.distance_to(spot) < best:
						best = at.distance_to(spot)
						prey = spot
				if at.distance_to(prey) > CHARGE_RANGE and last_commands.get(squad.squad_name, {}).get("verb", "") != "assault":
					_plan(plans, squad, "move", prey, "vee")
				else:
					_plan(plans, squad, "assault", prey, "vee")
			for squad: Squad in support:
				_plan(plans, squad, "move", main_center - axis * SUPPORT_TRAIL, "column")
		"withdraw":
			for squad: Squad in squads:
				if CpuCommander.squad_class(squad, by_name) == "support":
					_plan(plans, squad, "move", rally - forward * 20.0, "column")
				else:
					_plan(plans, squad, "break_contact", rally, "wedge")
	return plans


func _plan(plans: Dictionary, squad: Squad, verb: String, to: Vector3, formation: String) -> void:
	if not plans.has(squad.squad_name):
		plans[squad.squad_name] = _command(squad, verb, to, formation)


static func _command(squad: Squad, verb: String, to: Vector3, formation: String) -> Dictionary:
	return {"squad": squad.squad_name, "verb": verb, "to": _clamp_xz(to), "formation": formation}


static func _center(squad: Squad, by_name: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	var alive := squad.alive_members(by_name)
	for member in alive:
		sum += (by_name[member] as Tank).global_position
	return _flat(sum / maxf(alive.size(), 1))


static func _strength(squad: Squad, by_name: Dictionary) -> float:
	var total := 0.0
	for member in squad.alive_members(by_name):
		total += (by_name[member] as Tank).health + (by_name[member] as Tank).shield
	return total


## Hull + shield left over the members' full loads.
static func _toughness(squad: Squad, by_name: Dictionary) -> float:
	var left := 0.0
	var full := 0.0
	for member in squad.alive_members(by_name):
		var tank := by_name[member] as Tank
		left += tank.health + tank.shield
		full += tank.max_health + tank.max_shield
	return left / maxf(full, 1.0)


## Distance from `at` to the nearest fresh contact (INF with none).
func _nearest_contact(at: Vector3) -> float:
	var best := INF
	for contact: Dictionary in (game_match.intel[team] as Dictionary).values():
		if game_match.tick - int(contact["seen_tick"]) <= FRESH_TICKS:
			best = minf(best, at.distance_to(contact["position"]))
	return best


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
