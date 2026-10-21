class_name FeedbackLook
extends RefCounted
## Round 37 (feedback, F1): which look each of the four feedback slots draws. The lead picks on the directions page; until
## then DEFAULTS is the stream's recommendation, and `--feedback-look=hit:b,pinned:a+c,repair:off` (URL
## `?feedback-look=...`) shows any other, or several at once, for the page's captures and for him to try in play.
##
##   hit     a: a flare coloured by the face struck   b: a hit marker over the unit   c: the struck side lit on a ring
##   pinned  a: heads-down chevrons over the bar      b: a pin ring at the hull       c: the bar outlined, "PINNED"
##   repair  a: a mending beam Tanker -> patient      b: the Tanker's reach as a ring c: the patient's bar filling, "+5/s"
##   cone    a: sound ripples running out the cone    b: the cone's footprint         c: a shimmering cone in the air

const SLOTS := ["hit", "pinned", "repair", "cone"]
const LETTERS := ["a", "b", "c"]
const DEFAULTS := {"hit": "a", "pinned": "a", "repair": "a", "cone": "b"}

## slot -> PackedStringArray of letters ("off" = an empty one). Resolved from the flags on first use.
static var _picked := {}


static func has(slot: String, letter: String) -> bool:
	if _picked.is_empty():
		_resolve()
	return (_picked.get(slot, PackedStringArray()) as PackedStringArray).has(letter)


## Show exactly `spec` ("hit:b,pinned:a+c"); slots it does not name keep DEFAULTS. Tests and the showcase call it.
static func use(spec: String) -> void:
	_picked = parse(spec)


## Back to whatever the launch flags say (tests restore this).
static func reset() -> void:
	_picked = {}


static func parse(spec: String) -> Dictionary:
	var picked := {}
	for slot: String in SLOTS:
		picked[slot] = PackedStringArray([DEFAULTS[slot]])
	for part in spec.split(",", false):
		var pair := part.strip_edges().split(":")
		if pair.size() != 2 or not SLOTS.has(pair[0]):
			push_warning("feedback-look: ignoring '%s' (slot:letter, slots %s)" % [part, SLOTS])
			continue
		var letters := PackedStringArray()
		for letter in pair[1].split("+", false):
			if LETTERS.has(letter):
				letters.append(letter)
		picked[pair[0]] = letters  # "off" (or nothing valid) draws nothing for that slot
	return picked


static func _resolve() -> void:
	_picked = parse(LaunchFlags.from_environment().text("feedback-look"))
