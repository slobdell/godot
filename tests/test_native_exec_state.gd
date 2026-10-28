extends TestCase
## Round 27 (native, stage 1 E1): the execute state OWNED by the C++ (native/src/exec_state.h, ExecState). Every script
## member of a crew's Movement, Gunnery and Engagement.Lay is a typed C++ field (one table, native/src/exec_fields.h);
## the C++ copies it from the GDScript (pull) and back (push: every field, or only those it changed). Proven here:
## (1) the table IS the scripts' member list (a member an owner adds or retypes fails this test until the table follows);
## (2) in a real fight the pull reads what the GDScript reads, bit for bit; (3) a push puts back exactly what was pulled
## after every member was scrambled (containers by identity); (4) a changed-only push writes exactly what changed.

const MATCH := preload("res://game/match/match.tscn")
## Gunnery's getters that forward the controller's own members: not state.
const FORWARDERS: Array[String] = ["tank", "tanks_root", "weapon_order", "move_order", "_step"]
const PREFIX: Array[String] = ["m:", "g:", "l:"]
## Variant.Type -> the C++ type the table declares it with (the line printed for a member the table lacks).
const CTYPES := {TYPE_BOOL: "bool", TYPE_INT: "int64_t", TYPE_FLOAT: "double", TYPE_STRING: "String",
		TYPE_VECTOR2: "Vector2", TYPE_VECTOR3: "Vector3", TYPE_STRING_NAME: "StringName", TYPE_RID: "RID",
		TYPE_DICTIONARY: "Dictionary", TYPE_ARRAY: "Array", TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
		TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array", TYPE_NIL: "Variant", TYPE_OBJECT: "Variant",
		TYPE_CALLABLE: "Callable"}
const VTYPES := {TYPE_BOOL: "BOOL", TYPE_INT: "INT", TYPE_FLOAT: "FLOAT", TYPE_STRING: "STRING", TYPE_VECTOR2: "VECTOR2",
		TYPE_VECTOR3: "VECTOR3", TYPE_STRING_NAME: "STRING_NAME", TYPE_RID: "RID", TYPE_DICTIONARY: "DICTIONARY",
		TYPE_ARRAY: "ARRAY", TYPE_PACKED_FLOAT32_ARRAY: "PACKED_FLOAT32_ARRAY",
		TYPE_PACKED_VECTOR3_ARRAY: "PACKED_VECTOR3_ARRAY", TYPE_NIL: "NIL", TYPE_OBJECT: "OBJECT",
		TYPE_CALLABLE: "CALLABLE"}


## [owner, name, Variant.Type] of every script member that is state, in declaration order.
static func _members(object: Object, owner: int) -> Array:
	var out := []
	for prop: Dictionary in object.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if owner == 1 and FORWARDERS.has(String(prop["name"])):
			continue
		out.append([owner, String(prop["name"]), int(prop["type"])])
	return out


static func _owners(mover: Movement) -> Array:
	return [mover, mover.ctl.gunnery, mover.ctl.gunnery.engagement_lay]


## The table's LATE rows (exec_fields.h) the scripts don't declare: [owner, name] -> true. CP42.0: a member an owner asked
## for lands in the table before the member lands on main; until then it is skipped everywhere below.
static func _absent_late(table: Array, live: Array) -> Dictionary:
	var names := {}
	for row: Array in live:
		names[[row[0], row[1]]] = true
	var out := {}
	for row: Array in NativeBridge.impl.exec_late_fields():
		assert(table.has(row), "a late row is a table row")
		if not names.has([row[0], row[1]]):
			out[[row[0], row[1]]] = true
	return out


static func _live_members(ctl: OrderController) -> Array:
	return _members(ctl.movement, 0) + _members(ctl.gunnery, 1) + _members(ctl.gunnery.engagement_lay, 2)


## The table less its absent late rows (the fields every test below compares).
static func _present(table: Array) -> Array:
	var ctl := OrderController.new()
	var absent := _absent_late(table, _live_members(ctl))
	ctl.free()
	return table.filter(func(row: Array) -> bool: return not absent.has([row[0], row[1]]))


static func _same(live: Variant, held: Variant) -> bool:
	if typeof(live) != typeof(held):
		return false
	if live is Array or live is Dictionary:
		return is_same(live, held)  # the struct holds the very container
	if live is Object:
		return is_same(live, held)
	return live == held


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func _fight() -> Match:
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	await wait_physics_frames(2)
	return game_match


static func _movers(game_match: Match) -> Array[Movement]:
	var out: Array[Movement] = []
	for node in game_match.tanks.get_children():
		var mover := Movement.of(node)
		if mover != null and mover.ctl != null and mover.ctl.gunnery != null:
			out.append(mover)
	return out


