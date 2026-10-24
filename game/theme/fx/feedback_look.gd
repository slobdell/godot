class_name FeedbackLook
extends RefCounted
## Round 37 (feedback, C37.6): which of the rules made visible are drawn. The lead picked one look per slot on the
## directions page (2026-10-21, game_design.md "his picks on feedback's directions page"); the other looks are gone.
##
##   hit     the struck side lit on a ring segment under the tank (FeedbackFx)
##   pinned  heads-down chevrons over the bar, one to three by how pinned (UnitBars)
##   repair  a mending beam, Tanker -> patient (FeedbackFx)
##   cone    a shimmering cone in the air while a Sonic Emitter blows (FeedbackFx)
##   slowed  round 39 (his pick "slowed: amber", 2026-10-24): the pinned chevrons show from the first 5 % of R3's slow
##           and warm from yellow to orange as it deepens (UnitBars; needs pinned on)
##   marks   the radar rings a pinned enemy in sight; the unit card says PINNED / REPAIRING +5/s (OFF: not on his page)
##
## `--feedback-look=hit:off,marks:on` (URL `?feedback-look=...`) turns any of them off or on, for captures and A/B.

const SLOTS := ["hit", "pinned", "repair", "cone", "slowed", "marks"]
const DEFAULTS := {"hit": true, "pinned": true, "repair": true, "cone": true, "slowed": true, "marks": false}

## slot -> bool. Resolved from the flags on first use.
static var _on := {}


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
