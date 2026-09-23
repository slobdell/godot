extends TestCase
## Round 9 (nav, round 8's last open stretch item): **a `face` order had no recovery.** `Movement.unstick` runs only
## for a `move_to` and the mover is `idle()` under a face, so a wheeled hull wedged against scenery creeps for ever
## on `WHEELS_MIN_THROTTLE` and nothing notices.
##
## It is the lead's complaint directly. Round 8 measured what it looks like from his camera: the War Rig's apparent
## pivot IS the creep's legs cancelling against props — **26 degrees within 1.5 m on yard against 7 degrees on bare
## ground at every hull length**. The hull is neither turning nor going anywhere, and N1's guarantee — *"it never
## stands still silently"* — had a `face` order as its one exemption.
##
## OPT-IN (`--nav-off=facegiveup` turns it ON), because it is behaviour on the default path.

const MATCH := preload("res://game/match/match.tscn")
## The wedging corridor's width, and the bar on how far the hull's rotated footprint may still exceed it. The
## measured residual is 1.27 m; the bar sits just above it so that a regression is a failure and the number is in the
## message. It is NOT a target: see the partial-result note on the wedged test below.
##
## ⚠ IF THIS GOES RED, LOOK AT THE ROSTER BEFORE LOOKING AT THE CODE (nav's note, and it will save an hour). The
## sweep is `length x sin(yaw)`, so the bar's 0.53 m of headroom is eaten by hull LENGTH, not by the constraint
## weakening: an 18 m hull at the same 11.6 deg needs ~0.7 m more footprint on its own, which breaches this on a
## roster change alone. CP2 resizes most of the roster. The right reading then is "CP2 moved it", and the right fix
## is to re-measure the corridor and move this number WITH THE NEW FIGURE STATED -- never to widen it to whatever
## makes the test pass.
const CORRIDOR_M := 4.8
const RESIDUAL_BAR_M := 1.8


static func _giveup(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["facegiveup"]) if on else PackedStringArray()
	Movement._off_parsed = true
	OrderController.face_giveups = 0
	OrderController.face_checked = 0
	return was


## THE GUARD, first: a hull that CAN come round must still come round. A recovery that fires on a healthy face would
## break the one thing the order is for, and it would do it behind a flag where nobody looks.
func test_a_car_with_room_still_turns_to_its_face() -> void:
	var was := _giveup(true)
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Turner", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "face", "x": -60.0, "z": 40.0}, {"type": "hold_fire"}), "", "told to face east")
	for frame in int(SimClock.TICK_RATE * 8):
		await tree.physics_frame
	var east := (-tank.global_basis.z).dot(Vector3.RIGHT)
	var stalled := ctl.face_stalled
	Movement._off = was
	assert_true(east > 0.7, "a car with open ground comes round (dot %.2f)" % east)
	assert_true(not stalled, "and is never reported as unable to (%s)" % stalled)


## The arithmetic of the window itself, so the bar is checkable without a wedged hull: under FACE_STALL_DEG of turn
## across FACE_STALL_SECONDS is a shuffle, not a rotation. Round 8's bare-ground figure was 7 degrees and its
## against-scenery figure 26, so a 3 degree bar sits well below both and does not fire on either.
func test_the_stall_bar_sits_below_the_numbers_round_8_measured() -> void:
	assert_true(OrderController.FACE_STALL_DEG < 7.0,
			"3 degrees is below round 8's 7-degree bare-ground turn, so an unobstructed hull never trips it")
	assert_true(OrderController.FACE_STALL_SECONDS >= 1.0,
			"and the window is long enough that a hull mid-swing is not called stalled")


## The arm, provable from outside (lesson 147): `face_checked` is the denominator, so a zero in `face_giveups` is
## distinguishable from a mechanism nothing reached — which is round 8's `gates aimed 0` in a new place.
func test_the_counter_distinguishes_never_checked_from_never_stalled() -> void:
	var was := _giveup(true)
	assert_eq(OrderController.face_checked, 0, "nothing checked yet")
	assert_eq(OrderController.face_giveups, 0, "and nothing given up")
	Movement._off = was
	assert_true(not OrderController.face_giveup_on(), "and the switch is OFF by default, like every round-9 row")


