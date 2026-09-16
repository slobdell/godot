class_name ElementAwareness
extends RefCounted
## Control X2: how every element of your force is doing, and the alerts that tell you when one needs you.
##
## An "element" is a control group (doctrine squads start as groups 1-5, so they are the same thing). For each
## one this reports where it is, how much of it is left, and what it is doing; when that state turns bad it
## raises an alert with a place attached, so `Q` can take you straight there. Alerts are rate-limited per
## element and kind: an element that stays in contact says so once, not sixty times a second.
##
## The camera frames one element at a time (X1), so this is the rest of the awareness the player used to get
## from a god view: the edge markers (EdgeMarkers) and the radar draw it, and the HUD messages read it.

## A unit hit within this many ticks counts as under fire (1.5 s at 60 Hz).
const UNDER_FIRE_TICKS := 90
## The same element cannot raise the same kind of alert again for this long (seconds).
const ALERT_COOLDOWN := 8.0
## How many alerts are kept; older ones fall off.
const ALERT_KEEP := 6
## A wiped-out element stays in the list this long, so "Bravo wiped out" has something to point at and the
## player can see which element it was before it disappears (seconds).
const LOST_LINGER := 10.0
## States worth interrupting the player for, worst first.
const ALERT_STATES := {"lost": "wiped out", "under_fire": "under fire", "contact": "contact"}

var game_match: Match
var groups: ControlGroups
var orders: Orders
var team := Match.Team.GREEN

## Newest last: [{"text", "position": Vector3, "kind", "element": int, "at": float, "seen": bool}].
var alerts: Array = []

## element number -> the state it was in last update, so only changes raise alerts.
var _was := {}
## number -> [element, clock] for elements whose group has emptied out: ControlGroups.prune drops dead units, so
## without this a wiped element would simply vanish instead of telling you it died.
var _lost := {}
## "<number>:<kind>" -> the clock reading when it last fired.
var _fired := {}
var _clock := 0.0
var _elements: Array = []
## number -> the last place an element was seen alive, so a wiped one can still be pointed at.
var _positions := {}
## The living enemies, refreshed once per update.
var _enemies: Array = []


## One entry per non-empty control group: {"number", "label", "units", "alive", "total", "health" 0..1,
## "position": Vector3, "state"}. Recomputed by `update`, so callers in one frame all see the same thing.
func elements() -> Array:
	return _elements


## Recompute every element and raise alerts for the ones whose state just got worse. Call once a frame.
func update(delta: float) -> void:
	_clock += delta
	_elements = []
	if game_match == null or groups == null:
		return
	# X4: one pass over the tank list per update instead of one per member. At 30 a side the per-member scan was
	# 1800 casts and distance checks a frame, and it was this class's whole cost.
	_enemies = []
	for node in game_match.tanks.get_children():
		var enemy := node as Tank
		if enemy != null and enemy.is_alive() and enemy.team != team:
			_enemies.append(enemy)
	var live := groups.numbers()
	for number in live:
		var element := _describe(number)
		_elements.append(element)
		var state := String(element["state"])
		if _was.get(number, "") != state and ALERT_STATES.has(state):
			_raise(element, state)
		_was[number] = state
		_lost.erase(number)
	for number in _was.keys():
		if live.has(number) or _was[number] == "":
			continue
		if not _lost.has(number):
			var gone := {"number": number, "label": groups.label(number), "units": [], "alive": 0, "total": 0,
					"health": 0.0, "position": _positions.get(number, Vector3.ZERO), "state": "lost"}
			_lost[number] = [gone, _clock]
			_raise(gone, "lost")
			_was[number] = "lost"
	for number in _lost.keys():
		if _clock - float(_lost[number][1]) > LOST_LINGER:
			_lost.erase(number)
			_was.erase(number)
		else:
			_elements.append(_lost[number][0])


