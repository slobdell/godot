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
var _last_tick := -1


static func install(p_match: Match, p_team: int, p_elements: Elements = null) -> ElementCommander:
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
	var tick: int = game_match.tick
	if tick == _last_tick or tick % THINK_TICKS != 0:
		return
	_last_tick = tick
	if elements.of_team(team).is_empty():
		form_elements()
	think()


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
	var axis := _axis(mine, objective)
	var focus: Dictionary = contacts[0] if not contacts.is_empty() else {}
	# Round-5 X3/X5: a table can ask for the pin-and-flank plan the offline discovery harness found (traits.commander).
	if String(mine[0].table.traits.get("commander", "direct")) == "pin_and_flank" if mine[0].table != null else false:
		_pin_and_flank(line, focus, objective)
		line = []

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
	if not previous.is_empty() and String(previous.get("verb", "")) == String(task["verb"]):
		if String(previous.get("target", "")) == String(task.get("target", "")):
			var moved := true
			if previous.has("to") and task.has("to"):
				moved = Vector2(float(previous["to"][0]) - float(task["to"][0]),
						float(previous["to"][1]) - float(task["to"][1])).length() > REASSIGN_M
			if not moved:
				return
	var error := element.assign(task)
	if error == "":
		assigned[element.id] = task


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


## Where the team is going when nothing is known: the control point if there is one, else the enemy's ground.
func _objective() -> Vector3:
	if game_match.control_point:
		return Match.CONTROL_CENTER
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
