class_name ElementCommander
extends Node
## A commander that plays the doctrine layer the way a player does (doctrine X5): it forms ELEMENTS from a
## team's squads and gives them TASKS — move, attack, screen, support by fire, hold — and nothing else. Every
## formation, movement technique and battle drill below that line is the shared library in `game/tactics/`,
## so there is no CPU-only tactic. The lead (2026-09-16): *"if the opposing computer player can easily create
## sophisticated formations all the time while the player can't … it would be no good."*
##
##   var commander := ElementCommander.install(game_match, Match.Team.RUST)
##
## Deterministic: it thinks on Match.tick, in element id order, and never reads a clock or a random number.
## ai owns the unit brains and the squad-level CpuCommander; this is the element layer between them, and it
## is deliberately small — the interesting decisions belong to the leaders.

## How often the commander re-thinks (ticks). Elements re-plan far more often than this on their own.
const THINK_TICKS := SimClock.TICK_RATE
## A task is only re-assigned when the verb changes or its destination moves this far (meters): re-assigning
## resets the element's movement leg and any drill it was running.
const REASSIGN_M := 25.0
## Round 6 (X6): a task is kept at least this long before it changes (unless its target is gone), and a change of target
## or point under the SAME verb re-aims the element (Element.retarget) instead of starting it over. `make squad-coherence`
## caught the commander re-giving attack and support-by-fire every think in a brawl — "the nearest contact" changes
## every second when thirty vehicles meet — and every re-assignment reset the element's drill and firing line.
const KEEP_TASK_TICKS := SimClock.TICK_RATE * 6
## Elements are formed this big when a team has no squads to form them from.
const ELEMENT_SIZE := 4
## How far ahead of the main body the recon element screens, and how far behind the support element trails.
const SCREEN_AHEAD_M := 45.0
const SUPPORT_BEHIND_M := 45.0
## An element attacks a contact this close to the axis of advance rather than driving past it.
const ENGAGE_M := 110.0
## Pin and flank: how far off the base of fire's line the flanking elements swing, when they count as there, how far
## a lane may pull that point sideways, which lanes count as flanks (not the centre), and when a lane-bound element is
## level enough with the objective to turn in.
const FLANK_M := 45.0
const FLANK_ARRIVED_M := 20.0
const LANE_SNAP_M := 25.0
const LANE_MIN_OFFSET_M := 20.0
const LANE_LEVEL_M := 30.0

var game_match: Match
var team := Match.Team.RUST
var elements: Elements
## element id -> the task it was last given.
var assigned := {}
## element id -> the tick it was given it.
var assigned_tick := {}
var _last_tick := -1
## X8: the army plan's state between thinks (roles, when the main effort's fight began).
var _army_state := {}
## Round 18 (brains): AMBUSH. One line element out of contact lies in ambush on the enemy's way to our objective when
## AmbushSite finds a spot hidden from it on the flank of open ground it must cross (parade's bays). It gives the ambush
## up when it has not been sprung after AMBUSH_PATIENCE_TICKS with nobody within its reach of the kill zone, or once
## the enemy has gone past the kill zone; then AMBUSH_COOLDOWN_TICKS before that element may take another.
static var AMBUSH_ENABLED := true
const AMBUSH_OUT_OF_CONTACT_M := 60.0
const AMBUSH_PATIENCE_TICKS := SimClock.TICK_RATE * 30
const AMBUSH_COOLDOWN_TICKS := SimClock.TICK_RATE * 20
## An ambush is taken only if the element can be in place this long before the enemy, assumed to come at this speed,
## reaches the kill zone.
const AMBUSH_MARGIN_S := 4.0
const AMBUSH_ENEMY_MPS := 9.0
## element id -> {"spot", "zone", "since", "reach"} while it lies in ambush; element id -> tick its cooldown ends.
var ambushes := {}
var _ambush_cooldown := {}
## How many ambushes were taken and sprung (probes and tests).
var ambushes_taken := 0
var ambushes_sprung := 0
## Round 19 (census): why no ambush was taken, counted per element per think: {"in_contact", "no_site", "late"}.
var ambush_refused := {"in_contact": 0, "no_site": 0, "late": 0}
## Round 19 (brains B2): the POSTURE (Posture.decide), re-read every think from the match's score and the objectives'
## owners (C19.4: polled until board's score_changed lands). A HOLD is kept at least POSTURE_KEEP_TICKS so one second's
## score does not flip the army back and forth; it ends at once if the side no longer holds the zone.
static var POSTURE_ENABLED := true
const POSTURE_KEEP_TICKS := SimClock.TICK_RATE * 10
## Holding: the line's posts are spread this far apart across the enemy's approach, at the zone; recon screens this
## far out toward the enemy; an ambush laid for a defence waits this long before it is given up unsprung.
const HOLD_POST_SPACING_M := 22.0
const HOLD_AMBUSH_PATIENCE_TICKS := SimClock.TICK_RATE * 90
## Stretch (a): holding with an ambush laid, the support element fires on the ambush's kill zone (tests switch it off).
var REGISTER_ON_KILL_ZONE := true
## {"posture", "zone", "why", "since"}: the last decision (probes, tests, the census).
var posture := {"posture": "attack", "zone": {}, "why": "", "since": -1}
## How many think cycles were spent holding (census).
var hold_thinks := 0


