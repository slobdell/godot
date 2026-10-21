extends SceneTree
## Round 37 (CP37.1, native): THE GUARD LINES. His measure for every rule this round (game_design.md, open question 11): "a blob
## frontal assault should lose, AND a pure turtle must not always win". One showmatch fight (both sides the CPU at its normal
## doctrine, exactly as `--skirmish --demo-match` plays) in which ONE side is ordered instead:
##   blob    every element attack-moves at once at the zone in the enemy's half (the other side's zone); when it holds that,
##           at whichever zone it does not hold; when it holds both, at the enemy's spawn. Re-tasked only when that target
##           changes, as a player would right-click once.
##   turtle  every element holds a post across its OWN half's zone (facing the enemy spawn, 22 m apart, no drills, as the
##           CPU's own hold lays them), once, and never advances: its crews shoot what they see.
##   none    nobody is ordered: today's CPU v CPU, run to the end (the control).
## No game code: the ordered side is marked as the side a human commands (`player_team`, the game's own switch: its
## ElementCommander stands down, OrderFeed.player_team), and its elements get ElementTasks through Element.assign, the same
## call the tactical map makes for his attack-move (`{"verb": "move", "to": ...}` with drills) and his hold.
##   godot --headless --fixed-fps 30 --path . --script res://tests/ai_scenarios/guard_line.gd -- --skirmish --demo-match --clean \
##       --seed=N --arena=A --mute --guard=blob|turtle|none --guard-side=green|rust [--seconds=600]
## Prints GUARD_RESULT {json} once: who won (the ordered side "guard", the CPU "tactics", or "draw"), why, how long, kills
## and losses a side, the zone points, and what the ordered side was told. Read by tools/scoreboard/guard.py.
## A fight that has not ended by --seconds is judged as the game judges a time-out (Match.result("time_limit")).

## Seconds between looks at the zones (the blob's target, unseated crews). The CPU's own commander thinks every second.
const THINK_S := 1.0
## The cap on a fight (simulated seconds); a skirmish ends at 90 zone points or the last crew, so most end well before it.
const DEFAULT_SECONDS := 600.0

var _printed := false
var _tasks := 0
var _retargets := 0
var _target_name := ""
var _posts := {}  # element id -> true once a turtle post is given
var _kills := [0, 0]
var _losses := [0, 0]
var _shots := [0, 0]
var _hits := [0, 0]


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _xz(point: Vector3) -> Array:
	return [snappedf(point.x, 0.01), snappedf(point.z, 0.01)]


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


## The blob's target: the zone in the enemy's half (nearer the enemy spawn) it does not hold; else any zone it does not hold (nearest the enemy
## spawn first); {} when it holds every zone (then it drives at the enemy spawn). Pure.
static func blob_target(objectives: Array, team: int, own_spawn: Vector3, enemy_spawn: Vector3) -> Dictionary:
	var best := {}
	var best_key := INF
	for objective: Dictionary in objectives:
		if int(objective.get("owner", -1)) == team:
			continue
		var position: Vector3 = objective["position"]
		var theirs := _flat(position).distance_to(_flat(enemy_spawn)) < _flat(position).distance_to(_flat(own_spawn))
		var key := _flat(position).distance_to(_flat(enemy_spawn)) - (10000.0 if theirs else 0.0)
		if key < best_key - 0.001:
			best = objective
			best_key = key
	return best


## The turtle's zone: the one in its own half (nearest its spawn). Pure.
static func turtle_zone(objectives: Array, own_spawn: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for objective: Dictionary in objectives:
		var d := _flat(objective["position"]).distance_to(_flat(own_spawn))
		if d < best_d - 0.001:
			best = objective
			best_d = d
	return best


## Post `index` of `count` across `zone`, facing `toward` (ElementCommander._hold's layout, without its intruder attack). Pure.
static func turtle_post(zone: Vector3, toward: Vector3, index: int, count: int) -> Vector3:
	var across := Vector3(-toward.z, 0.0, toward.x)
	return ElementPlan.clamp_to_arena(_flat(zone) + across * (float(index) - float(count - 1) * 0.5) \
			* ElementCommander.HOLD_POST_SPACING_M)


func _run() -> void:
	var guard := _flag("guard", "none")
	var side := Match.Team.RUST if _flag("guard-side", "green") == "rust" else Match.Team.GREEN
	var seconds := float(_flag("seconds", str(DEFAULT_SECONDS)))
	if not ["blob", "turtle", "none"].has(guard):
		push_error("guard_line: --guard must be blob, turtle or none (got %s)" % guard)
		quit(2)
		return
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	if guard != "none":
		# The ordered side is the one a human commands: its ElementCommander stands down (element_commander.gd) and its
		# elements take the player's preempting tasks, exactly as in his skirmish.
		game_match.set_meta("player_team", side)
	var shooter_of := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter != null:
			_shots[shooter.team] += 1
			shooter_of[event.get("projectile_id", -1)] = shooter.team)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var team: Variant = shooter_of.get(event.get("projectile_id", -1))
		if team == null or not event.has("target"):
			return
		var victim := game_match.tanks.get_node_or_null(String(event["target"])) as Tank
		if victim != null and victim.team != int(team):
			_hits[int(team)] += 1)
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var team := int(event.get("team", -1))
		if team == 0 or team == 1:
			_losses[team] += 1
		var killer := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
		if killer != null and String(event.get("cause", "")) == "enemy":
			_kills[killer.team] += 1)
	var result := {}
	game_match.finished.connect(func(r: Dictionary) -> void: result = r)
	var started := -1
	var last_tick := -1
	var last_think := -1
	var frames := 0
	while result.is_empty():
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 30:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		var run_s := (tick - started) / float(SimClock.TICK_RATE)
		if guard != "none" and (last_think < 0 or tick - last_think >= int(THINK_S * SimClock.TICK_RATE)):
			last_think = tick
			_order(game_match, guard, side)
		if seconds > 0.0 and run_s > seconds:
			break
	var reason_capped := result.is_empty()
	if reason_capped and game_match != null and is_instance_valid(game_match):
		result = game_match.result("time_limit")
	_report(game_match, guard, side, result, reason_capped)
	quit(0)


