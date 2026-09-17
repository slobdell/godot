class_name TacticsFlags
extends RefCounted
## Round-5 X3 (ai, inheriting doctrine): run a side's army by DOCTRINE in any mode that spawns brains, from the command
## line, so the tactics ladder can play doctrine variants against each other without the match runner knowing:
##
##   --green-elements[=<table>]   green's squads become elements under an ElementCommander; <table> picks
##   --rust-elements[=<table>]    doctrines/doctrine_<table>.json instead of each faction's own table
##   --tactics-ledger             print TACTICS_LEDGER <json> when the match finishes (TacticsLedger)
##
## Skirmish still wires its own elements (control); this is for the CPU-vs-CPU runs that measure doctrine. Brains call
## ensure() on every think; after the first look it is one integer comparison.

## Wait this many ticks after the match starts before forming elements (squads and navigation settle first; the same
## wait tactics-parity uses).
const SETTLE_TICKS := 12

static var _match_id := 0
static var _done := false
static var _parsed := false
static var _tables: Array = [null, null]
static var _ledger := false


static func _parse() -> void:
	if _parsed:
		return
	_parsed = true
	for arg in OS.get_cmdline_user_args():
		for side in 2:
			var key := "--%s-elements" % ["green", "rust"][side]
			if arg == key:
				_tables[side] = ""
			elif arg.begins_with(key + "="):
				_tables[side] = arg.trim_prefix(key + "=")
		if arg == "--tactics-ledger":
			_ledger = true


## Whether any flag asks for this at all (tests use it to skip the work).
static func requested() -> bool:
	_parse()
	return _tables[0] != null or _tables[1] != null or _ledger


## Install what the flags ask for into `game_match`, once per match, after SETTLE_TICKS.
static func ensure(game_match: Match) -> void:
	if _match_id == game_match.get_instance_id() and _done:
		return
	if _match_id != game_match.get_instance_id():
		_match_id = game_match.get_instance_id()
		_done = false
	if not requested():
		_done = true
		return
	if game_match.tick < SETTLE_TICKS:
		return
	_done = true
	install(game_match, _tables, _ledger)


## `tables`: [green, rust], each null (not by doctrine), "" (the faction's own table) or a table name.
static func install(game_match: Match, tables: Array, ledger: bool) -> Dictionary:
	var result := {"elements": null, "commanders": [], "ledger": null}
	if tables[0] != null or tables[1] != null:
		var orders := Orders.of(game_match)
		if orders == null:
			orders = Orders.new(game_match)
			Orders.attach(game_match, orders)
		var elements := Elements.install(game_match, orders)
		result["elements"] = elements
		for side in 2:
			if tables[side] == null:
				continue
			if String(tables[side]) != "":
				var loaded := DoctrineTable.load_table(String(tables[side]))
				if loaded.has("error"):
					push_error(loaded["error"])
				else:
					elements.team_tables[side] = loaded["table"]
			var commander := ElementCommander.install(game_match, side, elements)
			commander.form_elements()
			(result["commanders"] as Array).append(commander)
	if ledger:
		result["ledger"] = TacticsLedger.attach(game_match)
	return result


## Tests: forget the flags and the match.
static func reset() -> void:
	_match_id = 0
	_done = false
	_parsed = false
	_tables = [null, null]
	_ledger = false