## THE BENEFIT IS UNREACHABLE, AND THIS TEST IS WHY — the pre-registered falsifier for this row came back negative
## and names its cause. The recovery fires when a hull under a `face` FAILS to turn. **That condition does not occur**,
## because a hull's rotation is never collision-resolved: `tank.gd` assigns `global_basis` directly and only
## `move_and_slide()` below it resolves translation. A hull pinned against scenery therefore keeps yawing, through the
## scenery, for as long as its creep wins it any legal translation at all.
##
## Which is the lead's complaint, more exactly than round 8 could state it: *"the semi trucks are yawing in place
## (should be impossible, they're not a tracker vehicle)"*. The semi is not failing to turn. It is turning when it has
## no room to, and a stall detector is the wrong instrument for a hull that never stalls.
##
## `game/tank/tank.gd` is COMBAT's file (`game/tank/` except `tank_motion.gd`), so nav reports this rather than fixing
## it. **When combat couples the basis to a collision test, the third assertion here goes red** — that is the signal
## that the defect is fixed and this row's benefit becomes measurable for the first time. Re-run it then; do not
## delete it.
## ROUND 9, RENAMED AND INVERTED: the plant now refuses a yaw that would push the hull deeper into geometry
## (`Tank.yaw_fit_enabled`, `--tune=match.yaw_fit=0` restores the old behaviour). nav wrote the previous version to
## assert the DEFECT -- "keeps yawing because rotation is never collided" -- and said its going red would be the
## signal the defect was gone. It went red; this is that signal, written down as the new expectation.
##
## Measured, laptop, BOTH ARMS ON ONE BUILD with the tune proven to move the predicate:
##            off           on
##   yaw      44.0 deg      11.6 deg     (74% of the illegal rotation gone)
##   footprint 12.1 m        6.1 m       in a 4.8 m corridor
##   giveups   0             1           the recovery FIRES, having been inert all round
##   refusals  0 applied     3+ applied  the arm's own behavioural evidence, asserted below
##
## ⚠ AN EARLIER "before" OF 28.5 deg / 9.6 m IS STRUCK: it was taken with a knob that did nothing, so it measured
## the constraint ON. The off column above reproduces this test's ORIGINAL unconstrained reading (10.42 m of path,
## 44.0 deg, 4.42 m of drift, 12.1 m of footprint) to the decimal, which is what says the arm is genuinely off.
##
## ⚠ THE RESIDUAL IS NAMED RATHER THAN HIDDEN: 6.1 m of footprint in a 4.8 m corridor still means the hull rotates
## about **1.3 m** through the wall. The constraint is a per-tick comparison against the hull's CURRENT penetration,
## and `move_and_slide` depenetrates between ticks, so a rotation that is illegal cumulatively is legal at every
## increment. The exact form -- refuse any yaw that penetrates at all -- freezes a wedged rig solid for 30 ticks,
## which is N1's breach. No form that is both exact and non-freezing has been found; this asserts what IS true.
##
## **This is a PARTIAL result, not a closed one**, and nav asked for it to be written that way: a hull still sweeping
## 1.3 m more than its corridor allows is still doing the thing the lead complained about, only less of it. The sweep
## is `length x sin(yaw)`, so CP2's resize moves the residual across the roster and 1.3 m will not hold for every
## hull -- which is why the bar below is on the EXCEEDANCE and prints the figure, rather than asserting "it works".
func test_a_wedged_semi_no_longer_yaws_through_the_wall() -> void:
	var path := await _wedged_path(false)
	print("MEASURE face_wedged: %.2f m of path, %.1f deg of yaw (windows checked %d, giveups %d); net drift %.2f m in a corridor 4.8 m wide, where the hull's rotated footprint needs %.1f m" % [
			path, _last_yaw, OrderController.face_checked, OrderController.face_giveups, _last_net, _last_span])
	# ⚠ THE ARM, ASSERTED FIRST AND BEHAVIOURALLY. The constraint is off by default, so this row selects it -- and a
	# selection that silently fails to take gives a freely-yawing hull, a large residual, and a RED THAT READS AS
	# THE CONSTRAINT REGRESSING rather than as the switch never firing. `applied` is the only counter that can rise
	# when the mechanism actually refuses a yaw; `offered` rises either way. Measured with the arm genuinely off:
	# 44.0 deg, 12.1 m of footprint, giveups 0, `applied 0`.
	assert_true(_last_refusals > 0,
			"the constraint is LIVE for this row (%d yaw refusals applied), so everything below measures it"
			% _last_refusals)
	# POSITIVE CONTROL, unchanged: the corridor must really wedge the hull, or nothing below means anything.
	assert_true(path > 1.0, "the corridor wedges the semi into a shuffle (%.2f m of path ground out)" % path)
	# THE DENOMINATOR, unchanged: the mechanism was reached, so the count below is a measurement and not dead code.
	assert_true(OrderController.face_checked > 0,
			"the recovery was REACHED (%d windows checked), so the count below is a measurement" % OrderController.face_checked)
	# INVERTED: it used to be asserted at 0 because the hull never stalled -- it rotated through the wall instead.
	# The plant now refuses that rotation, so the hull DOES stall and the recovery nav built for it finally fires.
	assert_true(OrderController.face_giveups > 0,
			"the recovery fires now that the plant refuses an impossible yaw (%d giveups, %.1f deg yawed)" % [
			OrderController.face_giveups, _last_yaw])
	assert_true(_last_yaw < 20.0,
			"the wedged yaw is cut well below the 44.0 deg it reaches unconstrained (%.1f deg)" % _last_yaw)
	# THE RESIDUAL AS A NUMBER, at nav's request and for its reason: the obvious rewrite here is "the constraint
	# works", and that assertion would throw the 1.3 m away -- the remainder could then grow back to 2 m or 3 and the
	# test would still pass, asserting the wrong thing about the right mechanism. So the BAR IS ON THE EXCEEDANCE and
	# the measured figure is in the failure text, exactly as nav's original printed "12.1 m of footprint in 4.8 m".
	var over := _last_span - CORRIDOR_M
	print("MEASURE face_wedged residual: the rotated footprint exceeds its %.1f m corridor by %.2f m (unconstrained: 7.3 m over, at 12.1 m of footprint)" % [
			CORRIDOR_M, over])
	assert_true(over <= RESIDUAL_BAR_M,
			"the rotated footprint exceeds its corridor by no more than %.1f m (1.27 m at 6.1 m in a 4.8 m corridor; unconstrained 7.3 m; now %.2f m)" % [
			RESIDUAL_BAR_M, over])


