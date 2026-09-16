extends SceneTree
## Announcer command line (no credits, no audio): `make announcer-transcript FIXTURE=comeback SEED=1`.
##
##   --fixture=PATH      a K5 timeline (.jsonl)
##   --seed=N            the director's seed (default 1)
##   --out=PATH_PREFIX   writes PREFIX.txt (the readable transcript) and PREFIX.json (events, cues, decisions)
##   --all=DIR --seeds=1,2 --out-dir=DIR   every fixture in DIR, for each seed
##   --manifest=PATH     a clip manifest: lines last as long as their recorded clips (else estimated)
##   --audit             prints library coverage instead (lines per moment kind, speaker, and act)
## Prints ANNOUNCER_CLI_EXIT=<code> last, so wrappers can find the result among Godot's own output.

const SPEAKER_LABELS := {"caller": "CALLER", "color": "VETERAN", "pa": "PA"}


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var code := _run(args)
	print("ANNOUNCER_CLI_EXIT=%d" % code)
	quit(code)


func _run(args: Dictionary) -> int:
	var library := AnnouncerLibrary.load_default()
	if args.has("manifest") and library.load_manifest(args["manifest"]):
		print("line durations from %s" % args["manifest"])
	if not library.errors.is_empty():
		printerr("library errors:\n  " + "\n  ".join(library.errors))
		return 1
	if args.has("audit"):
		print(coverage(library))
		return 0
	if args.has("all"):
		return _run_all(library, args)
	if not args.has("fixture"):
		printerr("usage: --fixture=PATH [--seed=N] [--out=PREFIX] | --all=DIR --seeds=1,2 --out-dir=DIR | --audit")
		return 2
	return _run_one(library, args["fixture"], int(args.get("seed", "1")), args.get("out", ""))


## Every .jsonl in a folder, for each seed: DIR/<fixture>_seed<N>.txt and .json.
func _run_all(library: AnnouncerLibrary, args: Dictionary) -> int:
	var folder: String = args["all"]
	var names := Array(DirAccess.get_files_at(folder)).filter(func(file: String) -> bool: return file.ends_with(".jsonl"))
	names.sort()
	var seeds := String(args.get("seeds", "1")).split(",")
	for file in names:
		for seed_text in seeds:
			var prefix := "%s/%s_seed%s" % [args.get("out-dir", "build/announcer/transcripts"), file.get_basename(), seed_text]
			var code := _run_one(library, folder.path_join(file), int(seed_text), prefix)
			if code != 0:
				return code
	return 0


func _run_one(library: AnnouncerLibrary, fixture: String, seed_value: int, out: String) -> int:
	var args := {"fixture": fixture, "seed": seed_value}
	if out != "":
		args["out"] = out
	var loaded := AnnouncerEvents.load_file(args["fixture"])
	if loaded["error"] != "":
		printerr(loaded["error"])
		return 1
	var problems := AnnouncerEvents.validate_timeline(loaded["events"])
	if not problems.is_empty():
		printerr("invalid timeline:\n  " + "\n  ".join(problems))
		return 1
	var director := AnnouncerDirector.new(library, seed_value)
	var cues := director.run_timeline(loaded["events"])
	var name := String(args["fixture"]).get_file().get_basename()
	var text := transcript(name, seed_value, loaded["events"], cues, library)
	if args.has("out"):
		var prefix: String = args["out"]
		DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
		_write(prefix + ".txt", text)
		_write(prefix + ".json", JSON.stringify({"fixture": name, "seed": seed_value, "events": loaded["events"],
				"cues": clean_cues(cues), "decisions": director.decisions, "speakers": library.speakers}, "  "))
		print("wrote %s.txt and .json: %d lines" % [prefix, cues.size()])
	else:
		print(text)
	return 0


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


static func clean_cues(cues: Array) -> Array:
	var cleaned: Array = []
	for cue in cues:
		var copy: Dictionary = cue.duplicate()
		copy.erase("_moment")
		cleaned.append(copy)
	return cleaned


