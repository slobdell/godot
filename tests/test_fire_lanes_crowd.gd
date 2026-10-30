extends TestCase
## Round 46 (engage L2, `--lane-clear`): his IFV behind his own parked squads (Terminus 116-140 s, `_agents/streams/engage.md`
## L1) held fire ~20 s. Staged here: his IFV, an enemy 25 m off, his own crews PARKED in and beside its lane (the near
## sidesteps blocked as on his replay). Each case runs both arms (TankBrain.LANE_CLEAR off = the round-45 game, on).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SHOOTER_AT := Vector3(-100, 0, 40)
const TARGET_AT := Vector3(-100, 0, 15)
## A wall: one squadmate dead in the lane, two either side a little ahead (only a long relocation clears it).
const CROWD: Array[Vector3] = [Vector3(-100, 0, 30), Vector3(-95, 0, 33), Vector3(-105, 0, 33)]
## His case at 134 s: the enemy ~19 m off, Wrenches_3 parked in the lane 10 m out, Hunters_2 parked 14 m off to the side.
const NEAR_TARGET := Vector3(-100, 0, 21)
const HIS_CROWD: Array[Vector3] = [Vector3(-100, 0, 30), Vector3(-90, 0, 30)]

var _match: Match
var _orders: Orders


func _stage(crowd: Array[Vector3], target_at: Vector3, unit: String) -> Tank:
	add_to_tree(ARENA.instantiate())
	_match = add_to_tree(MATCH.instantiate())
	_match.seed_spawns(1, 0.0)
	_match.elimination = true
	_match.set_meta("player_team", Match.Team.GREEN)
	_orders = Orders.new(_match)
	Orders.attach(_match, _orders)
	var me := _match.add_brain_tank(Match.Team.GREEN, "Hunters", unit, [{}], "Green_Hunters_1")
	me.place(SHOOTER_AT, 0.0)
	var i := 0
	for at: Vector3 in crowd:
		i += 1
		var friend := _match.spawn_tank("Green_Guns_%d" % i, 0, Match.Team.GREEN, "tank")
		friend.place(at, 0.0)
		var controller := OrderController.new()
		controller.name = "Orders_" + String(friend.name)
		controller.tank = friend
		controller.tanks_root = _match.tanks
		_match.brains.add_child(controller)
		controller.set_orders({"type": "stop"}, {"type": "hold_fire"})
		AiScenario.make_durable(friend)
	var target := _match.spawn_tank("Rust_Eyes_3", 0, Match.Team.RUST, "tank")
	target.place(target_at, PI)
	var holder := OrderController.new()
	holder.name = "Orders_Rust_Eyes_3"
	holder.tank = target
	holder.tanks_root = _match.tanks
	_match.brains.add_child(holder)
	holder.set_orders({"type": "stop"}, {"type": "hold_fire"})
	AiScenario.make_durable(target)
	await wait_physics_frames(6)
	return me


## {"first_s": seconds to the first round (-1 none), "shots", "through" (rounds fired with a friend in the lane),
## "moved": metres from where it started, "path": metres driven}.
## Round 46 (L3): his selection, as RtsControls reports it to HudMessages.
class SelectionStub:
	extends RefCounted
	var units: Array[String] = []

	func selection_state() -> Dictionary:
		return {"units": units.duplicate()}