## The ordered side's think: seat unseated crews (its commander, which used to, stands down), then task its elements.
func _order(game_match: Match, guard: String, side: int) -> void:
	var elements := Elements.of_match(game_match)
	if elements == null:
		return
	for squad: Squad in game_match.team_squads(side):
		var loose: Array = []
		for unit_name in squad.roster:
			var tank := game_match.tanks.get_node_or_null(NodePath(String(unit_name))) as Tank
			if tank != null and tank.is_alive() and elements.of(String(unit_name)) == null:
				loose.append(String(unit_name))
		if not loose.is_empty():
			elements.form_squad(loose, String(squad.squad_name))
	var mine := elements.of_team(side)
	if mine.is_empty():
		return
	var own_spawn := Match.spawn_position(side, 0)
	var enemy_spawn := Match.spawn_position(1 - side, 0)
	var objectives := Objectives.all(game_match)
	if guard == "blob":
		var target := blob_target(objectives, side, own_spawn, enemy_spawn)
		var name := String(target.get("name", "the enemy spawn"))
		var to: Vector3 = target["position"] if not target.is_empty() else enemy_spawn
		var retarget := name != _target_name
		if retarget and _target_name != "":
			_retargets += 1
		_target_name = name
		for element: Element in mine:
			var task := {"verb": "move", "to": _xz(to)}
			if retarget or element.task.is_empty() or not _same_to(element.task, task):
				if element.task.is_empty() and not retarget and _arrived(game_match, element, to):
					continue  # an attack-move that arrived completes; a player would not click again
				if element.assign(task) == "":
					_tasks += 1
		return
	var zone := turtle_zone(objectives, own_spawn)
	var at: Vector3 = zone["position"] if not zone.is_empty() else own_spawn
	var toward := _flat(enemy_spawn - at).normalized()
	for i in mine.size():
		var element: Element = mine[i]
		if _posts.has(element.id):
			continue
		var post := turtle_post(at, toward, i, mine.size())
		if element.assign({"verb": "hold", "to": _xz(post), "facing": _xz(toward), "drills": false}) == "":
			_posts[element.id] = true
			_tasks += 1


static func _same_to(a: Dictionary, b: Dictionary) -> bool:
	var ta: Array = a.get("to", [])
	var tb: Array = b.get("to", [])
	return String(a.get("verb", "")) == String(b.get("verb", "")) and ta.size() == 2 and tb.size() == 2 \
			and Vector2(ta[0], ta[1]).distance_to(Vector2(tb[0], tb[1])) < 1.0


static func _arrived(game_match: Match, element: Element, to: Vector3) -> bool:
	for unit_name in element.members():
		var tank := game_match.tanks.get_node_or_null(NodePath(String(unit_name))) as Tank
		if tank != null and tank.is_alive() and _flat(tank.global_position).distance_to(_flat(to)) < 30.0:
			return true
	return false


func _report(game_match: Match, guard: String, side: int, result: Dictionary, capped: bool) -> void:
	if _printed:
		return
	_printed = true
	var winner := String(result.get("winner", "draw"))
	var role := "draw"
	if winner == Match.TEAM_NAMES[Match.Team.GREEN] or winner == Match.TEAM_NAMES[Match.Team.RUST]:
		var team := Match.TEAM_NAMES.find(winner)
		role = "tactics" if guard == "none" or team != side else "guard"
	# The demo's factions, rolled from the seed by the same pure functions SkirmishMode.demo_flags calls (Green = its player).
	var player := _flag("player-faction", "")
	if player == "":
		player = SkirmishMode.roll_demo_player(int(_flag("seed", "0")))
	var enemy := _flag("enemy-faction", "")
	if enemy == "":
		enemy = FactionPicker.roll_enemy(int(_flag("seed", "0")), player)
	var factions := {Match.TEAM_NAMES[Match.Team.GREEN]: player, Match.TEAM_NAMES[Match.Team.RUST]: enemy}
	print("GUARD_RESULT " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"guard": guard, "side": Match.TEAM_NAMES[side], "winner": winner, "role": role,
			"reason": "cap" if capped else String(result.get("reason", "")), "seconds": result.get("sim_seconds", 0.0),
			"kills": {"green": _kills[0], "rust": _kills[1]}, "losses": {"green": _losses[0], "rust": _losses[1]},
			"shots": {"green": _shots[0], "rust": _shots[1]}, "hits": {"green": _hits[0], "rust": _hits[1]},
			"control": result.get("control"), "tanks": result.get("tanks"), "army_cost": result.get("army_cost"),
			"factions": factions, "tasks": _tasks, "retargets": _retargets, "last_target": _target_name}))
