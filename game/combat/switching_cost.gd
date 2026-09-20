class_name SwitchingCost
extends RefCounted
## A2 (`_agents/research_catalog.md`): a switch pays what it destroys.
##
## A utility AI that re-scores every option several times a second will change its mind whenever two options are
## near-equal, and the lead sees that as vehicles that "move back and forth indefinitely". Round 8 answered it twice
## and both answers were wrong in the same way. A flat commitment bonus (`TankBrain.COMMIT_BONUS`, 1.15; 1.35 tried and
## reverted) is one number for a roster whose vehicles differ by 5x in length and 4x in turret speed, so it is always
## too much for a rat rod and too little for a 14 m war rig. A dwell timer is worse: P3 measured a hard veto on fast
## target switches making switch-and-switch-back MORE than twice as bad, because blocking a switch while the scoring
## keeps integrating stores the pressure up and discharges it intact the moment the timer clears.
##
## Branicky (1998) and Liberzon (2003) give the principled form: a switched system is stable when each switch pays a
## cost related to the energy that switch destroys. So permit i -> j only when utility(j) - utility(i) exceeds the
## physical work the crew throws away — the velocity it must shed to stop serving the old fight, plus the time to lay
## the gun on the new one. Every term comes from the vehicle's own `Units.PROFILES` entry, so the roster prices itself
## and there is nothing to tune per class. A scout switching 10 degrees pays almost nothing; a war rig shedding 12 m/s
## and slewing 140 degrees pays a lot.
##
## Two properties this must keep, both of them lessons paid for:
##   - It is a PRICE, never a veto. The penalty is capped (MAX_PENALTY), so an option that is decisively better always
##     wins however expensive the switch. P3 is what a veto does.
##   - It is stateless and deterministic: a handful of multiplies and one acos off the situation dictionary. No wall
##     clock, no stored history, no float reduction across units.
##
## Used from `TankBrain.decide()`: one `context()` per think, then a cheap `penalty()` per candidate.

## Utility charged per second of work a switch discards. Calibrated against the term it replaces: the flat 1.15
## multiplier asked a challenger for ~0.08-0.13 of extra score at the scores fights actually reach, and a mid-roster
## hull swapping targets 60 degrees apart at speed discards ~1.6 s, so 0.07/s lands the common case in that band. It is
## the exchange rate between seconds and utility, not a per-class knob — there is exactly one for the whole roster.
const PRICE_PER_SECOND := 0.07
## The cap that keeps this a price and not a veto: ~2.7x the common case, reached by a heavy hull reversing at speed.
const MAX_PENALTY := 0.35
## Options a switch to is never charged for. Two different reasons, both of them rules this project already had:
##   - **Obeying and surviving must never be made harder** — the same carve-out the REVISIT penalty carried. These are
##     the options that carry out a player order (MOVE, PURSUE, FOLLOW, INVESTIGATE, KEEP_SLOT) and the ones that keep
##     a crew alive or able to fight at all (RETREAT, TAKE_COVER, RECHARGE, RESUPPLY, REGROUP). The lead's standing
##     complaint is that units do not do what he commands them; nothing here may add to that.
##   - **CLEAR_LANE is not a change of mind** — it steps aside to shoot the target this crew is ALREADY engaging. That
##     is why it used to carry a doubled commitment bake in its own score, and why the bake could be dropped with it.
## Everything else pays, not only the fight options: the flat bonus this replaces favoured the current choice over
## *every* candidate, so letting ADVANCE or HOLD take a fight away for free would be a behaviour change smuggled in
## under a refactor.
const FREE := ["CLEAR_LANE", "KEEP_SLOT", "RETREAT", "MOVE", "PURSUE", "FOLLOW", "INVESTIGATE", "TAKE_COVER",
		"RECHARGE", "RESUPPLY", "REGROUP"]
## A wheeled hull with a fixed gun cannot pivot: it drives the arc. Below this fraction of its top speed the arc time is
## computed as if it were crawling at that speed, so a stopped vehicle is not charged an infinite manoeuvre.
const ARC_SPEED_FLOOR := 0.25