func _run(arm: bool, crowd: Array[Vector3], order: Dictionary, seconds: float, target_at := TARGET_AT, unit := "ifv",
		lines: Array = []) -> Dictionary:
	var saved := TankBrain.LANE_CLEAR
	TankBrain.LANE_CLEAR = arm
	var me := await _stage(crowd, target_at, unit)
	var shots := [0, -1, 0]
	_match.weapon_fired.connect(func(event: Dictionary) -> void:
		if String(event.get("shooter", "")) == "Green_Hunters_1":
			shots[0] += 1
			if shots[1] < 0:
				shots[1] = _match.tick)
	var start_tick := _match.tick
	if not order.is_empty():
		assert_eq(_orders.issue(order), "", "setup: his order is taken")
	# His selection is this crew; the feed's lines are collected (L3).
	var selected := SelectionStub.new()
	selected.units = ["Green_Hunters_1"]
	var messages := HudMessages.new()
	messages.game_match = _match
	messages.selection_source = selected
	messages.posted.connect(func(text: String, _severity: int) -> void: lines.append(text))
	_match.add_child(messages)
	var path := 0.0
	var last := me.global_position
	var options := {}
	var brain := _match.brains.get_node("Brain_Green_Hunters_1") as TankBrain
	for tick in int(seconds * SimClock.TICK_RATE):
		await wait_physics_frames(1)
		path += last.distance_to(me.global_position)
		last = me.global_position
		var option := String(brain.choice.get("option", ""))
		options[option] = int(options.get(option, 0)) + 1
	TankBrain.LANE_CLEAR = saved
	# Friendly fire is read where it lands: damage on the (durable) friends.
	var friends_hit := 0
	for node in _match.tanks.get_children():
		var friend := node as Tank
		if friend != null and friend.team == Match.Team.GREEN and friend != me and friend.health < 1_000_000:
			friends_hit += 1
	var result := {"first_s": float(shots[1] - start_tick) / SimClock.TICK_RATE if shots[1] >= 0 else -1.0,
			"shots": shots[0], "through": friends_hit, "moved": SHOOTER_AT.distance_to(me.global_position), "path": path,
			"options": options}
	print("LANE_RUN arm %s %s" % [arm, JSON.stringify(result)])
	_match.free()
	return result


func test_his_ifv_behind_a_parked_friend_steps_to_a_lane_under_his_attack() -> void:
	var order := {"units": ["Green_Hunters_1"], "verb": "attack", "target": "Rust_Eyes_3", "source": "player"}
	var before := await _run(false, HIS_CROWD, order, 12.0, NEAR_TARGET)
	var after := await _run(true, HIS_CROWD, order, 12.0, NEAR_TARGET)
	print("MEASURE lane_crowd_attack off first %.1f s shots %d through %d moved %.1f | on first %.1f s shots %d through %d moved %.1f" % [
			before["first_s"], before["shots"], before["through"], before["moved"],
			after["first_s"], after["shots"], after["through"], after["moved"]])
	assert_true(float(before["first_s"]) < 0.0 or float(before["first_s"]) > 10.0,
			"setup: today his IFV holds more than 10 s behind them (first round %.1f s)" % before["first_s"])
	assert_true(float(after["first_s"]) >= 0.0 and float(after["first_s"]) <= 4.0,
			"with the rule it finds a lane and fires within ~3 s (first round %.1f s)" % after["first_s"])
	assert_eq(int(after["through"]), 0, "and never hits a friend (friends hit: %d)" % after["through"])


func test_behind_a_wall_of_parked_friends_it_relocates_and_fires() -> void:
	var order := {"units": ["Green_Hunters_1"], "verb": "attack", "target": "Rust_Eyes_3", "source": "player"}
	var before := await _run(false, CROWD, order, 12.0)
	var after := await _run(true, CROWD, order, 12.0)
	print("MEASURE lane_wall_attack off first %.1f s shots %d | on first %.1f s shots %d friends hit %d moved %.1f" % [
			before["first_s"], before["shots"], after["first_s"], after["shots"], after["through"], after["moved"]])
	assert_true(float(before["first_s"]) < 0.0, "setup: today it never fires in 12 s (%.1f s)" % before["first_s"])
	assert_true(float(after["first_s"]) >= 0.0 and float(after["first_s"]) <= 9.0,
			"with the rule it drives round the wall and fires (first round %.1f s)" % after["first_s"])
	assert_eq(int(after["through"]), 0, "and never hits a friend")


func test_at_his_move_post_the_lane_step_stays_within_four_metres() -> void:
	# His case at 118-123 s: his move done, the crew at the post it left him at, the lane blocked by a parked squadmate 7 m
	# ahead. R46.7: it may step at most ~4 m and come back; with a tank-sized friend that close a 4 m step rarely clears
	# the lane (measured: it holds and the feed line says who is in the way), so what is pinned here is the bound.
	var order := {"units": ["Green_Hunters_1"], "verb": "move", "to": [SHOOTER_AT.x, SHOOTER_AT.z + 0.5], "source": "player"}
	var after := await _run(true, [Vector3(-100, 0, 33)], order, 12.0, TARGET_AT, "tank")
	print("MEASURE lane_post_step first %.1f s shots %d friends hit %d moved %.1f m driven %.1f m" % [after["first_s"],
			after["shots"], after["through"], after["moved"], after["path"]])
	assert_true(float(after["moved"]) <= TankBrain.LANE_POST_STEP + 1.5,
			"it stays within ~4 m of his post (%.1f m)" % after["moved"])
	assert_true(float(after["path"]) <= 2.0 * TankBrain.LANE_POST_STEP + 2.0, "one step out and back at most (%.1f m)" % after["path"])
	assert_eq(int(after["through"]), 0, "never through the friend")


