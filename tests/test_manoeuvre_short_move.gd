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


func _run(arm: String, angle_deg: float, distance_m: float, arena := "yard_open", spot := SPOT, yaw := 0.0, goal := Vector2.INF) -> Dictionary:
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
	if goal != Vector2.INF:  # round 46 (M5): his recorded click, absolute
		to = goal
		distance_m = to.distance_to(Vector2(spot.x, spot.z))
		angle_deg = rad_to_deg(forward.angle_to(to - Vector2(spot.x, spot.z))) * -1.0
	var map: RID = scout.get_world_3d().navigation_map
	var off_mesh_max := 0.0
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
		var flat_at := Vector3(scout.global_position.x, 0.0, scout.global_position.z)
		var on_mesh := NavigationServer3D.map_get_closest_point(map, flat_at)
		off_mesh_max = maxf(off_mesh_max, Vector2(on_mesh.x - flat_at.x, on_mesh.z - flat_at.z).length())
		if arrived < 0 and d <= 3.5:  # the order's own arrival radius, not a tighter one: a car settles within a share of its circle
			arrived = i + 1
	var out := {"arm": arm, "angle": angle_deg, "distance": distance_m, "first_reverse": first_reverse, "reverse_ticks": reverse_ticks,
			"arrived": arrived, "away_max_m": snappedf(away_max, 0.1), "kturns": int(Movement.route_arms().get("kturns", 0)),
			"his_order": (mover.ctl as TankBrain)._his_order, "native_drive": BrainSwitches.native_drive,
			"off_mesh_max_m": snappedf(off_mesh_max, 0.01), "shortfwd_ticks": Movement.shortfwd_ticks}
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


## Round 46 (M5): HIS GORGE SHORT MOVES AS A STAGED CORPUS (Bar shortfwd's workload; opt-in: SHORT_CORPUS=on, SHORT_SEEDS=a-b). The lone
## scout's seven move orders in his Gorge game (2026-10-29, seed 91711), posed from `make replay-match ... REPLAY_FLAGS=--trace=2505-3080`
## (builder3, round 46): where the scout stood, its yaw and his click. The lab stages each at REST (the trace's speeds were 0-15 m/s).
## Seed s runs pose (s - a) mod 7, jittered by s (+/- 1 m, +/- 20 deg of yaw, the click +/- 1.5 m), both arms; one SHORT_MOVE row a run
## with "pose" and "seed" (read by tests/manoeuvre/short_judge.py). Poses 0 and 2 are inside the rule's reach (3 circles, 100 deg).
const GORGE_POSES := [
	[Vector3(-45.4, 0.0, 37.5), 119.0, Vector2(-39.7, 47.5)],   # 83.7 s: 11.5 m, 91 deg left (engage's E5 case)
	[Vector3(-46.2, 0.0, 35.0), -152.0, Vector2(-44.0, 51.6)],  # 85.2 s: 16.7 m, 21 deg right
	[Vector3(-43.8, 0.0, 45.9), 178.0, Vector2(-50.8, 56.1)],   # 87.0 s: 12.4 m, 32 deg right
	[Vector3(-56.1, 0.0, 59.3), 80.0, Vector2(-55.9, 73.1)],    # 88.8 s: 13.8 m, 101 deg left
	[Vector3(-57.5, 0.0, 80.7), 161.0, Vector2(-50.4, 72.7)],   # 91.8 s: 10.7 m, 158 deg left
	[Vector3(-47.6, 0.0, 70.0), 6.0, Vector2(-35.2, 43.2)],     # 94.6 s: 29.5 m, 31 deg right
	[Vector3(-59.8, 0.0, 12.0), -4.0, Vector2(-47.1, 31.1)],    # 102.6 s: 22.9 m, 143 deg right
]


func test_his_gorge_short_moves_corpus() -> void:
	if OS.get_environment("SHORT_CORPUS") != "on":
		print("SHORT_CORPUS: skipped (SHORT_CORPUS=on SHORT_SEEDS=a-b runs his Gorge poses in both arms)")
		return
	var parts := OS.get_environment("SHORT_SEEDS").split("-")
	var only := OS.get_environment("SHORT_ONLY")
	for s in range(int(parts[0]), int(parts[parts.size() - 1]) + 1):
		if only != "" and int(only) != s:
			continue
		var pose_i := (s - int(parts[0])) % GORGE_POSES.size()
		var pose: Array = GORGE_POSES[pose_i]
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var spot: Vector3 = pose[0] + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		var yaw := deg_to_rad(float(pose[1]) + rng.randf_range(-20.0, 20.0))
		var goal: Vector2 = pose[2] + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		for arm in ["off", "on"]:
			Movement.shortfwd_ticks = 0
			var row := await _run(arm, 0.0, 0.0, "gorge", spot, yaw, goal)
			print("SHORT_ROW " + JSON.stringify({"pose": pose_i, "seed": s, "arm": arm, "row": row}))
			assert_true(int(row["arrived"]) != 0, "pose %d seed %d %s produced a row" % [pose_i, s, arm])
