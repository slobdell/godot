extends "res://tests/ai_scenarios/guard_line.gd"
## Round 41 (balance B5, C41.5): WHERE the rounds land on TANKS. His levers (a slower tank turret, a slower tank hull) can
## only work if the mixed army's fast units get round to a tank's side and rear, where an autocannon does ~50 % / ~100 %
## of its damage instead of ~5 % on the front (armor.gd penetration v front 8 / side 4 / rear 2). The guard fight exactly
## as guard_line plays it, plus one read: every impact event's `face`, summed per SHOOTER team, on enemy TANKS and on
## every enemy, and on tanks by the shooter's role. Read-only: listeners only, no game state written.
##   godot ... --script res://tests/tactics/face_probe.gd -- <guard_line.gd's flags>
## Prints GUARD_RESULT (unchanged) then FACE {"guard", "arena", "seed", "side", "teams": {"green": {...}, "rust": {...}}} where a
## team's row is {"to_tanks": {"front", "side", "rear"}, "to_tanks_by_role": {"<shooter role>": {...}}, "to_all": {...},
## "dealt"}: shield + hull points its rounds put on ENEMY tanks / enemies, by the face struck (an indirect round's face is
## "side": nothing is strong against it); "dealt" is the team's UnitTally total, cones included (a cone has no impact
## event, so faced / dealt is the probe's coverage). Read by tools/balance/search.py faces (mk/balance.mk balance-guard-run
## runs it in guard-run's place; tools/balance/guard_probe.sh drives it).

var _face_shooters := {}  # projectile_id -> shooter name
var _face := {"green": _face_blank(), "rust": _face_blank()}


static func _face_blank() -> Dictionary:
	return {"to_tanks": {"front": 0.0, "side": 0.0, "rear": 0.0}, "to_tanks_by_role": {},
			"to_all": {"front": 0.0, "side": 0.0, "rear": 0.0}}


func _initialize() -> void:
	super._initialize()
	_face_listen.call_deferred()


## guard_line's _run instantiates main on its first deferred call; wait for its match, then listen.
func _face_listen() -> void:
	var game_match: Match = null
	for frame in 600:
		await process_frame
		var main := root.get_node_or_null("Main")
		if main == null:
			for child in root.get_children():
				if child.get("game_match") != null:
					main = child
					break
		game_match = main.get("game_match") if main != null else null
		if game_match != null:
			break
	if game_match == null:
		return
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		_face_shooters[event.get("projectile_id", -1)] = String(event.get("shooter", "")))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shooter := String(_face_shooters.get(event.get("projectile_id", -1), ""))
		if event.has("victims"):
			for entry: Dictionary in event["victims"]:
				_face_land(shooter, String(entry.get("target", "")), String(entry.get("face", "")), float(entry.get("damage", 0.0)))
		elif event.has("target"):
			_face_land(shooter, String(event["target"]), String(event.get("face", "")), float(event.get("damage", 0.0))))


## `amount` from `shooter` on `victim`'s `face`; counted only between enemies the tally knows (registered the tick first seen).
func _face_land(shooter: String, victim: String, face: String, amount: float) -> void:
	if amount <= 0.0 or not _tally.has(shooter) or not _tally.has(victim) or _tally.teams[shooter] == _tally.teams[victim]:
		return
	if not ["front", "side", "rear"].has(face):
		return
	var row: Dictionary = _face["green" if int(_tally.teams[shooter]) == 0 else "rust"]
	(row["to_all"] as Dictionary)[face] += amount
	if Units.role_of(String(_tally.rows[victim]["type"])) != "tank":
		return
	(row["to_tanks"] as Dictionary)[face] += amount
	var by_role: Dictionary = row["to_tanks_by_role"]
	var role := Units.role_of(String(_tally.rows[shooter]["type"]))
	var cell: Dictionary = by_role.get_or_add(role, {"front": 0.0, "side": 0.0, "rear": 0.0})
	cell[face] += amount


func _report(game_match: Match, guard: String, side: int, result: Dictionary, capped: bool) -> void:
	if _printed:
		return
	super._report(game_match, guard, side, result, capped)
	var teams := {}
	for team: String in ["green", "rust"]:
		var row: Dictionary = (_face[team] as Dictionary).duplicate(true)
		var dealt := 0.0
		for unit: String in _tally.rows:
			if ("green" if int(_tally.teams[unit]) == 0 else "rust") == team:
				dealt += float(_tally.rows[unit]["dealt"])
		row["dealt"] = snappedf(dealt, 0.01)
		for key: String in ["to_tanks", "to_all"]:
			for face: String in row[key]:
				row[key][face] = snappedf(row[key][face], 0.01)
		for role: String in row["to_tanks_by_role"]:
			for face: String in row["to_tanks_by_role"][role]:
				row["to_tanks_by_role"][role][face] = snappedf(row["to_tanks_by_role"][role][face], 0.01)
		teams[team] = row
	print("FACE " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"guard": guard, "side": Match.TEAM_NAMES[side], "teams": teams}))
