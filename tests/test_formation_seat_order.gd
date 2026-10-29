extends TestCase
## Round 44 (manoeuvre, Bar S v4's candidate; `--seat-order=on`, OFF until judged): a plain move's seats are dealt in the crews' own
## left-to-right order across the heading, so a crew never takes a seat across a squadmate's path. Bar S v3's Locks cells: the eastern
## crew of a two-row deploy block was dealt the westmost seat of a 35 m shape by least total driving and crossed two squadmates on the
## way in. Pure: TacticsFormation.seat on a line laid 30 m ahead at an angle, five crews in two rows. Forward is -Z.

const SPACING := 8.0

var _was := TacticsFormation.SEAT_ORDER


func teardown() -> void:
	TacticsFormation.SEAT_ORDER = _was
	super.teardown()


## Five crews in two rows at the origin facing -z; the shape's anchor 30 m ahead and 12 m to the LEFT (the move bends left), its
## five seats a line abreast across the heading (x: right), 8 m apart: the rightmost crew is nearest the LEFT seats by the
## straight line only when the shape sits far enough left, which is the crossing the rule removes.
func _members() -> Array:
	var out: Array = []
	var spots := [Vector3(-8.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(-5.0, 0.0, 12.0), Vector3(1.0, 0.0, 12.0)]
	for i in 5:
		out.append({"name": "Crew_%d" % i, "position": spots[i], "unit": "gang_tank", "role": Units.role_of("gang_tank")})
	return out


static func _offsets() -> Array[Vector2]:
	var o: Array[Vector2] = []
	for j in 5:
		o.append(Vector2((j - 2) * SPACING, 0.0))
	return o


## The seating's lateral order v the crews' own, ACROSS THE HEADING (the rule's frame): a crossing = a crew left of another whose
## seat is right of the other's.
static func crossings(seating: Dictionary, members: Array, offsets: Array[Vector2], anchor: Vector3, heading: Vector3) -> int:
	var fwd := TacticsFormation.flat(heading)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var n := 0
	for a: Dictionary in members:
		for b: Dictionary in members:
			if a["name"] == b["name"]:
				continue
			var la := ((a["position"] as Vector3) - anchor).dot(right)
			var lb := ((b["position"] as Vector3) - anchor).dot(right)
			var sa := (TacticsFormation.to_world(anchor, heading, offsets[int(seating[a["name"]])]) - anchor).dot(right)
			var sb := (TacticsFormation.to_world(anchor, heading, offsets[int(seating[b["name"]])]) - anchor).dot(right)
			if la < lb - 1.0 and not (sa < sb):  # two crews within a metre laterally have no order worth the name
				n += 1
	return n


func test_off_by_default() -> void:
	assert_true(not TacticsFormation.SEAT_ORDER or OS.get_cmdline_user_args().has("--seat-order=on"), "opt-in until Bar S v4")


func test_seats_follow_the_crews_lateral_order() -> void:
	# Twenty seeded stages: two rows of crews with jittered spots, a swarm-like shape (lateral, along) laid 25-45 m ahead and up to
	# 25 m to a side, the heading turned up to 60 deg. ON never crosses; OFF crosses on some (the rule is exercised).
	var offsets: Array[Vector2] = [Vector2(-16.0, 0.0), Vector2(-8.0, -10.0), Vector2(0.0, 0.0), Vector2(8.0, -10.0), Vector2(16.0, 0.0)]
	var rng := RandomNumberGenerator.new()
	var plain_crossings := 0
	var ordered_crossings := 0
	var stages_crossing := 0
	for stage in 20:
		rng.seed = 4400 + stage
		var members: Array = []
		var spots := [Vector3(-8.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(-5.0, 0.0, 12.0), Vector3(1.0, 0.0, 12.0)]
		for i in 5:
			var spot: Vector3 = spots[i] + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
			members.append({"name": "Crew_%d" % i, "position": spot, "unit": "gang_tank", "role": Units.role_of("gang_tank")})
		var turn := deg_to_rad(rng.randf_range(-60.0, 60.0))
		var heading := Vector3(-sin(turn), 0.0, -cos(turn))
		var anchor := Vector3(rng.randf_range(-25.0, 25.0), 0.0, -rng.randf_range(25.0, 45.0))
		var opts := {"policy": "travel", "spacing": SPACING, "seat_order": true}
		TacticsFormation.SEAT_ORDER = false
		var plain: Dictionary = TacticsFormation.seat(members, offsets, anchor, heading, opts)
		TacticsFormation.SEAT_ORDER = true
		var ordered: Dictionary = TacticsFormation.seat(members, offsets, anchor, heading, opts)
		var not_asked: Dictionary = TacticsFormation.seat(members, offsets, anchor, heading, {"policy": "travel", "spacing": SPACING})
		var pc := crossings(plain, members, offsets, anchor, heading)
		var oc := crossings(ordered, members, offsets, anchor, heading)
		plain_crossings += pc
		ordered_crossings += oc
		if pc > 0:
			stages_crossing += 1
		assert_eq(oc, 0, "stage %d: ON, no crew takes a seat across a squadmate (plain had %d crossings)" % [stage, pc])
		assert_eq(not_asked, plain, "stage %d: ON without `seat_order` (a halt, a group's squad) is today's seating" % stage)
	print("SEAT_ORDER_STAGE 20 stages: plain crossings %d on %d stages, ordered %d" % [plain_crossings, stages_crossing, ordered_crossings])
	assert_true(stages_crossing >= 1, "least total driving crosses on some stage (%d), so the rule is exercised" % stages_crossing)
