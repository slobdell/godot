class_name UnansweredFire
extends RefCounted
## Round 22 (brains B1, DECLARED, C22.6): a crew being hit by fire it CANNOT RETURN does not stay on its post.
##
## The lead (2026-10-07): *"I had one of those laser vehicles from the condemned. It was shooting at a Syndicate vehicle
## at range, and the SYndicate vehicle just sat there and took it until it died. THat clearly looks like dumb CPU
## player"*. His recording: a Limousine Gunship (pulse cannon, effective 55 m) on its element's post for 22.5 s under a
## Lancer's laser from ~86 m, 36 hits, 440 shield + hull to nothing, never moving.
##
## The rule: a crew ON ITS POST (its order is a hold, or it stands within POST_M of where it was sent) that has been hit
## for GRACE_TICKS (1.5 s) with no visible enemy inside its own effective range leaves the post, by the first of:
##   close      the probable shooter is SEEN, the element is not outgunned (strength >= CLOSE_RATIO x what it knows of)
##              and its own band is at most CLOSE_LEASH_M away (20 m): an attack-move to a point inside
##              its own band of where the shooter stood, guns toward it (it fights from there; no chase);
##   cover      a spot within COVER_M that hides the whole hull from the shooter (TacticalQuery.find_cover): drive
##              there, guns toward it;
##   fall_back  neither: straight away from the shooter until it is FALLBACK_MARGIN_M outside the shooter's reach (at
##              most FALLBACK_MAX_M), guns toward it.
## Under HIS posture order (`player` and the task one of PLAYER_POSTS) the crew HOLDS: his order wins (lesson 264), and
## the element's readout says so. Under the element's own hold (a halt after a move, the CPU leader's posture) it acts.
##
## Pure: the per-crew memory goes in and comes out as a dictionary the Element keeps (`ducks`); the clock is
## `situation.tick`; members and contacts are iterated in name / distance order (ElementSituation), so two runs of a
## seed decide identically.

## Off: round 21's behaviour (the probe's and the series' control arm, `--duck=off`).
static var ENABLED := true

## Hits nothing of ours can answer for this long (ticks) before the crew moves: one hit is a stray, a second and a half
## of them (a Lancer's third pulse) is a gun that has found you. 2 s (the brief's suggestion) moved his recording's
## gunship 3.3 s after the first hit, once its close was leashed to 20 m (cover is a short drive that starts slowly).
const GRACE_TICKS := SimClock.TICK_RATE * 3 / 2
## Round 23 (B3): UNDER THREE GUNS, ACT INSIDE THE GRACE. A crew that has lost this share of its hull + shield since
## its unanswered fire began does not wait the grace out: three Lancers took a gunship's 440 in ~3 s, so outcome (b)
## was decided at 1.5 s and the crew died on the way (round 22's stage table). One Lancer takes ~20 a second, two ~40:
## neither reaches a quarter inside the grace, so a stray hit, or one gun, still waits as before. `--duck-urgent=on`.
## OFF (measured, round 23): under three Lancers the decision comes at 0.5 s after the first hit instead of 1.5, and
## the crew dies in place all the same (his recording's stage, builder0, 4 seeds, both arms: cover decided, moved 0 of
## 4, 440 lost): its cover point is 5.6 m BEHIND it and the 120-degree pivot eats the 2 s it has left. The lever is a
## reverse leg (a short move to a point behind, facing the threat, driven backing: the brain's move for every short
## facing-bound order, a declared change of its own), not the grace.
static var URGENT_ENABLED := false
const URGENT_LOSS := 0.25
## A crew is "hit" while its last hit is this recent (ElementSituation.FIRE_TICKS); a longer quiet resets the clock.
const QUIET_TICKS := SimClock.TICK_RATE * 3 / 2
## A crew counts as on its post when its order is a hold, or it stands within this of the order's point (meters).
const POST_M := 8.0
## Close only when we have at least this much of the strength we know of near us...
const CLOSE_RATIO := 1.0
## ...and the drive to our own band is at most this (meters): farther, we are a target the whole way in.
const CLOSE_GAP_M := 45.0
## Close only when its point is within this of the crew (meters): a holder that drives 35 m to its band has left the
## ground it holds. The hold stage's lancers series (builder0, 8 paired seeds, on - off), foundry: no leash (f9c49c0e)
## CPU alive +0.75 (se 0.16) but its points -10.5 (se 3.6); leash 20 (f21ad013) alive +0.75 (se 0.16), points -4.4
## (se 1.7); leash 30 the same points, parade weaker. `hold_probe --duck-leash=` (inf = none) is the measurement arm.
static var CLOSE_LEASH_M := 20.0
## Round 22 (measurement arm, OFF = INF): a crew on a post of a holding task (POST_TASKS) leaves it by at most this
## (meters): cover is looked for within it and a fall-back is cut to it. The question it answers: whether the points a
## holder gives up on foundry (the hold stage) come from cover and fall-back leaving the zone. `hold_probe
## --duck-post-leash=` sets it.
static var POST_LEASH_M := INF
const POST_TASKS := ["hold", "ambush", "support_by_fire", "screen"]
## Cover is looked for this far from the crew (meters).
const COVER_M := 25.0
## A fall-back ends this far outside the shooter's reach (meters), and is never longer than FALLBACK_MAX_M nor shorter
## than FALLBACK_MIN_M.
const FALLBACK_MARGIN_M := 10.0
const FALLBACK_MAX_M := 45.0
const FALLBACK_MIN_M := 12.0
## A crew in cover or fallen back stays there while it was hit within this (ticks), or while what drove it off still
## reaches its old post.
const SETTLE_TICKS := SimClock.TICK_RATE * 12
## A cover spot is aimed this much deeper behind its cover than the query's point (meters), when that is still hidden
## and standable.
const COVER_DEPTH_M := 3.0
## A reaction that has had this long to take effect (ticks) and is still being hit without an answer has failed: cover
## that does not hide, or a shooter that followed. It is re-decided with cover ruled out, at most MAX_TRIES times.
const FAIL_TICKS := SimClock.TICK_RATE * 5
const MAX_TRIES := 2
## No reaction lasts longer than this without being re-decided (ticks).
const MAX_TICKS := SimClock.TICK_RATE * 30
## A post the shooter's reach covers by less than this still counts as covered (meters).
const REACH_SLACK_M := 3.0
## HIS tasks that put a crew on a post he chose: under these his crews hold (C22.6).
const PLAYER_POSTS := ["hold", "ambush", "support_by_fire", "screen"]
## Drills that already move the crew (or are an immediate action): the rule waits for them.
const BUSY_DRILLS := ["near_ambush", "assault_through", "break_contact", "bait", "encircle"]

