extends RefCounted
## CP43.0 (round 43, native): what a replay of a match recording must set before the first tick, read from the recording
## (tests/replay_orders.gd). Pure but for `place`, so tests/replay/test_replay_setup.gd pins it on rows.

## A census position is rounded to 0.1 m (MatchRecorder.census_row): a unit the replay already has within the rounding
## (0.071 m on the diagonal) is left exactly where the layout put it rather than moved by the rounding.
const ROUNDING_M := 0.08


## The match's squad cap and the two factions. A recording that names them (`squad_cap`, `factions` on the `match` row,
## C43.2) is believed; an older one is read from its roster: the squads Green fields (his laptop preset fields four) and
## each side's faction from its first unit's id.
static func from_header(header: Dictionary) -> Dictionary:
	var squads := {}
	var faction := {0: "", 1: ""}
	for unit: Dictionary in header.get("units", []):
		var team := int(unit.get("team", -1))
		if team == 0:
			squads[String(unit.get("name", "")).rsplit("_", true, 1)[0]] = true
		if faction.has(team) and String(faction[team]) == "":
			faction[team] = Units.faction_of(String(unit.get("id", "")))
	var named: Dictionary = header.get("factions", {})
	return {"squad_cap": int(header.get("squad_cap", maxi(1, squads.size()))),
			"player_faction": String(named.get("green", faction[0] if faction[0] != "" else "gangs")),
			"enemy_faction": String(named.get("rust", faction[1] if faction[1] != "" else "syndicate"))}


## Every unit named in `spawn` (name -> [x, z] or [x, z, yaw]) put where the recording had it; returns how many moved.
static func place(game_match: Match, spawn: Dictionary) -> int:
	var moved := 0
	for unit_name: String in spawn:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var at: Array = spawn[unit_name]
		if tank == null or at.size() < 2:
			continue
		var to := Vector3(float(at[0]), tank.global_position.y, float(at[1]))
		var yaw := float(at[2]) if at.size() > 2 else tank.rotation.y
		if Vector2(to.x - tank.global_position.x, to.z - tank.global_position.z).length() <= ROUNDING_M \
				and absf(angle_difference(yaw, tank.rotation.y)) < 0.001:
			continue
		tank.place(to, yaw)
		moved += 1
	return moved


## Switches of his match (the `flags` key, C43.2) that are presentation, input or I/O, or that the replay sets itself:
## never passed on. Everything else (`--attack-shot=off`, `--squad-cap=3`, ...) is, so the replay runs his switches.
const NOT_REPLAYED := ["arena", "seed", "skirmish", "enemy", "player-faction", "enemy-faction", "squad-cap", "pick-faction",
		"no-pick-faction", "hints", "record", "no-record", "record-dir", "perf", "perf-trace", "announcer", "music",
		"camera-readout", "screenshot", "screenshot-delay", "resolution", "orders", "seconds", "spawn", "fullscreen",
		"mute", "garage"]


## The recorded switches the replay passes on, sorted (so the re-run's command line is the same every time).
static func match_switches(header: Dictionary) -> Array:
	var keys: Array = []
	for key: String in header.get("flags", {}):
		if not NOT_REPLAYED.has(key):
			keys.append(key)
	keys.sort()
	return keys


## "" when the replay fields exactly his units (name and unit id, both sides); else the first difference. An army the
## header cannot rebuild (a garage army saved under his user://) shows here rather than as a mysterious divergence.
static func roster_difference(header: Dictionary, game_match: Match) -> String:
	var his := {}
	for unit: Dictionary in header.get("units", []):
		his[String(unit.get("name", ""))] = String(unit.get("id", ""))
	var mine := {}
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank != null:
			mine[String(tank.name)] = String(tank.unit_id)
	return difference(his, mine)


## Pure: the first unit missing on either side or carrying another id, "" when the two rosters are the same.
static func difference(his: Dictionary, mine: Dictionary) -> String:
	var names := his.keys() + mine.keys()
	names.sort()
	for unit_name: String in names:
		if not his.has(unit_name):
			return "%s only in the replay (%d v his %d units)" % [unit_name, mine.size(), his.size()]
		if not mine.has(unit_name):
			return "%s missing from the replay (%d v his %d units)" % [unit_name, mine.size(), his.size()]
		if his[unit_name] != mine[unit_name]:
			return "%s is %s, his was %s" % [unit_name, mine[unit_name], his[unit_name]]
	return ""


