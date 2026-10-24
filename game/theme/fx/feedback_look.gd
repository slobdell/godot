class_name FeedbackLook
extends RefCounted
## Round 37 (feedback, C37.6): which of the rules made visible are drawn. The lead picked one look per slot on the
## directions page (2026-10-21, game_design.md "his picks on feedback's directions page"); the other looks are gone.
##
##   hit     the struck side lit on a ring segment under the tank (FeedbackFx)
##   pinned  heads-down chevrons over the bar, one to three by how pinned (UnitBars)
##   repair  a mending beam, Tanker -> patient (FeedbackFx)
##   cone    a shimmering cone in the air while a Sonic Emitter blows (FeedbackFx)
##   marks   the radar rings a pinned enemy in sight; the unit card says PINNED / REPAIRING +5/s (OFF: not on his page)
##
## `--feedback-look=hit:off,marks:on` (URL `?feedback-look=...`) turns any of them off or on, for captures and A/B.

## Round 39 (F1, C39.5): candidate looks for the round-37 rules (ON since R38.55), filmed for his directions page. Nothing
## new shows until he picks: every one defaults to "none". `--rules-look=sight:edge,fire:wedge,slowed:amber`.
##   sight   edge: the fog's boundary glows brighter round a crew that has settled (~110 %); ring: a live sight ring
##           under each selected crew of his
##   fire    wedge: a shot fired on the move leaves a fading wedge of its spread, the stopped spread drawn inside it
##   slowed  amber: chevrons from the first slow, warming to orange as it deepens; brake: brake lights on a slowed hull
const RULE_LOOKS := {"sight": ["none", "edge", "ring"], "fire": ["none", "wedge"], "slowed": ["none", "amber", "brake"]}

const SLOTS := ["hit", "pinned", "repair", "cone", "marks"]
const DEFAULTS := {"hit": true, "pinned": true, "repair": true, "cone": true, "marks": false}

## slot -> bool. Resolved from the flags on first use.
static var _on := {}
## rule slot -> look name (RULE_LOOKS). Resolved from the flags on first use.
static var _rule := {}


static func on(slot: String) -> bool:
	if _on.is_empty():
		_resolve()
	return bool(_on.get(slot, false))


## Show exactly `spec` ("hit:off,marks:on"); slots it does not name keep DEFAULTS. Tests and the captures call it.
static func use(spec: String) -> void:
	_on = parse(spec)


## Back to whatever the launch flags say (tests restore this).
static func reset() -> void:
	_on = {}
	_rule = {}


## The look drawn for a rule slot ("none" unless --rules-look or use_rules picked one).
static func rule(slot: String) -> String:
	if _rule.is_empty():
		_rule = parse_rules(LaunchFlags.from_environment().text("rules-look"))
	return String(_rule.get(slot, "none"))


## Show exactly `spec` ("sight:edge,fire:wedge"); slots it does not name draw nothing. Tests and the captures call it.
static func use_rules(spec: String) -> void:
	_rule = parse_rules(spec)


static func parse_rules(spec: String) -> Dictionary:
	var picked := {}
	for slot: String in RULE_LOOKS:
		picked[slot] = "none"
	for part in spec.split(",", false):
		var pair := part.strip_edges().split(":")
		if pair.size() != 2 or not RULE_LOOKS.has(pair[0]) or not (RULE_LOOKS[pair[0]] as Array).has(pair[1]):
			push_warning("rules-look: ignoring '%s' (slot:look, %s)" % [part, RULE_LOOKS])
			continue
		picked[pair[0]] = pair[1]
	return picked


static func parse(spec: String) -> Dictionary:
	var picked := DEFAULTS.duplicate()
	for part in spec.split(",", false):
		var pair := part.strip_edges().split(":")
		if pair.size() != 2 or not SLOTS.has(pair[0]) or not ["on", "off"].has(pair[1]):
			push_warning("feedback-look: ignoring '%s' (slot:on|off, slots %s)" % [part, SLOTS])
			continue
		picked[pair[0]] = pair[1] == "on"
	return picked


static func _resolve() -> void:
	_on = parse(LaunchFlags.from_environment().text("feedback-look"))