func test_the_table_is_the_scripts_members() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the execute state is not exercised in this run")
		return
	var ctl := OrderController.new()
	var live := _live_members(ctl)
	ctl.free()
	var table: Array = NativeBridge.impl.exec_fields()
	var absent := _absent_late(table, live)
	var missing: Array[String] = []
	var extra: Array[String] = []
	for row: Array in live:
		if not table.has(row):
			var type: int = row[2]
			missing.append("owner %d: F(%s, %s, %s)" % [row[0], CTYPES.get(type, "?"), VTYPES.get(type, "?"), row[1]])
	for row: Array in table:
		if not live.has(row) and not absent.has([row[0], row[1]]):
			extra.append("owner %d: %s (type %d)" % [row[0], row[1], row[2]])
	print("native exec state: %d fields in the table (%d late, not declared yet), %d script members" % [table.size(),
			absent.size(), live.size()])
	assert_true(missing.is_empty(), "add to native/src/exec_fields.h: %s" % ", ".join(missing))
	assert_true(extra.is_empty(), "no longer in the scripts (remove or retype in exec_fields.h): %s" % ", ".join(extra))
	assert_eq(table.size(), live.size() + absent.size(), "one field per member (and per late member not declared yet)")


func test_the_pull_reads_what_the_gdscript_reads() -> void:
	if NativeExpect.absent(self):
		return
	var native: Object = NativeBridge.impl
	native.exec_clear()
	var game_match := await _fight()
	var table := _present(native.exec_fields())
	var pulls := 0
	var compared := 0
	var mismatches := 0
	var non_default := {}
	var first := ""
	for frame in 360:
		await wait_physics_frames(1)
		if frame % 12 != 11:
			continue
		for mover in _movers(game_match):
			assert_eq(int(native.exec_pull(mover)), 0, "every member had its declared type")
			pulls += 1
			var row: Dictionary = native.exec_row(mover)
			var owners := _owners(mover)
			for field: Array in table:
				var key: String = PREFIX[field[0]] + String(field[1])
				var live: Variant = (owners[field[0]] as Object).get(field[1])
				compared += 1
				if not _same(live, row[key]):
					mismatches += 1
					if first == "":
						first = "frame %d %s %s: live %s v native %s" % [frame, mover.ctl.tank.name, key, live, row[key]]
				non_default[key] = true
	print("native exec state: %d pulls, %d values compared, %d mismatches" % [pulls, compared, mismatches])
	assert_eq(mismatches, 0, "the pull is the GDScript's read: %s" % first)
	assert_true(pulls >= 400 and compared >= 400 * 140, "a real sample (%d pulls, %d values)" % [pulls, compared])
	assert_eq(int(native.exec_count()), _movers(game_match).size(), "one state per mover")
	native.exec_clear()


func test_a_push_after_a_scramble_restores_every_member() -> void:
	if NativeExpect.absent(self):
		return
	var native: Object = NativeBridge.impl
	native.exec_clear()
	var game_match := await _fight()
	var table := _present(native.exec_fields())
	var checks := 0
	var scrambled := 0
	var unrestored := 0
	var first := ""
	for frame in 240:
		await wait_physics_frames(1)
		if frame % 20 != 19:
			continue
		for mover in _movers(game_match):
			var owners := _owners(mover)
			var before := {}
			for field: Array in table:
				before[PREFIX[field[0]] + String(field[1])] = (owners[field[0]] as Object).get(field[1])
			assert_eq(int(native.exec_pull(mover)), 0, "pulled cleanly")
			var changed: int = native.exec_scramble(mover)
			scrambled += changed
			var differs := 0
			for field: Array in table:
				var key: String = PREFIX[field[0]] + String(field[1])
				if not _same((owners[field[0]] as Object).get(field[1]), before[key]):
					differs += 1
			assert_eq(differs, changed, "the scramble changed what it says it changed")
			assert_eq(int(native.exec_push(mover, true)), table.size(), "a forced push writes every field")
			for field: Array in table:
				var key: String = PREFIX[field[0]] + String(field[1])
				checks += 1
				if not _same((owners[field[0]] as Object).get(field[1]), before[key]):
					unrestored += 1
					if first == "":
						first = "%s %s: was %s, now %s" % [mover.ctl.tank.name, key, before[key],
								(owners[field[0]] as Object).get(field[1])]
	print("native exec state: %d members checked after scramble + push, %d scrambled, %d not restored" % [checks,
			scrambled, unrestored])
	assert_eq(unrestored, 0, "push restores exactly: %s" % first)
	assert_true(scrambled >= checks / 2, "the scramble changed most members (%d of %d)" % [scrambled, checks])
	native.exec_clear()


