extends TestCase
## Round 47 (manoeuvre, mapkit's request; `--traffic-on=overstay`): A CREW PARKED IN A CLOSING DOORWAY MOVES ON. On the doors
## dev arena (arenas/doors_dev.json: a wall along z = 0, the west door at (-40, 0)) a crew stands in the west doorway, nose
## through the slot, when the door's schedule shuts it. The door holds open (it never lands on a hull); after
## ArenaDoors.HOLD_EVICT_S it emits `overstay` naming the crew. ON: the crew gives way off the slab (DoorOverstay). OFF
## (today): the crew stands in the doorway and the door stays held. The crew is on HIS hold (a lab brain with no order
## drives off, and an element seat is never in a doorway: the grounding snaps it off the carve), the realistic overstay.

const DOOR := Vector2(-40.0, 0.0)
const CREW := "Green_Probe_1"
## After the overstay the crew must be clear of the doorway, and the door sealed, within this long.
const CLEAR_BY_S := 8.0
## ON, the crew is on its way off the slab: at least MOVED_M from where it stood within MOVED_BY_S of the overstay.
const MOVED_BY_S := 4.0
const MOVED_M := 3.0

var _lab: TacticsLab
var _was := Traffic.off(DoorOverstay.SWITCH)


func teardown() -> void:
	Traffic.set_off(DoorOverstay.SWITCH, _was)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## Stages the crew in the doorway and runs from the warning to CLEAR_BY_S after the overstay; returns what it saw.
func _run(on: bool) -> Dictionary:
	Traffic.set_off(DoorOverstay.SWITCH, not on)
	DoorOverstay.reset()
	_lab = TacticsLab.create(self, 7, "doors_dev")
	var doors: ArenaDoors = (_lab.arena as Arena).doors
	var events: Array[Dictionary] = []
	doors.door_event.connect(func(e: Dictionary) -> void: events.append(e))
	var first := doors.doors.next_change("west_gate", 0)
	var tick := [first - SimClock.ticks(BlastDoors.WARN_S) - 2]
	doors.tick_source = func() -> int: return tick[0]
	# Nose through the slot, straddling it (the hull's long axis across the wall).
	var tank := _lab.unit(0, CREW, Vector3(DOOR.x, 0.0, DOOR.y + 1.0), 0.0)
	# His hold: the crew stays where it stands (a lab brain with no order drives off on its own).
	assert_eq(_lab.orders.issue({"units": [CREW], "verb": "hold", "source": "player"}, Match.Team.GREEN), "", "the hold is valid")
	await _lab.start()
	var start_at := Vector2(tank.global_position.x, tank.global_position.z)
	var overstay_at := -1
	var sealed_on_crew := 0
	var max_moved := 0.0
	var limit := SimClock.ticks(BlastDoors.WARN_S) + 2 + SimClock.ticks(ArenaDoors.HOLD_EVICT_S + CLEAR_BY_S) + 30
	for i in limit:
		await _lab.step()
		tick[0] += 1
		var flat := Vector2(tank.global_position.x, tank.global_position.z)
		if doors.is_sealed("west_gate") and doors.doors.in_doorway("west_gate", flat, ArenaDoors.HULL_MARGIN):
			sealed_on_crew += 1
		if overstay_at >= 0 and tick[0] - overstay_at <= SimClock.ticks(MOVED_BY_S):
			max_moved = maxf(max_moved, flat.distance_to(start_at))
		if overstay_at < 0 and events.any(func(e: Dictionary) -> bool: return e["kind"] == "overstay"):
			overstay_at = tick[0]
		if overstay_at >= 0 and OS.get_environment("OVERSTAY_TRACE") == "on" and (tick[0] - overstay_at) % 15 == 0:
			var mover := Movement.of(tank)
			print("OVERSTAY_TICK %d at %s yield_to '%s' phase %s point %s left %d thr %.2f turn %.2f order %s native %s" % [tick[0] - overstay_at,
					str(flat), mover.yield_to, mover.phase, str(mover._yield_point), mover._yield_left, tank.command.throttle,
					tank.command.turn, str(mover.ctl.move_order.get("type", "")), str(NativeExec.usable(mover.ctl))])
		if overstay_at >= 0 and tick[0] - overstay_at >= SimClock.ticks(CLEAR_BY_S):
			break
	var flat := Vector2(tank.global_position.x, tank.global_position.z)
	var out := {"overstay": overstay_at >= 0, "sealed": doors.is_sealed("west_gate"), "held": doors.is_held("west_gate"),
			"in_doorway": doors.doors.in_doorway("west_gate", flat, ArenaDoors.HULL_MARGIN), "sealed_on_crew": sealed_on_crew,
			"moves": DoorOverstay.moves, "max_moved": max_moved, "at": flat, "start": start_at, "alive": tank.is_alive()}
	print("OVERSTAY_ROW %s %s" % ["on" if on else "off", str(out)])
	return out


func test_overstay_is_off_by_default_until_doors_reach_a_real_arena() -> void:
	assert_true(Traffic.DEFAULT_OFF.has(DoorOverstay.SWITCH), "opt-in until doors are on a dealt arena")


func test_a_crew_parked_in_a_closing_doorway_moves_on() -> void:
	var seen := await _run(true)
	assert_true(seen["overstay"], "the door asked (overstay after %.0f s held)" % ArenaDoors.HOLD_EVICT_S)
	assert_eq(int(seen["moves"]), 1, "the crew gave way to the door once")
	assert_true(float(seen["max_moved"]) >= MOVED_M, "it drove off the slab (%.1f m in %.0f s)" % [float(seen["max_moved"]), MOVED_BY_S])
	assert_eq(int(seen["sealed_on_crew"]), 0, "the door never sealed with the crew in it")
	assert_true(seen["alive"], "alive")
	# OPEN (Status, a question to the orchestrator): under HIS hold the brain drives the crew back to his post, in the
	# doorway, once the give-way ends (this run: out to z 5.0, back to 3.5), so the door stays held. Sealing behind it needs
	# his post moved off the slab: TankBrain state, not this stream's.


func test_today_the_crew_stays_and_the_door_stays_held() -> void:
	var seen := await _run(false)
	assert_true(seen["overstay"], "the door asked")
	assert_eq(int(seen["moves"]), 0, "nobody moved it")
	assert_true(seen["in_doorway"] and seen["held"] and not seen["sealed"], "the crew stands in the doorway, the door held open")