const WHY_HELD := "under fire from beyond range: holding on your order"
const WHY := {"close": "under fire from beyond range: closing to our range",
		"cover": "under fire from beyond range: into cover",
		"fall_back": "under fire from beyond range: falling back out of its reach"}


## Apply the rule to `plan` (ElementPlan.build's output: its orders, slots and why are changed for the crews that act)
## and return the new memory {unit: {"since", "last_hit", "outcome", "point", "target", "shooter", "post", "started"}}.
static func apply(plan: Dictionary, situation: Dictionary, state: Dictionary) -> Dictionary:
	var before: Dictionary = state.get("ducks", {})
	if not ENABLED:
		return {}
	var tick := int(situation.get("tick", 0))
	var task: Dictionary = state.get("task", {})
	var his_post := bool(state.get("player", false)) and PLAYER_POSTS.has(String(task.get("verb", "")))
	var busy := BUSY_DRILLS.has(String(plan.get("drill", "")))
	var orders: Dictionary = plan.get("orders", {})
	var memory := {}
	var held := false
	var acting := ""
	for member: Dictionary in situation.get("members", []):
		var name := String(member["name"])
		var mine: Dictionary = (before.get(name, {}) as Dictionary).duplicate()
		var hit := int(member.get("since_hit", 1 << 30)) < QUIET_TICKS
		if hit:
			mine["last_hit"] = tick
		if String(mine.get("outcome", "")) != "":
			if _over(mine, member, situation, tick):
				continue  # back under the element's plan; a new clock starts with the next hit
			if failing(mine, hit, answerable(member, situation), tick):
				# Cover that does not hide it, or a shooter that followed it out: give the ground up (again).
				var again := decide(member, situation, _others(situation, name), true,
						POST_LEASH_M if POST_TASKS.has(String(task.get("verb", ""))) else INF)
				for key: String in ["since", "post", "tries"]:
					again[key] = mine.get(key)
				again["tries"] = int(mine.get("tries", 0)) + 1
				again["last_hit"] = tick
				again["started"] = tick
				mine = again
			memory[name] = mine
			_keep(plan, name, mine)
			acting = String(mine["outcome"])
			continue
		var order: Dictionary = orders.get(name, {})
		if busy or not hit or answerable(member, situation) or not on_post(member, order):
			continue  # nothing to answer for (yet): the clock starts again with the next unanswered hit
		mine["since"] = int(mine.get("since", tick))
		mine["left_since"] = float(mine.get("left_since", member.get("left", 1.0)))
		memory[name] = mine
		if tick - int(mine["since"]) < GRACE_TICKS and not urgent(mine, member):
			continue
		if his_post:
			held = true
			continue
		var decided := decide(member, situation, _others(situation, name), false,
				POST_LEASH_M if POST_TASKS.has(String(task.get("verb", ""))) else INF)
		if decided.is_empty():
			continue
		decided["since"] = mine["since"]
		decided["last_hit"] = tick
		decided["started"] = tick
		decided["post"] = order.get("to") if order.get("to") is Vector3 else member["position"]
		memory[name] = decided
		_keep(plan, name, decided)
		acting = String(decided["outcome"])
	if acting != "":
		plan["why"] = WHY[acting]
	elif held:
		plan["why"] = WHY_HELD
	return memory