func test_a_changed_only_push_writes_exactly_the_changed_fields() -> void:
	if NativeExpect.absent(self):
		return
	var native: Object = NativeBridge.impl
	native.exec_clear()
	var game_match := await _fight()
	await wait_physics_frames(30)
	var mover: Movement = _movers(game_match)[0]
	assert_eq(int(native.exec_pull(mover)), 0, "pulled")
	assert_eq(int(native.exec_dirty(mover)), 0, "a pull leaves nothing to push")
	assert_eq(int(native.exec_push(mover, false)), 0, "and pushes nothing")
	var lay := mover.ctl.gunnery.engagement_lay
	var path := PackedVector3Array([Vector3(1, 0, 2), Vector3(3, 0, 4)])
	assert_true(native.exec_set(mover, "m:stalled_ticks", mover.stalled_ticks + 5), "set an int")
	assert_true(native.exec_set(mover, "m:phase", "test-phase"), "set a String")
	assert_true(native.exec_set(mover, "m:_path", path), "set a packed array")
	assert_true(native.exec_set(mover, "m:last_replan", &"test"), "set a StringName")
	assert_true(native.exec_set(mover, "g:lane_blocker", "nobody"), "set a gunnery member")
	assert_true(native.exec_set(mover, "l:progress", 0.625), "set a lay member")
	assert_true(not native.exec_set(mover, "m:no_such_member", 1), "an unknown key is refused")
	assert_eq(int(native.exec_dirty(mover)), 6, "six dirty fields")
	var stalled_before := mover.stalled_ticks
	var goal_before := mover._goal
	assert_eq(int(native.exec_push(mover, false)), 6, "a changed-only push writes the six")
	assert_eq(mover.stalled_ticks, stalled_before + 5, "the int")
	assert_eq(mover.phase, "test-phase", "the String")
	assert_eq(mover._path, path, "the packed array")
	assert_eq(mover.last_replan, &"test", "the StringName")
	assert_eq(mover.ctl.gunnery.lane_blocker, "nobody", "the gunnery member")
	assert_eq(lay.progress, 0.625, "the lay member")
	assert_eq(mover._goal, goal_before, "an unchanged field is untouched")
	assert_eq(int(native.exec_dirty(mover)), 0, "the push cleared the dirty bits")
	native.exec_clear()


## CP42.0: a late member is skipped while the script lacks it and checked like any other once declared. The declared case
## runs on a Movement subclass that adds the late members (or on Movement itself once its owner has landed them).
## A late member's value of its type: 0 its declared default, 1 the value set before the pull, 2 the value pushed. Round 44: the
## backout members (manoeuvre M2) are the first late Vector3 and bool ones.
static func _late_value(type: int, which: int) -> Variant:
	match type:
		TYPE_STRING:
			return ["", "q5-friend", "pushed"][which]
		TYPE_BOOL:
			return [false, true, false][which]
		TYPE_FLOAT:
			return [-1.0, 42.5, 7.5][which]
		TYPE_VECTOR3:
			return [Vector3.ZERO, Vector3(4, 2, 4.5), Vector3(7, -1, 0.25)][which]
	return [-1, 4242, 7][which]


func test_a_late_member_is_skipped_until_declared_then_mirrored() -> void:
	if NativeExpect.absent(self):
		return
	var native: Object = NativeBridge.impl
	native.exec_clear()
	var late: Array = native.exec_late_fields()
	assert_true(late.size() >= 1, "the table has late members (Q5's four)")
	var mover_fields: int = native.exec_fields().filter(func(row: Array) -> bool: return int(row[0]) == 0).size()
	var plain := Movement.new()  # no controller: only the Movement's own members are pulled and pushed
	var absent := late.filter(func(row: Array) -> bool: return not (String(row[1]) in plain))
	if not absent.is_empty():
		assert_eq(int(native.exec_pull(plain)), 0, "a pull of a script without the late members is clean")
		assert_eq(int(native.exec_push(plain, true)), mover_fields - absent.size(),
				"a forced push skips the late members the script lacks")
		native.exec_forget(plain)
	var source := "extends Movement\n"
	for row: Array in absent:
		source += "var %s := %s\n" % [row[1], var_to_str(_late_value(int(row[2]), 0))]
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "the declaring subclass compiles")
	var mover: Movement = script.new()
	for row: Array in late:
		mover.set(row[1], _late_value(int(row[2]), 1))
	assert_eq(int(native.exec_pull(mover)), 0, "declared: the pull reads the late members with their types")
	var row: Dictionary = native.exec_row(mover)
	for field: Array in late:
		assert_eq(row["m:" + String(field[1])], mover.get(field[1]), "declared: %s pulled" % field[1])
	assert_eq(int(native.exec_push(mover, true)), mover_fields, "declared: a forced push writes every field")
	for field: Array in late:
		assert_true(native.exec_set(mover, "m:" + String(field[1]), _late_value(int(field[2]), 2)),
				"set %s" % field[1])
	assert_eq(int(native.exec_push(mover, false)), late.size(), "declared: a changed-only push writes the late members")
	for field: Array in late:
		assert_eq(mover.get(field[1]), _late_value(int(field[2]), 2), "declared: %s pushed" % field[1])
	native.exec_forget(mover)
	native.exec_clear()