## Experiment overrides, set from `--tune=switch.price=0` (see `Units.apply_tuning`). Never set in normal play.
##   price   0 removes the cost without removing the code path: the control arm for every A/B of this mechanism, in
##           the same build as the treatment (lesson 117).
##   cap     the veto guard, lowered or raised only to measure what it is worth.
##   legacy  1 restores the flat commitment multiplier this replaces (`TankBrain.COMMIT_BONUS` and its dwell timer),
##           so `main`'s pre-A2 behaviour is an arm of this build rather than an older checkout.
const TUNABLE := {"price": PRICE_PER_SECOND, "cap": MAX_PENALTY, "legacy": 0.0}
static var tuning := {}
## Set by `make switch-arm`: fills in the per-think telemetry X1 counts. Off in play, so a match pays nothing for it.
static var probing := false


static func _knob(key: String) -> float:
	return float(tuning.get(key, TUNABLE[key]))


## True when an option is never charged for a switch (see FREE). The seam asks rather than keeping its own list, so a
## new option is priced by default and a carve-out has to be argued for in one place.
## (Named `never_charged`, not `free`: `Object.free()` exists and a static override of it does not parse.)
static func never_charged(option: String) -> bool:
	return FREE.has(option)


## True when `--tune=switch.legacy=1` selects the flat commitment bonus instead of the cost.
static func legacy_arm() -> bool:
	return _knob("legacy") > 0.0


## Everything a think needs to price its candidates, computed once. `current` is the option+target this brain is
## carrying out ({} when it has none — then nothing is a switch and nothing is priced).
##   consulted   a current fight choice existed, so the term was in the code path at all (the X1 arm counter reads
##               this: a mechanism that is never consulted is not an arm, it is a comment — lesson 117)
static func context(s: Dictionary, current: Dictionary) -> Dictionary:
	var me: Dictionary = s["self"]
	var unit := String(me.get("unit", ""))
	var profile := Units.profile(unit)
	var forward: Vector3 = me.get("forward", Vector3.FORWARD)
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var velocity: Vector3 = me.get("velocity", Vector3.ZERO)
	velocity.y = 0.0
	var positions := {}
	for c: Dictionary in s.get("contacts", []):
		positions[c["name"]] = c["position"]
	var from_target := String(current.get("target", "")) if not current.is_empty() else ""
	var ctx := {
		"unit": unit,
		"class": String(me.get("class", "tank")),
		"locomotion": String(profile.get("locomotion", "wheels")),
		"position": me["position"],
		"forward": forward,
		"speed": velocity.length(),
		"positions": positions,
		"from_option": String(current.get("option", "")) if not current.is_empty() else "",
		"from_dir": _bearing(me["position"], positions.get(from_target), forward),
		"consulted": not current.is_empty(),
		# The vehicle's own physics. Missing keys read as the defaults a hull without them behaves like.
		"turret_deg_s": maxf(float(profile.get("turret_turn_rate_deg", 360.0)), 1.0),
		"hull_deg_s": maxf(float(profile.get("hull_turn_rate_deg", 90.0)), 1.0),
		"braking": maxf(float(profile.get("braking_mps2", 10.0)), 0.1),
		"turn_radius": maxf(float(profile.get("min_turn_radius_m", 0.0)), 0.0),
		"arc_speed_floor": maxf(float(profile.get("max_forward_speed", 8.0)), 0.1) * ARC_SPEED_FLOOR,
		"turret": String(profile.get("mount", "turret")) != "fixed",
		# Filled in by the seam as it prices: what the counter reports.
		"priced": 0,
		"max_cost_s": 0.0,
	}
	return ctx


## The seconds of work the crew discards by taking `option` on `target` instead of what it is doing now.
## Two terms, both from the vehicle's profile:
##   slew    getting the gun onto the new bearing. A turret swings on its own ring; a fixed gun comes round with the
##           hull, and on wheels the hull cannot pivot, so it drives an arc of its own minimum radius.
##   brake   the velocity that no longer serves. v*(1-cos) is 0 straight ahead, v at a right angle, 2v for a reversal
##           (shed it, then build it again the other way), which is the 1/2 m v^2 shape without needing a mass.
## An option change on the SAME target still discards the velocity in flight, because engaging, suppressing and
## orbiting drive to different places; that floor is what keeps ENGAGE <-> SUPPRESS thrash priced at all.
static func seconds_for(ctx: Dictionary, option: String, target: String) -> float:
	if not bool(ctx["consulted"]) or FREE.has(option):
		return 0.0
	var to_dir := _bearing(ctx["position"], ctx["positions"].get(target), ctx["forward"])
	var cosine := clampf(Vector3(ctx["from_dir"]).dot(to_dir), -1.0, 1.0)
	var angle_deg := rad_to_deg(acos(cosine))
	var slew_s := 0.0
	if bool(ctx["turret"]):
		slew_s = angle_deg / float(ctx["turret_deg_s"])
	else:
		slew_s = angle_deg / float(ctx["hull_deg_s"])
		var radius := float(ctx["turn_radius"])
		if radius > 0.0:
			var arc_m := radius * deg_to_rad(angle_deg)
			slew_s = maxf(slew_s, arc_m / maxf(float(ctx["speed"]), float(ctx["arc_speed_floor"])))
	var speed := float(ctx["speed"])
	var lost := speed * (1.0 - cosine)
	if String(ctx["from_option"]) != option:
		lost = maxf(lost, speed)
	return slew_s + lost / float(ctx["braking"])


