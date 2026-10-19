extends TestCase
## Round 34 (traffic, O4; his correction 2, verbatim): *"if we overcorrect on this term then we might have 25 vehicles all
## trying to roll through the same waypoint. The waypoints are obviously sort of loose guidelines, and it's more about the
## squad moving through that waypoint versus individual vehicles"*.
##
## Today a shift-queued move gives each squad its own spread anchor at EVERY waypoint, and an element's queued move is done
## only when it has `arrived` (formed up): a route is a chain of stop-and-form-ups. Wanted: an in-between waypoint is passed
## when the SQUAD's centre is within about its own width (Element.passed_waypoint; crews keep their slots, no form-up stop);
## for several squads an in-between waypoint is a GATE as wide as the ground (RtsControls.gate_anchors: abreast in the open,
## ranks behind along the approach, single file where the terrain narrows). Only the last waypoint packs (brains' O2) and
## keeps today's arrived rule, which also stays the fallback for a squad diverted off its line.

const Fixture := preload("res://tests/support/control_fixture.gd")
const SQUAD := ["Green_S1_1", "Green_S1_2", "Green_S1_3", "Green_S1_4", "Green_S1_5"]
const W := 20.0
const D := 10.0
const GAP := SelectionSquads.GAP_M

var _lab: TacticsLab


func teardown() -> void:
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A corridor `width` wide across the approach, open along it: by ground = straight inside it, unreachable outside.
static func _corridor(width: float, across: Vector3, click: Vector3, left_only := -1.0) -> Callable:
	return func(from: Vector3, to: Vector3) -> float:
		var off := Vector3(to.x - click.x, 0.0, to.z - click.z).dot(across)
		var left := width * 0.5 if left_only < 0.0 else left_only
		var right := width * 0.5 if left_only < 0.0 else width - left_only
		if off < -left - 0.01 or off > right + 0.01:
			return -1.0
		return from.distance_to(to)


static func _never(_from: Vector3, _to: Vector3) -> bool:
	return false


static func _same(p: Vector3) -> Vector3:
	return p


static func _blocks(n: int, across: Vector3) -> Array:
	var out: Array = []
	for i in n:
		out.append({"center": across * (i * 30.0 - 30.0), "width": W, "depth": D})
	return out


static func _across_of(p: Vector3, click: Vector3, across: Vector3) -> float:
	return snappedf(Vector3(p.x - click.x, 0.0, p.z - click.z).dot(across), 0.1)


static func _along_of(p: Vector3, click: Vector3, ahead: Vector3) -> float:
	return snappedf(Vector3(p.x - click.x, 0.0, p.z - click.z).dot(ahead), 0.1)


## (d)(3) In the open the gate holds every squad abreast, centred on the click.
func test_gate_anchors_lays_three_abreast_in_the_open() -> void:
	var click := Vector3(10.0, 0.0, -5.0)
	var ahead := Vector3(0.0, 0.0, -1.0)
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var width := RtsControls.gate_width(click, across, _corridor(120.0, across, click), _never)
	assert_eq(width, [60.0, 60.0] as Array[float], "the clear width reads 60 m each side (%s)" % [width])
	var anchors := RtsControls.gate_anchors(_blocks(3, across), click, ahead, _corridor(120.0, across, click), _never, _same)
	assert_eq(anchors.size(), 3, "one anchor a squad")
	var asides: Array = []
	for a in anchors:
		asides.append(_across_of(a, click, across))
		assert_eq(_along_of(a, click, ahead), 0.0, "all on the gate line (%s)" % [a])
	asides.sort()
	assert_eq(asides, [-(W + GAP), 0.0, W + GAP], "a frontage plus GAP_M apart, centred on the click (%s)" % [asides])
	# In their standing order: the left-most block (centre at -30 across) takes the left anchor.
	assert_eq(_across_of(anchors[0], click, across), -(W + GAP), "the squad standing left goes left")
	assert_eq(_across_of(anchors[2], click, across), W + GAP, "and the one standing right goes right")