func test_an_ifv_at_his_post_with_no_step_it_can_make_stays_put() -> void:
	# A wheeled hull can't step 4 m sideways inside its turning circle: it stays, never shuffles (the feed line says why).
	var order := {"units": ["Green_Hunters_1"], "verb": "move", "to": [SHOOTER_AT.x, SHOOTER_AT.z + 0.5], "source": "player"}
	var after := await _run(true, [Vector3(-100, 0, 36)], order, 8.0)
	print("MEASURE lane_post_ifv moved %.1f m driven %.1f m shots %d friends hit %d" % [after["moved"], after["path"],
			after["shots"], after["through"]])
	assert_true(float(after["path"]) <= TankBrain.LANE_POST_STEP + 1.0, "no shuffle (%.1f m driven)" % after["path"])
	assert_eq(int(after["through"]), 0, "never through the friend")


func test_the_feed_says_who_is_in_the_way_when_it_cannot_step() -> void:
	# His post after a move, an IFV with no step it can make (the case above): the feed names the friend, once.
	var order := {"units": ["Green_Hunters_1"], "verb": "move", "to": [SHOOTER_AT.x, SHOOTER_AT.z + 0.5], "source": "player"}
	var lines: Array = []
	await _run(true, [Vector3(-100, 0, 36)], order, 8.0, TARGET_AT, "ifv", lines)
	var off_lines: Array = []
	await _run(false, [Vector3(-100, 0, 36)], order, 8.0, TARGET_AT, "ifv", off_lines)
	var held := lines.filter(func(text: String) -> bool: return text.contains("holding fire"))
	print("MEASURE lane_line on %s | off %d lines" % [held, off_lines.filter(func(text: String) -> bool: return text.contains("holding fire")).size()])
	assert_eq(held, ["Hunters 1 holding fire: Guns 1 in the way"], "one line, naming the friend (%s)" % [held])
	assert_eq(off_lines.filter(func(text: String) -> bool: return text.contains("holding fire")).size(), 0, "none with the switch off")


func test_under_his_explicit_hold_it_never_moves_for_a_lane() -> void:
	var order := {"units": ["Green_Hunters_1"], "verb": "hold", "source": "player"}
	var after := await _run(true, CROWD, order, 8.0)
	print("MEASURE lane_hold moved %.1f m shots %d through %d" % [after["moved"], after["shots"], after["through"]])
	assert_true(float(after["moved"]) <= 1.5, "his hold holds (R46.7): %.1f m" % after["moved"])
	assert_eq(int(after["through"]), 0, "and it never fires through a friend")


func test_a_crew_with_no_clear_spot_does_not_wander() -> void:
	# A ring of parked friends all round it: no spot within 16 m has a lane. It must stay, not sidestep back and forth.
	var ring: Array[Vector3] = []
	for i in 8:
		var angle := TAU * i / 8.0
		ring.append(SHOOTER_AT + Vector3(cos(angle), 0.0, sin(angle)) * 7.0 + Vector3(0, 0, -4))
	var order := {"units": ["Green_Hunters_1"], "verb": "attack", "target": "Rust_Eyes_3", "source": "player"}
	var before := await _run(false, ring, order, 8.0)
	var after := await _run(true, ring, order, 8.0)
	print("MEASURE lane_boxed off driven %.1f m | on moved %.1f m driven %.1f m shots %d friends hit %d" % [before["path"],
			after["moved"], after["path"], after["shots"], after["through"]])
	assert_eq(int(after["through"]), 0, "it never hits a friend")
	assert_true(float(after["path"]) <= float(before["path"]) + 3.0,
			"the rule adds no wandering when there is no lane (%.1f m driven v %.1f today)" % [after["path"], before["path"]])
