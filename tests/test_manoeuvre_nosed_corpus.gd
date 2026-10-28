extends TestCase
## Round 44 (Bar B1's deciding corpus, R44's condition: "one start is too thin to decide on"): STAGED NOSE-ON POSES. A War Rig placed
## with its nose NOSE_GAP_M from a container's long face, facing the box, ordered to a point 80 m away at 20-60 deg off its nose, in two
## shapes: `crawl` (his deploy: four squadmates beside and behind it, the element's centre behind it, so its first station crawls) and
## `alone` (a one-crew element: the far seat is its steering point from the first tick). Two arenas' containers. Each pose runs OFF
## and ON (`--traffic-on=backout`) and prints one NOSED_ROW a run (read by tests/manoeuvre/nosed_judge.py): the first tick the rig's
## centre stands CLEAR_M from its spot, the first reversing tick, the metres crept forward before it. Opt-in (NOSED_CORPUS=on in the
## environment: 2 x POSES labs of a baked arena each, minutes on a builder); the only assertion is that every pose produced both rows.
## Forward is -Z (trip-up 2); yaw 0 faces -z; positive yaw turns left.

const NOSE_GAP_M := 2.0
const RIG_HALF_M := 7.0
const CLEAR_M := 8.0
const WATCH_S := 12
const ORDER_M := 80.0
## [arena, container centre, container rotation deg, box half depth, which side of the box the rig stands on (+1 = its local +z
## side), the shape, the order's angle off the nose (deg, positive = left)]
const POSES := [
	["locks", Vector2(-42.0, 80.0), 5.0, 1.22, 1, "crawl", -45.0],    # his
	["locks", Vector2(-42.0, 80.0), 5.0, 1.22, 1, "alone", -25.0],
	["locks", Vector2(-42.0, 80.0), 5.0, 1.22, 1, "alone", 45.0],
	["locks", Vector2(-30.0, 66.0), 357.0, 1.22, 1, "alone", -30.0],
	["locks", Vector2(-30.0, 66.0), 357.0, 1.22, 1, "alone", 60.0],
	["locks", Vector2(-120.0, 16.0), 2.0, 1.22, 1, "alone", -40.0],
	["locks", Vector2(-120.0, 16.0), 2.0, 1.22, 1, "crawl", 60.0],
	["crossing", Vector2(0.0, 40.0), 3.0, 1.22, 1, "crawl", 45.0],
	["crossing", Vector2(0.0, 40.0), 3.0, 1.22, 1, "alone", -20.0],
	["crossing", Vector2(-69.0, 36.0), 357.0, 1.22, 1, "alone", -35.0],
	["crossing", Vector2(-69.0, 36.0), 357.0, 1.22, 1, "crawl", 50.0],
	["crossing", Vector2(30.0, 4.0), 357.0, 1.22, -1, "alone", -45.0],
	["crossing", Vector2(30.0, 4.0), 357.0, 1.22, -1, "crawl", -30.0],
	["crossing", Vector2(24.0, 11.0), 355.0, 1.22, 1, "alone", 55.0],
]
## The crawl shape's squadmates in the rig's frame (x: right, z: behind), his deploy around Guns_2.
const CRAWL_MATES := [Vector2(-8.0, 1.0), Vector2(5.0, 1.0), Vector2(-5.0, 15.0), Vector2(1.5, 15.0)]
## Bar B1's FRESH poses (NOSED_SEED=<n> in the environment): every pose jittered from the seed, the same in both arms: the spot
## +/- JITTER_ALONG_M along the box face, the nose gap NOSE_GAP_M +/- JITTER_GAP_M, the nose JITTER_YAW_DEG either way off square, the
## order's angle +/- JITTER_ANGLE_DEG. Unset: the 14 dev poses as listed (read already; never a bar).
const JITTER_ALONG_M := 3.0
const JITTER_GAP_M := 0.5
const JITTER_YAW_DEG := 5.0
const JITTER_ANGLE_DEG := 5.0

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("backout", Traffic.DEFAULT_OFF.has("backout"))
	BrainSwitches.native_drive = _native_drive_was
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## The rig's spot and yaw for a pose: on the box's `side`, its nose NOSE_GAP_M from the face, facing the face; `jitter` = [along m,
## gap m, yaw deg, angle deg] from the seed (zeros for the dev poses).
static func rig_pose(pose: Array, jitter: Array = [0.0, 0.0, 0.0, 0.0]) -> Array:
	var centre: Vector2 = pose[1]
	var rot := deg_to_rad(float(pose[2]))
	var half_depth := float(pose[3])
	var side := float(pose[4])
	# The box's local +z axis in world (its depth axis), rotated like ArenaKit's footprint; its long axis is +x rotated the same.
	var axis := Vector2(-sin(rot), cos(rot)) * side
	var along := Vector2(cos(rot), sin(rot))
	var spot := centre + axis * (half_depth + NOSE_GAP_M + float(jitter[1]) + RIG_HALF_M) + along * float(jitter[0])
	var forward := (-axis).rotated(deg_to_rad(float(jitter[2])))  # facing the box, a few degrees off square when jittered
	var yaw := atan2(-forward.x, -forward.y)  # yaw 0 faces -z; positive turns left
	return [Vector3(spot.x, 0.0, spot.y), yaw, forward]


