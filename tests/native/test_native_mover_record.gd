extends TestCase
## Round 26 (perf, stage-1 groundwork for round 27): the execute state gathered by the C++ (TankNative.mover_record_*,
## native/src/mover_record.cpp; OFF by default, nothing in the game calls it) equals the GDScript's own read of every
## fixed-type member of each crew's Movement, Gunnery and Engagement.Lay, bit for bit, in a real fight on the Sumps.
## The field list comes from the live scripts, so a member an owner adds is covered without editing this file.

const MATCH := preload("res://game/match/match.tscn")
const KINDS := [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR3]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


static func _fields(object: Object, owner: int) -> Array:
	var out := []
	for prop: Dictionary in object.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and KINDS.has(int(prop["type"])):
			out.append([owner, String(prop["name"]), int(prop["type"])])
	return out


func test_the_native_gather_reads_what_the_gdscript_reads() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the mover record is not exercised in this run")
		return
	var native: Object = NativeBridge.impl
	assert_true(not native.mover_record_is_on(), "the mover record ships OFF")
	assert_eq(native.mover_record_gather(null, {}), -1, "OFF: the gather does nothing")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	await wait_physics_frames(2)
	var sample: Movement = null
	for node in game_match.tanks.get_children():
		sample = Movement.of(node)
		if sample != null:
			break
	assert_true(sample != null and sample.ctl.gunnery != null, "a crew with a mover and a gunnery")
	var spec := _fields(sample, 0) + _fields(sample.ctl.gunnery, 1) + _fields(sample.ctl.gunnery.engagement_lay, 2)
	var accepted: int = native.mover_record_configure(spec)
	assert_eq(accepted, spec.size(), "every fixed-type member is a column (rejected: %s)" % native.mover_record_rejected())
	native.mover_record_set_on(true)
	var gathers := 0
	var rows := 0
	var compared := 0
	var mismatches := 0
	var usec := 0
	var first := ""
	for frame in 360:
		await wait_physics_frames(1)
		if frame % 12 != 11:
			continue
		var n: int = native.mover_record_gather(game_match.tanks, Movement._registry)
		gathers += 1
		usec += int(native.mover_record_usec())
		assert_eq(int(native.mover_record_mismatches()), 0, "every member had its declared type")
		for r in n:
			var row: Dictionary = native.mover_record_row(r)
			var tank := game_match.tanks.get_node_or_null(NodePath(String(row["name"]))) as Tank
			var mover := Movement.of(tank)
			if mover == null:
				continue
			rows += 1
			var owners: Array = [mover, mover.ctl.gunnery, mover.ctl.gunnery.engagement_lay]
			for field: Array in spec:
				var live: Variant = (owners[field[0]] as Object).get(field[1])
				if live is StringName:
					live = String(live)
				var key: String = ["m:", "g:", "l:"][field[0]] + String(field[1])
				compared += 1
				if typeof(live) != typeof(row[key]) or live != row[key]:
					mismatches += 1
					if first == "":
						first = "frame %d %s %s: live %s v native %s" % [frame, tank.name, key, var_to_str(live), var_to_str(row[key])]
	native.mover_record_set_on(false)
	print("native mover record: %d fields, %d gathers, %d rows, %d values compared, %d mismatches, %.1f us a gather" % [
			spec.size(), gathers, rows, compared, mismatches, float(usec) / maxi(gathers, 1)])
	assert_eq(mismatches, 0, "the native gather is the GDScript's read: %s" % first)
	assert_true(gathers >= 25 and rows >= 400 and spec.size() >= 50, "a real sample (%d gathers, %d rows, %d fields)" % [gathers, rows, spec.size()])
