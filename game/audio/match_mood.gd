class_name MatchMood
extends RefCounted
## L5: one reading of how the match *feels*, for everything that reacts to it — the announcer's energy, the music
## director, and later the crowd and the arena screens (workstreams.md, contract L5).
##
## It listens to the same K5 event stream the announcer does ([AnnouncerEvents]) and never reads the simulation, so
## it runs headless over fixtures and can't change a match. It has no clock of its own: [method push_event] and
## [method advance] move it, both in match seconds, which keeps it deterministic.
##
##     var mood := MatchMood.new("green")
##     mood.push_event(event); mood.advance(t)
##     mood.current()  # {"intensity": 0.0-1.0, "state": "battle", "reasons": ["three kills in the last ten seconds"]}
##
## **State is from one team's point of view** (the player's, "green" by default): the same match is a victory for one
## side and a defeat for the other, and a last stand is something that happens *to you*.

## Emitted when the state changes, with the new reading. The intensity moves continuously; watch [method current]
## for that (the music director crossfades on the beat, so it samples rather than listens).
signal state_changed(mood: Dictionary)

const STATES := ["lull", "skirmish", "battle", "last_stand", "victory", "defeat"]
## Heat halves this often with nothing happening; roughly how long a kill keeps the music up.
const HALF_LIFE_S := 7.0
## What each event adds to the heat. Tuned so one kill reaches "battle" and a quiet minute falls back to "lull".
const WEIGHTS := {
	"first_contact": 0.40,
	"damage": 0.06,
	"critical_damage": 0.13,
	"friendly_fire": 0.10,
	"unit_destroyed": 0.45,
	"friendly_kill": 0.55,
	"close_call": 0.22,
	"control_changed": 0.25,
	"squad_wiped": 0.50,
}
const BATTLE_AT := 0.55
const SKIRMISH_AT := 0.18
## A state is only left once the intensity has moved this far past its threshold, so the music doesn't flap.
const HYSTERESIS := 0.08
## A team at or under this share of the units it started with, and behind, is making a last stand.
const LAST_STAND_SHARE := 1.0 / 3.0
## The floor a last stand puts under the intensity: it is tense even when nothing is being shot.
const LAST_STAND_FLOOR := 0.6
## Kills inside this window are what "three kills in the last ten seconds" counts.
const RECENT_KILLS_S := 10.0

const COUNT_WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

var point_of_view := "green"
var now := 0.0
var state := "lull"
var started_contact := false
var finished := false
var winner := ""
## team -> units alive, and team -> units it started with.
var alive := {"green": 0, "rust": 0}
var started := {"green": 0, "rust": 0}

var _heat := 0.0
var _heat_t := 0.0
## Times of the kills seen, oldest first (trimmed to RECENT_KILLS_S).
var _kill_times: Array[float] = []
var _control_changes := 0
var _reasons := PackedStringArray()


## How many times the control point has changed hands this match (show reads it for its capture beats; it read the
## private field through get() before this accessor existed).
func control_changes() -> int:
	return _control_changes


func _init(team: String = "green") -> void:
	point_of_view = team


static func other(team: String) -> String:
	return "rust" if team == "green" else "green"


## One K5 event. Out-of-order events are tolerated (the clock never goes backwards).
func push_event(event: Dictionary) -> void:
	var t := float(event.get("t", now))
	advance(t)
	match String(event["type"]):
		"match_start":
			for team in event["teams"]:
				var count: int = (team["units"] as Array).size()
				alive[team["team"]] = count
				started[team["team"]] = count
		"first_contact":
			started_contact = true
			_add(WEIGHTS["first_contact"])
		"damage":
			_add(WEIGHTS["critical_damage"] if event.get("critical", false) else WEIGHTS["damage"])
		"friendly_fire":
			_add(WEIGHTS["friendly_fire"])
		"close_call":
			_add(WEIGHTS["close_call"])
		"control_changed":
			_control_changes += 1
			_add(WEIGHTS["control_changed"])
		"squad_wiped":
			_add(WEIGHTS["squad_wiped"])
		"unit_destroyed":
			var victim_team := String(event["victim_team"])
			alive[victim_team] = maxi(int(alive.get(victim_team, 0)) - 1, 0)
			_kill_times.append(t)
			_add(WEIGHTS["friendly_kill"] if event.get("friendly", false) else WEIGHTS["unit_destroyed"])
		"match_end":
			finished = true
			winner = String(event["winner"])
			for team in event.get("units_left", {}):
				alive[team] = int(event["units_left"][team])
	_settle()