var _last_yaw := 0.0
## The arm's BEHAVIOURAL evidence: refusals this run actually APPLIED. `refusals_offered` counts the call site and
## would rise with the constraint off; only `applied` can rise when the mechanism fires. Snapshotted as a delta
## because both are process-wide statics.
var _refusals_at := 0
var _last_refusals := 0
var _last_net := 0.0
var _last_span := 0.0


## Drives the wedged semi for 8 s with the recovery `on` or off, returning the metres of path it grinds out.
func _wedged_path(on: bool) -> float:
	# The constraint is OFF by default for round 10. Combat's slide-off passed CP4's four bars (five_squads 0 of 30
	# off), but a hull pinched on BOTH sides, commanded a pure pivot, is refused every candidate: the driver must creep
	# out of the pinch first (a refused-pivot regime in Movement, round 11). See `Tank.yaw_fit_enabled`.
	# This row measures what it DOES, so it selects the arm itself, through the tuning key production reads.
	Units.tuning["yaw_fit"] = 1.0
	_refusals_at = Tank.refusals_applied
	var was := _giveup(on)
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var at := Vector3(-100, 0, 40)
	add_to_tree(_corridor(at))
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = at
	tank.rotation.y = 0.0  # 14 m of hull lying along z, in a corridor 5 m wide
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "face", "x": at.x + 20.0, "z": at.z}, {"type": "hold_fire"}), "",
			"told to face across the corridor, which it cannot do")
	var previous := tank.global_position
	var heading0 := -tank.global_basis.z
	var path := 0.0
	for frame in int(SimClock.TICK_RATE * 8):
		await tree.physics_frame
		path += Vector2(tank.global_position.x - previous.x, tank.global_position.z - previous.z).length()
		previous = tank.global_position
	var forward := -tank.global_basis.z
	_last_yaw = rad_to_deg(absf(atan2(heading0.x * forward.z - heading0.z * forward.x,
			heading0.x * forward.x + heading0.z * forward.z)))
	_last_net = Vector2(tank.global_position.x - at.x, tank.global_position.z - at.z).length()
	# The footprint the hull's 14 m of length now demands across the 4.8 m corridor. If this exceeds the corridor
	# and the hull is still inside it, the basis was rotated THROUGH the walls.
	_last_span = 14.0 * sin(deg_to_rad(_last_yaw)) + 3.32 * cos(deg_to_rad(_last_yaw))
	Movement._off = was
	_last_refusals = Tank.refusals_applied - _refusals_at
	Units.tuning.erase("yaw_fit")
	return path