static func install(p_match: Match, p_team: int, p_elements: Elements = null) -> ElementCommander:
	# Round 18: `--no-cpu-ambush` is the ambush's control arm for series and ladders (the switch is per process).
	if OS.get_cmdline_user_args().has("--no-cpu-ambush"):
		AMBUSH_ENABLED = false
	# Round 19: `--no-cpu-hold` is the posture's control arm (the commander always attacks, as in round 18).
	if OS.get_cmdline_user_args().has("--no-cpu-hold"):
		POSTURE_ENABLED = false
	var commander := ElementCommander.new()
	commander.name = "ElementCommander_%d" % p_team
	commander.game_match = p_match
	commander.team = p_team
	commander.elements = p_elements if p_elements != null else Elements.install(p_match)
	p_match.add_child(commander)
	return commander


func _ready() -> void:
	process_physics_priority = Elements.PRIORITY - 1


## Form one element per squad (or blocks of ELEMENT_SIZE when the team has no squads). Safe to call again:
## units already in an element of ours are left alone.
func form_elements() -> Array:
	var made: Array = []
	var squads := game_match.team_squads(team)
	if not squads.is_empty():
		for squad: Squad in squads:
			var roster: Array = []
			for unit_name in squad.roster:
				var tank := _tank(unit_name)
				if tank != null and tank.is_alive() and elements.of(unit_name) == null:
					roster.append(unit_name)
			if not roster.is_empty():
				made.append(elements.form(roster, squad.squad_name))
		return made
	var loose: Array = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and elements.of(String(tank.name)) == null:
			loose.append(String(tank.name))
	while not loose.is_empty():
		var block := loose.slice(0, ELEMENT_SIZE)
		loose = loose.slice(ELEMENT_SIZE)
		made.append(elements.form(block, "E%d" % (made.size() + 1)))
	return made


func _physics_process(_delta: float) -> void:
	if game_match == null or not game_match.simulate or elements == null:
		return
	# A CPU commander never commands the side a human is commanding: that army takes its orders from the player alone.
	if team == OrderFeed.player_team(game_match):
		return
	var tick: int = game_match.tick
	if tick == _last_tick or tick % THINK_TICKS != 0:
		return
	_last_tick = tick
	if elements.of_team(team).is_empty():
		form_elements()
	think()
	if TankBrain.census and tick % (SimClock.TICK_RATE * 15) == 0:
		print("BRAINS_AMBUSH_T team %d t=%ds posture %s taken %d refused %s" % [team, tick / SimClock.TICK_RATE,
				posture["posture"], ambushes_taken, ambush_refused])


