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

var _lab: TacticsLab
var _buried_was := Traffic.off(Movement.BURIED_SWITCH)


## The arm under test: `buried` ON (NOPROGRESS_ARM=off reads today's for a dev comparison).
func _arm() -> void:
	Traffic.set_off(Movement.BURIED_SWITCH, OS.get_environment("NOPROGRESS_ARM") == "off")


func teardown() -> void:
	Traffic.set_off(Movement.BURIED_SWITCH, _buried_was)
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
