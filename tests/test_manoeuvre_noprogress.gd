extends TestCase
## Round 47 (manoeuvre M1/M2): HIS TWO STALLS, STAGED. A crew that makes no progress toward its seat while its squad drives on
## looks dumb (his Locks and Crossing notes, game_design.md *His second match* / *His playtest after round 46's ships*).
##
## Locks (2026-10-30 15:49, Burners2_4): his squad of five fire trucks from its spawn row, one group click to (-68.3, 31.2). The
## squad's travelling station for Burners2_4 slid into the 2.8 m gap between the city block at (-30, 42) and the container_40 at
## (-30, 66); its grounded station (the nearest standable point) stayed pinned at the container's east end (-19.9, 66.1), so the
## crew drove its nose into the block there and parked "arrived" ~2 s while the squad drove on, then reversed out for 2.5 s
## (M1's trace, references/round47/manoeuvre/m1-trace/).
## Crossing (15:41, Hunters): four gang IFVs at his tick-3030 spots, his move click to (-68.7, -57.9) over the west bridge.
##
## The measure (the bar's deciding line): NO-PROGRESS crew-seconds = ticks in which the crew's distance to its FINAL seat has not
## fallen by PROGRESS_M over the last WINDOW_S while its squad is still under way and the crew is more than FAR_M from that seat.
## A crew standing in its own lane while its seat comes up (the pacing rule) counts too: to his eye it is a crew not going anywhere.
## NOPROGRESS_TRACE=on prints a NOPROGRESS_TICK row a second per crew.

const PROGRESS_M := 1.0
const WINDOW_S := 1.0
const FAR_M := 15.0
## The CPU's sliver case: a crew is off the sliver once it comes within NEAR_SEAT_M of its seat (today Hunters_2 / Hunters_4 never
## get under 14.5 m), and must be by LEAVE_BY_S.
const NEAR_SEAT_M := 8.0
const LEAVE_BY_S := 10.0

var _lab: TacticsLab
var _buried_was := Traffic.off(Movement.BURIED_SWITCH)
var _watch_was := Traffic.off(NoProgressWatch.SWITCH)


## The arm under test: `buried` and `noprogress` ON (NOPROGRESS_ARM=off reads today's for a dev comparison).
func _arm() -> void:
	var off := OS.get_environment("NOPROGRESS_ARM") == "off"
	Traffic.set_off(Movement.BURIED_SWITCH, off)
	Traffic.set_off(NoProgressWatch.SWITCH, off)


func teardown() -> void:
	Traffic.set_off(Movement.BURIED_SWITCH, _buried_was)
	Traffic.set_off(NoProgressWatch.SWITCH, _watch_was)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## Runs `seconds` of the staged squad and returns {crew: no-progress seconds}.
func _watch(names: Array, element: Element, seconds: float) -> Dictionary:
	var trace := OS.get_environment("NOPROGRESS_TRACE") == "on"
	var window := int(WINDOW_S * SimClock.TICK_RATE)
	var history := {}
	var stalled := {}
	for n: String in names:
		history[n] = []
		stalled[n] = 0
	for i in int(seconds * SimClock.TICK_RATE):
		await _lab.step()
		for n: String in names:
			var tank := _lab.tank_of(n)
			if tank == null or not tank.is_alive() or not (element.slots.get(n) is Vector3):
				continue
			var seat: Vector3 = element.slots[n]
			# Route distance (a straight line reads a crew driving round a bend or over a bridge as stalled).
			var to_seat := SlotGround.path_length(tank, tank.global_position, seat)
			var h: Array = history[n]
			h.append(to_seat)
			if h.size() > window + 1:
				h.pop_front()
			var under_way := element.in_transit() or not element.arrived
			if under_way and to_seat > FAR_M and h.size() > window and float(h[0]) - to_seat < PROGRESS_M:
				stalled[n] = int(stalled[n]) + 1
			if trace and i % 30 == 0:
				var mover := Movement.of(tank)
				print("NOPROGRESS_TICK %d %s at (%.1f, %.1f) seat (%.1f, %.1f) to_seat %.1f v %.1f phase %s goal (%.1f, %.1f) station %s transit %s stalled %d" % [
						i, n, tank.global_position.x, tank.global_position.z, seat.x, seat.z, to_seat, tank.speed(), mover.phase,
						mover._goal.x, mover._goal.z, str(element.stations.get(n)), str(element.in_transit()), int(stalled[n])])
	var out := {}
	for n: String in names:
		out[n] = float(stalled[n]) / SimClock.TICK_RATE
	print("NOPROGRESS_ROW %s buried_swaps %d %s" % [OS.get_environment("NOPROGRESS_ARM"), Movement.buried_swaps, JSON.stringify(out)])
	return out


