extends "res://tests/ai_scenarios/guard_line.gd"
## Round 38 (doctrine D1): WHO fires on the move, and why. R37.26 found the CPU "defender" fires faster than a crawl on 56 %
## of its direct rounds in the guard lines; this splits every direct-fire round by what its shooter was doing when it fired:
##   posture  the side's ElementCommander posture ("hold" / "attack"; "ordered" for the guard side, which has none)
##   verb     the shooter's element task verb (hold, attack, support_by_fire, screen, move, ... ; "" when it has none)
##   option   the shooter's brain option (TankBrain.choice: ENGAGE, HOLD, SPOT, FLANK, COVER_FIRE, MOVE, ...)
##   seat     the shooter's distance from its element slot: near < 5 m <= off < 15 m <= away ("-" with no slot)
##   motion   |speed| / max_forward_speed as R37.26: still < 0.15 (a crawl) <= slow < 0.5 <= fast
## and samples every living crew's state at 2 Hz the same way, whether or not it fires (a crew that drives while holding
## but never gets a shot off is still a crew not holding). Read-only: listeners and reads, no game state written.
##   godot ... --script res://tests/tactics/hold_fire_probe.gd -- <guard_line.gd's flags>
## Prints GUARD_RESULT (unchanged) then HOLD_FIRE {"guard", "arena", "seed", "side", "listening", "args",
## "shots": {"guard"|"tactics": {"posture|verb|option|seat": [still, slow, fast]}}, "time": {.. the same, in samples}}.
## Read by tests/tactics/hold_fire_table.py.

const SLOW := 0.15
const FAST := 0.5
const NEAR_M := 5.0
const OFF_M := 15.0
const SAMPLE_TICKS := SimClock.TICK_RATE / 2

var _hf_shots := {"guard": {}, "tactics": {}}
var _hf_time := {"guard": {}, "tactics": {}}
## The same rounds weighted by the shooter's damage a round (a scout's machine gun fires ten rounds to a cannon's one).
var _hf_dmg := {"guard": {}, "tactics": {}}
## CPU rounds (and damage) by why its posture is what it is, and which half of the map the shooter stood in.
var _hf_why := {}
var _listening := false
## Stretch (O6 under defend): the most seats each element's deploy ever moved behind low cover (`--cover-seat=on`), per side.
var _hf_cover := {"guard": {}, "tactics": {}}
## ...and element samples at 2 Hz split [not deployed, deployed] (cover seats are offered only once a deploy stands).
var _hf_deployed := {"guard": [0, 0], "tactics": [0, 0]}


func _initialize() -> void:
	super._initialize()
	_listen.call_deferred()


static func motion_bucket(speed: float, top: float) -> int:
	var moving := clampf(absf(speed) / maxf(top, 0.001), 0.0, 1.0)
	return 0 if moving < SLOW else (1 if moving < FAST else 2)


static func seat_bucket(distance: float) -> String:
	if distance < 0.0:
		return "-"
	return "near" if distance < NEAR_M else ("off" if distance < OFF_M else "away")


static func tally(table: Dictionary, key: String, bucket: int, amount := 1.0) -> void:
	var row: Array = table.get_or_add(key, [0, 0, 0])
	row[bucket] += amount


## The CPU posture's reason in a word ("threatened", "ahead", "opening", "nothing", "behind", "?") and the shooter's half
## ("own" when nearer its own spawn than the enemy's).
static func why_key(game_match: Match, tank: Tank) -> String:
	var commander := game_match.get_node_or_null("ElementCommander_%d" % tank.team)
	var why := String((commander.get("posture") as Dictionary).get("why", "")) if commander != null else ""
	var word := "?"
	for pair in [["defend", "defend"], ["threatened", "threatened"], ["ahead", "ahead"], ["opening", "opening"], ["holds no", "nothing"],
			["not ahead", "behind"]]:
		if why.contains(String(pair[0])):
			word = String(pair[1])
			break
	var here := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var own := Match.spawn_position(tank.team, 0)
	var enemy := Match.spawn_position(1 - tank.team, 0)
	var half := "own" if here.distance_to(Vector3(own.x, 0.0, own.z)) < here.distance_to(Vector3(enemy.x, 0.0, enemy.z)) \
			else "theirs"
	return "%s|%s" % [word, half]