## Two walls 5 m apart and two end caps: room to creep along its length, none to rotate.
func _corridor(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Corridor"
	for side: float in [-1.0, 1.0]:
		_slab(body, at + Vector3(side * 2.9, 2.0, 0.0), Vector3(1.0, 4.0, 30.0))
		_slab(body, at + Vector3(0.0, 2.0, side * 10.0), Vector3(6.0, 4.0, 1.0))
	return body


func _slab(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


## S3: `facing_arc` must be PUBLISHED, and must be live only while the hull is actually being steered at a gate.
## metrics' emitter writes `null` until nav publishes this key, and a null column made `make metrics` print
## `arc_live=0.0s` in both arms of nav's own A4 A/B — a zero that reads like a measurement of behaviour and was an
## unpublished field. The guard that matters is the CLEAR: a stale `true` becomes arc seconds the hull never spent.
func test_the_arrival_arc_publishes_whether_it_is_live() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Arcer", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	# A wheeled hull sent somewhere with an ordered facing: the gate is what it steers at first.
	assert_eq(ctl.set_orders({"type": "move_to", "x": -60.0, "z": 40.0, "facing": [1.0, 0.0]},
			{"type": "hold_fire"}), "", "told to arrive facing east")
	await tree.physics_frame  # `Movement.of` has no mover until the hull is driven, and `state` is {} until then
	assert_true(Movement.state(tank).has("facing_arc"), "the key is published at all (metrics reads it as optional)")
	var seen_live := false
	for frame in int(SimClock.TICK_RATE * 6):
		await tree.physics_frame
		if bool(Movement.state(tank).get("facing_arc", false)):
			seen_live = true
			break
	assert_true(seen_live, "the arc reports itself LIVE while the hull is steered at the gate")
	# ...and stops reporting live the moment the mover is no longer driving.
	Movement.of(tank).idle()
	assert_true(not bool(Movement.state(tank).get("facing_arc", true)),
			"and is cleared by idle(), so it can never be counted as arc seconds the hull did not spend")


## S4: control signed A6 on one condition — that `Movement.state(unit)` carry `legibility: {active, why}` so their
## readout names which level took the nose instead of inferring it from geometry. Their C-2 readout was built and
## SILENT waiting for this key. These tests hold the shape control renders against, and the closed set, because a
## `why` outside it renders as nothing and a silent readout looks exactly like a working one.
func test_the_legibility_key_control_signed_for_is_published() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Legible", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "move_to", "x": -60.0, "z": 40.0, "facing": [1.0, 0.0]},
			{"type": "hold_fire"}), "", "sent somewhere with an ordered facing")
	await tree.physics_frame
	var leg: Variant = Movement.state(tank).get("legibility")
	assert_true(leg is Dictionary, "the key is published as a Dictionary")
	var pair: Dictionary = leg
	assert_true(pair.has("active") and pair["active"] is bool, "`active` is a bool")
	assert_true(pair.has("why"), "`why` is present")
	assert_true(Movement.LEGIBILITY_WHY.has(pair["why"]),
			"`why` (%s) is in the closed set control renders: %s" % [pair["why"], Movement.LEGIBILITY_WHY])
	# A6 is not built, so nothing nav owns shapes the nose. Asserting this keeps a later `active: true` honest:
	# whoever flips it has to come through this test and say which law did it.
	assert_true(not bool(pair["active"]),
			"`active` is false until A6-a/A6-b exist - no nav-owned motion law is shaping the nose yet")
	# `override` is RESERVED and must stay unpublished until a law can actually be outranked. control renders the
	# absence of a law as nothing; publishing `override` for it would be attribution for a cause that never ran.
	assert_true(pair["why"] != &"override",
			"nothing publishes `override` while no nav-owned law exists to be overridden (got %s)" % pair["why"])