## A pose's jitter from NOSED_SEED (one RandomNumberGenerator per pose, seeded by seed * 100 + pose: the same in both arms).
static func jitter_of(pose_id: int) -> Array:
	var seed_text := OS.get_environment("NOSED_SEED")
	if seed_text == "":
		return [0.0, 0.0, 0.0, 0.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_text) * 100 + pose_id
	return [rng.randf_range(-JITTER_ALONG_M, JITTER_ALONG_M), rng.randf_range(-JITTER_GAP_M, JITTER_GAP_M),
			rng.randf_range(-JITTER_YAW_DEG, JITTER_YAW_DEG), rng.randf_range(-JITTER_ANGLE_DEG, JITTER_ANGLE_DEG)]


var _native_drive_was := BrainSwitches.native_drive


func _run(pose_id: int, pose: Array, arm: String) -> Dictionary:
	Traffic.set_off("backout", arm == "off")
	if OS.get_environment("NOSED_GDSCRIPT") == "on":
		BrainSwitches.native_drive = false  # a dev read of a GDScript change before native's twin follows it
	_lab = TacticsLab.create(self, 7, String(pose[0]))
	var jitter := jitter_of(pose_id)
	var rp := rig_pose(pose, jitter)
	var spot: Vector3 = rp[0]
	var yaw: float = rp[1]
	var forward: Vector2 = rp[2]
	var right := Vector2(-forward.y, forward.x)
	var rig := _lab.unit(Match.Team.GREEN, "Green_Guns_1", spot, yaw, "gang_tank")
	var names := ["Green_Guns_1"]
	if String(pose[5]) == "crawl":
		for i in CRAWL_MATES.size():
			var o: Vector2 = CRAWL_MATES[i]
			var at := Vector2(spot.x, spot.z) + right * o.x - forward * o.y
			_lab.unit(Match.Team.GREEN, "Green_Guns_%d" % (i + 2), Vector3(at.x, 0.0, at.y), yaw, "gang_tank")
			names.append("Green_Guns_%d" % (i + 2))
	await _lab.start()
	Movement.reset_route_arms()
	DoctrineTable.clear_cache()
	var gangs: DoctrineTable = DoctrineTable.load_table("gangs").get("table")
	var element := _lab.elements.form(names, "Guns", gangs)
	var angle := deg_to_rad(float(pose[6]) + float(jitter[3]))
	var dir := forward.rotated(-angle)  # positive = left of the nose (yaw's sense)
	var to := Vector2(spot.x, spot.z) + dir * ORDER_M
	to = Vector2(clampf(to.x, -125.0, 125.0), clampf(to.y, -125.0, 125.0))
	element.assign({"verb": "move", "to": [to.x, to.y], "drills": false})
	var first_reverse := -1
	var cleared := -1
	var crept := 0.0
	var nose0 := -rig.global_basis.z
	# The pose's own numbers (the same in both arms): the navmesh run past the nose (the rule's nose test) and the route's departure
	# angle (the first vertex of the rig's route to the order a hull's length out, off the nose).
	var mover := Movement.of(rig)
	var frame: Array = mover._kturn_frame(rig)
	var nose_room := Movement._free_run(rig.get_world_3d().navigation_map, rig.global_position + nose0 * float(frame[1]),
			Vector3(nose0.x, 0.0, nose0.z).normalized(), float(frame[2]))
	var depart_deg := 0.0
	for point in Pathing.find_path(rig, rig.global_position, Vector3(to.x, 0.0, to.y)):
		if Vector2(point.x - spot.x, point.z - spot.z).length() >= float(frame[1]) * 2.0:
			depart_deg = rad_to_deg(Vector3(nose0.x, 0.0, nose0.z).signed_angle_to(Vector3(point.x - spot.x, 0.0, point.z - spot.z), Vector3.UP))
			break
	for i in WATCH_S * SimClock.TICK_RATE:
		await _lab.step()
		var along := rig.real_velocity.dot(-rig.global_basis.z)
		if first_reverse < 0 and along < -0.5:
			first_reverse = i + 1
		if first_reverse < 0:
			crept = maxf(crept, (rig.global_position - spot).dot(nose0))
		if Vector2(rig.global_position.x - spot.x, rig.global_position.z - spot.z).length() >= CLEAR_M:
			cleared = i + 1
			break
	var row := {"pose": pose_id, "arena": pose[0], "shape": pose[5], "angle": pose[6], "arm": arm, "clear_tick": cleared,
			"seed": OS.get_environment("NOSED_SEED"), "jitter": [snappedf(jitter[0], 0.1), snappedf(jitter[1], 0.1), snappedf(jitter[2], 0.1), snappedf(jitter[3], 0.1)],
			"first_reverse": first_reverse, "crept_m": snappedf(crept, 0.01), "looks": int(Movement.route_arms().get("backout_looks", 0)),
			"kturns": int(Movement.route_arms().get("kturns", 0)),
			"nose_room_m": snappedf(nose_room, 0.1), "depart_deg": snappedf(depart_deg, 1.0), "native_drive": BrainSwitches.native_drive}
	print("NOSED_ROW " + JSON.stringify(row))
	_lab.dispose()
	_lab = null
	return row


func test_the_staged_nose_on_corpus_runs_both_arms() -> void:
	if OS.get_environment("NOSED_CORPUS") != "on":
		print("NOSED_CORPUS: skipped (NOSED_CORPUS=on runs the %d poses in both arms)" % POSES.size())
		return
	var rows := 0
	for i in POSES.size():
		for arm in ["off", "on"]:
			var row := await _run(i, POSES[i], arm)
			rows += 1
			assert_true(int(row["clear_tick"]) != 0, "pose %d %s produced a row" % [i, arm])
	assert_eq(rows, POSES.size() * 2, "every pose ran in both arms")
