class_name HudMessages
extends Node
## C6: the player's message feed in a match, between what happens and Hud.post_message. It keeps the feed
## useful instead of spammy:
##   - order acknowledgements at most once per ORDER_COOLDOWN (the map's toast confirms every order);
##     rejected orders always
##   - losses merged per squad over LOSS_MERGE_SECONDS, naming unit types ("Alpha lost a Tank, 2 left");
##     a squad's last loss says "Alpha destroyed" instead
##   - enemy kills merged the same way; friendly-fire kills called out at once
##   - the control point: a warning when either side is CONTROL_WARN_POINTS from winning there
##   - identical text within DUPLICATE_SECONDS dropped; at most WINDOW_MAX info messages per WINDOW_SECONDS
##     (warnings and errors always get through)
## MatchAnnouncer (rules) still supplies contact, shields, ammo, commander, center, and result messages via
## relay(); its own loss and kill lines are dropped because this node posts richer ones.

signal posted(text: String, severity: int)

const DUPLICATE_SECONDS := 4.0
const ORDER_COOLDOWN := 3.0
const LOSS_MERGE_SECONDS := 1.5
const WINDOW_SECONDS := 3.0
const WINDOW_MAX := 3
const CONTROL_WARN_POINTS := 15
## MatchAnnouncer lines this node replaces (see relay()).
const REPLACED_PATTERNS := ["^\\S+ lost \\S+", "^Enemy tank destroyed"]

var game_match: Match
var team := Match.Team.GREEN

## Seconds since start (advanced in _process, which runs while paused; tests call advance()).
var _clock := 0.0
var _last_text := {}  # text → time posted
var _info_times: Array[float] = []
var _last_order := -INF
## squad name ("" = enemy) → {"units": [display names], "since": time}
var _pending := {}
var _destroyed_squads := {}
var _control_warned := [false, false]
var _replaced: Array[RegEx] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for pattern in REPLACED_PATTERNS:
		_replaced.append(RegEx.create_from_string(pattern))
	if game_match != null:
		game_match.tank_destroyed.connect(_on_tank_destroyed)


func _process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	_clock += seconds
	for key in _pending.keys():
		# A small tolerance: _clock sums frame deltas, so "exactly LOSS_MERGE_SECONDS later" can land a hair short.
		if _clock - float(_pending[key]["since"]) >= LOSS_MERGE_SECONDS - 0.001:
			_flush(key)
	_check_control()


## Messages from MatchAnnouncer.announced.
func relay(text: String, severity: int) -> void:
	if _replaced.is_empty():
		for pattern in REPLACED_PATTERNS:
			_replaced.append(RegEx.create_from_string(pattern))
	for regex in _replaced:
		if regex.search(text) != null:
			return
	post(text, severity)


## TacticalMap.command_issued, with the map's summary of the command.
func order(summary: String, error: String) -> void:
	if error != "":
		post("Can't: " + error, Hud.WARNING)
		return
	if _clock - _last_order < ORDER_COOLDOWN:
		return
	_last_order = _clock
	post(summary, Hud.INFO)


func post(text: String, severity: int) -> bool:
	if _last_text.has(text) and _clock - float(_last_text[text]) < DUPLICATE_SECONDS:
		return false
	if severity == Hud.INFO:
		while not _info_times.is_empty() and _clock - _info_times[0] >= WINDOW_SECONDS:
			_info_times.pop_front()
		if _info_times.size() >= WINDOW_MAX:
			return false
		_info_times.append(_clock)
	_last_text[text] = _clock
	posted.emit(text, severity)
	return true


func _on_tank_destroyed(victim: Tank, killer: String) -> void:
	var shooter := game_match.tanks.get_node_or_null(NodePath(killer)) as Tank if killer != "" else null
	if shooter != null and shooter != victim and shooter.team == victim.team and victim.team == team:
		post("Friendly fire! %s destroyed %s" % [MatchAnnouncer.short_name(killer),
				MatchAnnouncer.short_name(String(victim.name))], Hud.WARNING)
	var key := game_match.squad_of(victim) if victim.team == team else ""
	if victim.team == team and key == "":
		key = "We"
	if not _pending.has(key):
		_pending[key] = {"units": [], "since": _clock}
	(_pending[key]["units"] as Array).append(unit_name(victim))


func _flush(key: String) -> void:
	var units: Array = _pending[key]["units"]
	_pending.erase(key)
	if key == "":
		var left := game_match.alive_count(1 - team)
		var what := ("an enemy %s" % units[0]) if units.size() == 1 else "%d enemies" % units.size()
		post("Destroyed %s (%d left)" % [what, left], Hud.INFO)
		return
	var squad := _squad(key)
	var alive := squad.alive_members(game_match.tanks_by_name()).size() if squad != null else -1
	if alive == 0:
		if not _destroyed_squads.has(key):
			_destroyed_squads[key] = true
			post("%s destroyed" % key, Hud.ERROR)
		return
	var lost := with_article(units[0]) if units.size() == 1 else "%d vehicles (%s)" % [units.size(), ", ".join(units)]
	post("%s lost %s, %d left" % [key, lost, alive] if alive >= 0 else "%s lost %s" % [key, lost], Hud.WARNING)


func _check_control() -> void:
	if game_match == null or not game_match.control_point:
		return
	for side in [team, 1 - team]:
		var to_go: int = Match.CONTROL_POINTS_TO_WIN - int(game_match.control_score[side])
		if to_go <= CONTROL_WARN_POINTS and to_go > 0 and not _control_warned[side]:
			_control_warned[side] = true
			if side == team:
				post("%d points to win: hold the center!" % to_go, Hud.WARNING)
			else:
				post("Enemy is %d points from winning at the center" % to_go, Hud.WARNING)


func _squad(squad_name: String) -> Squad:
	for squad in game_match.team_squads(team):
		if squad.squad_name == squad_name:
			return squad
	return null


## "Tank", "Scout", ...: the catalog's display name for a vehicle.
## "a Tank", "an IFV", "an Artillery": unit names are proper nouns or initialisms, so the first letter decides.
static func with_article(name: String) -> String:
	return ("an %s" if name.substr(0, 1).to_upper() in ["A", "E", "I", "O", "U"] else "a %s") % name


static func unit_name(tank: Tank) -> String:
	return String((Units.PROFILES.get(tank.unit_id, {}) as Dictionary).get("display_name", tank.unit_id.capitalize()))
