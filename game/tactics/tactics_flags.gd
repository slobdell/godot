class_name TacticsFlags
extends RefCounted
## Round-5 X3 (ai, inheriting doctrine): run a side's army by DOCTRINE in any mode that spawns brains, from the command
## line, so the tactics ladder can play doctrine variants against each other without the match runner knowing:
##
##   --green-elements[=<table>]   green's squads become elements under an ElementCommander; <table> picks
##   --rust-elements[=<table>]    doctrines/doctrine_<table>.json instead of each faction's own table
##   --tactics-ledger             print TACTICS_LEDGER <json> when the match finishes (TacticsLedger)
##   --green-discovery[=seconds]  X5, offline only: that side's elements take tasks from stdin every `seconds`
##   --rust-discovery[=seconds]   (DiscoveryBridge; default 5), with --discovery-log=<path> for (state, decision,
##                                outcome) lines and --slow-motion=<factor> for a windowed run a person can follow
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
static var _discovery: Array = [null, null]
static var _discovery_log := ""


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
		for side in 2:
			var key := "--%s-discovery" % ["green", "rust"][side]
			if arg == key:
				_discovery[side] = DiscoveryBridge.DEFAULT_EVERY_SECONDS
			elif arg.begins_with(key + "="):
				_discovery[side] = maxf(0.1, float(arg.trim_prefix(key + "=")))
		if arg.begins_with("--discovery-log="):
			_discovery_log = arg.trim_prefix("--discovery-log=")
		if arg.begins_with("--slow-motion="):
			Engine.time_scale = clampf(float(arg.trim_prefix("--slow-motion=")), 0.05, 1.0)


## Whether any flag asks for this at all (tests use it to skip the work).
static func requested() -> bool:
	_parse()
	return _tables[0] != null or _tables[1] != null or _ledger or _discovery[0] != null or _discovery[1] != null


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
	var installed := install(game_match, _tables, _ledger)
	for side in 2:
		if _discovery[side] == null:
			continue
		var elements: Elements = installed["elements"] if installed["elements"] != null \
				else Elements.install(game_match, _orders_for(game_match))
		DiscoveryBridge.install(game_match, side, elements, float(_discovery[side]),
				_discovery_log.replace("{team}", ["green", "rust"][side]))


## `tables`: [green, rust], each null (not by doctrine), "" (the faction's own table) or a table name.
static func install(game_match: Match, tables: Array, ledger: bool) -> Dictionary:
	var result := {"elements": null, "commanders": [], "ledger": null}
	if tables[0] != null or tables[1] != null:
		var elements := Elements.install(game_match, _orders_for(game_match))
		result["elements"] = elements
		for side in 2:
			if tables[side] == null:
				continue
			# "<table>-drill-drill+commander": a table (or "" = each faction's own) with drills switched off and a
			# commander plan set, e.g. "-far_ambush-bait" or "standard+pin_and_flank".
			var spec := parse_spec(String(tables[side]))
			elements.team_variants[side] = {"drop": spec["drop"], "commander": spec["commander"]} \
					if not (spec["drop"] as PackedStringArray).is_empty() or spec["commander"] != "" else {}
			if String(spec["table"]) != "":
				var loaded := DoctrineTable.load_table(String(spec["table"]))
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


## {"table": String, "drop": PackedStringArray, "commander": String} from "<table>[-drill ...][+commander]". A table
## given by res:// path keeps its own dashes: changes are only read after the last "/".
static func parse_spec(text: String) -> Dictionary:
	var result := {"table": text, "drop": PackedStringArray(), "commander": ""}
	var slash := text.rfind("/")
	var head := text.substr(0, slash + 1)
	var tail := text.substr(slash + 1)
	# A file path ends its name at ".json"; a plain table name at the first "+" or "-".
	var cut := tail.find(".json") + 5 if tail.contains(".json") else -1
	if cut < 0:
		for i in tail.length():
			if tail[i] == "+" or tail[i] == "-":
				cut = i
				break
	if cut < 0 or cut >= tail.length():
		return result
	result["table"] = head + tail.substr(0, cut)
	var rest := tail.substr(cut)
	var regex := RegEx.create_from_string("([+-])([a-z_]+)")
	var drop := PackedStringArray()  # packed arrays are values: fill a local, then store it
	for found in regex.search_all(rest):
		if found.get_string(1) == "-":
			drop.append(found.get_string(2))
		else:
			result["commander"] = found.get_string(2)
	result["drop"] = drop
	return result


static func _orders_for(game_match: Match) -> Orders:
	var orders := Orders.of(game_match)
	if orders == null:
		orders = Orders.new(game_match)
		Orders.attach(game_match, orders)
	return orders


## Tests: forget the flags and the match.
static func reset() -> void:
	_match_id = 0
	_done = false
	_parsed = false
	_tables = [null, null]
	_ledger = false
	_discovery = [null, null]
	_discovery_log = ""