## One planning cycle: classify our elements, then give each one a task.
func think() -> void:
	var mine := elements.of_team(team)
	if mine.is_empty():
		return
	var objective := _objective()
	var contacts := _contacts()
	var line: Array = []
	var recon: Array = []
	var support: Array = []
	for element: Element in mine:
		match _class_of(element):
			"recon":
				recon.append(element)
			"support":
				support.append(element)
			_:
				line.append(element)
	# X8: a table can ask for the army layer (traits.commander = "army", the ladder's "+army").
	if String(mine[0].table.traits.get("commander", "direct")) == "army" if mine[0].table != null else false:
		_army(mine, objective, contacts)
		return
	var axis := _axis(mine, objective)
	var focus: Dictionary = contacts[0] if not contacts.is_empty() else {}
	# Round-5 X3/X5: a table can ask for the pin-and-flank plan the offline discovery harness found (traits.commander).
	if String(mine[0].table.traits.get("commander", "direct")) == "pin_and_flank" if mine[0].table != null else false:
		_pin_and_flank(line, focus, objective)
		line = []

	# Round 19 (B2): a side ahead on points, or whose zone is threatened, HOLDS: its line posts over the zone and one
	# element lies in ambush on the flank of the enemy's way to it. Behind, it attacks as before.
	if _hold_posture(contacts):
		_hold(line, recon, support, contacts)
		return
	line = _plan_ambush(line, contacts, objective)
	for i in line.size():
		var element: Element = line[i]
		if focus.is_empty():
			_give(element, {"verb": "move", "to": _xz(objective)})
		elif i == 0:
			_give(element, {"verb": "attack", "target": String(focus["name"])})
		else:
			# Everyone else in the fight pins them from where they can see them.
			_give(element, {"verb": "support_by_fire", "to": _xz(focus["position"])})
	for element: Element in recon:
		# Scouts are spotters first (game_design.md): screen ahead of the axis, never charge alone.
		var ahead: Vector3 = (focus["position"] if not focus.is_empty() else objective)
		_give(element, {"verb": "screen", "to": _xz(_toward(_center(element), ahead, SCREEN_AHEAD_M))})
	for element: Element in support:
		if focus.is_empty():
			_give(element, {"verb": "move", "to": _xz(objective - axis * SUPPORT_BEHIND_M)})
		else:
			_give(element, {"verb": "support_by_fire", "to": _xz(focus["position"])})


## Round 18 (census only): what the ambush did this match.
func _exit_tree() -> void:
	if TankBrain.census:
		print("BRAINS_AMBUSH team %d taken %d sprung %d hold_s %d refused in_contact %d no_site %d late %d" % [team,
				ambushes_taken, ambushes_sprung, hold_thinks * THINK_TICKS / SimClock.TICK_RATE,
				int(ambush_refused["in_contact"]), int(ambush_refused["no_site"]), int(ambush_refused["late"])])


## Round 18: keep, drop or take an ambush; returns the line elements NOT lying in ambush (they get the usual tasks).
## `holding`: the side defends `objective` (its zone): the site is searched from the zone, not from the element, and the
## ambush is kept longer.
func _plan_ambush(line: Array, contacts: Array, objective: Vector3, holding := false) -> Array:
	if not AMBUSH_ENABLED:
		for element: Element in line:
			_drop_ambush(element)
		return line
	# Where the enemy comes from: the centre of what we know of it, or before contact its base (an ambush is set before
	# they arrive, on the way they must come).
	var enemy := _enemy_center(contacts)
	var patience := HOLD_AMBUSH_PATIENCE_TICKS if holding else AMBUSH_PATIENCE_TICKS
	var free: Array = []
	for element: Element in line:
		if not ambushes.has(element.id):
			free.append(element)
			continue
		var held: Dictionary = ambushes[element.id]
		var zone: Vector3 = held["zone"]
		var sprung := element.drill == "spring_ambush"
		if sprung and not bool(held.get("sprung", false)):
			held["sprung"] = true
			ambushes_sprung += 1
		var near_zone := _nearest_contact(contacts, zone) <= float(held["reach"])
		var past := TacticsFormation.flat(objective - enemy).dot(zone - enemy) < 0.0
		if (not sprung and not near_zone and game_match.tick - int(held["since"]) >= patience) \
				or (past and not near_zone):
			_drop_ambush(element)
			_ambush_cooldown[element.id] = game_match.tick + AMBUSH_COOLDOWN_TICKS
			free.append(element)
	if not ambushes.is_empty():
		return free
	# Take one: the free line element out of contact with the nearest site.
	var best: Element = null
	var best_site := {}
	for element: Element in free:
		if game_match.tick < int(_ambush_cooldown.get(element.id, -1)):
			continue
		var center := _center(element)
		if _nearest_contact(contacts, center) <= AMBUSH_OUT_OF_CONTACT_M:
			ambush_refused["in_contact"] += 1
			continue
		var reach := _reach_of(element)
		var probe := _first_tank(element)
		if probe == null:
			continue
		var site := _find_site(CoverMap.of(probe), objective if holding else center, enemy, objective, reach)
		if site.is_empty():
			ambush_refused["no_site"] += 1
			continue
		# In place before they arrive: the element reaches its spot (straight line, its slowest crew) with
		# AMBUSH_MARGIN_S to spare before the enemy (assumed AMBUSH_ENEMY_MPS) reaches the kill zone. Without it the CPU
		# was caught driving to its spot on the open floor (his squad across parade: sprung 5 times in 8, from a bay 0).
		var mine_s := center.distance_to(site["spot"]) / maxf(_slowest_speed(element), 0.5)
		var theirs_s := enemy.distance_to(site["zone"]) / AMBUSH_ENEMY_MPS
		if mine_s + AMBUSH_MARGIN_S > theirs_s:
			ambush_refused["late"] += 1
			continue
		if best_site.is_empty() or center.distance_to(site["spot"]) < _center(best).distance_to(best_site["spot"]):
			best = element
			best_site = site
	if best == null:
		return free
	var spot: Vector3 = best_site["spot"]
	var zone: Vector3 = best_site["zone"]
	ambushes[best.id] = {"spot": spot, "zone": zone, "since": game_match.tick, "reach": _reach_of(best)}
	ambushes_taken += 1
	_give(best, {"verb": "ambush", "to": _xz(zone), "from": _xz(spot)})
	free.erase(best)
	return free


