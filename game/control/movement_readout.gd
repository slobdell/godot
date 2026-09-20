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
## against. Vector3.ZERO when there is no leg to have a tangent.
##
## **nav publishes this now** (`Movement.state(unit)["corridor"]`, S4 §2's "one definition, one publisher"), so take
## nav's value whenever it is there and derive one only on a build that predates it. Deriving it here as well would
## be a SECOND interpretation of `path_points` - three projections of one fact was exactly what §2 was written to
## stop, and a readout that disagreed with the falsifier about which way the corridor ran would be worse than one
## that said nothing. nav sends `null` for "no leg", never Vector3.ZERO, on the same principle this file applies to
## an inactive law: an unreadable corridor must not be able to look like a readable one.
func corridor_tangent(unit_name: String, from: Vector3) -> Vector3:
	# `has`, not `get(..., null)`: nav sends null for "no leg", so the default would make an ANSWER OF NULL
	# indistinguishable from NO ANSWER AT ALL and send this straight to the fallback - overruling nav with a
	# derivation on exactly the ticks nav said there was nothing to derive. It is the same absent-versus-empty
	# distinction the facing key turns on, and getting it wrong here silently reinstates the second publisher.
	var reading := state(unit_name)
	if reading.has("corridor"):
		var published: Variant = reading["corridor"]
		if not published is Vector3:
			return Vector3.ZERO  # nav answered, and its answer was "no leg"
		var given: Vector3 = published
		return given.normalized() if given.length() > 0.001 else Vector3.ZERO
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
	# LIVE TODAY, and the only reason a player sees on this tree: the unit is swinging onto the heading he DREW with
	# a right-drag. Off the corridor by construction, and obedience - which is why S4 names it, and why folding it
	# into anything else would show "no reason" for a nose that has a perfectly good one.
	"arrival_arc": "arriving on the heading you drew",
	# RESERVED BY NAV AND NOT PUBLISHED YET, but safe to word now: nav split its old `override` in two after this
	# readout caught the name drifting, so `override` can only ever arrive meaning *a nav-owned law RAN and
	# something outranked it without naming itself*. The absence of a law is `no_law`, below, and is silent.
	"override": "a higher priority has the wheel",
	# A7's levels, real the day A6-a/A6-b exist to lose to them. Wired so the words are already the shipped ones.
	"survival": "under fire", "band": "holding its range", "armour": "front toward the threat",
}
## Reasons that get NO line. Three of these are C-3 doing its job rather than gaps.
##
## `no_law` is nav's answer on most ticks today: **no nav-owned motion law exists to run**. It is the ABSENCE of a
## cause, not a cause, and a line on every off-corridor unit every tick would be the 30-messages failure C-3 exists
## to prevent, dressed as an explanation. (This entry is why nav split the name: it used to be called `override`.)
##
## `yielding`, `blocked` and `no_path` are already spoken by the callout band over the hull (CALLOUTS, and
## `card_line`'s "No way through"/"Stuck for 4 s"). **One fact, one channel** - a fact in two vocabularies teaches a
## player to read neither. nav keeps them in its set because metrics wants them; control simply does not speak them.
##
## `no_order` is a unit with nothing to be off the corridor of.
##
## `run_style` and `reflex` are NOT in nav's set at all - `CombatMotion`'s knowledge, with no channel to the mover -
## and are listed here only so that if they ever arrive they arrive silent rather than as an unknown.
const LEGIBILITY_SILENT := ["", "no_law", "yielding", "blocked", "no_path", "no_order", "run_style", "reflex"]


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
	# A reason this build does not know renders as NOTHING, not as a guess. nav refuses anything outside its closed
	# set with push_error, so an unknown `why` here means the sets have drifted - and a wrong cause is worse than
	# none, because the player believes it.
	return String(LEGIBILITY_WORDS.get(why, ""))


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