## Moves the clock to `seconds` (heat decays); safe to call every frame.
func advance(seconds: float) -> void:
	if seconds <= now:
		return
	now = seconds
	_settle()


## The current reading: {intensity 0..1, state, reasons}.
func current() -> Dictionary:
	return {"intensity": snappedf(intensity(), 0.001), "state": state, "reasons": Array(_reasons)}


func intensity() -> float:
	var decayed := _heat * pow(0.5, (now - _heat_t) / HALF_LIFE_S)
	if finished:
		# The result carries its own weight; the music doesn't need the fight's heat any more.
		return 1.0 if _won() else 0.35
	return clampf(maxf(decayed, LAST_STAND_FLOOR if _is_last_stand() else 0.0), 0.0, 1.0)


## Kills in the last [constant RECENT_KILLS_S] seconds.
func recent_kills() -> int:
	var count := 0
	for t in _kill_times:
		if now - t <= RECENT_KILLS_S:
			count += 1
	return count


func _add(heat: float) -> void:
	_heat = clampf(intensity_raw() + heat, 0.0, 1.0)
	_heat_t = now


## The decayed heat alone (no last-stand floor, no result).
func intensity_raw() -> float:
	return _heat * pow(0.5, (now - _heat_t) / HALF_LIFE_S)


func _won() -> bool:
	return winner == point_of_view


func _is_last_stand() -> bool:
	if finished or not started_contact:
		return false
	var mine := int(alive.get(point_of_view, 0))
	var theirs := int(alive.get(other(point_of_view), 0))
	var start := maxi(int(started.get(point_of_view, 0)), 1)
	return mine > 0 and theirs > mine and float(mine) / float(start) <= LAST_STAND_SHARE


## Recomputes the state (with hysteresis) and the reasons, and emits when the state changed.
func _settle() -> void:
	while not _kill_times.is_empty() and now - _kill_times[0] > RECENT_KILLS_S * 3.0:
		_kill_times.pop_front()
	var was := state
	state = _state_now()
	_reasons = _reasons_now()
	if state != was:
		state_changed.emit(current())


func _state_now() -> String:
	if finished:
		return "victory" if _won() else "defeat"
	if _is_last_stand():
		return "last_stand"
	var level := intensity()
	# Leaving a state needs a little more movement than entering it, so the music doesn't flap on one stray round.
	var battle_at := BATTLE_AT - HYSTERESIS if state == "battle" else BATTLE_AT
	var skirmish_at := SKIRMISH_AT - HYSTERESIS if state in ["skirmish", "battle"] else SKIRMISH_AT
	if level >= battle_at:
		return "battle"
	if started_contact and level >= skirmish_at:
		return "skirmish"
	return "lull"


## Why it reads this way, in plain words, worst first: the announcer can quote them and a log can show them.
func _reasons_now() -> PackedStringArray:
	var found := PackedStringArray()
	if finished:
		if winner == "draw":
			found.append("the match ended in a draw")
		else:
			found.append("%s won" % winner)
		return found
	var mine := int(alive.get(point_of_view, 0))
	var theirs := int(alive.get(other(point_of_view), 0))
	if _is_last_stand():
		found.append("%s is down to %s against %s" % [point_of_view, _count(mine), _count(theirs)])
	var kills := recent_kills()
	if kills > 0:
		found.append("%s %s in the last ten seconds" % [_count(kills), "kill" if kills == 1 else "kills"])
	if not started_contact:
		found.append("nobody has fired yet")
	elif kills == 0 and intensity_raw() < SKIRMISH_AT:
		found.append("the floor has gone quiet")
	if _control_changes >= 3:
		found.append("the control point keeps changing hands")
	return found


static func _count(n: int) -> String:
	return COUNT_WORDS[n] if n >= 0 and n < COUNT_WORDS.size() else str(n)