## Round 19 (B3): AmbushSite.find, memoised for this think: holding, every free element searches from the same zone
## toward the same enemy, so one search answers all of them (the same arguments give the same answer: it is pure).
var _site_memo := {}
var _site_memo_tick := -1


func _find_site(cover: CoverMap, origin: Vector3, enemy: Vector3, objective: Vector3, reach: float) -> Dictionary:
	if game_match.tick != _site_memo_tick:
		_site_memo_tick = game_match.tick
		_site_memo.clear()
	var key := [cover.get_instance_id(), origin, enemy, objective, reach]
	if not _site_memo.has(key):
		_site_memo[key] = AmbushSite.find(cover, origin, enemy, objective, reach)
	return _site_memo[key]


## Where the enemy comes from: the centre of what we know of it, or before contact its base (an ambush is set before
## they arrive, on the way they must come).
func _enemy_center(contacts: Array) -> Vector3:
	if contacts.is_empty():
		var base := Match.spawn_position(1 - team, 0)
		return Vector3(base.x, 0.0, base.z)
	var enemy := Vector3.ZERO
	for contact: Dictionary in contacts:
		enemy += Vector3((contact["position"] as Vector3).x, 0.0, (contact["position"] as Vector3).z)
	return enemy / float(contacts.size())


## Round 19 (B2): decide the posture this think (Posture.decide over the match's score and objectives); true = hold.
func _hold_posture(contacts: Array) -> bool:
	if not POSTURE_ENABLED or not Objectives.active(game_match):
		return false
	var decided := Posture.decide(team, game_match.control_score, Objectives.all(game_match), contacts,
			_enemy_center(contacts))
	var was_holding := String(posture["posture"]) == "hold"
	var keep := was_holding and String(decided["posture"]) == "attack" \
			and game_match.tick - int(posture["since"]) < POSTURE_KEEP_TICKS \
			and int((posture["zone"] as Dictionary).get("owner", -1)) == team
	if keep:
		return true
	if String(decided["posture"]) != String(posture["posture"]) \
			or String((decided["zone"] as Dictionary).get("name", "")) != String((posture["zone"] as Dictionary).get("name", "")):
		decided["since"] = game_match.tick
		if TankBrain.census:
			print("BRAINS_POSTURE team %d t=%ds %s %s" % [team, game_match.tick / SimClock.TICK_RATE, decided["posture"],
					decided["why"]])
	else:
		decided["since"] = posture["since"]
	posture = decided
	if String(posture["posture"]) != "hold":
		return false
	hold_thinks += 1
	return true


