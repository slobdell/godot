class_name Elements
extends Node
## The elements of one match (contract L1, doctrine X1): form them, find the one a unit belongs to, disband
## them, and run every leader's decision cycle on the simulating peer. One node per match, reachable with
## `Elements.of_match(match)`.
##
##   var elements := Elements.install(game_match)              # or Elements.of_match(match) if it's there
##   var alpha := elements.form(["Green_Alpha_1", ...], "Alpha")
##   alpha.assign({"verb": "move", "to": [0, -40]})            # ElementTask; the leader does the rest
##   elements.of("Green_Alpha_1") == alpha
##   elements.element_changed.connect(...)                     # the HUD redraws element id
##
## A unit belongs to at most one element: forming a new one takes its members out of their old elements.
## Leaders decide every UPDATE_TICKS ticks, in element id order, so the same seed always plays the same way.

## The HUD's cue: this element's formation, technique, drill, reason, leader or roster changed.
signal element_changed(id: int)
## A decision worth talking about, as structured data in the announcer's K5 shape (ElementReport): a drill
## starting, or an element changing shape or movement technique. Doctrine publishes; audio writes the words.
signal element_reported(event: Dictionary)
## A leader was destroyed and `successor` took over (empty when the whole element is gone).
signal leader_lost(id: int, fallen: String, successor: String)

const UPDATE_TICKS := Element.UPDATE_TICKS
## Elements run before brains think (they set the orders the brains execute this tick).
const PRIORITY := -30
## Anyone who wants the decisions (the announcer's MatchEventAdapter) finds this node by group, so nothing
## outside game/tactics/ has to name the Elements class to listen — it doesn't exist on their branch until
## the checkpoint merges, and a file that names it wouldn't compile (audio, 2026-09-16).
const GROUP := "elements"

var game_match: Match
var orders: Object
## id -> Element, in creation order.
var by_id := {}
var _by_unit := {}
var _next_id := 1
var _last_tick := -1
## element id -> {report key: the tick it was last published}, so the booth isn't told the same thing twice.
var _reported := {}


## The Elements of `game_match`, or null.
static func of_match(p_match: Match) -> Elements:
	if p_match == null:
		return null
	if p_match.has_meta("elements"):
		var found: Variant = p_match.get_meta("elements")
		if found is Elements and is_instance_valid(found):
			return found
	return null


## Create (or return) the Elements node for `game_match`, wired to its K1 Orders.
static func install(p_match: Match, p_orders: Object = null) -> Elements:
	var existing := of_match(p_match)
	if existing != null:
		return existing
	var elements := Elements.new()
	elements.name = "Elements"
	elements.game_match = p_match
	elements.orders = p_orders if p_orders != null else OrderFeed.source(p_match)
	p_match.set_meta("elements", elements)
	p_match.add_child(elements)
	return elements


func _ready() -> void:
	process_physics_priority = PRIORITY
	add_to_group(GROUP)


## Form an element from `units` (all on one team). They leave any element they were in.
func form(units: Array, element_name := "", table: DoctrineTable = null) -> Element:
	var roster: PackedStringArray = []
	var team := 0
	for unit: Variant in units:
		var unit_name := String(unit)
		if roster.has(unit_name):
			continue
		var tank := _tank(unit_name)
		if tank == null or not tank.is_alive():
			continue
		team = tank.team
		var previous: Element = _by_unit.get(unit_name)
		if previous != null:
			previous.remove(unit_name)
			_touch(previous)
		roster.append(unit_name)
	var element := Element.new(_next_id, element_name if element_name != "" else "E%d" % _next_id, team, roster,
			table if table != null else _table_for(roster))
	_next_id += 1
	by_id[element.id] = element
	for unit_name in roster:
		_by_unit[unit_name] = element
	element_changed.emit(element.id)
	return element


## The element `unit_name` belongs to, or null.
func of(unit_name: String) -> Element:
	var element: Element = _by_unit.get(unit_name)
	if element == null:
		return null
	# A destroyed vehicle is dropped from its element's roster (Element._prune): it belongs to nobody.
	if not by_id.has(element.id) or not element.has(unit_name):
		_by_unit.erase(unit_name)
		return null
	return element


func get_element(id: int) -> Element:
	return by_id.get(id)


## Every element, in id order (deterministic iteration for callers too).
func all() -> Array:
	var ids: Array = by_id.keys()
	ids.sort()
	var result: Array = []
	for id: int in ids:
		result.append(by_id[id])
	return result


## Elements of one team, in id order.
func of_team(team: int) -> Array:
	return all().filter(func(element: Element) -> bool: return element.team == team)


func disband(element: Variant) -> void:
	var found: Element = element if element is Element else by_id.get(int(element))
	if found == null:
		return
	for unit_name in found.members():
		if _by_unit.get(unit_name) == found:
			_by_unit.erase(unit_name)
	by_id.erase(found.id)
	_reported.erase(found.id)
	element_changed.emit(found.id)


func _physics_process(_delta: float) -> void:
	if game_match == null or not game_match.simulate:
		return
	var tick: int = game_match.tick
	if tick == _last_tick or tick % UPDATE_TICKS != 0:
		return
	_last_tick = tick
	if orders == null:
		orders = OrderFeed.source(game_match)
	for element: Element in all():
		var leader_before := element.leader
		var changed := element.update(game_match, orders)
		if element.leader != leader_before:
			leader_lost.emit(element.id, leader_before, element.leader)
		if element.members().is_empty():
			disband(element)
		elif changed:
			element_changed.emit(element.id)
			_publish(element, tick)


## Publish an element's decision once, unless the same call was made recently (ElementReport.COOLDOWN_TICKS).
func _publish(element: Element, tick: int) -> void:
	var report := ElementReport.of(element)
	if report.is_empty():
		return
	var key := ElementReport.key(report)
	var seen: Dictionary = _reported.get_or_add(element.id, {})
	if tick - int(seen.get(key, -ElementReport.COOLDOWN_TICKS * 10)) < ElementReport.COOLDOWN_TICKS:
		return
	seen[key] = tick
	element_reported.emit(report)


## Every element's one-line state, for a spectator or a log.
func describe() -> PackedStringArray:
	var lines: PackedStringArray = []
	for element: Element in all():
		lines.append(element.describe())
	return lines


## The doctrine these units fight by: their faction's table (L3 adds `faction` to the catalog), else standard.
func _table_for(roster: PackedStringArray) -> DoctrineTable:
	for unit_name in roster:
		var tank := _tank(unit_name)
		if tank != null:
			return DoctrineTable.for_faction(String(Units.PROFILES.get(tank.unit_id, {}).get("faction", "")))
	return DoctrineTable.for_faction("")


func _touch(element: Element) -> void:
	if element.members().is_empty():
		disband(element)
	else:
		element_changed.emit(element.id)


func _tank(unit_name: String) -> Tank:
	if game_match == null or game_match.tanks == null:
		return null
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
