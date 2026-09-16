extends TestCase
## Round-4 X1: brains execute doctrine (contract L1, read through ElementFeed). The element's leader decides the
## formation, the movement technique and the drill; these scenarios measure how well a *brain* carries that out:
##
##   1. in a formation slot it holds its slot and its sector of fire while it fights,
##   2. told to bound it moves fast, and it stops the moment the leader calls the halt,
##   3. as the base of fire it keeps shooting while the other element moves across its front.
##
## The element is staged with StubElements (AiScenario.elements()) until CP1 lands; the same scenarios then run
## against doctrine's real `Elements`. Open ground west of the walls (x ≈ -95) unless a scenario needs cover.

const PENDING := []
## The leader's call must reach the hull within this many ticks (the K1 response guarantee, plus braking).
const HALT_DECIDE_TICKS := 3


func _issue(orders: Object, units: Array, verb: String, extra := {}) -> void:
	var command := {"units": units.map(func(t: Tank) -> String: return String(t.name)), "verb": verb, "queue": false}
	command.merge(extra, true)
	var error: String = orders.call("issue", command)
	assert_eq(error, "", "order accepted: %s" % [command])


static func _slot_of(element: Object, tank: Tank) -> Vector3:
	var slots: Dictionary = element.state()["slots"]
	return slots[String(tank.name)]["position"]


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---- 1. slot and sector ------------------------------------------------------------------------

func test_a_unit_fighting_from_a_formation_slot_stays_in_it() -> void:
	# Three tanks in line abreast, told by their leader to attack an enemy pair 55 m ahead. Fighting on the move is
	# right (round 3), but a unit that circles 40 m out of its slot has left the formation: mutual support, sectors
	# of fire and armor facing all go with it. Doctrine's answer is to fight *within* your slot — so the same fight
	# is run twice, with and without the element, and the drift is compared.
	var free_drift := await _slot_drift(false)
	var in_slot := await _slot_drift(true)
	print("MEASURE element_slot_drift %.1f m in its slot vs %.1f m without an element (%d vs %d shots)" % [
			in_slot["drift"], free_drift["drift"], in_slot["shots"], free_drift["shots"]])
	assert_true(int(in_slot["shots"]) >= 6, "the element still fought (%d shots)" % in_slot["shots"])
	assert_true(float(in_slot["drift"]) <= 16.0,
			"no unit left its formation slot by more than 16 m (worst %.1f m, %s)" % [in_slot["drift"], in_slot["who"]])
	assert_true(float(in_slot["drift"]) < float(free_drift["drift"]) - 4.0,
			"and the same fight without an element wanders further (%.1f m vs %.1f m)" % [free_drift["drift"], in_slot["drift"]])


## The same 3 v 2 fight, with the three tanks in a formation element or not. Returns the worst distance any of them
## ended up from the slot it was given (the same slots either way), who drifted, and how much they shot.
func _slot_drift(in_element: bool) -> Dictionary:
	var s := AiScenario.create(self, 11)
	var line: Array[Tank] = []
	for i in 3:
		# Slot order is leader first, then alternating sides: A_1 centre, A_2 left, A_3 right.
		line.append(s.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3([-98.0, -110.0, -86.0][i], 0, 20), 0.0))
	for i in 2:
		var foe := s.shooter(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(-104.0 + i * 12.0, 0, -35), PI)
		AiScenario.make_durable(foe)
	for tank in line:
		AiScenario.make_durable(tank)
	var slots := {}
	if in_element:
		var elements := s.elements()
		var element: Object = elements.form(line.map(func(t: Tank) -> String: return String(t.name)), "Alpha")
		element.formation = "line"
		element.heading = Vector3.FORWARD
		element.anchor = Vector3(-98.0, 0, 20)
		element.assign({"verb": "attack", "target": "Rust_A_1"})
		for tank in line:
			slots[String(tank.name)] = _slot_of(element, tank)
	else:
		for tank in line:
			slots[String(tank.name)] = tank.global_position
	_issue(s.orders(), line, "attack", {"target": "Rust_A_1"})
	await s.start()
	var worst := 0.0
	var worst_name := ""
	for tick in 60 * 20:
		await s.step()
		for tank in line:
			if not tank.is_alive():
				continue
			var gap := _flat_distance(tank.global_position, slots[String(tank.name)])
			if gap > worst:
				worst = gap
				worst_name = String(tank.name)
	var shots: int = line.reduce(func(total: int, t: Tank) -> int: return total + s.shots_by(t), 0)
	s.dispose()
	return {"drift": worst, "who": worst_name, "shots": shots}


