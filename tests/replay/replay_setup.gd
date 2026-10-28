extends RefCounted
## CP43.0 (round 43, native): what a replay of a match recording must set before the first tick, read from the recording
## (tests/replay_orders.gd). Pure but for `place`, so tests/replay/test_replay_setup.gd pins it on rows.

## A census position is rounded to 0.1 m (MatchRecorder.census_row): a unit the replay already has within the rounding
## (0.071 m on the diagonal) is left exactly where the layout put it rather than moved by the rounding.
const ROUNDING_M := 0.08


## The match's squad cap and the two factions. A recording that names them (`squad_cap`, `factions` on the `match` row,
## C43.2) is believed; an older one is read from its roster: the squads Green fields (his laptop preset fields four) and
## each side's faction from its first unit's id.
static func from_header(header: Dictionary) -> Dictionary:
	var squads := {}
	var faction := {0: "", 1: ""}
	for unit: Dictionary in header.get("units", []):
		var team := int(unit.get("team", -1))
		if team == 0:
			squads[String(unit.get("name", "")).rsplit("_", true, 1)[0]] = true
		if faction.has(team) and String(faction[team]) == "":
			faction[team] = Units.faction_of(String(unit.get("id", "")))
	var named: Dictionary = header.get("factions", {})
	return {"squad_cap": int(header.get("squad_cap", maxi(1, squads.size()))),
			"player_faction": String(named.get("green", faction[0] if faction[0] != "" else "gangs")),
			"enemy_faction": String(named.get("rust", faction[1] if faction[1] != "" else "syndicate"))}


## Every unit named in `spawn` (name -> [x, z] or [x, z, yaw]) put where the recording had it; returns how many moved.
static func place(game_match: Match, spawn: Dictionary) -> int:
	var moved := 0
	for unit_name: String in spawn:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var at: Array = spawn[unit_name]
		if tank == null or at.size() < 2:
			continue
		var to := Vector3(float(at[0]), tank.global_position.y, float(at[1]))
		var yaw := float(at[2]) if at.size() > 2 else tank.rotation.y
		if Vector2(to.x - tank.global_position.x, to.z - tank.global_position.z).length() <= ROUNDING_M \
				and absf(angle_difference(yaw, tank.rotation.y)) < 0.001:
			continue
		tank.place(to, yaw)
		moved += 1
	return moved


## Switches of his match (the `flags` key, C43.2) that are presentation, input or I/O, or that the replay sets itself:
## never passed on. Everything else (`--attack-shot=off`, `--squad-cap=3`, ...) is, so the replay runs his switches.
const NOT_REPLAYED := ["arena", "seed", "skirmish", "enemy", "player-faction", "enemy-faction", "squad-cap", "pick-faction",
		"no-pick-faction", "hints", "record", "no-record", "record-dir", "perf", "perf-trace", "announcer", "music",
		"camera-readout", "screenshot", "screenshot-delay", "resolution", "orders", "seconds", "spawn", "fullscreen",
		"mute", "garage"]


## The recorded switches the replay passes on, sorted (so the re-run's command line is the same every time).
static func match_switches(header: Dictionary) -> Array:
	var keys: Array = []
	for key: String in header.get("flags", {}):
		if not NOT_REPLAYED.has(key):
			keys.append(key)
	keys.sort()
	return keys


## "" when the replay fields exactly his units (name and unit id, both sides); else the first difference. An army the
## header cannot rebuild (a garage army saved under his user://) shows here rather than as a mysterious divergence.
static func roster_difference(header: Dictionary, game_match: Match) -> String:
	var his := {}
	for unit: Dictionary in header.get("units", []):
		his[String(unit.get("name", ""))] = String(unit.get("id", ""))
	var mine := {}
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank != null:
			mine[String(tank.name)] = String(tank.unit_id)
	return difference(his, mine)


## Pure: the first unit missing on either side or carrying another id, "" when the two rosters are the same.
static func difference(his: Dictionary, mine: Dictionary) -> String:
	var names := his.keys() + mine.keys()
	names.sort()
	for unit_name: String in names:
		if not his.has(unit_name):
			return "%s only in the replay (%d v his %d units)" % [unit_name, mine.size(), his.size()]
		if not mine.has(unit_name):
			return "%s missing from the replay (%d v his %d units)" % [unit_name, mine.size(), his.size()]
		if his[unit_name] != mine[unit_name]:
			return "%s is %s, his was %s" % [unit_name, mine[unit_name], his[unit_name]]
	return ""