## His formation picks in a recording made before they were recorded (round 41's): a Green squad's task in the exact
## shape RtsControls._give_formation gives an idle squad it re-forms where it stands ({verb move, to: the squad's middle,
## drills false, facing: the sum of its hulls' forwards, formation}; no `facing_from`, which a waypoint's task has),
## whose `to` no order of that tick names, is a pick. Returned as `order`-shaped rows
## (verb "formation", `inferred`), to be issued BEFORE that tick's recorded orders: the task rows are scanned once a
## tick, so a pick and the move that carried its shape share a tick and the pick's row is written first.
static func inferred_formations(rows: Array) -> Array:
	var ordered := {}  # tick -> the `to` points his orders named
	for row: Dictionary in rows:
		if row.get("t") == "order":
			if String(row.get("verb", "")) == "formation":
				return []  # this recording holds its picks
			var tick := int(row["tick"])
			if not ordered.has(tick):
				ordered[tick] = []
			if row.has("to"):
				ordered[tick].append(row["to"])
	var out: Array = []
	for row: Dictionary in rows:
		if row.get("t") != "task" or int(row.get("team", -1)) != 0:
			continue
		var task: Dictionary = row.get("task", {})
		if not task.has("formation") or not task.has("facing") or task.has("facing_from") \
				or task.get("drills", true) != false or String(task.get("verb", "")) != "move":
			continue
		var tick := int(row["tick"])
		var units: Array = []
		for unit: Dictionary in _roster(rows):
			if String(unit["name"]).begins_with("Green_%s_" % String(row["element"])):
				units.append(String(unit["name"]))
		if units.is_empty() or (ordered.get(tick, []) as Array).has(task.get("to")):
			continue
		out.append({"t": "order", "tick": tick, "verb": "formation", "units": units, "formation": task["formation"],
				"inferred": true})
	return out


static func _roster(rows: Array) -> Array:
	for row: Dictionary in rows:
		if row.get("t") == "match":
			return row.get("units", [])
	return []


## One click over a selection of several squads is written as one `order` row PER SQUAD (RtsControls tasks each squad
## and signals each), all on one tick with the same verb, point, target and queue. Replayed one squad at a time it is a
## different order (the group click lays the squads out together, an attack shares its target among them), so rows a
## hand could only have given in one click are merged back into one order over the union of their units. Pure.
static func merge_clicks(orders: Array) -> Array:
	var out: Array = []
	for row: Dictionary in orders:
		var last: Dictionary = out[out.size() - 1] if not out.is_empty() else {}
		if not last.is_empty() and String(row.get("verb", "")) != "formation" and _same_click(last, row):
			var units: Array = (last["units"] as Array).duplicate()
			for unit_name in row.get("units", []):
				if not units.has(unit_name):
					units.append(unit_name)
			last["units"] = units
			last["merged"] = int(last.get("merged", 1)) + 1
			if last.has("click") and last.has("to"):
				last["to"] = last["click"]  # C44.2: the point under his cursor; the replay's group layout spreads it again
			continue
		out.append(row.duplicate())
	return out


## Round 44 (C44.2): from G1 v9 on, a group click's rows carry each squad's OWN laid-out point in `to`, so `to` no longer
## says which rows were one click; the `click` key (the ground under his cursor) does, when both rows have it.
static func _same_click(a: Dictionary, b: Dictionary) -> bool:
	var point := "click" if a.has("click") and b.has("click") else "to"
	for key in ["tick", "verb", point, "target", "queue"]:
		if a.get(key) != b.get(key):
			return false
	return String(a.get("error", "")) == "" and String(b.get("error", "")) == ""


## Whether this process's float trig is the correctly rounded one his match ran (native.md *Machine-independent trig*): a
## Godot started by hand on a glibc older than 2.41 (the laptop: 2.39) rounds atan2f & co. 1 ulp off CORE-MATH, while the
## native library carries CORE-MATH inside, so the replay leaves his match within a second (round 43: "a twin gap" at tick 22
## and "a parting at ~28 s" were both this). make preloads the shim (`make trig-info`). The probe is tests/test_native_trig.gd's.
static func trig_is_correctly_rounded() -> bool:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(0, 0xad04f469)
	b.encode_u32(4, 0x73c66291)
	var angle := Vector2(b.decode_float(0), b.decode_float(4)).angle()
	var out := PackedByteArray()
	out.resize(4)
	out.encode_float(0, angle)
	return out.decode_u32(0) == 0x3fc90fdb


## The shim make preloads on an old glibc (.tools/trig/libtank_trig-<sha>.so), "" when there is none.
static func trig_shim() -> String:
	var dir := ProjectSettings.globalize_path("res://.tools/trig")
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("libtank_trig-") and file.ends_with(".so"):
			return dir.path_join(file)
	return ""


## The re-run's command line. Godot keeps its own options out of OS.get_cmdline_args(): `--headless`, `--fixed-fps 30` and
## `--path` never reach it (probe, 4.7.2: `--headless --fixed-fps 30 --path P --script S -- U` reads `["--script", S]`), so a
## re-run built from it alone opened a window on the laptop and could not start on a builder (no display). They go back
## here: headless when this process is, the replay's fixed 30 fps (make replay-match's), this project.
static func reexec_args(engine_args: PackedStringArray, user_args: PackedStringArray, wanted: Array, headless: bool,
		project: String) -> PackedStringArray:
	var args := PackedStringArray()
	if headless and not engine_args.has("--headless"):
		args.append("--headless")
	if not engine_args.has("--fixed-fps"):
		args.append_array(["--fixed-fps", "30"])
	if not engine_args.has("--path"):
		args.append_array(["--path", project])
	args.append_array(engine_args)
	args.append("--")
	args.append_array(user_args)
	for flag: String in wanted:
		args.append(flag)
	return args


