class_name WaterLook
extends RefCounted
## Round 12 (arena, A1): the wet look as a sequence of PAIRS, one dial moved per step (show's rule 12), so the lead
## judges each change on its own at his pose. Step 0 is round 10's water exactly; the last step is what ships, and
## `test_the_water_pairs_end_at_what_ships` holds the shader's defaults to it. `make water-pairs` shoots them all.
##
## A dial is a water.gdshader uniform. Two steps move a pair of uniforms that are ONE decision (the specular's source:
## the real lamps on and round 10's fake streak off; the swell: its long and short waves together); the caption says so.

## Round 10's value of every dial (read from its water.gdshader: `water_deep`, the one streak, a +-0.04 swell).
const ROUND_10 := {
	"water_deep": Color(0.004, 0.012, 0.018),
	"body_flood": 0.0,
	"venue_reflect": 0.0,
	"glint": 0.0,
	"legacy_streak": 1.0,
	"swell_amp": 0.04,
	"swell_fine": 0.0,
	"lap": 0.0,
}
const DIALS := ["water_deep", "body_flood", "venue_reflect", "glint", "legacy_streak", "swell_amp", "swell_fine", "lap"]

## [name, caption, {dial: value}] in the order the diagnosis builds it (arenas.md *Water reads black*).
const STEPS := [
	["r10", "round 10 as shipped: oily black", {}],
	["a_body", "(a) body colour off black: water_deep (0.004, 0.012, 0.018) -> dark teal (0.025, 0.09, 0.1)",
			{"water_deep": Color(0.025, 0.09, 0.1)}],
	["a_flood", "(a) the body lit by the floor's own light map where the floodlight pools fall: body_flood 0 -> 0.3",
			{"body_flood": 0.3}],
	["b_venue", "(b) reflect the venue as built (blocks, containers, wall bars, stands, crowd) instead of the horizon band: venue_reflect 0 -> 1",
			{"venue_reflect": 1.0}],
	["c_lamps", "(c) specular from the REAL lamp heads (towers, floodlights), each a column of light toward the eye, and the floodlight pools glinting on the swell's crests, instead of round 10's one fixed streak: glint 0 -> 1, legacy_streak 1 -> 0",
			{"glint": 1.0, "legacy_streak": 0.0}],
	["c_swell", "(c) a slow swell that moves the glints: swell_amp 0.04 -> 0.08 rad, swell_fine 0 -> 0.025 rad (3-16 m waves, no sparkle)",
			{"swell_amp": 0.08, "swell_fine": 0.025}],
	["d_lap", "(d) the lap line where water meets its walls (pits have none): lap 0 -> 1",
			{"lap": 1.0}],
]


## Every dial's value at step `name`: round 10's, then each step's changes up to and including that one.
static func at(name: String) -> Dictionary:
	var look := ROUND_10.duplicate()
	for step: Array in STEPS:
		look.merge(step[2], true)
		if step[0] == name:
			return look
	push_error("WaterLook: no step %s" % name)
	return look


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for step: Array in STEPS:
		out.append(step[0])
	return out


static func caption(name: String) -> String:
	for step: Array in STEPS:
		if step[0] == name:
			return step[1]
	return ""


## What ships: the last step.
static func shipped(dial: String) -> Variant:
	return at(STEPS[-1][0])[dial]