## ...a narrower gate takes what fits abreast and queues the rest back along the approach (his decided default)...
func test_gate_anchors_queues_back_where_the_ground_is_narrow() -> void:
	var click := Vector3.ZERO
	var ahead := Vector3(1.0, 0.0, 0.0)
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var anchors := RtsControls.gate_anchors(_blocks(3, across), click, ahead, _corridor(30.0, across, click), _never, _same)
	var alongs: Array = []
	for a in anchors:
		assert_eq(_across_of(a, click, across), 0.0, "one abreast: on the click line (%s)" % [a])
		alongs.append(_along_of(a, click, ahead))
	alongs.sort()
	assert_eq(alongs, [-2.0 * (D + GAP), -(D + GAP), 0.0], "the others queue back along the approach, a depth + GAP_M apart (%s)" % [alongs])
	# Two fit: 2 abreast, 1 behind (the width read in GATE_STEP_M steps, so a hair over two squads' worth).
	anchors = RtsControls.gate_anchors(_blocks(3, across), click, ahead, _corridor(2.0 * W + GAP + 2.0 * RtsControls.GATE_STEP_M, across, click), _never, _same)
	var front := 0
	for a in anchors:
		if _along_of(a, click, ahead) == 0.0:
			front += 1
	assert_eq(front, 2, "two abreast in a two-squad width, one behind (%s)" % [anchors])


## ...single file ON the click line where the terrain is narrower than a squad (a bridge, a gap)...
func test_gate_anchors_goes_single_file_through_a_gap_narrower_than_a_squad() -> void:
	var click := Vector3(0.0, 0.0, 40.0)
	var ahead := Vector3(0.0, 0.0, -1.0)
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	# The clear ground is 10 m wide and all to one side: single file stays on the click, not in the middle of the clear bit.
	var anchors := RtsControls.gate_anchors(_blocks(3, across), click, ahead, _corridor(10.0, across, click, 0.0), _never, _same)
	for a in anchors:
		assert_eq(_across_of(a, click, across), 0.0, "single file on the click line (%s)" % [a])
	var alongs: Array = []
	for a in anchors:
		alongs.append(_along_of(a, click, ahead))
	alongs.sort()
	assert_eq(alongs, [-2.0 * (D + GAP), -(D + GAP), 0.0], "stepped back along the approach (%s)" % [alongs])


## ...and a rank is centred in the CLEAR width when the ground is clear to one side only, and stops at a deck.
func test_gate_width_is_centred_in_the_clear_ground_and_stops_at_a_deck() -> void:
	var click := Vector3.ZERO
	var ahead := Vector3(0.0, 0.0, -1.0)
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var width := RtsControls.gate_width(click, across, _corridor(70.0, across, click, 10.0), _never)
	assert_eq(width, [10.0, 60.0] as Array[float], "10 m clear to the left, 60 to the right (%s)" % [width])
	var anchors := RtsControls.gate_anchors(_blocks(2, across), click, ahead, _corridor(70.0, across, click, 10.0), _never, _same)
	var asides: Array = []
	for a in anchors:
		asides.append(_across_of(a, click, across))
	asides.sort()
	var middle := (60.0 - 10.0) * 0.5
	assert_eq(asides, [snappedf(middle - (W + GAP) * 0.5, 0.1), snappedf(middle + (W + GAP) * 0.5, 0.1)],
			"two abreast, centred in the clear width at +25 m (%s)" % [asides])
	var deck := func(_from: Vector3, to: Vector3) -> bool: return Vector3(to.x - click.x, 0.0, to.z - click.z).dot(across) > 20.0
	width = RtsControls.gate_width(click, across, _corridor(120.0, across, click), deck)
	assert_eq(width, [60.0, 20.0] as Array[float], "the scan stops where a deck lies between (%s)" % [width])