static func clock(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


## What happened, in words, for the transcript's margin.
static func describe(event: Dictionary) -> String:
	match String(event["type"]):
		"first_contact":
			return "first contact: %s %s fires on a %s" % [event["team"], event["unit"], event["target_unit"]]
		"unit_destroyed":
			if event["killer"] == "":
				return "%s %s destroyed by a hazard" % [event["victim_team"], event["victim_unit"]]
			if event["friendly"]:
				return "%s %s destroyed by its own %s" % [event["victim_team"], event["victim_unit"], event["killer_unit"]]
			return "%s %s destroys %s %s" % [event["killer_team"], event["killer_unit"], event["victim_team"], event["victim_unit"]]
		"friendly_fire":
			return "friendly fire: %s %s hits its own %s" % [event["team"], event["shooter_unit"], event["victim_unit"]] \
					if not event["killed"] else ""
		"close_call":
			return "close call: %s %s at %d%% hull" % [event["team"], event["unit"], roundi(float(event["hull_left"]) * 100)]
		"control_changed":
			return "control point: %s" % event["owner"]
		"squad_wiped":
			return "%s squad %s wiped out" % [event["team"], event["squad"]]
		"match_end":
			return "MATCH OVER: %s wins by %s (%d green, %d rust left)" % [event["winner"], event["reason"],
					int(event["units_left"]["green"]), int(event["units_left"]["rust"])] \
					if event["winner"] != "draw" else "MATCH OVER: draw"
	return ""


static func transcript(name: String, seed_value: int, events: Array, cues: Array, library: AnnouncerLibrary) -> String:
	var out := PackedStringArray()
	var start: Dictionary = events[0]
	var end: Dictionary = events[-1]
	out.append("TRANSCRIPT: %s (director seed %d)" % [name, seed_value])
	var rosters := PackedStringArray()
	for team in start["teams"]:
		var units := PackedStringArray()
		for unit in team["units"]:
			units.append(unit["unit"])
		rosters.append("%s: %s" % [team["team"], ", ".join(units)])
	out.append("%s | %s" % [library.speak("arena", start["arena"]), " | ".join(rosters)])
	out.append("result: %s by %s at %s" % [end["winner"], end["reason"], clock(float(end["duration_seconds"]))])
	out.append("(── lines are what happened on the floor, for context. Only CALLER, VETERAN, and PA lines are spoken;")
	out.append(" a line ending in — was cut off by something bigger.)")
	out.append("")
	var index := 0
	for cue in cues:
		while index < events.size() and float(events[index]["t"]) <= float(cue["t"]):
			var said := describe(events[index])
			if said != "":
				out.append("%s   ── %s" % [clock(float(events[index]["t"])), said])
			index += 1
		var text: String = cue["text"]
		if cue["cut"]:
			text = _cut_text(text, float(cue["end"]) - float(cue["t"]), float(cue.get("full_seconds", library.estimate_seconds(cue["speaker"], text))))
		out.append("%s   %-8s %s" % [clock(float(cue["t"])), SPEAKER_LABELS[cue["speaker"]], text])
	while index < events.size():
		var said := describe(events[index])
		if said != "":
			out.append("%s   ── %s" % [clock(float(events[index]["t"])), said])
		index += 1
	return "\n".join(out) + "\n"


## A cut line shows the words that fit in the time it was spoken, then a dash.
static func _cut_text(text: String, spoken_s: float, full_s: float) -> String:
	var words := text.split(" ")
	var keep := clampi(int(words.size() * spoken_s / maxf(full_s, 0.01)), 1, words.size())
	return " ".join(words.slice(0, keep)).rstrip(",.!?") + "—"


static func coverage(library: AnnouncerLibrary) -> String:
	var out := PackedStringArray()
	out.append("%d lines" % library.lines.size())
	for speaker in AnnouncerLibrary.SPEAKERS:
		var acts: Dictionary = library.by_act[speaker]
		var parts := PackedStringArray()
		var total := 0
		for act in acts:
			parts.append("%s %d" % [act, acts[act].size()])
			total += acts[act].size()
		out.append("  %-7s %3d: %s" % [speaker, total, ", ".join(parts)])
	var kinds := {}
	for line in library.lines:
		for tag in line.get("tags", []):
			if tag in library.kind_tags or tag == "any":
				kinds[tag] = kinds.get(tag, 0) + 1
	var parts := PackedStringArray()
	for kind in kinds:
		parts.append("%s %d" % [kind, kinds[kind]])
	out.append("  by moment: " + ", ".join(parts))
	return "\n".join(out)
