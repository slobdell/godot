class_name TacticsLedger
extends Node
## Round-5 X3: what each piece of doctrine is worth in a real match. Every unit is, at any moment, doing ONE thing
## the ladder can name — running a drill ("drill:near_ambush"), moving in a shape ("move:wedge/bounding_overwatch"),
## or just its brain ("brain", no element) — and the ledger charges every round that lands to what its shooter was
## doing (damage dealt) and to what its target was doing (damage taken), and counts unit-seconds per activity.
## `make tactics-ladder` sums it over counterbalanced matches: a drill earns its place when the exchange it buys
## (dealt / taken) beats the brains' own (game_design.md "What earns a place in doctrine").
##
## Pure bookkeeping on K2 events plus a sample of element state every SAMPLE_TICKS: it never changes the fight.
##
##   TACTICS_LEDGER {"green": {activity: {"seconds", "dealt", "taken", "kills", "deaths"}}, "rust": {...}}

const SAMPLE_TICKS := SimClock.TICK_RATE / 2

var game_match: Match
## [green, rust]: activity -> {"seconds", "dealt", "taken", "kills", "deaths"}
var sides: Array = [{}, {}]
## unit name -> activity, refreshed every SAMPLE_TICKS.
var _activity := {}
## projectile id -> shooter name (from weapon_fired).
var _shooters := {}


static func attach(p_match: Match) -> TacticsLedger:
	var ledger := TacticsLedger.new()
	ledger.name = "TacticsLedger"
	ledger.game_match = p_match
	p_match.weapon_fired.connect(ledger._on_fired)
	p_match.projectile_impact.connect(ledger._on_impact)
	p_match.finished.connect(ledger._on_finished)
	p_match.add_child(ledger)
	return ledger


func _ready() -> void:
	# After the elements (-30) have decided this tick, before the brains act on it.
	process_physics_priority = Elements.PRIORITY + 1


func _physics_process(_delta: float) -> void:
	if game_match == null or game_match.tick % SAMPLE_TICKS != 0:
		return
	var elements := Elements.of_match(game_match)
	for tank: Tank in game_match.sorted_team_tanks(Match.Team.GREEN) + game_match.sorted_team_tanks(Match.Team.RUST):
		if not tank.is_alive():
			_activity.erase(String(tank.name))
			continue
		var activity := activity_of(elements.of(String(tank.name)) if elements != null else null)
		_activity[String(tank.name)] = activity
		_row(tank.team, activity)["seconds"] += SAMPLE_TICKS / float(SimClock.TICK_RATE)


## What an element (or null: no element) has its units doing, as the ledger names it.
static func activity_of(element: Element) -> String:
	if element == null:
		return "brain"
	if element.drill != "":
		return "drill:" + element.drill
	return "%s:%s/%s" % [String(element.task.get("verb", "none")), element.formation, element.technique]


func _row(team: int, activity: String) -> Dictionary:
	var side: Dictionary = sides[team]
	if not side.has(activity):
		side[activity] = {"seconds": 0.0, "dealt": 0.0, "taken": 0.0, "kills": 0, "deaths": 0}
	return side[activity]


func _on_fired(event: Dictionary) -> void:
	_shooters[int(event.get("projectile_id", -1))] = String(event.get("shooter", ""))


func _on_impact(event: Dictionary) -> void:
	var damage := float(event.get("damage", 0.0))
	var target := String(event.get("target", ""))
	if damage <= 0.0 or target == "":
		return
	var shooter := String(_shooters.get(int(event.get("projectile_id", -1)), ""))
	var tanks := AiTickCache.tanks_by_name(game_match)
	var shooter_tank := tanks.get(shooter) as Tank
	var target_tank := tanks.get(target) as Tank
	var killed := bool(event.get("killed", false))
	if shooter_tank != null and target_tank != null and shooter_tank.team != target_tank.team:
		var row := _row(shooter_tank.team, String(_activity.get(shooter, "brain")))
		row["dealt"] += damage
		row["kills"] += 1 if killed else 0
	if target_tank != null:
		var row := _row(target_tank.team, String(_activity.get(target, "brain")))
		row["taken"] += damage
		row["deaths"] += 1 if killed else 0


func report() -> Dictionary:
	var rounded := func(side: Dictionary) -> Dictionary:
		var out := {}
		for activity: String in side:
			var row: Dictionary = side[activity]
			out[activity] = {"seconds": snappedf(row["seconds"], 0.1), "dealt": snappedf(row["dealt"], 0.1),
					"taken": snappedf(row["taken"], 0.1), "kills": row["kills"], "deaths": row["deaths"]}
		return out
	return {"green": rounded.call(sides[0]), "rust": rounded.call(sides[1])}


func _on_finished(_result: Dictionary) -> void:
	print("TACTICS_LEDGER " + JSON.stringify(report()))
