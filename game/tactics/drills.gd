class_name Drills
extends RefCounted
## Battle drills: what a trained crew does on contact without being told (doctrine X3). Pure, deterministic
## decision functions — no engine state, no clock, no randomness — so every trigger has a unit test and a
## seeded scenario. The doctrine and citations (React to Contact, React to Ambush near and far, Break Contact,
## Support by Fire, herringbone at a halt) are in _agents/doctrine.md.
##
##   Drills.select(situation, state, table) -> {"drill", "why", "point", "target"}
##
## `situation` is ElementSituation.build(); `state` is the element's {drill, drill_tick, drill_point,
## drill_target, task, arrived}; `table` is the element's DoctrineTable, which owns every number and may
## switch a drill off entirely (factions differ by table, never by engine).
##
## Each drill has an ENTRY condition, an ABORT condition and a TIMEOUT (table.drills.timeout_ticks), and any
## of them yields at once to a player order: the element stops commanding a unit the moment its order came
## from somewhere else (Element._adopt), so a drill can never hold a unit against its commander.
##
## Priority, highest first (a near ambush interrupts everything: it is immediate action, not a decision):
##   near_ambush -> assault_through -> break_contact -> a support-by-fire TASK (a screen on its line: no drill)
##   -> encircle -> bait -> react_to_contact -> far_ambush -> herringbone
##
## Two of these are not in any manual, because not every faction has read one. `encircle` (a pack fanning
## around a target and circling it, so the damage lands on many vehicles instead of one) and `bait` (a fast
## vehicle drawing fire back onto the rest) belong to the road gangs, and only exist for a doctrine whose
## table switches them on. The lead (2026-09-16): *"the street gangs ... should be noticeably less military
## disciplined ... they might use tactics of spreading out their formations wide for better survivability or
## do circular swarms ... I suspect the street gang would also be more likely to create tactics of having a
## vehicle draw fire to try and lead the opponents into an ambush."*

const NAMES := ["react_to_contact", "near_ambush", "assault_through", "far_ambush", "support_by_fire",
		"break_contact", "herringbone", "encircle", "bait"]
## Drills that mean "we are fighting this contact": react to contact does not restart while one of them runs.
const CONTACT_DRILLS := ["react_to_contact", "near_ambush", "assault_through", "far_ambush", "break_contact",
		"encircle", "bait"]
## A contact first seen within this many ticks counts as sudden (the ambush is sprung, not walked into).
const SUDDEN_TICKS := SimClock.TICK_RATE * 3 / 4
## How long the element turns into a near ambush before the assault carries it through (ticks).
const TURN_TICKS := SimClock.TICK_RATE / 2
## Break contact is re-checked with hysteresis: this much better than the trigger ratio ends it.
const RECOVER_FACTOR := 1.25
## A halt counts as halted when the element is within this far of where it was told to stop (meters).
const HALTED_M := 12.0
## A screen counts as on its line when the element's centre is this close to the point it was sent to (meters).
const SCREEN_REACHED_M := 30.0