## Round 23 (B3): whether the fire since the clock started (`mine["left_since"]`, the crew's hull + shield share then)
## has cost the crew URGENT_LOSS of its hull + shield: the grace is not waited out. Pure.
static func urgent(mine: Dictionary, member: Dictionary) -> bool:
	if not URGENT_ENABLED:
		return false
	return float(mine.get("left_since", 1.0)) - float(member.get("left", 1.0)) >= URGENT_LOSS


## What the crew does about it: {"outcome", "point" (Vector3 or null), "target" (a contact's name or ""), "shooter"
## (Vector3), "reach" (the shooter's)} or {} when there is nothing to do. Pure.
static func decide(member: Dictionary, situation: Dictionary, friends: Array = [], no_cover := false,
		leash := INF) -> Dictionary:
	var here: Vector3 = _flat(member["position"])
	var own := float(member.get("effective_range", member.get("range", 60.0)))
	var shooter := probable_shooter(member, situation)
	var at: Vector3
	var reach := 0.0
	if shooter.is_empty():
		# Unseen: the fire comes from where the enemy is, as far as we know it; else from ahead of the element.
		var nearest := Drills.nearest_contact(situation)
		at = _flat(nearest["position"]) if not nearest.is_empty() \
				else here + TacticsFormation.flat(situation.get("heading", Vector3.FORWARD)) * own * 1.5
		reach = maxf(here.distance_to(at), own) + REACH_SLACK_M
	else:
		at = _flat(shooter["position"])
		reach = reach_of(String(shooter.get("unit", "")), here.distance_to(at))
	var distance := here.distance_to(at)
	var enemy := float(situation.get("enemy_strength", 0.0))
	var ratio := float(situation.get("strength", 0.0)) / enemy if enemy > 0.0 else INF
	if not shooter.is_empty() and bool(shooter.get("visible", false)) and ratio >= CLOSE_RATIO \
			and distance - own <= CLOSE_GAP_M:
		var toward := (at - here).normalized()
		var close_at := at - toward * own * 0.9
		if close_at.distance_to(here) <= CLOSE_LEASH_M:
			return {"outcome": "close", "target": String(shooter["name"]), "point": close_at, "shooter": at, "reach": reach}
	var map: Variant = situation.get("cover_map")
	if map is CoverMap and not no_cover:
		var spots := TacticalQuery.find_cover(map, {"position": here, "threats": [{"position": at, "weight": 1.0}],
				"search_radius": minf(COVER_M, leash), "friends": friends}, 1)
		if not spots.is_empty() and TacticalQuery.hull_hidden(map, at, spots[0]["point"]):
			var spot := _flat(spots[0]["point"])
			# A move "arrives" a couple of metres short, which is still in view at the corner: aim deeper behind it.
			var deeper := spot + (spot - at).normalized() * COVER_DEPTH_M
			if TacticalQuery.hull_hidden(map, at, deeper) \
					and not (map as CoverMap).inside_any(Vector2(deeper.x, deeper.z), TacticalQuery.STAND_CLEARANCE):
				spot = deeper
			return {"outcome": "cover", "target": "", "point": spot, "shooter": at, "reach": reach}
	var away := (here - at).normalized() if distance > 0.1 else -TacticsFormation.flat(situation.get("heading", Vector3.FORWARD))
	var back := minf(clampf(reach + FALLBACK_MARGIN_M - distance, FALLBACK_MIN_M, FALLBACK_MAX_M), leash)
	if back < FALLBACK_MIN_M:
		return {}  # leashed to its post with no cover in reach: it holds
	return {"outcome": "fall_back", "target": "", "point": ElementPlan.clamp_to_arena(here + away * back), "shooter": at,
			"reach": reach}