## (d)(2) On the Locks, a gate read on a bridge's deck with the real ground helpers is as wide as the deck: three squads
## through a spot narrower than two squads are laid in a file along the way over, every anchor on the deck's line, none
## across the water. The spot is searched for (the decks' places are the arena's); none found reads NOT ARISEN, not a pass.
func test_a_gate_on_the_locks_bridge_is_single_file_on_the_deck() -> void:
	_lab = TacticsLab.create(self, 7, "locks")
	var probe := _lab.unit(Match.Team.GREEN, "Green_Probe_1", Vector3(-92.0, 0.0, 60.0), 0.0, "law_tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	var drive := SelectionSquads.drive_on(probe)
	var crosses := SelectionSquads.crosses_on(probe)
	var found: Array = []  # [click, ahead, across, width]
	for x in range(-100, 101, 4):
		for z in range(-60, 61, 4):
			var p := Vector3(float(x), 0.0, float(z))
			if not SlotGround.near_deck(p, 0.0):
				continue
			for ahead: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0)]:
				var across := Vector3(-ahead.z, 0.0, ahead.x)
				var width := RtsControls.gate_width(p, across, drive, crosses)
				if width[0] + width[1] < W and width[0] + width[1] > 0.0:
					found.append([p, ahead, across, width])
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	if found.is_empty():
		print("NOT ARISEN locks_bridge_gate: no deck point narrower than a squad (%.0f m) found on the grid" % W)
		assert_true(false, "a deck narrower than a squad exists on the Locks (none found: the test's grid or the arena changed)")
		return
	var click: Vector3 = found[0][0]
	var ahead: Vector3 = found[0][1]
	var across: Vector3 = found[0][2]
	var width: Array = found[0][3]
	print("MEASURE locks_bridge_gate click %s ahead %s clear left %.1f right %.1f m" % [click, ahead, width[0], width[1]])
	var blocks: Array = []
	for i in 3:
		blocks.append({"center": click - ahead * 60.0 + across * ((i - 1) * 30.0), "width": W, "depth": D})
	# The geometry is under test; the arena clamp (Orders.clamp_to_arena, the control's own last step) is not: it moved
	# anchors 4 m near a lock gate in the first run, so the lay is read before it.
	var anchors := RtsControls.gate_anchors(blocks, click, ahead, drive, crosses, _same)
	var alongs: Array = []
	for a in anchors:
		assert_true(absf(_across_of(a, click, across)) <= 0.5, "on the deck's line, not across the water (%s)" % [a])
		alongs.append(_along_of(a, click, ahead))
	alongs.sort()
	assert_eq(alongs, [-2.0 * (D + GAP), -(D + GAP), 0.0], "single file back along the way over (%s)" % [alongs])


# ---- Element's side (brains' file, the agreed two methods) --------------------------------------------------------------

func _squad_fixture() -> Fixture:
	var f := Fixture.new(self)
	await f.build_scale(5)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	for i in 5:
		f.place("Rust_S1_%d" % (i + 1), Vector3(-60.0 + i * 8.0, 0.0, -150.0))  # out of the fight
	return f


func test_relay_queued_rewrites_a_queued_destination_and_bumps_the_state() -> void:
	var f := await _squad_fixture()
	var element: Element = f.controls.elements.form(SQUAD.duplicate(), "S1")
	assert_true(element != null, "setup: the squad forms an element")
	assert_eq(element.enqueue({"verb": "move", "to": [0.0, 0.0], "drills": false}), "", "setup: first queued")
	assert_eq(element.enqueue({"verb": "move", "to": [10.0, 0.0], "drills": false}), "", "setup: second queued")
	var stamp: int = element._state_stamp
	var revision := element.revision
	assert_eq(element.relay_queued(1, [5.0, 7.0]), "", "the second queued move is re-laid")
	assert_eq(element.queued_tasks[1]["to"], [5.0, 7.0], "to its new place")
	assert_eq(element.queued_tasks[0]["to"], [0.0, 0.0], "the first untouched")
	assert_true(element._state_stamp > stamp and element.revision > revision, "the state and revision bumped, as enqueue does")
	stamp = element._state_stamp
	assert_true(element.relay_queued(2, [1.0, 1.0]) != "", "out of bounds is refused")
	assert_true(element.relay_queued(-1, [1.0, 1.0]) != "", "so is a negative index")
	assert_eq(element._state_stamp, stamp, "and a refusal bumps nothing")