## Round 19 (B2): HOLD the zone. One line element lies in ambush on the flank of the enemy's way to the zone (the site
## searched from the zone, taken only if it can be in place in time); the rest of the line posts across the zone facing
## the approach and fights what comes into it; recon screens out toward the enemy; support stands behind the zone.
func _hold(line: Array, recon: Array, support: Array, contacts: Array) -> void:
	var zone_info: Dictionary = posture["zone"]
	var zone: Vector3 = zone_info["position"]
	zone = Vector3(zone.x, 0.0, zone.z)
	var enemy := _enemy_center(contacts)
	var toward := TacticsFormation.flat(enemy - zone)
	var across := Vector3(-toward.z, 0.0, toward.x)
	line = _plan_ambush(line, contacts, zone, true)
	# Who is in (or at the edge of) the zone: the nearest one is attacked by the first post; everyone else holds.
	var intruder := {}
	var intruder_d := INF
	for contact: Dictionary in contacts:
		var d := Vector2((contact["position"] as Vector3).x - zone.x, (contact["position"] as Vector3).z - zone.z).length()
		if d <= float(zone_info.get("radius", 15.0)) + 10.0 and d < intruder_d - 0.001:
			intruder = contact
			intruder_d = d
	for i in line.size():
		var element: Element = line[i]
		if i == 0 and not intruder.is_empty():
			_give(element, {"verb": "attack", "target": String(intruder["name"])})
			continue
		var post := ElementPlan.clamp_to_arena(zone + across * (float(i) - float(line.size() - 1) * 0.5) * HOLD_POST_SPACING_M)
		# No contact drill: a post that reacts to contact, or assaults through a near ambush, leaves the zone it holds
		# (the first parade stage: react_to_contact took the post 30 m off the depot, assault_through 50 m). Its crews
		# hold their places and shoot what they see; the commander decides when to go for an intruder (above).
		_give(element, {"verb": "hold", "to": _xz(post), "facing": _xz(toward), "drills": false})
	for element: Element in recon:
		var out := ElementPlan.clamp_to_arena(zone + toward * SCREEN_AHEAD_M)
		_give(element, {"verb": "screen", "to": _xz(out)})
	# Stretch (a): with an ambush laid, the support element (artillery, Lancers) is REGISTERED on its kill zone: once
	# there is contact its fire goes where the ambush springs, not at the nearest contact.
	var kill_zone: Variant = null
	for held: Dictionary in ambushes.values():
		kill_zone = held["zone"]
	for element: Element in support:
		if contacts.is_empty():
			_give(element, {"verb": "hold", "to": _xz(ElementPlan.clamp_to_arena(zone - toward * SUPPORT_BEHIND_M)),
					"facing": _xz(toward)})
		elif kill_zone is Vector3 and REGISTER_ON_KILL_ZONE:
			_give(element, {"verb": "support_by_fire", "to": _xz(kill_zone)})
		else:
			_give(element, {"verb": "support_by_fire", "to": _xz(contacts[0]["position"])})


func _drop_ambush(element: Element) -> void:
	ambushes.erase(element.id)


func _nearest_contact(contacts: Array, point: Vector3) -> float:
	var nearest := INF
	for contact: Dictionary in contacts:
		var at: Vector3 = contact["position"]
		nearest = minf(nearest, Vector2(at.x - point.x, at.z - point.z).length())
	return nearest


## The SHORTEST effective range among the element's living crews: an ambush lies no farther off the kill zone than every
## gun in it can hit well from (lying at a cannon's 70 m maximum with a 45 m effective band, the first stage lost four
## tanks to a line whose 62 m guns out-ranged them; without the ambush the same four won).
func _reach_of(element: Element) -> float:
	var reach := INF
	for unit_name in element.members():
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive():
			reach = minf(reach, float(tank.weapon.get("effective_range", tank.weapon.get("range", 60.0))))
	return reach if is_finite(reach) else 0.0


func _slowest_speed(element: Element) -> float:
	var slowest := INF
	for unit_name in element.members():
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive():
			slowest = minf(slowest, tank.max_forward_speed)
	return slowest if is_finite(slowest) else 0.0


func _first_tank(element: Element) -> Tank:
	for unit_name in element.members():
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive():
			return tank
	return null