func test_each_unit_covers_its_own_sector_of_fire() -> void:
	# A halted element covers all round: the leader watches ahead, the flank tank watches the open west. The west
	# enemy is 7 m FARTHER away than the one ahead, so a brain that just shoots the nearest thing fails this — which
	# is exactly the element going blind on a flank.
	var s := AiScenario.create(self, 12)
	var lead := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-70, 0, 45), 0.0)
	var flank := s.brain_tank(Match.Team.GREEN, "Green_A_2", Vector3(-82, 0, 45), 0.0)
	var ahead := s.dummy(Match.Team.RUST, "Rust_Ahead_1", Vector3(-78, 0, 20), PI)
	var west := s.dummy(Match.Team.RUST, "Rust_West_1", Vector3(-114, 0, 45), PI / 2.0)
	for foe in [ahead, west]:
		AiScenario.make_durable(foe)
	var elements := s.elements()
	var element: Object = elements.form(["Green_A_1", "Green_A_2"], "Alpha")
	element.formation = "line"
	element.heading = Vector3.FORWARD
	element.anchor = Vector3(-70, 0, 45)
	# The leader's sectors: the leader takes the front, the flank tank takes the open ground to the west.
	element.sectors["Green_A_1"] = Vector3.FORWARD
	element.sectors["Green_A_2"] = Vector3.LEFT
	element.assign({"verb": "hold"})
	var orders := s.orders()
	for tank in [lead, flank]:
		var slot := _slot_of(element, tank)
		_issue(orders, [tank], "hold", {"to": [slot.x, slot.z]})
	await s.start()
	assert_true(flank.global_position.distance_to(west.global_position)
			> flank.global_position.distance_to(ahead.global_position) + 5.0,
			"setup: the enemy in the flank tank's sector is the FARTHER one")
	var engaged := {}
	for tick in 60 * 16:
		await s.step()
		for tank in [lead, flank]:
			var controller := s.controller_of(tank)
			var name_of := controller.engaged_target if controller != null else ""
			if name_of != "":
				var seen: Dictionary = engaged.get_or_add(String(tank.name), {})
				seen[name_of] = int(seen.get(name_of, 0)) + 1
	print("MEASURE element_sectors %s" % [engaged])
	assert_eq(_favourite(engaged.get("Green_A_1", {})), "Rust_Ahead_1",
			"the leader covers the front (%s)" % [engaged.get("Green_A_1", {})])
	assert_eq(_favourite(engaged.get("Green_A_2", {})), "Rust_West_1",
			"the flank tank covers the west even though the nearer enemy is ahead (%s)" % [engaged.get("Green_A_2", {})])


static func _favourite(counts: Dictionary) -> String:
	var best := ""
	var most := 0
	for key: String in counts:
		if int(counts[key]) > most:
			most = int(counts[key])
			best = key
	return best


# ---- 2. bounding -------------------------------------------------------------------------------

func test_a_bounding_unit_rushes_and_halts_on_the_leaders_call() -> void:
	# Bounding overwatch: one half rushes between covered positions while the other half watches. The rush is fast
	# (you are exposed), and it ends the instant the leader calls it, not when the unit happens to arrive.
	var s := AiScenario.create(self, 13)
	var units: Array[Tank] = []
	for i in 4:
		units.append(s.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-110.0 + i * 8.0, 0, 40), 0.0))
	var elements := s.elements()
	var element: Object = elements.form(units.map(func(t: Tank) -> String: return String(t.name)), "Alpha")
	element.formation = "line"
	element.heading = Vector3.FORWARD
	element.anchor = Vector3(-104.0, 0, 40)
	element.assign({"verb": "move", "to": [-104.0, -20.0]})
	var bounding: Array[Tank] = [units[0], units[1]]
	var watching: Array[Tank] = [units[2], units[3]]
	element.bound(bounding.map(func(t: Tank) -> String: return String(t.name)))
	var orders := s.orders()
	_issue(orders, bounding, "move", {"to": [-104.0, -20.0]})
	for tank in watching:
		_issue(orders, [tank], "hold", {"to": [tank.global_position.x, tank.global_position.z]})
	await s.start()
	var rush_speed := 0.0
	var watcher_speed := 0.0
	var samples := 0
	for tick in 60 * 6:
		await s.step()
		samples += 1
		for tank in bounding:
			rush_speed += absf(tank.speed())
		for tank in watching:
			watcher_speed += absf(tank.speed())
	rush_speed /= samples * bounding.size()
	watcher_speed /= samples * watching.size()
	var top := float(bounding[0].max_forward_speed)
	# The leader calls the halt. Nothing else changes: no new K1 order, just the element's state.
	element.halt()
	var stopped_after := -1
	for tick in 60 * 4:
		await s.step()
		var still_driving := bounding.any(func(t: Tank) -> bool:
			return s.controller_of(t).move_order.get("type") == "move_to")
		if not still_driving and stopped_after < 0:
			stopped_after = tick + 1
			break
	print("MEASURE element_bound rush %.1f m/s of %.1f top, watchers %.1f m/s, halted after %d ticks" % [
			rush_speed, top, watcher_speed, stopped_after])
	assert_true(rush_speed >= top * 0.6, "the bounding half rushes (%.1f m/s of %.1f)" % [rush_speed, top])
	assert_true(watcher_speed < 1.0, "the overwatch half stays put (%.1f m/s)" % watcher_speed)
	assert_true(stopped_after >= 0 and stopped_after <= HALT_DECIDE_TICKS,
			"the bound ends on the leader's call, within %d ticks (was %d)" % [HALT_DECIDE_TICKS, stopped_after])