## S4 names this case explicitly: an arrival arc under an ORDERED facing is off-corridor by construction, and those
## ticks must be counted as ordered and never charged to A6's fraction. The readout can only do that if nav says so,
## which is why `arrival_arc` is in the set rather than folded into `override`.
func test_an_ordered_arrival_arc_names_itself_rather_than_looking_like_a6() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Arced", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "move_to", "x": -60.0, "z": 40.0, "facing": [1.0, 0.0]},
			{"type": "hold_fire"}), "", "told to arrive facing east")
	var named := false
	for frame in int(SimClock.TICK_RATE * 6):
		await tree.physics_frame
		var pair: Dictionary = Movement.state(tank).get("legibility", {})
		if pair.get("why") == &"arrival_arc":
			named = true
			assert_true(bool(Movement.state(tank).get("facing_arc", false)),
					"and it agrees with `facing_arc` on the same tick - one fact, not two that can drift")
			break
	assert_true(named, "the arc names itself as `arrival_arc` while it is live, so A12 can exclude it from A6")


## S4 §2: nav publishes the corridor TANGENT so the law, control's readout and the falsifier read one interpretation
## rather than each projecting `path_points` their own way. And §5: `null` when there is no leg, never a zero vector
## — an unreadable corridor must not look like a readable one.
func test_the_corridor_tangent_is_published_and_is_null_when_there_is_no_leg() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Corridor", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "move_to", "x": -60.0, "z": 40.0}, {"type": "hold_fire"}), "", "sent east")
	var tangent: Variant = null
	for frame in int(SimClock.TICK_RATE * 4):
		await tree.physics_frame
		tangent = Movement.state(tank).get("corridor")
		if tangent != null:
			break
	assert_true(tangent is Vector3, "the tangent is published as a Vector3 while a leg exists")
	var t: Vector3 = tangent
	assert_true(absf(t.length() - 1.0) < 0.001, "it is a UNIT vector (%.3f)" % t.length())
	assert_true(absf(t.y) < 0.001, "flattened to the ground plane (y %.3f)" % t.y)
	assert_true(t.dot(Vector3.RIGHT) > 0.5, "and points down the ordered leg, east (dot %.2f)" % t.dot(Vector3.RIGHT))
	# ...and an idle hull has no leg at all, which must read as absent rather than as a zero tangent.
	Movement.of(tank).idle()
	var reading := Movement.state(tank)
	assert_true(reading.get("corridor") == null, "no leg publishes null, never Vector3.ZERO")
	assert_eq(reading.get("legibility", {}).get("why"), &"no_order",
			"and the law reports itself inactive with §5's reason rather than looking broken")