func test_passed_waypoint_reads_the_living_centre_within_about_its_width() -> void:
	var f := await _squad_fixture()
	var element: Element = f.controls.elements.form(SQUAD.duplicate(), "S1")
	assert_true(not element.passed_waypoint(f.game_match), "no task: not passed")
	var centre := Vector3.ZERO
	for unit_name in SQUAD:
		centre += f.tank(unit_name).global_position
	centre = Vector3(centre.x, 0.0, centre.z) / SQUAD.size()
	var far := centre + Vector3(0.0, 0.0, -120.0)
	assert_eq(element.assign({"verb": "move", "to": [far.x, far.z], "drills": false}), "", "setup: a move far off")
	assert_true(not element.passed_waypoint(f.game_match), "120 m off: not passed")
	var pass_m := clampf(0.5 * TacticsFormation.frontage(element.formation, SQUAD.size(), element._doctrine().spacing("open")), ElementPlan.ARRIVE_M, Element.PASS_MAX_M)
	print("MEASURE passed_waypoint pass_m %.1f (%s of %d)" % [pass_m, element.formation, SQUAD.size()])
	var near := centre + Vector3(0.0, 0.0, -(pass_m - 1.0))
	assert_eq(element.assign({"verb": "move", "to": [near.x, near.z], "drills": false}), "", "setup: a move just inside pass_m")
	assert_true(element.passed_waypoint(f.game_match), "within about its own width: passed (pass_m %.1f)" % pass_m)
	var beyond := centre + Vector3(0.0, 0.0, -(pass_m + 3.0))
	assert_eq(element.assign({"verb": "move", "to": [beyond.x, beyond.z], "drills": false}), "", "setup: a move just outside")
	assert_true(not element.passed_waypoint(f.game_match), "just outside: not passed")
	assert_true(pass_m >= ElementPlan.ARRIVE_M and pass_m <= Element.PASS_MAX_M, "pass_m sits between ARRIVE_M and PASS_MAX_M")


## A unit in no squad keeps its own direct shift-queue (test_control_commands' rule: the first shift-click starts at once, the
## others wait), untouched by O4.
func test_a_loose_unit_keeps_its_own_direct_shift_queue() -> void:
	var f := await _squad_fixture()
	f.controls.selection.units.assign(["Green_S1_1"])
	for wp: Vector3 in [Vector3(-30.0, 0.0, 0.0), Vector3(-30.0, 0.0, -50.0), Vector3(20.0, 0.0, -50.0)]:
		assert_eq(f.controls.order_selection("move", {"to": [wp.x, wp.z], "queue": true}), "", "setup: shifted move taken")
		await wait_physics_frames(2)
	assert_eq(String(f.orders.current("Green_S1_1").get("verb", "")), "move", "the first shift-click starts at once")
	assert_eq(f.orders.queue("Green_S1_1").size(), 2, "the others wait in its own queue")
	assert_true(f.controls.elements.of("Green_S1_1") == null, "no element was formed for a loose unit")