## Locks: his Burners2 from its spawn row (header `spawn`, yaw 0), his first group click's spot.
func test_locks_burner_is_never_parked_at_the_block_while_its_squad_drives_on() -> void:
	_arm()
	_lab = TacticsLab.create(self, 497, "locks")
	var spawn := {"Green_Burners2_1": Vector2(-21.125, 90.0), "Green_Burners2_2": Vector2(-14.625, 90.0),
			"Green_Burners2_3": Vector2(-17.875, 99.54), "Green_Burners2_4": Vector2(-8.125, 90.0),
			"Green_Burners2_5": Vector2(-11.375, 99.54)}
	var names := spawn.keys()
	names.sort()
	for n: String in names:
		_lab.unit(Match.Team.GREEN, n, Vector3(spawn[n].x, 0.0, spawn[n].y), 0.0, "burner")
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("condemned").get("table")
	var element := _lab.elements.form(names, "Burners2", table)
	await _lab.start()
	element.assign({"verb": "move", "to": [-68.317, 31.226], "drills": false})
	var stalls := await _watch(names, element, 14.0)
	assert_true(float(stalls["Green_Burners2_4"]) < 1.0, "Burners2_4 makes progress toward its seat (no-progress %.1f s)" % float(stalls["Green_Burners2_4"]))


## Crossing: his four Hunters (gang IFVs) where they stood at tick 3030, headings from their last moves, his click. A GUARD, not his
## case: without the Lances' fire this lab does not reproduce his Hunters sitting (M1: all four leave at once; today 1.0 / 0 / 1.97 /
## 0 s, builder3 113fa2856+). It catches a buried rule that fires on the bridge mouth's thin barricade (an over-broad build sent
## Hunters_1 into a 3 s k-turn there: 3.73 s).
func test_crossing_hunters_all_leave_for_the_bridge() -> void:
	_arm()
	_lab = TacticsLab.create(self, 101, "crossing")
	var pose := {"Green_Hunters_1": [Vector2(-60.4, 81.9), 37.0], "Green_Hunters_3": [Vector2(-81.5, 77.8), -59.0],
			"Green_Hunters_4": [Vector2(-61.7, 65.4), -59.0], "Green_Hunters_5": [Vector2(-87.5, 57.9), -18.0]}
	var names := pose.keys()
	names.sort()
	for n: String in names:
		var at: Vector2 = pose[n][0]
		_lab.unit(Match.Team.GREEN, n, Vector3(at.x, 0.0, at.y), deg_to_rad(float(pose[n][1])), "gang_ifv")
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("gangs").get("table")
	var element := _lab.elements.form(names, "Hunters", table)
	await _lab.start()
	element.assign({"verb": "move", "to": [-68.69, -57.88], "drills": false})
	var stalls := await _watch(names, element, 12.0)
	for n: String in names:
		assert_true(float(stalls[n]) < 2.5, "%s makes progress toward its seat (no-progress %.1f s)" % [n, float(stalls[n])])


