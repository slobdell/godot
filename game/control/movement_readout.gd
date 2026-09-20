class_name MovementReadout
extends RefCounted
## Control X5 (round 6): orders you can see landing. A unit that is *yielding* to a friend or *blocked* must say so on
## the HUD instead of looking idle (the lead, round 5: the units "aren't very responsive"; a unit that acknowledges and
## explains itself feels responsive even when it takes a second to move).
##
## The facts come from nav's N1 contract, `Movement.state(unit) -> {"phase": "pathing" | "driving" | "yielding" |
## "blocked" | "arrived", "eta_s", "remaining_m", "path_points", "blocked_by"}`. Until nav's CP1 is on `main` there is
## no Movement to ask, so `provider` is a Callable (unit name -> that Dictionary) that the mode wires to Movement when it
## exists; with none, every read is {} and nothing is drawn. This file is the whole seam: when CP1 lands, only
## `from_movement()` changes, if its call shape differs from the contract's.

## Phases the HUD calls out over a vehicle, with the word it shows. `driving`, `pathing` and `arrived` are what a
## player expects of an order and need no words. (nav: `yielding` goes live with nav's X4, right-of-way.)
const CALLOUTS := {"yielding": "YIELDING", "blocked": "BLOCKED"}
## A driving unit that has made no progress this long (nav's `stalled_s`) is called out as STUCK: the honest version of
## the number round 5 hid (a stalled unit used to declare its order complete from 12 m away).
const STALLED_SHOWN_S := 2.0
## What nav's `blocked_by` means when it is not a unit name.
const BLOCKED_WORDS := {"no_path": "No way through", "terrain": "Stuck on terrain"}
## ETAs longer than this aren't shown ("arrives in 40 s" is noise; the waypoint line already says it's far).
const ETA_SHOWN_MAX_S := 30.0

## unit name -> N1 state Dictionary; invalid = no movement system to ask.
var provider := Callable()


## The provider for nav's N1 Movement API when the class exists (CP1), else an invalid Callable. The class is looked up
## by name, so this compiles on a branch where nav has not merged yet.
static func from_movement(game_match: Node) -> Callable:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) != "Movement":
			continue
		var script := load(String(entry["path"])) as Script
		if script == null:
			return Callable()
		return func(unit_name: String) -> Dictionary:
			var tank: Node = (game_match.get("tanks") as Node).get_node_or_null(NodePath(unit_name)) if game_match != null else null
			if tank == null:
				return {}
			var reading: Variant = script.call("state", tank)
			return reading if reading is Dictionary else {}
	return Callable()


func state(unit_name: String) -> Dictionary:
	if not provider.is_valid():
		return {}
	var reading: Variant = provider.call(unit_name)
	return reading if reading is Dictionary else {}


## The word to float over a vehicle ("" = nothing to say). `{}` from nav means a hull nothing drives (a wreck, one not
## spawned yet, a unit with no order): nothing to say, never "unknown".
func callout(unit_name: String) -> String:
	var reading := state(unit_name)
	if reading.is_empty():
		return ""
	var phase := String(reading.get("phase", ""))
	if phase in ["driving", "pathing"] and float(reading.get("stalled_s", 0.0)) >= STALLED_SHOWN_S:
		return "STUCK"
	return String(CALLOUTS.get(phase, ""))


## The rest of the route a unit means to take (nav's `path_points`), for drawing: empty when nav has none.
func route(unit_name: String) -> PackedVector3Array:
	var points: Variant = state(unit_name).get("path_points", PackedVector3Array())
	if points is PackedVector3Array:
		return points
	return PackedVector3Array(points) if points is Array else PackedVector3Array()


## S4 (`_agents/legibility.md` §2, signed 2026-09-20): the ordered corridor, split for drawing into the **current leg**
## and the rest of the route. `{}` when nav has no path for this unit - the A6 legibility law is INACTIVE then, and an
## inactive law draws nothing rather than a guessed corridor (§5: an inactive law must never look like a broken one).
##
## Why the split: the law is a claim about the CURRENT LEG and nothing else ("velocity opposing the corridor tangent"
## is measured against this leg's direction), so the leg is drawn at full weight and the rest is left faint. One
## definition, one publisher: this reads nav's `path_points` and nobody recomputes a corridor of their own.
func corridor(unit_name: String, from: Vector3) -> Dictionary:
	var points := route(unit_name)
	if points.is_empty():
		return {}
	var rest := PackedVector3Array()
	for i in range(1, points.size()):
		rest.append(points[i])
	return {"leg": [Vector3(from.x, 0.0, from.z), Vector3(points[0].x, 0.0, points[0].z)], "rest": rest}