## The drill the element should be running now, and why (a string the player reads). "" = no drill:
## carry on with the movement plan.
static func select(situation: Dictionary, state: Dictionary, table: DoctrineTable) -> Dictionary:
	var previous := String(state.get("drill", ""))
	var current := previous
	var elapsed: int = int(situation.get("tick", 0)) - int(state.get("drill_tick", 0))
	var timed_out := current != "" and elapsed >= table.drill_ticks("timeout_ticks")
	if timed_out or (current != "" and _finished(current, situation, state, table, elapsed)):
		current = ""
	# A plain move (the player's right-click, X4): the player said where, not how to fight. No drill at all.
	if not ElementTask.runs_drills(state.get("task", {})):
		return {"drill": "", "why": "", "point": null, "target": ""}

	# 1. Near ambush: close, sudden and deadly. Turn into it and charge; nothing else outranks this.
	if table.runs_drill("near_ambush") and current != "near_ambush" and current != "assault_through" \
			and is_near_ambush(situation, table, CONTACT_DRILLS.has(previous)):
		var ambush := nearest_contact(situation)
		return _drill("near_ambush", "ambushed at %d m: turn into it and assault through"
				% int(float(ambush.get("distance", 0.0))), ambush)
	# 2. The turn is done: carry the assault through the ambush position.
	if current == "near_ambush" and elapsed >= TURN_TICKS:
		return _drill("assault_through", "assault through the ambush", _remembered(state, situation))
	# 3. We are losing and can still get out: break contact by bounds.
	if table.runs_drill("break_contact") and should_break_contact(situation, state, table):
		return _drill("break_contact", "outgunned here: break contact and bound back", nearest_contact(situation))
	# 3b. A base-of-fire TASK is the drill. The commander has said where the element fights from; contact must not turn
	# it into an advance (react_to_contact) or a flank (far_ambush), which used to outrank it (round 6: the lead pressed
	# support-by-fire, watched nothing form up, and lesson 17 found the rules above it starving it).
	var task_verb := String((state.get("task", {}) as Dictionary).get("verb", ""))
	if task_verb == "support_by_fire" and table.runs_drill("support_by_fire"):
		return _drill("support_by_fire", "support by fire: suppress from here, don't advance", nearest_contact(situation))
	# 3c. A screen that is on its line fights only what comes to it: no drill takes it forward or round a flank.
	if task_verb == "screen" and on_screen_line(situation, state):
		return {"drill": "", "why": "", "point": null, "target": ""}
	# 4. Keep running what we have. (The gang drills below are checked only when nothing is running: they
	# are alternatives to each other, and an element that keeps swapping between them does neither.)
	if current != "":
		return _drill(current, String(state.get("drill_why", "")), _remembered(state, situation))
	# 4b. A pack doesn't line up and trade: it gets around them and keeps moving (gangs).
	if table.runs_drill("encircle") and should_encircle(situation, table):
		return _drill("encircle", "get around them and keep circling: spread the damage",
				nearest_visible(situation))
	# 4c. Or sends one vehicle to pull them onto the rest (gangs).
	if table.runs_drill("bait") and should_bait(situation, table):
		return _drill("bait", "one runs at them and leads them back onto the pack", nearest_visible(situation))
	# 5. First contact: deploy, return fire and report, then the leader picks a course of action. Actions on
	# contact happen ONCE per contact: while the element is already fighting this one, it does not go back to
	# the start of the drill (that flip-flop cost the far-ambush scenario its maneuver, 2026-09-16).
	if table.runs_drill("react_to_contact") and not CONTACT_DRILLS.has(previous) \
			and String(situation.get("threat", "none")) == "contact":
		return _drill("react_to_contact", "contact: return fire, take cover, report", nearest_contact(situation))
	# 6. Contact has been evaluated: a far ambush is fought by fire and maneuver (only while engaged; a
	# contact watched from 100 m is not an ambush).
	if table.runs_drill("far_ambush") and _has_visible(situation) \
			and String(situation.get("threat", "none")) == "contact":
		return _drill("far_ambush", "far ambush: pin them by fire, flank with the rest", nearest_contact(situation))
	# 8. Halted with something out there: herringbone, all-round security.
	if table.runs_drill("herringbone") and is_halted(situation, state) and String(situation.get("threat", "none")) != "none":
		return _drill("herringbone", "halted: herringbone, watch the flanks", {})
	return {"drill": "", "why": "", "point": null, "target": ""}


## Whether a screening element has reached the line it was sent to hold (its centre within SCREEN_REACHED_M of the
## task's point).
static func on_screen_line(situation: Dictionary, state: Dictionary) -> bool:
	var point: Variant = ElementTask.destination(state.get("task", {}))
	if point == null:
		return false
	return _flat(situation.get("center", Vector3.ZERO)).distance_to(_flat(point)) <= SCREEN_REACHED_M