## The contact most likely shooting at `member`: one that can reach it (its own weapon's range covers the distance)
## but that the crew cannot reach back; seen ones first, then the nearest. {} when no known contact fits.
static func probable_shooter(member: Dictionary, situation: Dictionary) -> Dictionary:
	var here: Vector3 = _flat(member["position"])
	var own := float(member.get("effective_range", member.get("range", 60.0)))
	var best := {}
	var best_key := INF
	for contact: Dictionary in situation.get("contacts", []):
		var distance := here.distance_to(_flat(contact["position"]))
		if distance <= own:
			continue
		if reach_of(String(contact.get("unit", "")), 0.0) + REACH_SLACK_M < distance:
			continue
		var key := distance + (0.0 if bool(contact.get("visible", false)) else 1000.0)
		if key < best_key:
			best_key = key
			best = contact
	return best


## Whether the crew can shoot back at anything: a SEEN enemy inside its own effective range. Pure.
static func answerable(member: Dictionary, situation: Dictionary) -> bool:
	var here: Vector3 = _flat(member["position"])
	var own := float(member.get("effective_range", member.get("range", 60.0)))
	for contact: Dictionary in situation.get("contacts", []):
		if bool(contact.get("visible", false)) and here.distance_to(_flat(contact["position"])) <= own:
			return true
	return false


## Whether the crew is standing on a post: told to hold, or within POST_M of where its order sends it. Pure.
static func on_post(member: Dictionary, order: Dictionary) -> bool:
	if order.is_empty():
		return false
	var verb := String(order.get("verb", ""))
	if verb == "hold":
		return true
	if verb == "attack" or verb == "follow":
		return false
	var to: Variant = order.get("to")
	return to is Vector3 and _flat(member["position"]).distance_to(_flat(to)) <= POST_M


## A unit's weapon reach (meters) by its catalog id; `fallback` when the id is unknown.
static func reach_of(unit_id: String, fallback: float) -> float:
	if unit_id == "" or not Units.exists(unit_id):
		return fallback
	return float(Weapons.profile(String(Units.stat(unit_id, "weapon", ""))).get("range", fallback))


## Whether a cover or fall-back reaction has failed: FAIL_TICKS after it started, the crew is still being hit by
## something it cannot answer, and it has tries left. Pure.
static func failing(mine: Dictionary, hit: bool, can_answer: bool, tick: int) -> bool:
	if String(mine.get("outcome", "")) == "close" or not hit or can_answer:
		return false
	return tick - int(mine.get("started", tick)) >= FAIL_TICKS and int(mine.get("tries", 0)) < MAX_TRIES


## Whether a running reaction is over: a close when its target is gone or dead; cover or a fall-back once the crew has
## had SETTLE_TICKS without a hit AND neither the shooter where it was last seen nor anything known reaches its post; any
## of them after MAX_TICKS without a hit.
static func _over(mine: Dictionary, member: Dictionary, situation: Dictionary, tick: int) -> bool:
	var started := int(mine.get("started", tick))
	var quiet := tick - int(mine.get("last_hit", tick)) >= SETTLE_TICKS
	if tick - started >= MAX_TICKS and quiet:
		return true
	if String(mine["outcome"]) == "close":
		# Over when the shooter is gone (dead, or out of everything the element knows), or once the crew has been at its
		# point SETTLE_TICKS without a hit.
		var target := String(mine.get("target", ""))
		var known := false
		for contact: Dictionary in situation.get("contacts", []):
			known = known or String(contact["name"]) == target
		if not known:
			return true
		var there: bool = mine.get("point") is Vector3 \
				and _flat(member["position"]).distance_to(_flat(mine["point"])) <= POST_M
		return (there and quiet) or tick - started >= MAX_TICKS
	if not quiet:
		return false
	var post: Vector3 = _flat(mine.get("post", member["position"]))
	# The shooter where it was last seen, even once the team has lost sight of it: a crew in cover cannot see it either,
	# and going back because it is out of sight was a peek every ~15 s into the same laser (the recording's stage at 20 s).
	# MAX_TICKS above re-decides it.
	if mine.get("shooter") is Vector3 and post.distance_to(_flat(mine["shooter"])) <= float(mine.get("reach", 0.0)) + REACH_SLACK_M:
		return false
	for contact: Dictionary in situation.get("contacts", []):
		if post.distance_to(_flat(contact["position"])) <= reach_of(String(contact.get("unit", "")), 0.0) + REACH_SLACK_M:
			return false
	return true