# ---- Round 44 (native N2): a match whose seed was not recorded ---------------------------------------------------------
#
# His round-43 playtests ran `--seed=56416.` (a full stop typed after it; `make skirmish` keeps digits only since): the flag
# did not parse, so SkirmishMode rolled both armies from the clock (unix time % 100000), the recorder wrote seed -1, and
# Match's fire RNG (`--seed` from the PROCESS command line, else 0, + 7919) started from 0. A replay matches all three by
# passing his seed TEXT on its command line (every reader of the process's flags falls back exactly as his did) and giving
# the skirmish (Main.next_flags) the army seed found from his roster. His 08-21 match: seed 891, the recorder's second.

## The `--seed` text his match was launched with: the switch as typed when the header has it, else the recorded seed.
static func seed_text(header: Dictionary) -> String:
	var flags: Dictionary = header.get("flags", {})
	return String(flags["seed"]) if flags.has("seed") else str(int(header.get("seed", 0)))


## The roster a skirmish with these settings fields from `seed_value`, name -> unit id, both sides: SkirmishMode._start_match's
## roll (lineup_plan, Army.load_pair, fielded) and Match.load_doctrine's names. Units.max_squads() must already be his preset's
## (the laptop rolls at most 20 vehicles a side: Army.cpu_army's unit cap), so the replay runs with `--render-preset`.
static func rolled_roster(setup: Dictionary, budget: int, seed_value: int, player := "player_default") -> Dictionary:
	var plan := SkirmishMode.lineup_plan(player, "cpu", String(setup["player_faction"]), String(setup["enemy_faction"]), budget)
	var lineups := {Match.Team.GREEN: String(plan[Match.Team.GREEN]["lineup"]), Match.Team.RUST: String(plan[Match.Team.RUST]["lineup"])}
	var armies := Army.load_pair(lineups, {Match.Team.GREEN: String(plan[Match.Team.GREEN]["faction"]),
			Match.Team.RUST: String(plan[Match.Team.RUST]["faction"])}, seed_value, int(plan["budget"]))
	var roster := {}
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var loaded: Dictionary = armies[team]
		if loaded.has("error"):
			return {}
		var doctrine := SkirmishMode.fielded(loaded["doctrine"], team == Match.Team.GREEN, int(setup["squad_cap"]))
		for squad: Dictionary in doctrine["squads"]:
			var index := 1
			for entry: Dictionary in squad["units"]:
				roster["%s_%s_%d" % [Match.TEAM_NAMES[team], squad["name"], index]] = String(entry["unit"])
				index += 1
	return roster


## Clock seeds to try, nearest first. The recorder names its file by the LOCAL time it opened (`2026-10-28T08-21-31`), a
## moment after the roll; the seed is the UTC unix second % 100000. `bias_minutes` is the local zone's offset (his laptop's:
## Time.get_time_zone_from_system()); every other zone follows, so a replay on a builder in UTC still finds it.
static func clock_seeds(recorder_path: String, bias_minutes: int, back_s := 20) -> Array:
	var stamp := recorder_path.get_file().substr(0, 19)
	if stamp.length() < 19 or stamp[10] != "T":
		return []
	var local := Time.get_unix_time_from_datetime_string(stamp.substr(0, 11) + stamp.substr(11).replace("-", ":"))
	var biases: Array = [bias_minutes]
	for minutes in range(-720, 841, 30):
		if minutes != bias_minutes:
			biases.append(minutes)
	var seeds: Array = []
	for minutes: int in biases:
		for back in range(0, back_s + 1):
			var value := posmod(int(local) - minutes * 60 - back, 100000)
			if not seeds.has(value):
				seeds.append(value)
	return seeds


## The army seed that fields exactly his roster (both sides, every name and unit id), -1 when none of `seeds` does.
static func army_seed(header: Dictionary, setup: Dictionary, budget: int, seeds: Array) -> int:
	var his := {}
	for unit: Dictionary in header.get("units", []):
		his[String(unit.get("name", ""))] = String(unit.get("id", ""))
	var player := String(header.get("flags", {}).get("player", "player_default"))
	for value: int in seeds:
		if difference(his, rolled_roster(setup, budget, value, player)) == "":
			return value
	return -1


## Round 44 (native N2): `--click=TICK:X,Z` gives a recording made before C44.2 the click of its group order at TICK: every
## row of that tick carries `click` [X, Z], so merge_clicks replays them as ONE order there (to search his click: the one
## whose replayed layout gives his recorded points). Rows are copied; a malformed spec changes nothing. Pure.
static func with_click(orders: Array, spec: String) -> Array:
	var parts := spec.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int():
		return orders
	var point := parts[1].split(",")
	if point.size() != 2 or not point[0].is_valid_float() or not point[1].is_valid_float():
		return orders
	var out: Array = []
	for row: Dictionary in orders:
		var copy := row.duplicate()
		if int(row.get("tick", -1)) == int(parts[0]):
			copy["click"] = [float(point[0]), float(point[1])]
		out.append(copy)
	return out
