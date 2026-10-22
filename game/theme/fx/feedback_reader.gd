class_name FeedbackReader
extends RefCounted
## Round 37 (feedback, C37.6): what the rules are doing that the player should SEE, read from the match and never
## written back. Four facts, each the rules' own numbers:
##
## - **a hit's face** (`hit_kind`): front / side / rear from `Match.projectile_impact`'s `face`, "deck" for the engine-deck
##   weak spot (its own flag); the lead's 9a: flank and rear hits must be obvious.
## - **a pinned crew** (`pinned_level`): `Tank.suppression` mapped so a stray round shows nothing and a crew under real
##   fire shows fully; his answer 8: "slow, never stop, and show it". Once rules' R3 lands, `Tank.pin_slow()` says how
##   much the crew is slowed (`slowed`).
## - **a Tanker mending** (`menders` + `mending`): the same conditions as `Match.repair_rate_for` and `Match._resupply`
##   (a living friendly mender within its radius, the patient hurt and quiet for its delay, and the mender's rate beating
##   what the home base already gives), so what is drawn is exactly what is being repaired, at the rate it is.
## - **an Emitter's cone** (`fired` + `active_cones`): the `weapon_fired` puffs Match emits every CONE_EVENT_TICKS while a
##   sound weapon blows, held for CONE_HOLD_S so the cone does not strobe between puffs.
##
## Visual only: nothing here is called by the simulation, and every read is of state the simulation already keeps.

## Suppression below this draws nothing (one stray burst); at PIN_FULL the pinned look is at full strength.
## Tank: rises 0.6/s under fire, recovers 0.3/s; the Emitter adds 4.0/s, a machine gun's lane 1.2 per round.
const PIN_SHOW := 0.3
const PIN_FULL := 0.8
## A cone stays drawn this long after its last puff (Match.CONE_EVENT_TICKS is 0.1 s at 30 Hz).
const CONE_HOLD_S := 0.25
## Weapons whose cone is drawn as sound (the flamethrowers draw their own flame).
const SOUND_WEAPONS := ["sonic_emitter"]

## shooter name -> {time, origin, direction, range, cone_deg}: the last puff of each sound cone.
var _cones := {}


## "front", "side", "rear" or "deck" (the engine-deck weak spot) for a K2 projectile_impact on a vehicle; "" for a hit on
## nothing. Artillery from above reports "side" (Match: arcing rounds have no facing), so it never reads as a flank shot.
static func hit_kind(event: Dictionary) -> String:
	if String(event.get("target", "")) == "":
		return ""
	if bool(event.get("weak_spot", false)):
		return "deck"
	var face := String(event.get("face", "front"))
	return face if face in ["front", "side", "rear"] else "front"


## 0 (not pinned) .. 1 (pinned hard) from a crew's suppression.
static func pinned_level(suppression: float) -> float:
	return clampf((suppression - PIN_SHOW) / (PIN_FULL - PIN_SHOW), 0.0, 1.0) if suppression > PIN_SHOW else 0.0


## How much rules' R3 slows this crew right now (0 before R3 lands, or when it is off).
static func slowed(tank: Object) -> float:
	return float(tank.call("pin_slow")) if tank != null and tank.has_method("pin_slow") else 0.0


## The living field menders among `tanks` (Units "repair_hp_per_second"), as [{node, team, position, radius, rate}].
static func menders(tanks: Array) -> Array:
	var found: Array = []
	for node in tanks:
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var rate := float(Units.stat(tank.unit_id, "repair_hp_per_second", 0.0))
		if rate > 0.0:
			found.append({"node": tank, "team": tank.team, "position": tank.global_position,
					"radius": float(Units.stat(tank.unit_id, "repair_radius_m", 0.0)), "rate": rate})
	return found


## Who is mending `tank` right now and how fast: {node: the mender, rate: hp/s}, or {} when nothing in the field is.
## The rules' own conditions (Match._resupply / repair_rate_for): alive, hurt, quiet for max(its shield delay,
## Match.REPAIR_QUIET_SECONDS), within a friendly mender's radius; and the mender only counts when it beats the home
## base's own rate there (inside its base the base does the mending, not the Tanker). Ties go to the nearest mender.
static func mending(tank: Tank, field_menders: Array) -> Dictionary:
	if tank == null or not tank.is_alive() or tank.health >= tank.max_health:
		return {}
	var quiet_ticks := roundi(maxf(tank.shield_recharge_delay, Match.REPAIR_QUIET_SECONDS) * SimClock.TICK_RATE)
	if tank.ticks_since_hit < quiet_ticks:
		return {}
	var base := Match.REPAIR_HP_PER_SECOND if Match.in_resupply_zone(tank.team, tank.global_position) else 0.0
	var best := {}
	var best_distance := INF
	for mender: Dictionary in field_menders:
		if int(mender["team"]) != tank.team or float(mender["rate"]) <= base:
			continue
		var offset: Vector3 = mender["position"] - tank.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance > float(mender["radius"]):
			continue
		if best.is_empty() or float(mender["rate"]) > float(best["rate"]) \
				or (float(mender["rate"]) == float(best["rate"]) and distance < best_distance):
			best = {"node": mender["node"], "rate": float(mender["rate"])}
			best_distance = distance
	return best


## K2 weapon_fired: remember a sound cone's puff (other weapons are ignored).
func fired(event: Dictionary, now: float) -> void:
	var weapon_id := String(event.get("weapon", ""))
	if not SOUND_WEAPONS.has(weapon_id):
		return
	var profile := Weapons.profile(weapon_id)
	_cones[String(event.get("shooter", ""))] = {"time": now, "origin": K2Events.to_vector(event.get("muzzle", [0, 0, 0])),
			"direction": K2Events.to_vector(event.get("direction", [0, 0, -1])), "range": float(profile.get("range", 32.0)),
			"cone_deg": float(profile.get("cone_deg", 40.0))}


## The sound cones blowing at `now`: [{shooter, time, origin, direction, range, cone_deg}], oldest puffs forgotten.
func active_cones(now: float) -> Array:
	var found: Array = []
	for shooter: String in _cones.keys():
		var cone: Dictionary = _cones[shooter]
		if now - float(cone["time"]) > CONE_HOLD_S:
			_cones.erase(shooter)
			continue
		var entry := cone.duplicate()
		entry["shooter"] = shooter
		found.append(entry)
	return found


func clear() -> void:
	_cones.clear()