## The reacting crew's order and slot for this update.
static func _keep(plan: Dictionary, name: String, mine: Dictionary) -> void:
	var at: Vector3 = mine.get("shooter", Vector3.ZERO)
	var point: Variant = mine.get("point")
	if String(mine["outcome"]) == "close":
		# An attack-move to its own band, not an attack: the crew fights from there and the post is a bound away. An
		# attack on the shooter chased a Lancer off the depot (the lancers stage, foundry: the CPU's points -15.6 per
		# match, se 2.8, builder0 f0e83a7f, 8 paired seeds).
		var order := {"verb": "attack_move", "to": point, "target": ""}
		var look := TacticsFormation.flat(at - (point as Vector3)) if point is Vector3 else Vector3.ZERO
		if look.length_squared() > 1e-6:
			order["facing"] = look
		plan["orders"][name] = order
	else:
		var facing := TacticsFormation.flat(at - (point as Vector3)) if point is Vector3 else Vector3.ZERO
		var order := {"verb": "move", "to": point, "target": ""}
		if facing.length_squared() > 1e-6:
			order["facing"] = facing
		plan["orders"][name] = order
	if point is Vector3 and plan.has("slots"):
		plan["slots"][name] = point
	plan.get_or_add("ducks_acting", []).append(name)


static func _others(situation: Dictionary, name: String) -> Array:
	var friends: Array = []
	for member: Dictionary in situation.get("members", []):
		if String(member["name"]) != name:
			friends.append(member["position"])
	return friends


static func _flat(point: Variant) -> Vector3:
	var value: Vector3 = point if point is Vector3 else Vector3.ZERO
	return Vector3(value.x, 0.0, value.z)


# ---- Round 23 (brains B2, C23.2): THE PER-CREW READ, for orders' readout of a crew he holds -------------------------
#
# A crew he holds with H leaves its element (orders' direct path), so `Element.reason` never says it is being shot from
# beyond its range. This answers for ONE crew, in or out of an element, with B1's own test (hit within QUIET_TICKS, no
# SEEN enemy inside its effective range, for at least GRACE_TICKS), and costs nothing until asked: the clock for a crew
# outside an element is kept here, only for crews that were asked about, and forgotten once the fire stops.
## {unit: {"since": the tick its unanswered fire was first noticed, "asked": the tick it was last asked about}}.
static var _asked := {}


## WHY_HELD while `unit_name` is being hit by something it cannot return (by the rule's own test, for at least the
## grace), "" otherwise. Static, read-only on the match; safe to call for a crew in or out of an element.
static func crew_reason(game_match: Match, unit_name: String) -> String:
	if game_match == null:
		return ""
	var tank := AiTickCache.tanks_by_name(game_match).get(unit_name) as Tank
	if tank == null or not tank.is_alive():
		_asked.erase(unit_name)
		return ""
	var tick: int = game_match.tick
	if tank.ticks_since_hit >= QUIET_TICKS:
		_asked.erase(unit_name)
		return ""
	var situation := ElementSituation.build(game_match, tank.team, PackedStringArray([unit_name]), unit_name)
	var members: Array = situation.get("members", [])
	if members.is_empty() or answerable(members[0], situation):
		_asked.erase(unit_name)
		return ""
	# The element's own clock when the crew has one (B1 noticed the fire before anyone asked); else this read's.
	var since := tick - tank.ticks_since_hit
	var elements := Elements.of_match(game_match)
	var element: Element = elements.of(unit_name) if elements != null else null
	if element != null and element.ducks.has(unit_name):
		since = mini(since, int((element.ducks[unit_name] as Dictionary).get("since", since)))
	var mine: Dictionary = _asked.get(unit_name, {})
	var asked := int(mine.get("asked", -1_000_000_000))
	if not mine.is_empty() and asked <= tick and tick - asked < QUIET_TICKS:
		since = mini(since, int(mine.get("since", since)))
	_asked[unit_name] = {"since": since, "asked": tick}
	return WHY_HELD if tick - since >= GRACE_TICKS else ""
