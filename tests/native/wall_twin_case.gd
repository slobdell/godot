class_name WallTwinCase
extends TestCase
## Round 29 (native N7.4): WallContact.observe with its scan native (NativeWall, native/src/wall_native.cpp) against the
## GDScript, from the same state. A brain-driven fight on the Sumps (walls, packed squads, hulls pressing each other);
## after every physics frame, each crew's observe runs twice from one snapshot of the observer (its fields, every static
## counter, the episode table and log, the give-way / k-turn / circle records it writes): the GDScript, then the
## native scan. Everything it wrote must be equal; then the snapshot goes back (the game's own observe already ran).
## Round 32 (native, C32.8): split into test_native_wall and test_native_wall_odd: each file plays the whole fight and
## compares every crew on every `parts`-th frame, staggered by crew (`(frame + index) % parts`); this base holds the case,
## its body unchanged but for that and the sample floor divided by `parts`. Not by crew: which crews meet walls is the
## fight's to decide, and with manoeuvre's H1b ON the even crews met 8 wall ticks where the odd met 554 (the branch floor
## failed on a fight that matched). Wall contacts last many frames, so alternate frames split every branch evenly.

const MATCH := preload("res://game/match/match.tscn")
const FIELDS: Array[String] = ["touching", "cause", "driver", "collider", "lane", "count", "mine_by_cause", "point",
		"normal", "decided"]
const STATICS: Array[String] = ["observed", "ticks", "by_cause", "by_driver", "by_gear", "by_driver_gear",
		"by_reverse_why", "by_unit", "by_lane", "hull_ticks", "log", "episodes", "plant_kind", "by_cause_collider"]
const RECORDS: Array[String] = ["_yield_rec", "_kturn_rec", "_circle_rec"]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


static func _copy(v: Variant) -> Variant:
	return v.duplicate(true) if v is Dictionary or v is Array else v


static func _capture(mover: Movement) -> Dictionary:
	var out := {}
	for name in FIELDS:
		out["f:" + name] = _copy(mover.contact.get(name))
	for name in STATICS:
		out["s:" + name] = _copy(mover.contact.get(name))
	for name in RECORDS:
		out["r:" + name] = _copy(mover.get(name))
	return out


## Put the snapshot back: the records' contents in place (the owned execute state shares those Dictionaries).
static func _restore(mover: Movement, snap: Dictionary) -> void:
	for name in FIELDS:
		mover.contact.set(name, _copy(snap["f:" + name]))
	for name in STATICS:
		mover.contact.set(name, _copy(snap["s:" + name]))
	for name in RECORDS:
		var rec: Dictionary = mover.get(name)
		rec.clear()
		rec.merge(_copy(snap["r:" + name]))
	mover.native_stale |= Movement.STALE_ALL


static func _diff(a: Dictionary, b: Dictionary) -> String:
	for key: String in a:
		if typeof(a[key]) != typeof(b[key]) or a[key] != b[key]:
			return "%s: %s v %s" % [key, str(a[key]).left(300), str(b[key]).left(300)]
	return ""


## Compares each crew on the frames where `frame + its node index` is `part` mod `parts`; the rest play uncompared.
func _scan_case(part: int, parts: int) -> void:
	if not NativeBridge.available:
		print("native: absent, the wall scan equality is not exercised in this run")
		return
	assert_true(NativeWall.configure(), "the native scan takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var was := BrainSwitches.native_wall
	var observes := 0
	var not_observed := 0
	var walls := 0
	var hulls := 0
	var mismatches := 0
	var first := ""
	for frame in 600:
		await wait_physics_frames(1)
		for node in game_match.tanks.get_children():
			var mover := Movement.of(node)
			if mover == null or mover.ctl == null or (frame + node.get_index()) % parts != part:
				continue
			var start := _capture(mover)
			BrainSwitches.native_wall = false
			mover.contact.observe(mover)
			var live := _capture(mover)
			_restore(mover, start)
			BrainSwitches.native_wall = true
			mover.contact.observe(mover)
			var native := _capture(mover)
			_restore(mover, start)
			observes += 1
			if int(live["s:observed"]) == int(start["s:observed"]):
				not_observed += 1
			if bool(live["f:touching"]):
				walls += 1
			if int(live["s:hull_ticks"]) > int(start["s:hull_ticks"]):
				hulls += 1
			var d := _diff(live, native)
			if d != "":
				mismatches += 1
				if first == "":
					first = "frame %d %s: %s" % [frame, node.name, d]
	BrainSwitches.native_wall = was
	print("native wall: %d observes (%d with no slide to read, %d wall ticks, %d hull ticks), %d mismatches" % [observes,
			not_observed, walls, hulls, mismatches])
	assert_eq(mismatches, 0, "the native scan observes as the GDScript: %s" % first)
	assert_true(observes * parts >= 6000, "a real sample (%d; 6000 over every crew)" % observes)
	assert_true(walls >= 20 and hulls >= 20 and not_observed >= 20, "every branch taken (walls %d, hulls %d, none %d)" % [
			walls, hulls, not_observed])
