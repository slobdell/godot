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
## for GRACE_TICKS with no visible enemy inside its own effective range leaves the post, by the first of:
##   close      the probable shooter is SEEN, the element is not outgunned (strength >= CLOSE_RATIO x what it knows of)
##              and the gap to the crew's own effective range is at most CLOSE_GAP_M: attack it (the brain closes to
##              its own band and fights);
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

## Hits nothing of ours can answer for this long (ticks) before the crew moves: one hit is a stray, two seconds of them
## is a gun that has found you.
const GRACE_TICKS := SimClock.TICK_RATE * 2
## A crew is "hit" while its last hit is this recent (ElementSituation.FIRE_TICKS); a longer quiet resets the clock.
const QUIET_TICKS := SimClock.TICK_RATE * 3 / 2
## A crew counts as on its post when its order is a hold, or it stands within this of the order's point (meters).
const POST_M := 8.0
## Close only when we have at least this much of the strength we know of near us...
const CLOSE_RATIO := 1.0
## ...and the drive to our own band is at most this (meters): farther, we are a target the whole way in.
const CLOSE_GAP_M := 45.0
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
				var again := decide(member, situation, _others(situation, name), true)
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
		memory[name] = mine
		if tick - int(mine["since"]) < GRACE_TICKS:
			continue
		if his_post:
			held = true
			continue
		var decided := decide(member, situation, _others(situation, name))
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


## What the crew does about it: {"outcome", "point" (Vector3 or null), "target" (a contact's name or ""), "shooter"
## (Vector3), "reach" (the shooter's)} or {} when there is nothing to do. Pure.
static func decide(member: Dictionary, situation: Dictionary, friends: Array = [], no_cover := false) -> Dictionary:
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
		return {"outcome": "close", "target": String(shooter["name"]), "point": at - toward * own * 0.9,
				"shooter": at, "reach": reach}
	var map: Variant = situation.get("cover_map")
	if map is CoverMap and not no_cover:
		var spots := TacticalQuery.find_cover(map, {"position": here, "threats": [{"position": at, "weight": 1.0}],
				"search_radius": COVER_M, "friends": friends}, 1)
		if not spots.is_empty() and TacticalQuery.hull_hidden(map, at, spots[0]["point"]):
			var spot := _flat(spots[0]["point"])
			# A move "arrives" a couple of metres short, which is still in view at the corner: aim deeper behind it.
			var deeper := spot + (spot - at).normalized() * COVER_DEPTH_M
			if TacticalQuery.hull_hidden(map, at, deeper) \
					and not (map as CoverMap).inside_any(Vector2(deeper.x, deeper.z), TacticalQuery.STAND_CLEARANCE):
				spot = deeper
			return {"outcome": "cover", "target": "", "point": spot, "shooter": at, "reach": reach}
	var away := (here - at).normalized() if distance > 0.1 else -TacticsFormation.flat(situation.get("heading", Vector3.FORWARD))
	var back := clampf(reach + FALLBACK_MARGIN_M - distance, FALLBACK_MIN_M, FALLBACK_MAX_M)
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
## had SETTLE_TICKS without a hit AND what drove it off no longer reaches its post (or is no longer known); any of them
## after MAX_TICKS.
static func _over(mine: Dictionary, member: Dictionary, situation: Dictionary, tick: int) -> bool:
	var started := int(mine.get("started", tick))
	var quiet := tick - int(mine.get("last_hit", tick)) >= SETTLE_TICKS
	if tick - started >= MAX_TICKS and quiet:
		return true
	if String(mine["outcome"]) == "close":
		var target := String(mine.get("target", ""))
		for contact: Dictionary in situation.get("contacts", []):
			if String(contact["name"]) == target:
				return tick - started >= MAX_TICKS
		return true
	if not quiet:
		return false
	var post: Vector3 = _flat(mine.get("post", member["position"]))
	for contact: Dictionary in situation.get("contacts", []):
		if post.distance_to(_flat(contact["position"])) <= reach_of(String(contact.get("unit", "")), 0.0) + REACH_SLACK_M:
			return false
	return true


## The reacting crew's order and slot for this update.
static func _keep(plan: Dictionary, name: String, mine: Dictionary) -> void:
	var at: Vector3 = mine.get("shooter", Vector3.ZERO)
	var point: Variant = mine.get("point")
	if String(mine["outcome"]) == "close":
		plan["orders"][name] = {"verb": "attack", "to": null, "target": String(mine["target"])}
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