## (d)(1) His route: three shift-clicked waypoints for one squad of five. The squad passes the middle one without a stop:
## the next leg starts while its centre is still about a squad's width out, `arrived` never flips on that leg, and the
## centre keeps moving. The LAST waypoint still arrives as today.
func test_a_route_passes_its_middle_waypoint_without_stopping_and_arrives_at_the_last() -> void:
	var f := await _squad_fixture()
	await f.select(SQUAD)
	f.controls.groups.save(1, SQUAD.duplicate())
	f.controls.selection.units.assign(SQUAD)
	var wp1 := Vector3(-30.0, 0.0, 0.0)
	var wp2 := Vector3(-30.0, 0.0, -50.0)
	var wp3 := Vector3(20.0, 0.0, -50.0)
	for wp: Vector3 in [wp1, wp2, wp3]:
		var error: String = f.controls.order_selection("move", {"to": [wp.x, wp.z], "queue": true})
		assert_eq(error, "", "setup: the shifted waypoint %s is taken" % [wp])
		await wait_physics_frames(2)
	var element: Element = f.controls.elements.of(SQUAD[0])
	assert_true(element != null, "a shifted route on a squad is the squad's: an element carries it")
	if element == null:
		return
	# O4's entry: the first leg is the element's move task at once; the others queue behind it; no crew runs its own queue.
	var first: Variant = element.task.get("to")
	assert_true(first is Array and absf(float(first[0]) - wp1.x) < 0.5 and absf(float(first[1]) - wp1.z) < 0.5,
			"the first shifted leg is the element's move, started at once (%s)" % [element.task])
	assert_eq(element.queued_tasks.size(), 2, "the two later legs wait behind it (%s)" % [element.queued_tasks])
	for unit_name in SQUAD:
		assert_eq(f.orders.queue(unit_name).size(), 0, "%s has no direct waypoint queue of its own" % unit_name)
	# Drive. Sample the centre every 5 frames: when leg 2 (to wp2) is the task, note arrived and the centre's speed near wp2.
	var pass_m := clampf(0.5 * TacticsFormation.frontage(element.formation, SQUAD.size(), element._doctrine().spacing("open")), ElementPlan.ARRIVE_M, Element.PASS_MAX_M)
	var last_centre := Vector3.INF
	var min_speed := INF
	var arrived_on_leg2 := false
	var switched_at := -1.0
	var leg2_seen := false
	var frames := 0
	while frames < 60 * 90:
		await wait_physics_frames(5)
		frames += 5
		var centre := Vector3.ZERO
		for unit_name in SQUAD:
			centre += f.tank(unit_name).global_position
		centre = Vector3(centre.x, 0.0, centre.z) / SQUAD.size()
		var to: Variant = element.task.get("to")
		var on_leg2: bool = to is Array and absf(float(to[0]) - wp2.x) < 0.5 and absf(float(to[1]) - wp2.z) < 0.5
		var on_leg3: bool = to is Array and absf(float(to[0]) - wp3.x) < 0.5 and absf(float(to[1]) - wp3.z) < 0.5
		if on_leg2:
			leg2_seen = true
			arrived_on_leg2 = arrived_on_leg2 or element.arrived
		if leg2_seen and switched_at < 0.0 and on_leg3:
			switched_at = centre.distance_to(wp2)
		# The centre's speed within 30 m of wp2 and for 3 s after the switch (the window where today's stop shows).
		if last_centre != Vector3.INF and (on_leg2 or on_leg3) and centre.distance_to(wp2) <= 30.0:
			min_speed = minf(min_speed, last_centre.distance_to(centre) / (5.0 / 60.0))
		last_centre = centre
		if on_leg3 and element.arrived:
			break
	print("MEASURE route_pass switched_at_m %.1f pass_m %.1f arrived_on_leg2 %s min_centre_speed_near_wp2 %.2f frames %d" % [
			switched_at, pass_m, arrived_on_leg2, min_speed, frames])
	assert_true(leg2_seen, "the squad drove leg 2")
	assert_true(switched_at >= 0.0, "and went on to leg 3")
	assert_true(switched_at <= pass_m + 3.0 and switched_at >= ElementPlan.ARRIVE_M - 3.0,
			"it passed wp2 at about its own width (%.1f m; pass_m %.1f)" % [switched_at, pass_m])
	assert_true(not arrived_on_leg2, "it never stopped to form up on the way (arrived stayed false on leg 2)")
	assert_true(min_speed >= 2.0, "and its centre kept moving through the waypoint (slowest %.2f m/s)" % min_speed)
	assert_true(element.arrived, "the LAST waypoint still arrives as today (within %d frames)" % frames)
