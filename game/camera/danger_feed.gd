class_name DangerFeed
extends RefCounted
## Round 42 (camera K4): where the danger is, for the play camera. The lead, after round 41: "if the camera is following
## the direction at which a squad is moving, and then there's an ambush from the east (assuming we're driving north), the
## camera doesn't end up pointing at the action." Until now the rig knew only the selection's heading (`facing`) and what
## his units see (`vision`, which moves the frame's centre, never its direction).
##
## One reader, used by BOTH the look census (CameraLook, K4.1) and the danger rule (RtsCamera, K4.2), so the bar measures
## what the rule sees. It reads, never writes (C42.3): it listens to the match's weapon_fired / projectile_impact signals
## and asks the controls what his team can see. `read()` returns, at sim time `t` (seconds):
##   from     the commanded units' centre (null with none alive); `heading` their facing (or null); `speed` their mean m/s
##   enemies  every KNOWN enemy: seen now, or last seen within MEMORY_S (at its last seen spot). Each {name, at, seen,
##            age_s (since last seen), fired_s (since its last round AT the commanded units), hit_s (since one hit them)}
##   own      the commanded units' drawn ground points (the census's "selection on screen")
##   middle   the arena's middle (arenas are point-symmetric about the origin: Arena checks it)
## A round is "at" the commanded units when its line passes within IncomingFire.DANGER_RADIUS of one of them inside the
## weapon's range, or it struck one. A shooter his team has never seen is not known and does not count: the camera must
## not point into the fog at something he cannot see (no cheating view).

## A known enemy out of sight is remembered this long, at its last seen spot (the danger rule fades it over this).
const MEMORY_S := 6.0
## How long the shooter of a round is remembered by its projectile id (a shell's flight is a few seconds at most).
const SHOT_MEMORY_S := 10.0
const NEVER := 1e9

var game_match: Match
var team := 0
## () -> Array[String]: the units the camera frames (RtsControls.commanded_units).
var units: Callable = Callable()
## (Tank) -> bool: whether his team sees that tank (RtsControls.can_see).
var can_see: Callable = Callable()
## () -> Variant: the commanded units' facing, a ground Vector3 or null (RtsControls.selection_facing).
var facing: Callable = Callable()

var _seen := {}  # enemy name -> {"at": Vector3, "t": seconds}
var _fired := {}  # enemy name -> seconds of its last round at the commanded units
var _hit := {}  # enemy name -> seconds of its last round that struck one of them
var _shooter_of := {}  # projectile id -> [shooter name, seconds]


## Wire it to a match and his controls. Signal hooks only: nothing in the match changes behaviour.
func attach(on_match: Match, on_team: int, commanded: Callable, sees: Callable, faces: Callable = Callable()) -> DangerFeed:
	game_match = on_match
	team = on_team
	units = commanded
	can_see = sees
	facing = faces
	game_match.weapon_fired.connect(_on_fired)
	game_match.projectile_impact.connect(_on_impact)
	return self


## `read` as a Callable that keeps this feed alive. A bare `feed.read` does not: a Callable holds its RefCounted weakly,
## so `DangerFeed.new().attach(...).read` is freed at once and the rig silently fell back to the heading (K4.2's first
## dev read measured exactly round 41's camera).
func reader() -> Callable:
	var feed := self
	return func() -> Dictionary: return feed.read()


func now() -> float:
	return float(game_match.tick) / float(SimClock.TICK_RATE) if game_match != null else 0.0


func read() -> Dictionary:
	var t := now()
	var out := {"t": t, "from": null, "heading": null, "speed": 0.0, "enemies": [], "middle": Vector3.ZERO, "own": []}
	if game_match == null:
		return out
	var mine := _commanded()
	if not mine.is_empty():
		var centre := Vector3.ZERO
		var speed := 0.0
		for tank: Tank in mine:
			centre += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			out["own"].append(Shown.ground(tank))
			speed += absf(tank.speed())
		out["from"] = centre / float(mine.size())
		out["speed"] = speed / float(mine.size())
	if facing.is_valid():
		out["heading"] = facing.call()
	var enemies: Array = []
	for node in game_match.tanks.get_children():
		var enemy := node as Tank
		if enemy == null or enemy.team == team:
			continue
		var key := String(enemy.name)
		if not enemy.is_alive():
			_seen.erase(key)
			continue
		var seen: bool = can_see.call(enemy) if can_see.is_valid() else true
		if seen:
			_seen[key] = {"at": Vector3(enemy.global_position.x, 0.0, enemy.global_position.z), "t": t}
		if not _seen.has(key):
			continue
		var last: Dictionary = _seen[key]
		var age := t - float(last["t"])
		if age > MEMORY_S:
			continue
		enemies.append({"name": key, "at": last["at"], "seen": seen, "age_s": age,
				"fired_s": t - float(_fired.get(key, -NEVER)), "hit_s": t - float(_hit.get(key, -NEVER))})
	out["enemies"] = enemies
	return out


func _commanded() -> Array:
	var out: Array = []
	if not units.is_valid():
		return out
	for unit_name: String in units.call():
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			out.append(tank)
	return out


func _on_fired(event: Dictionary) -> void:
	var shooter := game_match.tanks.get_node_or_null(NodePath(str(event.get("shooter", "")))) as Tank
	if shooter == null or shooter.team == team:
		return
	var t := now()
	var id: Variant = event.get("projectile_id")
	if id != null:
		_shooter_of[id] = [String(shooter.name), t]
		if _shooter_of.size() > 256:
			_forget_shots(t)
	var muzzle := DangerFeed._vec(event.get("muzzle"))
	var direction := DangerFeed._vec(event.get("direction"))
	var reach := float(event.get("range", 0.0))
	for tank: Tank in _commanded():
		if DangerFeed.passes_near(muzzle, direction, reach, tank.global_position, IncomingFire.DANGER_RADIUS):
			_fired[String(shooter.name)] = t
			return


func _on_impact(event: Dictionary) -> void:
	var id: Variant = event.get("projectile_id")
	if id == null or not _shooter_of.has(id):
		return
	var victims: Array = [str(event.get("target", ""))]
	for victim: Dictionary in event.get("victims", []):
		victims.append(str(victim.get("target", "")))
	var mine: Array = units.call() if units.is_valid() else []
	for victim: String in victims:
		if victim != "" and mine.has(victim):
			var shooter: String = _shooter_of[id][0]
			_hit[shooter] = now()
			_fired[shooter] = now()  # a round that struck us was fired at us, whatever its line said
			return


func _forget_shots(t: float) -> void:
	for id: Variant in _shooter_of.keys():
		if t - float(_shooter_of[id][1]) > SHOT_MEMORY_S:
			_shooter_of.erase(id)


## Whether a round from `muzzle` along `direction` passes within `radius` of `point` on the ground, inside `reach`
## metres (0 = any distance). Flat: the camera's question is which way the shot came from. Pure, for tests.
static func passes_near(muzzle: Vector3, direction: Vector3, reach: float, point: Vector3, radius: float) -> bool:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 1e-4:
		return false
	flat = flat.normalized()
	var offset := Vector3(point.x - muzzle.x, 0.0, point.z - muzzle.z)
	var along := offset.dot(flat)
	if along < 0.0 or (reach > 0.0 and along > reach + radius):
		return false
	return (offset - flat * along).length() <= radius


static func _vec(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Vector3:
		return value
	return Vector3.ZERO