## Crossing, THE CPU's SIDE (C47.9): the Rust Hunters (syndicate) on their ambush task (his recording, task row at tick 91: from
## (-13.4, -9.5) toward (-50.5, 15.6)) sat in a 6 m patch north of the city block at (-34, -33) for 24+ s (ticks 2400-3120):
## Hunters_2 yielding to Hunters_3 while Hunters_3 was blocked by Hunters_2, Hunters_4 blocked `no_path`, Hunters_1 yielding to
## Hunters_4. Staged where they stood at tick 2760 (headings from their last moves), the same task: no crew may sit yielding or
## blocked for long while it is still away from its seat.
func test_cpu_ambush_squad_does_not_sit_in_a_yield_cycle() -> void:
	_arm()
	_lab = TacticsLab.create(self, 101, "crossing")
	var pose := {"Rust_Hunters_1": [Vector2(-26.7, -7.3), -76.0, "syn_ifv"], "Rust_Hunters_2": [Vector2(-31.5, -6.9), 163.0, "syn_ifv"],
			"Rust_Hunters_3": [Vector2(-32.5, -9.7), -59.0, "syn_ifv"], "Rust_Hunters_4": [Vector2(-28.8, -9.6), -180.0, "syn_scout"]}
	var names := pose.keys()
	names.sort()
	for n: String in names:
		var at: Vector2 = pose[n][0]
		_lab.unit(Match.Team.RUST, n, Vector3(at.x, 0.0, at.y), deg_to_rad(float(pose[n][1])), String(pose[n][2]))
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("syndicate").get("table")
	var element := _lab.elements.form(names, "Hunters", table)
	await _lab.start()
	element.assign({"verb": "ambush", "from": [-13.4375, -9.5], "to": [-50.467, 15.627]})
	var stuck := {}
	var left_at := {}  # the tick each crew first came within NEAR_SEAT_M of its seat (off the sliver: today two never do)
	for n: String in names:
		stuck[n] = 0
		left_at[n] = -1
	var trace := OS.get_environment("NOPROGRESS_TRACE") == "on"
	for i in 15 * SimClock.TICK_RATE:
		await _lab.step()
		for n: String in names:
			var tank := _lab.tank_of(n)
			var mover := Movement.of(tank)
			if mover == null or not (element.slots.get(n) is Vector3):
				continue
			var seat: Vector3 = element.slots[n]
			var away := Vector2(seat.x - tank.global_position.x, seat.z - tank.global_position.z).length()
			if away > 4.0 and (mover.phase == "yielding" or mover.phase == "blocked"):
				stuck[n] = int(stuck[n]) + 1
			if int(left_at[n]) < 0 and away <= NEAR_SEAT_M:
				left_at[n] = i
			if trace and i % 30 == 0:
				var near := Pathing.closest_point(tank.get_world_3d().navigation_map, tank.global_position)
				print("CYCLE_TICK %d %s at (%.1f, %.1f) seat (%.1f, %.1f) away %.1f phase %s by %s yield_to %s v %.1f rv %.2f thr %.2f order %s goal %s steer %s path %d reach %s off_mesh %.2f touch %s/%s stuck_t %.2f esc %d stalled %d" % [i, n,
						tank.global_position.x, tank.global_position.z, seat.x, seat.z, away, mover.phase, mover.blocked_by, mover.yield_to,
						tank.speed(), tank.real_velocity.length(), tank.command.throttle, String(mover.ctl.move_order.get("type", "")), str(mover._goal),
						str(mover.steer_to), mover._path.size(), str(mover._reachable), Vector2(near.x - tank.global_position.x, near.z - tank.global_position.z).length(),
						str(mover.contact.touching), mover.contact.collider, mover._stuck_time, mover._esc_stage, mover.stalled_ticks])
	var out := {}
	for n: String in names:
		out[n] = float(stuck[n]) / SimClock.TICK_RATE
	print("CYCLE_ROW %s watch %s reroutes %s held_s %s left_tick %s" % [OS.get_environment("NOPROGRESS_ARM"), JSON.stringify(NoProgressWatch.report()),
			JSON.stringify(Pathing.reroutes), JSON.stringify(out), JSON.stringify(left_at)])
	# What this item fixes: nobody stays on the sliver. Today Hunters_2 and Hunters_4 never leave it in 15 s (his recording: 24+ s).
	# `held_s` (yielding / blocked more than 4 m from the seat) is reported, not asserted: with the sliver fixed, Hunters_2 then
	# waits 4.3 m from its seat behind Hunters_1 parked on its own (a settle contention at the destination, another item).
	for n: String in names:
		assert_true(int(left_at[n]) >= 0 and int(left_at[n]) < LEAVE_BY_S * SimClock.TICK_RATE,
				"%s comes within 8 m of its seat (off the sliver) within %.0f s (tick %d)" % [n, LEAVE_BY_S, int(left_at[n])])