## A near ambush: a contact inside near_ambush_m that we have only just seen, or — when we were not already
## fighting — one that close while we are being hit. Doctrine's immediate action is to assault through it.
## `engaged` (we are already running a contact drill) raises the bar to a *newly seen* enemy: being shot at by
## something we have been fighting for ten seconds is not an ambush, and treating it as one turned every
## flanking maneuver into a frontal charge (measured, 2026-09-16).
static func is_near_ambush(situation: Dictionary, table: DoctrineTable, engaged := false) -> bool:
	var contact := nearest_contact(situation)
	if contact.is_empty() or not bool(contact.get("visible", false)):
		return false
	if float(contact["distance"]) > table.drill_number("near_ambush_m"):
		return false
	if int(contact.get("age", 1 << 30)) <= SUDDEN_TICKS:
		return true
	return not engaged and bool(situation.get("taking_fire", false))


## Break contact when the element is clearly outgunned AND the enemy is still far enough that turning away
## doesn't just hand them our flanks (round-3 lesson: disengaging up close gets you shot).
static func should_break_contact(situation: Dictionary, state: Dictionary, table: DoctrineTable) -> bool:
	var enemy := float(situation.get("enemy_strength", 0.0))
	if enemy <= 0.0:
		return false
	var ratio := float(situation.get("strength", 0.0)) / enemy
	var trigger := table.drill_number("break_contact_ratio")
	if String(state.get("drill", "")) == "break_contact":
		# Hysteresis: keep withdrawing until the odds are clearly better or the contact is broken.
		return ratio < trigger * RECOVER_FACTOR and _nearest_distance(situation) < table.drill_number("broken_contact_m")
	if ratio >= trigger:
		return false
	return _nearest_distance(situation) > table.drill_number("disengage_m")


## Encircle: enough vehicles to make a ring worth having, an enemy we can see and reach, and nobody so close
## that turning side-on to them is suicide. A pack of two is not a ring, it is two targets.
static func should_encircle(situation: Dictionary, table: DoctrineTable) -> bool:
	if (situation.get("members", []) as Array).size() < int(table.drill_number("encircle_min_units")):
		return false
	var contact := nearest_visible(situation)
	if contact.is_empty():
		return false
	var distance := float(contact["distance"])
	return distance <= table.drill_number("encircle_m") and distance >= table.drill_number("encircle_min_m")


## Bait: we can see them, they are far enough away to be led, they are the kind of enemy that FOLLOWS, and we
## have someone fast enough to do the leading and live. One vehicle draws; the rest wait off the line it
## comes back along.
##
## The "follows" part is the whole drill. Against a dug-in gun that never moves, a lure is not a tactic: the
## bait drives into range, dies, and the pack sits 55 m back watching (measured, 2026-09-16 — the first
## version of this drill lost three of four vehicles to two stationary guns without landing a shot).
static func should_bait(situation: Dictionary, table: DoctrineTable) -> bool:
	if (situation.get("members", []) as Array).size() < 2:
		return false
	var contact := nearest_visible(situation)
	if contact.is_empty():
		return false
	var distance := float(contact["distance"])
	if distance < table.drill_number("bait_min_m") or distance > table.drill_number("bait_m"):
		return false
	if float(contact.get("speed", 0.0)) < table.drill_number("bait_chaser_mps"):
		return false
	return not bait_of(situation).is_empty()


## Who draws the fire: the fastest vehicle in the element, and never the leader. Speed is what makes the
## difference between a lure and a casualty.
static func bait_of(situation: Dictionary) -> Dictionary:
	var leader := String(situation.get("leader", ""))
	var best := {}
	for member: Dictionary in situation.get("members", []):
		if String(member["name"]) == leader:
			continue
		if best.is_empty() or float(member["speed"]) > float(best["speed"]) + 0.01 \
				or (is_equal_approx(float(member["speed"]), float(best["speed"]))
						and String(member["name"]) < String(best["name"])):
			best = member
	return best


## The element is standing where it was told to stand (or has no destination left to reach).
static func is_halted(situation: Dictionary, state: Dictionary) -> bool:
	var task: Dictionary = state.get("task", {})
	if task.is_empty() or String(task.get("verb", "")) == "hold":
		return true
	if not bool(state.get("arrived", false)):
		return false
	var destination: Variant = ElementTask.destination(task)
	if destination == null:
		return true
	return _flat(situation.get("center", Vector3.ZERO)).distance_to(_flat(destination)) <= HALTED_M