func _describe(number: int) -> Dictionary:
	var units := groups.members(number)
	var middle := Vector3.ZERO
	var alive := 0
	var health := 0.0
	var state := "idle"
	var moving := false
	var contact := false
	var under_fire := false
	var contact_at := Vector3.ZERO
	var contact_range := INF
	for unit_name in units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		alive += 1
		middle += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		health += clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
		if tank.ticks_since_hit <= UNDER_FIRE_TICKS:
			under_fire = true
		if orders != null and not orders.is_idle(unit_name):
			moving = true
		var seen: Variant = _nearest_enemy(tank)
		if seen != null:
			contact = true
			var gap: float = tank.global_position.distance_to((seen as Tank).global_position)
			if gap < contact_range:
				contact_range = gap
				contact_at = (seen as Tank).global_position
	if alive > 0:
		middle /= float(alive)
		health /= float(alive)
		state = "under_fire" if under_fire else ("contact" if contact else ("moving" if moving else "idle"))
	else:
		state = "lost"
	if alive > 0:
		_positions[number] = middle
	else:
		middle = _positions.get(number, middle)
	return {"number": number, "label": groups.label(number), "units": units, "alive": alive, "total": units.size(),
			"health": health, "position": middle, "state": state,
			"contact_at": contact_at if contact else Vector3.ZERO, "contact": contact}


## The closest living enemy inside this unit's sight, or null.
func _nearest_enemy(tank: Tank) -> Variant:
	var best: Tank = null
	var best_gap := INF
	for enemy: Tank in _enemies:
		var gap := enemy.global_position.distance_to(tank.global_position)
		if gap <= tank.sight_radius and gap < best_gap:
			best = enemy
			best_gap = gap
	return best


func _raise(element: Dictionary, state: String) -> void:
	var key := "%d:%s" % [int(element["number"]), state]
	if _clock - float(_fired.get(key, -1e9)) < ALERT_COOLDOWN:
		return
	_fired[key] = _clock
	var where := ""
	if state == "contact" and bool(element.get("contact", false)):
		# Which way the enemy lies from the element, not where the element is: "Bravo contact north" has to mean
		# "look north from Bravo" or it sends the player the wrong way.
		where = " " + compass(element["contact_at"] - (element["position"] as Vector3), team)
	alerts.append({"text": "%s %s%s" % [element["label"], ALERT_STATES[state], where], "position": element["position"],
			"kind": state, "element": int(element["number"]), "at": _clock, "seen": false})
	while alerts.size() > ALERT_KEEP:
		alerts.pop_front()


## The newest alert nobody has jumped to yet, marked seen ({} when there is none).
func take_alert() -> Dictionary:
	for i in range(alerts.size() - 1, -1, -1):
		var alert: Dictionary = alerts[i]
		if not bool(alert["seen"]):
			alert["seen"] = true
			return alert
	return {}


## How long ago an alert was raised (seconds).
func age_of(alert: Dictionary) -> float:
	return _clock - float(alert["at"])


## Forget every alert and rate limit (a fresh match, or a test setting up a clean situation).
func forget() -> void:
	alerts.clear()
	_was.clear()
	_fired.clear()
	_lost.clear()


func unseen_count() -> int:
	return alerts.filter(func(a: Dictionary) -> bool: return not bool(a["seen"])).size()


## Which way an offset points, in words, with the enemy base always "north" (the radar's convention).
static func compass(offset: Vector3, team: int) -> String:
	var frame := Match.team_frame(team)
	var forward: Vector3 = frame["forward"]
	var flip := 1.0 if forward == Vector3.FORWARD else -1.0
	var ahead := -offset.z * flip
	var right := offset.x * flip
	if absf(ahead) < absf(right) * 0.5:
		return "east" if right > 0.0 else "west"
	if absf(right) < absf(ahead) * 0.5:
		return "north" if ahead > 0.0 else "south"
	return ("north" if ahead > 0.0 else "south") + ("east" if right > 0.0 else "west")
