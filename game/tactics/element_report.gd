class_name ElementReport
extends RefCounted
## What an element decided, as **structured data for anyone who wants to talk about it** — the announcer
## first (contract K5), later the HUD, the crowd and the screens. The lead (2026-09-16): *"rather than
## cluttering the UI, we can use that information to generate scripted statements from the announcers about
## how a squad is lining up in whatever formation for whatever reason. Presumably we at least want the
## structured data publishable."*
##
## Doctrine publishes; it never writes a line of commentary. The words belong to audio's line library, which
## is why every field here is a value to slot into a sentence and none of them is a sentence.
##
##   Elements.element_reported(event)      -> one of these, on a decision worth mentioning
##
## The shape matches K5 match events (tests/announcer/fixtures/README.md): a `type` plus flat fields, with no
## `tick`/`t` — whoever forwards it into a timeline stamps those, the way MatchEventAdapter already does for
## every other event. Two types:
##
##   {"type": "element_formation", "team": "green", "element": "Alpha", "size": 4,
##    "formation": "wedge", "technique": "traveling_overwatch", "reason": "contact possible: wedge, fire to
##    the front and both flanks covered, trail element overwatching", "changed": ["formation"]}
##
##   {"type": "element_drill", "team": "green", "element": "Alpha", "size": 4, "drill": "near_ambush",
##    "formation": "line", "reason": "ambushed at 25 m: turn into it and assault through",
##    "distance": 25.4, "target": "Rust_Ambush_1"}
##
## `reason` is the doctrine table's own `why` (or the drill's), so the announcer can quote the element's
## logic instead of inventing one. `changed` says which of formation/technique moved, so a director can call
## a shape change and ignore a technique change, or the other way round.

const TEAM_KEYS := ["green", "rust"]
## Decisions worth mentioning: a drill starting is always news, so is a new task and a change of shape; a
## reason changing on its own is not (the same wedge for a slightly different reason is not a sentence).
const REPORTABLE := ["task", "formation", "technique", "drill"]
## The same call is not made twice inside this many ticks (10 s). An element that halts, moves and halts
## again forms the same herringbone each time, and a booth that says so every time is the PA repeating
## itself — the thing the lead complained about.
const COOLDOWN_TICKS := 600


## The event for an element's latest decision, or {} when nothing worth reporting changed.
static func of(element: Element) -> Dictionary:
	# An element nobody has given a job to is not doing anything worth saying. Before its first task it is
	# just parked, and five elements all "halting in cover" on the first tick is noise, not commentary.
	if element.task.is_empty():
		return {}
	var changed: Array = []
	for field in element.changed_fields:
		if REPORTABLE.has(field):
			changed.append(field)
	if changed.is_empty():
		return {}
	# A drill STARTING is the call. Coming off one is the element going back to moving, which reads as a
	# shape change and carries the movement reason the booth wants.
	if changed.has("drill") and element.drill != "":
		return drill_event(element)
	return formation_event(element)


## An element took a new shape, changed how carefully it is moving, or came off a drill and went back to
## moving. (Coming off a drill is a shape change, not a drill: `element_drill` always means one STARTED.)
static func formation_event(element: Element) -> Dictionary:
	var event := _common(element)
	event["type"] = "element_formation"
	event["formation"] = element.formation
	event["technique"] = element.technique
	event["changed"] = Array(element.changed_fields).filter(
			func(field: Variant) -> bool: return REPORTABLE.has(field))
	return event


## A battle drill started (or the element came off one: `drill` is "" then).
static func drill_event(element: Element) -> Dictionary:
	var event := _common(element)
	event["type"] = "element_drill"
	event["drill"] = element.drill
	event["formation"] = element.formation
	event["distance"] = snappedf(element.drill_distance, 0.1)
	event["target"] = element.drill_target
	return event


static func _common(element: Element) -> Dictionary:
	return {"team": team_key(element.team), "element": element.element_name,
			"size": maxi(element.strength, element.members().size()), "reason": element.reason}


## What makes two calls "the same" for the cooldown: the shape and technique, or the drill.
static func key(event: Dictionary) -> String:
	if String(event.get("type", "")) == "element_drill":
		return "drill|%s" % event.get("drill", "")
	return "shape|%s|%s" % [event.get("formation", ""), event.get("technique", "")]


static func team_key(team: int) -> String:
	return TEAM_KEYS[team] if team >= 0 and team < TEAM_KEYS.size() else "green"