## X8: every element's role and task from ArmyPlan (main effort, base of fire, shaping, reserve).
func _army(mine: Array, objective: Vector3, contacts: Array) -> void:
	var described: Array = []
	for element: Element in mine:
		var hp := 0.0
		var full := 0.0
		var alive := 0
		for unit_name in element.members():
			var tank := _tank(unit_name)
			if tank != null:
				full += tank.max_health
				if tank.is_alive():
					hp += tank.health
					alive += 1
		described.append({"id": element.id, "class": _class_of(element), "center": _center(element),
				"strength": hp / maxf(full, 1.0), "size": alive})
	var known: Array = []
	for contact: Dictionary in contacts:
		var intel: Dictionary = game_match.intel[team].get(String(contact["name"]), {})
		known.append({"name": contact["name"], "position": contact["position"],
				"pinned": float(intel.get("suppression", 0.0)) >= Tank.PINNED_SUPPRESSION})
	var context := {"objective": objective, "hold_ground": Objectives.active(game_match),
			"home": Match.spawn_position(team, 0), "lanes": _lane_offsets(), "tick": game_match.tick}
	_army_state = ArmyPlan.plan(described, known, context, _army_state)
	for element: Element in mine:
		var task: Variant = (_army_state["tasks"] as Dictionary).get(element.id)
		if task is Dictionary:
			_give(element, task)


## Pin and flank (round 5, first distilled from tools/discovery.py's `pin_and_flank` policy, which beat standard
## doctrine's direct plan in its first run): with a known enemy, the biggest line element becomes the base of fire on it
## and every other line element swings wide round it — to a point FLANK_M off the line of fire, on alternate sides,
## pulled onto the nearest annotated lane when the arena has them (arena's lanes were used 4-5% of unit-time) — and only
## then attacks. With nothing known, one element takes the direct route and the others take the outer lanes.
func _pin_and_flank(line: Array, focus: Dictionary, objective: Vector3) -> void:
	if line.is_empty():
		return
	var ordered := line.duplicate()
	ordered.sort_custom(func(a: Element, b: Element) -> bool:
		return a.members().size() > b.members().size() or (a.members().size() == b.members().size() and a.id < b.id))
	var lanes := _lane_offsets()
	if focus.is_empty():
		for i in ordered.size():
			var element: Element = ordered[i]
			if i == 0 or lanes.is_empty():
				_give(element, {"verb": "move", "to": _xz(objective)})
				continue
			# Outer lanes first, alternating sides, then in toward the objective once level with it.
			var lateral: float = lanes[(i - 1) % lanes.size()] * (1.0 if i % 2 == 1 else -1.0)
			var here := _center(element)
			var along := Vector3(objective.x + lateral, 0.0, objective.z)
			var level := absf(here.z - objective.z) < LANE_LEVEL_M
			_give(element, {"verb": "move", "to": _xz(ElementPlan.clamp_to_arena(objective if level else along))})
		return
	var target: Vector3 = focus["position"]
	var base: Element = ordered[0]
	var base_at := _center(base)
	_give(base, {"verb": "support_by_fire", "to": _xz(target), "target": String(focus["name"])})
	var line_of_fire := TacticsFormation.flat(target - base_at)
	var across := Vector3(-line_of_fire.z, 0.0, line_of_fire.x)
	for i in range(1, ordered.size()):
		var element: Element = ordered[i]
		var side := 1.0 if i % 2 == 1 else -1.0
		var wide: Vector3 = target + across * FLANK_M * side
		if not lanes.is_empty():
			wide.x = _snap_to_lane(wide.x, lanes)
		wide = ElementPlan.clamp_to_arena(wide)
		if _center(element).distance_to(wide) > FLANK_ARRIVED_M and String(element.task.get("verb", "")) != "attack":
			_give(element, {"verb": "move", "to": _xz(wide)})
		else:
			_give(element, {"verb": "attack", "target": String(focus["name"])})


## The arena's lanes as absolute lateral offsets from the centre line (x at the lane's midpoint), outermost first.
func _lane_offsets() -> Array:
	var offsets: Array = []
	for lane: Dictionary in Arena.lanes_of(Arena.active):
		var points: PackedVector3Array = lane["points"]
		var middle: Vector3 = points[points.size() / 2]
		var offset := absf(middle.x)
		if offset >= LANE_MIN_OFFSET_M and not offsets.has(offset):
			offsets.append(offset)
	offsets.sort()
	offsets.reverse()
	return offsets


