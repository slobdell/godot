extends TestCase
## Round 30 (native N7.5): ElementFeed's two builders natively (NativeFeed, native/src/feed_native.cpp) against the
## GDScript. Two halves: (1) live elements in a lab fight -- a bounding element moving into an enemy line and a line
## travelling behind it -- every crew of every element read both ways every few frames, each order verb, from the lean
## view and from state(); (2) stub sources that reach every branch the live elements never take (slots as a list or
## bare points, explicit facings, sectors as directions / degrees / junk, named halves and roles, a missing leader /
## id / member list, a source with no state). Equal means the same dictionary: key types and order, value types, values.

const VERBS: Array[String] = ["", "move", "attack_move", "hold", "stop", "fire_at_will"]


## A source shaped by hand: `state()` returns `published` (feed_state too when `lean`), plus optional properties.
class StubElement:
	extends RefCounted
	var published: Variant
	var leader: Variant
	var id: Variant
	var members: Variant
	var heading: Variant

	func _init(state_value: Variant, props := {}) -> void:
		published = state_value
		leader = props.get("leader")
		id = props.get("id")
		members = props.get("members")
		heading = props.get("heading")

	func state() -> Variant:
		return published


## Equal down to types and key order (`==` alone calls 1 equal to 1.0 and ignores a dictionary's order).
static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var ka: Array = (a as Dictionary).keys()
		var kb: Array = (b as Dictionary).keys()
		if not _same(ka, kb):
			return false
		for key: Variant in ka:
			if not _same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is float and is_nan(a):
		return is_nan(b)  # a NaN the source published, handed through: the same value both ways
	return a == b


## Both builders, GDScript then native, from one source; "" when equal, else what differed.
func _compare(element: Object, unit_name: String, verb: String) -> String:
	var was := BrainSwitches.native_feed
	BrainSwitches.native_feed = false
	var shared_gd := ElementFeed._shared(element)
	var ctx_gd := ElementFeed._normalize(element, unit_name, verb)
	var ctx_gd_shared := ElementFeed._normalize(element, unit_name, verb, shared_gd)
	BrainSwitches.native_feed = true
	var shared_n := ElementFeed._shared(element)
	var ctx_n := ElementFeed._normalize(element, unit_name, verb)
	var ctx_n_shared := ElementFeed._normalize(element, unit_name, verb, shared_gd)
	BrainSwitches.native_feed = was
	if not _same(shared_gd, shared_n):
		return "shared: %s v %s" % [var_to_str(shared_gd).left(400), var_to_str(shared_n).left(400)]
	if not _same(ctx_gd, ctx_n):
		return "context: %s v %s" % [var_to_str(ctx_gd).left(400), var_to_str(ctx_n).left(400)]
	if not _same(ctx_gd_shared, ctx_n_shared):
		return "context on a given shared half: %s v %s" % [var_to_str(ctx_gd_shared).left(400),
				var_to_str(ctx_n_shared).left(400)]
	return ""


func test_the_native_feed_builds_live_contexts_as_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the feed equality is not exercised in this run")
		return
	assert_true(NativeFeed.configure(), "the native feed takes the live lists")
	var lab := TacticsLab.create(self, 11, "yard")
	var bounders: Array = []
	var travellers: Array = []
	for i in 5:
		bounders.append(String(lab.unit(Match.Team.GREEN, "Green_B_%d" % (i + 1), Vector3(-24.0 + 12.0 * i, 0.0, 60.0), PI,
				"law_tank").name))
	for i in 3:
		travellers.append(String(lab.unit(Match.Team.GREEN, "Green_T_%d" % (i + 1), Vector3(-12.0 + 12.0 * i, 0.0, 90.0), PI,
				"law_tank").name))
	for i in 3:
		lab.gun(Match.Team.RUST, "Rust_G_%d" % (i + 1), Vector3(-20.0 + 20.0 * i, 0.0, -60.0), 0.0)
	await lab.start()
	var bounding := lab.element(bounders, "Alpha", TacticsLab.table_of("wedge", "bounding_overwatch"))
	var line := lab.element(travellers, "Bravo", TacticsLab.table_of("line", "traveling"))
	bounding.assign({"verb": "move", "to": [0.0, -50.0]})
	line.assign({"verb": "move", "to": [0.0, -20.0], "drills": false})
	var reads := 0
	var mismatches := 0
	var first := ""
	var seen := {"technique": {}, "role": {}, "drill": {}, "station": 0, "facing": 0, "is_leader": 0}
	for frame in 360:
		await lab.step()
		if frame % 3 != 0:
			continue
		for element: Element in lab.elements.all():
			for unit_name: String in element.members():
				for verb in VERBS:
					for lean in [true, false]:
						ElementFeed.FEED_CACHE = lean
						var d := _compare(element, unit_name, verb)
						ElementFeed.FEED_CACHE = true
						reads += 1
						if d != "":
							mismatches += 1
							if first == "":
								first = "frame %d %s %s '%s' lean %s: %s" % [frame, element.element_name, unit_name, verb, lean, d]
				var ctx := ElementFeed.context(lab.elements, unit_name, "move")
				(seen["technique"] as Dictionary)[ctx.get("technique")] = true
				(seen["role"] as Dictionary)[ctx.get("role")] = true
				(seen["drill"] as Dictionary)[ctx.get("drill")] = true
				seen["station"] = int(seen["station"]) + (1 if ctx.get("station") != null else 0)
				seen["facing"] = int(seen["facing"]) + (1 if ctx.get("facing") != null else 0)
				seen["is_leader"] = int(seen["is_leader"]) + (1 if ctx.get("is_leader") else 0)
	ElementFeed.FEED_CACHE = true
	print("native feed (live): %d reads, %d mismatches; seen %s" % [reads, mismatches, seen])
	lab.dispose()
	assert_eq(mismatches, 0, "the native feed builds the live contexts as the GDScript: %s" % first)
	assert_true(reads >= 5000, "a real sample (%d)" % reads)
	assert_true((seen["technique"] as Dictionary).size() >= 2 and (seen["role"] as Dictionary).size() >= 2,
			"more than one technique and role read (%s)" % seen)
	assert_true(int(seen["facing"]) > 0 and int(seen["is_leader"]) > 0, "sectors and leaders read (%s)" % seen)