## The nearest known contact, {} when the element knows of none.
static func nearest_contact(situation: Dictionary) -> Dictionary:
	var contacts: Array = situation.get("contacts", [])
	return contacts[0] if not contacts.is_empty() else {}


## The nearest VISIBLE contact (what the element can actually shoot at), {} when there is none.
static func nearest_visible(situation: Dictionary) -> Dictionary:
	for contact: Dictionary in situation.get("contacts", []):
		if bool(contact.get("visible", false)):
			return contact
	return {}


# ---- Internals ----------------------------------------------------------------------------------------

## Abort conditions, per drill: when the reason for the drill is gone, so is the drill.
static func _finished(drill: String, situation: Dictionary, state: Dictionary, table: DoctrineTable,
		elapsed: int) -> bool:
	var contact := nearest_contact(situation)
	var distance := _nearest_distance(situation)
	match drill:
		"react_to_contact":
			return elapsed >= table.drill_ticks("react_ticks") or contact.is_empty()
		"near_ambush":
			return contact.is_empty()
		"assault_through":
			var point: Variant = state.get("drill_point")
			if point == null:
				return true
			# Through: the element is past the ambush position, measured along the way it is driving
			# (distance alone would call an assault that never started "finished").
			var center := _flat(situation.get("center", Vector3.ZERO))
			var heading := TacticsFormation.flat(situation.get("heading", Vector3.FORWARD))
			return not _has_visible(situation) \
					or (center - _flat(point)).dot(heading) > table.drill_number("assault_through_m")
		"far_ambush":
			# Not "nobody is visible this tick": a crew that breaks line of sight for a moment has not
			# ended the fight. The drill ends when the contact is gone or far behind us.
			return contact.is_empty() or distance > table.drill_number("broken_contact_m")
		"break_contact":
			return distance >= table.drill_number("broken_contact_m") or not should_break_contact(situation, state, table)
		"support_by_fire":
			return String((state.get("task", {}) as Dictionary).get("verb", "")) != "support_by_fire"
		"herringbone":
			return String(situation.get("threat", "none")) == "contact" or not is_halted(situation, state)
		"encircle":
			# Over when there is nothing left to circle, or they have closed to knife range (then it is an
			# ambush and the pack charges).
			return not _has_visible(situation) or distance < table.drill_number("encircle_min_m")
		"bait":
			# Over when they take it — the near-ambush and assault drills carry it from there — when the
			# vehicle doing the drawing is gone, or when whatever we were luring turns out not to be
			# following (a gun line will sit there all day while the bait burns).
			if not _has_visible(situation) or distance <= table.drill_number("bait_min_m") \
					or bait_of(situation).is_empty():
				return true
			return elapsed >= table.drill_ticks("bait_patience_ticks") \
					and float(nearest_visible(situation).get("speed", 0.0)) < table.drill_number("bait_chaser_mps")
	return true


static func _drill(drill: String, why: String, contact: Dictionary) -> Dictionary:
	return {"drill": drill, "why": why, "point": contact.get("position"), "target": String(contact.get("name", ""))}


## Where the running drill is pointed: what it remembered when it started, else the nearest contact now.
static func _remembered(state: Dictionary, situation: Dictionary) -> Dictionary:
	var point: Variant = state.get("drill_point")
	if point != null:
		return {"position": point, "name": String(state.get("drill_target", ""))}
	return nearest_contact(situation)


static func _has_visible(situation: Dictionary) -> bool:
	return not nearest_visible(situation).is_empty()


static func _nearest_distance(situation: Dictionary) -> float:
	var contact := nearest_contact(situation)
	return float(contact.get("distance", INF)) if not contact.is_empty() else INF


static func _flat(point: Variant) -> Vector3:
	var value: Vector3 = point if point is Vector3 else Vector3.ZERO
	return Vector3(value.x, 0.0, value.z)