static func _snap_to_lane(x: float, lanes: Array) -> float:
	var best := x
	var best_gap := INF
	for offset: float in lanes:
		for signed: float in [offset, -offset]:
			if absf(signed - x) < best_gap:
				best_gap = absf(signed - x)
				best = signed
	return best if best_gap <= LANE_SNAP_M else x


## Give an element a task, unless it is already doing that.
func _give(element: Element, task: Dictionary) -> void:
	var previous: Dictionary = assigned.get(element.id, {})
	var same_verb := not previous.is_empty() and String(previous.get("verb", "")) == String(task["verb"])
	if same_verb:
		var same_target := String(previous.get("target", "")) == String(task.get("target", ""))
		var moved := false
		if previous.has("to") and task.has("to"):
			moved = Vector2(float(previous["to"][0]) - float(task["to"][0]),
					float(previous["to"][1]) - float(task["to"][1])).length() > REASSIGN_M
		if same_target and not moved:
			return
		# Held long enough, and is the old target still there to fight? Otherwise keep what we are doing.
		var held: int = game_match.tick - int(assigned_tick.get(element.id, -KEEP_TASK_TICKS))
		if held < KEEP_TASK_TICKS and _still_there(String(previous.get("target", ""))):
			return
		# Same verb, new aim: re-aim without starting the element over.
		if element.retarget(task) == "":
			assigned[element.id] = task
			assigned_tick[element.id] = game_match.tick
		return
	var error := element.assign(task)
	if error == "":
		assigned[element.id] = task
		assigned_tick[element.id] = game_match.tick


## Whether a named enemy is alive and known to this team ("" = no target: nothing to lose).
func _still_there(target: String) -> bool:
	if target == "":
		return true
	var tank := _tank(target)
	return tank != null and tank.is_alive() and game_match.intel[team].has(target)


## What this element is for: mostly scouts = recon, mostly artillery or Lancers = support, else the line.
func _class_of(element: Element) -> String:
	var roles: Array = []
	for unit_name in element.members():
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive():
			roles.append({"role": Units.role_of(tank.unit_id)})
	return {"light": "recon", "support": "support"}.get(ElementSituation.composition_of(roles), "line")


## Known enemies, nearest to our side first.
func _contacts() -> Array:
	var home := Match.spawn_position(team, 0)
	var contacts: Array = []
	for contact_name: String in game_match.intel[team]:
		var contact: Dictionary = game_match.intel[team][contact_name]
		contacts.append({"name": contact_name, "position": contact["position"],
				"distance": home.distance_to(contact["position"])})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["distance"]) - float(b["distance"])) > 0.001:
			return float(a["distance"]) < float(b["distance"])
		return String(a["name"]) < String(b["name"]))
	return contacts


## Where the team is going when nothing is known: the objective to go for from our base (the nearest we do not hold,
## else the nearest we do) if there are objectives, else the enemy's ground.
## Tests: the objective the commander fights for, instead of the match's (null = the match's).
var objective_override: Variant = null


func _objective() -> Vector3:
	if objective_override is Vector3:
		return objective_override
	var target := Objectives.goal(game_match, team, Match.spawn_position(team, 0))
	if not target.is_empty():
		return target["position"]
	return Match.spawn_position(1 - team, 0) * 0.75


func _axis(mine: Array, objective: Vector3) -> Vector3:
	var center := Vector3.ZERO
	for element: Element in mine:
		center += _center(element)
	center /= float(maxi(mine.size(), 1))
	return TacticsFormation.flat(objective - center)


func _center(element: Element) -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for unit_name in element.members():
		var tank := _tank(unit_name)
		if tank != null and tank.is_alive():
			center += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			count += 1
	return center / float(maxi(count, 1))


static func _toward(from: Vector3, to: Vector3, distance: float) -> Vector3:
	var step := TacticsFormation.flat(to - from) * distance
	var point: Vector3 = to - step if from.distance_to(to) > distance else to
	return ElementPlan.clamp_to_arena(point)


static func _xz(point: Vector3) -> Array:
	return [point.x, point.z]


func _tank(unit_name: String) -> Tank:
	if game_match == null or game_match.tanks == null:
		return null
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