## That work as a price in the scorer's own units, capped so it can never become a veto.
static func penalty(ctx: Dictionary, option: String, target: String) -> float:
	var cost_s := seconds_for(ctx, option, target)
	if cost_s <= 0.0:
		return 0.0
	ctx["priced"] = int(ctx["priced"]) + 1
	ctx["max_cost_s"] = maxf(float(ctx["max_cost_s"]), cost_s)
	return minf(cost_s * _knob("price"), _knob("cap"))


## Did commitment change this think's decision? The argmax of the scores as they stood before the term touched them,
## against what was actually chosen. A term that is consulted every think and flips nothing is not doing anything, and
## that is the failure mode this whole counter exists to catch.
static func _flipped(candidates: Array, unpriced: Array, best: Dictionary) -> bool:
	if unpriced.size() != candidates.size() or candidates.is_empty():
		return false
	var top := 0
	for i in candidates.size():
		if float(unpriced[i]) > float(unpriced[top]):
			top = i
	var would: Dictionary = candidates[top]
	return would["option"] != best["option"] or would["target"] != best["target"]


## X1's arm counter, one row per think, for `make switch-arm`. Lesson 117: a mechanism nobody proves is consulted is
## not an arm, it is a comment — round 8 shipped an additive commitment term into a code path that could never reach it
## and measured it twice before anyone noticed. So this reports, per hull class, whether the term was in the path at
## all (`arm`), whether it priced anything (`priced`), what it charged (`max_cost_s`), and what the choice this think
## actually paid (`cost_s`, 0 when the crew kept what it had). `arm` is "cost", the retired flat "legacy", or the
## reasons there was nothing to price: "order" (an unexecuted player order outranks commitment) or "fresh" (no current
## choice to switch away from).
static func probe(ctx: Dictionary, s: Dictionary, current: Dictionary, best: Dictionary, candidates: Array,
		unpriced: Array, legacy_bonus: float, order_pending: bool) -> Dictionary:
	var me: Dictionary = s["self"]
	var row := {"tick": int(s["tick"]), "unit": String(me.get("unit", "")), "class": String(me.get("class", "tank")),
			"locomotion": String(Units.profile(String(me.get("unit", ""))).get("locomotion", "wheels")),
			"switched": not current.is_empty() and (best["option"] != current.get("option", "")
					or best["target"] != current.get("target", "")),
			"priced": 0, "max_cost_s": 0.0, "cost_s": 0.0, "flipped": _flipped(candidates, unpriced, best)}
	if not ctx.is_empty():
		row["arm"] = "cost"
		row["priced"] = int(ctx["priced"])
		row["max_cost_s"] = float(ctx["max_cost_s"])
		row["cost_s"] = seconds_for(ctx, String(best["option"]), String(best["target"]))
	elif current.is_empty():
		row["arm"] = "fresh"
	elif order_pending:
		row["arm"] = "order"
	else:
		row["arm"] = "legacy"
		row["max_cost_s"] = legacy_bonus
	return row


## Hand-computable entry point for tests and probes: the cost of moving from one choice to another in one call.
static func seconds(s: Dictionary, from_choice: Dictionary, to_choice: Dictionary) -> float:
	var ctx := context(s, from_choice)
	return seconds_for(ctx, String(to_choice.get("option", "")), String(to_choice.get("target", "")))


static func _bearing(from: Vector3, target_position: Variant, fallback: Vector3) -> Vector3:
	if target_position == null:
		return fallback
	var to: Vector3 = (target_position as Vector3) - from
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return fallback
	return to.normalized()
