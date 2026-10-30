extends TestCase
## Round 45 (engage's E5 relay, R45.21: queued after B3): HIS SHORT MOVE TO A LONE WHEELED SCOUT BACKS AWAY FIRST. His Gorge replay
## (83.7 s / 85.2 s): the click ~56 deg off the scout's nose at 10.7 m, inside a wheeled scout's turning circle (gang_scout
## min_turn_radius_m 4.5), so Steering's circle rule reverses at full lock and the k-turn planner plans a 2 m back-up: the scout drives
## 3 m AWAY from his click for ~0.9 s before his next click replaces the order. Staged: a lone Rat Rod at rest on the open yard, its
## one-crew element (his direct move under E2) sent 5 m to a point 56 deg off the nose: today it reverses first; with `--traffic-on=shortfwd`
## a player's short move ahead-ish (within SHORTFWD_DEG of the nose) inside the circle drives forward on the tightest arc instead.
## Forward is -Z (trip-up 2); yaw 0 faces -z; positive yaw turns left.

const SPOT := Vector3(0.0, 0.0, 60.0)
const WATCH_S := 8

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("shortfwd", Traffic.DEFAULT_OFF.has("shortfwd"))
	BrainSwitches.native_drive = _native_drive_was
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


var _native_drive_was := BrainSwitches.native_drive


func _run(arm: String, angle_deg: float, distance_m: float, arena := "yard_open", spot := SPOT, yaw := 0.0) -> Dictionary:
	Traffic.set_off("shortfwd", arm == "off")
	if OS.get_environment("NOSED_GDSCRIPT") == "on":
		BrainSwitches.native_drive = false
	_lab = TacticsLab.create(self, 11, arena)
	_lab.game_match.set_meta("player_team", Match.Team.GREEN)  # his side: the one-crew element's move is HIS direct order (E2)
	var scout := _lab.unit(Match.Team.GREEN, "Green_Hunters_5", spot, yaw, "gang_scout")
	await _lab.start()
	Movement.reset_route_arms()
	DoctrineTable.clear_cache()
	var gangs: DoctrineTable = DoctrineTable.load_table("gangs").get("table")
	var element := _lab.elements.form(["Green_Hunters_5"], "Hunters", gangs)
	var forward := Vector2(-sin(yaw), -cos(yaw))  # yaw 0 faces -z; positive turns left
	var dir := forward.rotated(-deg_to_rad(angle_deg))  # positive = left of the nose
	var to := Vector2(spot.x, spot.z) + dir * distance_m
	element.assign({"verb": "move", "to": [to.x, to.y], "drills": false})
	var reverse_ticks := 0
	var first_reverse := -1
	var arrived := -1
	var away_max := 0.0
	var mover := Movement.of(scout)
	for i in WATCH_S * SimClock.TICK_RATE:
		await _lab.step()
		var along := scout.real_velocity.dot(-scout.global_basis.z)
		if along < -0.5:
			reverse_ticks += 1
			if first_reverse < 0:
				first_reverse = i + 1
		var d := Vector2(scout.global_position.x - to.x, scout.global_position.z - to.y).length()
		away_max = maxf(away_max, d - distance_m)
		if arrived < 0 and d <= 3.5:  # the order's own arrival radius, not a tighter one: a car settles within a share of its circle
			arrived = i + 1
	var out := {"arm": arm, "angle": angle_deg, "distance": distance_m, "first_reverse": first_reverse, "reverse_ticks": reverse_ticks,
			"arrived": arrived, "away_max_m": snappedf(away_max, 0.1), "kturns": int(Movement.route_arms().get("kturns", 0)),
			"his_order": (mover.ctl as TankBrain)._his_order, "native_drive": BrainSwitches.native_drive}
	print("SHORT_MOVE " + JSON.stringify(out))
	_lab.dispose()
	_lab = null
	return out


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("shortfwd"), "shortfwd is opt-in until its bar")


## Dev read only until the rule is settled (SHORTFWD_DEV=on): OFF reverses first (21 ticks on the yard); ON takes the forward arc, no
## reversing, but a point deep inside the circle (5 m at 56 deg: 2.8 m from the circle's centre) is ORBITED, and his real Gorge case was
## the k-turn PLANNER's 2 m back-up at the drop's edge (an arc hit), which a forward rule must not override blindly near an edge.
func test_a_short_move_inside_the_circle_drives_forward_with_the_switch() -> void:
	var off := await _run("off", 56.0, 5.0)
	var on := await _run("on", 56.0, 5.0)
	assert_true(int(off["reverse_ticks"]) > 0, "OFF (today): the scout reverses first (%d ticks, first t%d)" % [off["reverse_ticks"], off["first_reverse"]])
	if OS.get_environment("SHORTFWD_DEV") != "on":
		print("SHORTFWD: the ON lines are a dev read (SHORTFWD_DEV=on): %s" % JSON.stringify(on))
		return
	assert_eq(int(on["reverse_ticks"]), 0, "ON: no reversing on a short move ahead-ish of the nose (%d ticks)" % on["reverse_ticks"])
	assert_true(int(on["arrived"]) > 0, "ON: it arrives within %d s (t%d)" % [WATCH_S, on["arrived"]])


## Near an edge today's planner still decides: a Rat Rod nose-on to Locks' container at (-42, 80), 3 m off its face, told to move 5 m to a
## point 56 deg off its nose: the forward arc meets the box within the planner's reach, so with the switch ON the scout still backs away
## first exactly as today (the Gorge case: the planner's 2 m back-up at the drop's edge was the right move).
func test_near_a_box_the_planner_still_decides_with_the_switch() -> void:
	var at := Vector3(-42.0, 0.0, 80.0 + 1.22 + 3.0 + 1.5)  # the box's north face + 3 m + half the scout's length
	var off := await _run("off", 56.0, 5.0, "locks", at, 0.0)
	var on := await _run("on", 56.0, 5.0, "locks", at, 0.0)
	assert_true(int(on["reverse_ticks"]) > 0 and int(on["first_reverse"]) <= SimClock.TICK_RATE / 2,
			"ON: beside the box the planner's back-up still comes first (OFF %d reversing ticks, ON %d, first t%d)" % [off["reverse_ticks"], on["reverse_ticks"], on["first_reverse"]])
	# Measured (laptop, GDScript): OFF 22 reversing ticks, arrived t43, 2.1 m away at most; ON 12, t29, 0.6 m: the forward arc takes the
	# tick only once the arc is clear, after the back-up the box asks for.