func test_the_native_feed_reads_every_shape_a_source_may_publish_as_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the feed equality is not exercised in this run")
		return
	assert_true(NativeFeed.configure(), "the native feed takes the live lists")
	var base := {"id": 7, "leader": "a", "members": ["c", "a", "b"], "task": {"verb": "move", "to": [1, 2]},
			"formation": "wedge", "technique": "bounding_overwatch", "drill": "", "pitch": [12.5, 9],
			"heading": [0.0, -1.0], "slots": {"a": Vector3(1, 2, 3), "b": {"position": [4, 5], "role": "overwatch"},
			"c": {"position": Vector2(6, 7), "facing": [1, 1]}}, "sectors": {"a": 45, "b": -90.0, "c": 0},
			"pace": {"a": 0.5, "b": 3, "c": -1.0}, "stations": {"a": [1.5, 2.5], "b": Vector3(1, 1, 1)},
			"transit": {"velocity": Vector3(2, 9, -3)}, "relocating": true}
	var variants: Array = [
		{},
		{"members": PackedStringArray(["b", "a"]), "slots": [Vector3(1, 0, 1), {"position": [2, 2]}, "junk"]},
		{"members": null, "slots": {"b": [1, 2, 3], "a": "nowhere"}},
		{"members": null, "slots": null},
		{"leader": null, "id": null, "relocating": 1, "pace": "fast"},
		{"leader": "", "technique": "traveling", "drill": "support_by_fire", "task": "support_by_fire"},
		{"technique": "traveling", "drill": "support_by_fire", "moving": ["a", "c"]},
		{"maneuver": PackedStringArray(["b"]), "technique": "traveling_overwatch"},
		{"moving": "a", "roles": {"a": "bound", "b": "nonsense", "c": "base_of_fire"}},
		{"task": "attack", "drill": "react_to_contact", "technique": "made_up", "formation": 3},
		{"task": null, "verb": "screen"},
		{"task": {"verb": 5}, "pitch": [1, 2, 3], "transit": {"speed": 4}},
		{"pitch": PackedFloat32Array([1, 2]), "transit": "moving", "stations": "none"},
		{"sectors": {"a": NAN, "b": INF, "c": [0.0, 0.0]}, "heading": [0.0, 0.0]},
		{"sectors": {"a": 30, "b": Vector2(0.0, 2.0), "c": 180}, "heading": null},
		{"sectors": {"a": 120.5, "b": 359, "c": -45}, "heading": Vector3(3, 1, 4)},
		{"slots": {"a": {"position": [1, 2], "facing": [0.0, 0.0]}, "b": {"facing": Vector2(-1, 0)}, "c": 7}},
		{"id": "alpha", "leader": 4, "members": [1, 2, "a"]},
	]
	var props_list: Array = [{}, {"leader": "b", "id": 99, "members": ["z", "y"], "heading": Vector3(1, 0, 0)}]
	var cases := 0
	var mismatches := 0
	var first := ""
	for slide_off in [false, true]:
		Traffic._parsed = true
		if slide_off:
			Traffic._off["slide"] = true
		else:
			Traffic._off.erase("slide")
		for variant: Dictionary in variants:
			for props: Dictionary in props_list:
				var state := base.duplicate(true)
				state.merge(variant, true)
				for key: String in variant:
					if variant[key] == null and key in ["members", "slots", "leader", "id", "task", "heading"]:
						state.erase(key)
				var element := StubElement.new(state, props)
				for unit_name: String in ["a", "b", "c", "x", "1"]:
					for verb in VERBS:
						var d := _compare(element, unit_name, verb)
						cases += 1
						if d != "":
							mismatches += 1
							if first == "":
								first = "variant %s props %s unit %s verb '%s' slide_off %s: %s" % [variant, props,
										unit_name, verb, slide_off, d]
		# No state at all, or not a dictionary: {} both ways.
		for published: Variant in [null, [1, 2], "state"]:
			var d := _compare(StubElement.new(published), "a", "move")
			cases += 1
			if d != "":
				mismatches += 1
				if first == "":
					first = "published %s: %s" % [published, d]
	Traffic._off.erase("slide")
	Traffic._parsed = false
	print("native feed (shapes): %d cases, %d mismatches" % [cases, mismatches])
	assert_eq(mismatches, 0, "the native feed reads every shape as the GDScript: %s" % first)
	assert_true(cases >= 2000, "every case ran (%d)" % cases)