## What `tank` was doing, as the key the tables split by.
static func state_key(game_match: Match, tank: Tank, guard_team: int) -> String:
	var posture := "ordered"
	if tank.team != guard_team:
		var commander := game_match.get_node_or_null("ElementCommander_%d" % tank.team)
		posture = String((commander.get("posture") as Dictionary).get("posture", "?")) if commander != null else "none"
	var verb := ""
	var seat := -1.0
	var elements := Elements.of_match(game_match)
	var element: Element = elements.of(String(tank.name)) if elements != null else null
	if element != null:
		verb = String(element.task.get("verb", ""))
		var slot: Variant = element.slots.get(String(tank.name))
		if slot is Vector3:
			var here := tank.global_position
			seat = Vector2(here.x - (slot as Vector3).x, here.z - (slot as Vector3).z).length()
	var option := "-"
	var brain := game_match.brains.get_node_or_null("Brain_" + String(tank.name)) as TankBrain
	if brain != null:
		option = String(brain.choice.get("option", "-"))
	return "%s|%s|%s|%s" % [posture, verb, option, seat_bucket(seat)]


## guard_line's _run instantiates main on its first deferred call; wait for its match, then listen.
func _listen() -> void:
	var guard_team := 1 if _flag("guard-side", "green") == "rust" else 0
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
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null or shooter.weapon["kind"] == Weapons.Kind.ARC:
			return
		var who := "guard" if shooter.team == guard_team else "tactics"
		var key := state_key(game_match, shooter, guard_team)
		var bucket := motion_bucket(shooter.speed(), shooter.max_forward_speed)
		var damage := float(shooter.weapon.get("damage", 0.0))
		tally(_hf_shots[who], key, bucket)
		tally(_hf_dmg[who], key, bucket, damage)
		if who == "tactics":
			var why := why_key(game_match, shooter)
			tally(_hf_why, why, bucket)
			tally(_hf_why, why + "|dmg", bucket, damage))
	_listening = true
	var last := -SAMPLE_TICKS
	while is_instance_valid(game_match) and not _printed:
		await physics_frame
		if not is_instance_valid(game_match) or game_match.tick - last < SAMPLE_TICKS:
			continue
		last = game_match.tick
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			if tank == null or not tank.is_alive() or tank.weapon["kind"] == Weapons.Kind.ARC:
				continue
			var who := "guard" if tank.team == guard_team else "tactics"
			tally(_hf_time[who], state_key(game_match, tank, guard_team), motion_bucket(tank.speed(), tank.max_forward_speed))
		var elements := Elements.of_match(game_match)
		if elements != null:
			for element: Element in elements.all():
				(_hf_deployed["guard" if element.team == guard_team else "tactics"] as Array)[
						1 if bool(element.deploy.get("deployed", false)) else 0] += 1
				var cover: Variant = element.deploy.get("cover")
				if cover is Dictionary and not (cover as Dictionary).is_empty():
					var side := _hf_cover["guard" if element.team == guard_team else "tactics"] as Dictionary
					side[str(element.id)] = maxi(int(side.get(str(element.id), 0)), (cover as Dictionary).size())


func _report(game_match: Match, guard: String, side: int, result: Dictionary, capped: bool) -> void:
	var first := not _printed
	super._report(game_match, guard, side, result, capped)
	if not first:
		return
	print("HOLD_FIRE " + JSON.stringify({"guard": guard, "arena": String(Arena.active.get("name", "")),
			"seed": int(_flag("seed", "0")), "side": _flag("guard-side", "green"), "listening": _listening,
			"args": " ".join(_arm_args()), "shots": _hf_shots, "time": _hf_time, "dmg": _hf_dmg, "why": _hf_why,
			"cover": {"moved": ElementPlan.cover_seats_moved, "guard": _sum(_hf_cover["guard"]), "tactics": _sum(_hf_cover["tactics"]),
				"deployed": _hf_deployed}}))


static func _sum(counts: Dictionary) -> int:
	var total := 0
	for n: int in counts.values():
		total += n
	return total