# ---- 3. support by fire ------------------------------------------------------------------------

func test_the_base_of_fire_keeps_firing_while_the_others_move() -> void:
	# Support by fire: two tanks pin the enemy while two assault across their front. The base of fire must not go
	# quiet when friendlies cross its lane — it shifts to another enemy it *can* shoot, and it never shoots a friend.
	var s := AiScenario.create(self, 14)
	var base: Array[Tank] = []
	for i in 2:
		base.append(s.brain_tank(Match.Team.GREEN, "Green_B_%d" % (i + 1), Vector3(-112.0 + i * 10.0, 0, 18), 0.0))
	var assault: Array[Tank] = []
	for i in 2:
		assault.append(s.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-112.0 + i * 10.0, 0, 8), 0.0))
	var foes: Array[Tank] = []
	for i in 2:
		var foe := s.shooter(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(-116.0 + i * 16.0, 0, -28), PI)
		AiScenario.make_durable(foe)
		foes.append(foe)
	for tank in base + assault:
		AiScenario.make_durable(tank)
	var elements := s.elements()
	var all_names := (base + assault).map(func(t: Tank) -> String: return String(t.name))
	var element: Object = elements.form(all_names, "Alpha")
	element.formation = "line"
	element.heading = Vector3.FORWARD
	element.anchor = Vector3(-107.0, 0, 18)
	element.assign({"verb": "support_by_fire", "target": "Rust_A_1"})
	element.support_by_fire(assault.map(func(t: Tank) -> String: return String(t.name)))
	var orders := s.orders()
	for tank in base:
		_issue(orders, [tank], "attack", {"target": "Rust_A_1"})
	# The assault crosses the base of fire's front, left to right.
	_issue(orders, assault, "attack_move", {"to": [-60.0, -10.0]})
	await s.start()
	var early := 0
	var late := 0
	var through_a_friend := 0
	var fired_before := {}
	var ticks := 60 * 24
	for tick in ticks:
		await s.step()
		for tank in base:
			var now := s.shots_by(tank)
			if now > int(fired_before.get(String(tank.name), 0)):
				fired_before[String(tank.name)] = now
				var controller := s.controller_of(tank)
				var aimed_at: Tank = null
				for foe in foes:
					if String(foe.name) == controller.engaged_target:
						aimed_at = foe
				if aimed_at != null:
					for friend in assault:
						if _lane_distance(tank.global_position, aimed_at.global_position, friend.global_position) < 2.0:
							through_a_friend += 1
		var fired: int = base.reduce(func(total: int, t: Tank) -> int: return total + s.shots_by(t), 0)
		if tick == ticks / 2 - 1:
			early = fired
		elif tick == ticks - 1:
			late = fired - early
	print("MEASURE element_support_by_fire base shots %d then %d, through a friend %d" % [early, late, through_a_friend])
	assert_true(early >= 2, "the base of fire opened up while the assault set off (%d shots)" % early)
	assert_true(late >= 2, "it kept firing while the assault crossed its front (%d shots in the second half)" % late)
	assert_eq(through_a_friend, 0, "and it never shot through one of its own")


## How close `point` passes to the segment from `from` to `to` (the line of fire), in meters.
static func _lane_distance(from: Vector3, to: Vector3, point: Vector3) -> float:
	var line := Vector2(to.x - from.x, to.z - from.z)
	var offset := Vector2(point.x - from.x, point.z - from.z)
	var length := line.length()
	if length < 0.01:
		return offset.length()
	var along := clampf(offset.dot(line / length), 0.0, length)
	return (offset - line / length * along).length()