## The current leg's unit direction on the ground - the corridor tangent the A6 law and its falsifier are measured
## against. Vector3.ZERO when the law is inactive (no path) or the unit is already on the waypoint.
func corridor_tangent(unit_name: String, from: Vector3) -> Vector3:
	var lane := corridor(unit_name, from)
	if lane.is_empty():
		return Vector3.ZERO
	var leg: Array = lane["leg"]
	var along: Vector3 = (leg[1] as Vector3) - (leg[0] as Vector3)
	return along.normalized() if along.length() > 0.001 else Vector3.ZERO


# ---- S4 / A6, control's C-2: attribution when the legibility law gives way ---------------------------------
#
# `_agents/legibility.md` section 6.2, signed 2026-09-20, and the condition control's signature carries: when A6 is
# overridden - the case the player experiences as *"it stopped doing what I told it"* - the existing "why did my
# element do that" line says so, IN THE VOCABULARY ALREADY SHIPPED. It never invents a cause: control will not infer
# which level took the nose from geometry, because a guessed attribution is confidently wrong on exactly the ticks
# the player is watching. Silence is the correct output until nav publishes the cause.
#
# nav's shape (its N5 commit): `Movement.state(unit)["legibility"] = {"active": bool, "why": StringName}`. nav has
# stated what `why` can truthfully be, and it depends on the arm:
#   * A7 ON  - a real level name, because `choose_projected` narrows one level at a time and the level that last
#              reduced the candidate set IS the cause. Recorded, not inferred.
#   * A7 OFF (today's default) - **`override` and nothing finer**: the blend is a weighted sum, no term "bound"
#              anything, and any level name would be invented.
# So this vocabulary DEGRADES TO ONE WORD and must read correctly when it does.
const LEGIBILITY_WORDS := {
	# The level-1/2/3 overrides: a unit that breaks off FOR A REASON THE PLAYER CAN SEE is not disobedient.
	"survival": "under fire", "band": "holding its range", "armour": "front toward the threat",
	"arc": "keeping its gun on", "formation": "holding its place",
	# The honest single word for the blend, and what the default path will say until A7 is on by default.
	"override": "a higher priority has the wheel",
}
## Reasons the law is inactive that are NOT an override and get NO line: either the law has nothing to say, or
## something else on screen already says it. `blocked` and `no_path` belong to CALLOUTS (BLOCKED / STUCK) - C-3 keeps
## that band for *nav cannot proceed*, and A6 is about a unit that IS proceeding.
const LEGIBILITY_SILENT := ["", "no_order", "no_path", "blocked", "reflex", "style_run"]


## nav's legibility state for a unit, or {} when this build's nav does not publish one (every build before nav's N5).
func legibility(unit_name: String) -> Dictionary:
	var reading: Variant = state(unit_name).get("legibility", {})
	return reading if reading is Dictionary else {}


## What to tell the player about a unit driving off its ordered corridor: the cause in the words already on screen,
## or "" when there is nothing honest to say. "" covers every case that matters: nav publishes nothing (no guessing),
## the law is active (the unit is on its corridor, so there is nothing to explain), the unit has no order, and the
## reasons another readout already owns.
func legibility_line(unit_name: String) -> String:
	var reading := legibility(unit_name)
	if reading.is_empty() or bool(reading.get("active", false)):
		return ""
	var why := String(reading.get("why", ""))
	if why in LEGIBILITY_SILENT:
		return ""
	return String(LEGIBILITY_WORDS.get(why, LEGIBILITY_WORDS["override"]))


## One line for the unit card: "Blocked by Green_Alpha_2", "Giving way", "Arrives in 4 s", or "".
func card_line(unit_name: String, describe_unit: Callable = Callable()) -> String:
	var reading := state(unit_name)
	match String(reading.get("phase", "")):
		"blocked":
			var by := String(reading.get("blocked_by", ""))
			if by == "":
				return "Blocked"
			if BLOCKED_WORDS.has(by):
				return String(BLOCKED_WORDS[by])
			return "Blocked by %s" % (describe_unit.call(by) if describe_unit.is_valid() else by)
		"yielding":
			return "Giving way to a friend"
		"pathing", "driving":
			var stalled := float(reading.get("stalled_s", 0.0))
			if stalled >= STALLED_SHOWN_S:
				return "Stuck for %d s" % roundi(stalled)
			var eta := float(reading.get("eta_s", -1.0))
			if eta >= 0.0 and eta <= ETA_SHOWN_MAX_S:
				return "Arrives in %d s" % maxi(1, roundi(eta))
	return ""
