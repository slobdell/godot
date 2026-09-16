class_name AnnouncerLibrary
extends RefCounted
## The announcer's line library (assets/announcer/lines.json) and beat grammar (assets/announcer/beats.json).
##
## A line is eligible for a moment when every tag it lists is one of the moment's tags, none of its `without` tags
## are, its slots can all be filled, and its memory `needs` are set. Edges between lines come from tags, not a drawn
## graph (game_design.md "The banter graph"). The format is documented in assets/announcer/README.md.

const LINES_PATH := "res://assets/announcer/lines.json"
const BEATS_PATH := "res://assets/announcer/beats.json"
const SPEAKERS := ["caller", "color", "pa"]
const COUNT_WORDS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
		"eleven", "twelve"]

var lines: Array = []
var by_id := {}
## speaker -> act -> Array of lines.
var by_act := {}
var speakers := {}
## slot vocabulary: slot kind -> value -> spoken text ("team" -> "rust" -> "Rust").
var vocabulary := {}
## moment kind -> {priority, stale_s, cooldown_s, intensity, beats: [{weight, steps}]}
var moments := {}
## Priority and intensity added to a moment per tag it carries (first_blood, upset, ...).
var tag_priority := {}
var tag_intensity := {}
## unit type -> unit types it counters (the roster's good_vs).
var counters := {}
## Seconds of speech per word, per speaker (used until real clip durations exist).
var seconds_per_word := {}
## From a clip manifest, when one is loaded: line id -> {speaker, parts}, and clip id -> seconds.
var manifest_lines := {}
var clip_seconds := {}
## Silence between the clips of one line (tools/announcer/mixdown.py PART_GAP_S).
const PART_GAP_S := 0.02
var kind_tags := PackedStringArray()
var errors := PackedStringArray()


static func load_default() -> AnnouncerLibrary:
	return from_files(LINES_PATH, BEATS_PATH)


static func from_files(lines_path: String, beats_path: String) -> AnnouncerLibrary:
	var library := AnnouncerLibrary.new()
	var lines_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(lines_path))
	var beats_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(beats_path))
	if typeof(lines_data) != TYPE_DICTIONARY:
		library.errors.append("%s is not a JSON object" % lines_path)
		return library
	if typeof(beats_data) != TYPE_DICTIONARY:
		library.errors.append("%s is not a JSON object" % beats_path)
		return library
	library.setup(lines_data, beats_data)
	return library


func setup(lines_data: Dictionary, beats_data: Dictionary) -> void:
	speakers = lines_data.get("speakers", {})
	vocabulary = lines_data.get("vocabulary", {})
	moments = beats_data.get("moments", {})
	counters = beats_data.get("counters", {})
	tag_priority = beats_data.get("tag_priority", {})
	tag_intensity = beats_data.get("tag_intensity", {})
	seconds_per_word = beats_data.get("seconds_per_word", {})
	for kind in moments:
		kind_tags.append(kind)
	for speaker in SPEAKERS:
		by_act[speaker] = {}
	for line in lines_data.get("lines", []):
		var id: String = line.get("id", "")
		if id == "" or by_id.has(id):
			errors.append("line id missing or repeated: '%s'" % id)
			continue
		if not by_act.has(line.get("speaker", "")):
			errors.append("%s: unknown speaker '%s'" % [id, line.get("speaker", "")])
			continue
		line["slots"] = slots_in(line["text"])
		lines.append(line)
		by_id[id] = line
		var acts: Dictionary = by_act[line["speaker"]]
		if not acts.has(line["act"]):
			acts[line["act"]] = []
		acts[line["act"]].append(line)


## The {slot} names in a text, in order.
static func slots_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var start := text.find("{")
	while start >= 0:
		var end := text.find("}", start)
		if end < 0:
			break
		found.append(text.substr(start + 1, end - start - 1))
		start = text.find("{", end)
	return found


## Which vocabulary a slot draws from: {killer_unit} and {victim_unit} speak unit names, {other_team} team names.
static func slot_kind(slot: String) -> String:
	if slot in ["team_s", "other_team_s"]:
		return "team_s"
	if slot in ["team", "other_team"]:
		return "team"
	if slot in ["unit", "killer_unit", "victim_unit", "target_unit", "shooter_unit"]:
		return "unit"
	if slot in ["units", "other_units"]:
		return "units"
	if slot in ["count", "streak", "other_count", "kills"]:
		return "count"
	return slot


## The moment slot a text slot reads: {team_s} ("Rust's") reads the team.
static func base_slot(slot: String) -> String:
	return slot.trim_suffix("_s") if slot in ["team_s", "other_team_s"] else slot


## Spoken text for a slot value, or "" when the vocabulary has none.
func speak(slot: String, value: Variant) -> String:
	var kind := slot_kind(slot)
	if kind == "count":
		var n := int(value)
		return COUNT_WORDS[n] if n >= 0 and n < COUNT_WORDS.size() else ""
	return String(vocabulary.get(kind, {}).get(str(value), ""))


## Candidates for one beat step. `moment` = {kind, tags, slots}; `flags` = memory flags; `used` = line id -> true.
func candidates(speaker: String, acts: Array, moment: Dictionary, flags: Dictionary, topic: String = "") -> Array:
	var found: Array = []
	var tags: Dictionary = moment["tag_set"]
	var acts_of: Dictionary = by_act.get(speaker, {})
	for act in acts:
		for line in acts_of.get(act, []):
			if eligible(line, tags, moment["slots"], flags, topic, float(moment.get("t", INF))):
				found.append(line)
	return found


## `flags` maps flag -> the time it was set; a line only sees flags set before its moment happened (so the same beat
## can't satisfy its own "said it already" check).
func eligible(line: Dictionary, tags: Dictionary, slots: Dictionary, flags: Dictionary, topic: String,
		moment_t: float = INF) -> bool:
	var line_tags: Array = line.get("tags", [])
	var has_kind := false
	for tag in line_tags:
		if tag == "any":
			has_kind = true
			continue
		if not tags.has(tag):
			return false
		if tag in kind_tags:
			has_kind = true
	if not has_kind:
		return false
	for tag in line.get("without", []):
		if tags.has(tag):
			return false
	for slot in line["slots"]:
		var source := base_slot(slot)
		if not slots.has(source) or speak(slot, slots[source]) == "":
			return false
	for flag in line.get("unless_flags", []):
		if flags.has(fill_flag(flag, slots)):
			return false
	for flag in line.get("needs", []):
		var filled := fill_flag(flag, slots)
		if not flags.has(filled) or float(flags[filled]) >= moment_t:
			return false
	if topic != "" and line.has("topic") and line["topic"] != topic and line["topic"] != "any":
		return false
	if topic == "" and line.get("topic", "") != "" and line["act"].begins_with("answer"):
		return false
	return true


## Memory flags may name slots ("warned_friendly_fire_{team}").
func fill_flag(flag: String, slots: Dictionary) -> String:
	for slot in slots_in(flag):
		flag = flag.replace("{%s}" % slot, str(slots.get(slot, "")))
	return flag


## The line's text with slots spoken; a sentence that starts with a slot is capitalized.
func fill(line: Dictionary, slots: Dictionary) -> String:
	var text: String = line["text"]
	for slot in line["slots"]:
		text = text.replace("{%s}" % slot, speak(slot, slots[base_slot(slot)]))
	# A slot that starts a sentence is capitalized ("Two in a row", "Green's tank").
	for index in text.length():
		if index == 0 or (index >= 2 and text[index - 1] == " " and text[index - 2] in [".", "!", "?"]):
			text = text.substr(0, index) + text[index].to_upper() + text.substr(index + 1)
	return text


## Tags on the line that the moment matched, minus kind tags: how specific the pick was.
func specificity(line: Dictionary) -> int:
	var score := 0
	for tag in line.get("tags", []):
		if tag != "any" and not tag in kind_tags:
			score += 1
	return score


## Loads a clip manifest (tools/announcer/generate.py) so lines take as long as their recorded audio. Returns false
## when there is no manifest; estimates stay in use.
func load_manifest(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("%s is not a clip manifest" % path)
		return false
	manifest_lines = data.get("lines", {})
	clip_seconds = {}
	for clip in data.get("clips", {}):
		clip_seconds[clip] = float(data["clips"][clip]["duration_s"])
	return true


## How long a line takes to say with these slot values: its clips' durations when recorded, else an estimate.
func line_seconds(line: Dictionary, slots: Dictionary, text: String) -> float:
	var recorded: Dictionary = manifest_lines.get(line["id"], {})
	if recorded.is_empty():
		return estimate_seconds(line["speaker"], text)
	var total := 0.0
	for part in recorded["parts"]:
		var clip := String(part.get("clip", ""))
		if clip == "":
			var value: Variant = slots.get(base_slot(part["slot"]), "")
			if part["vocab"] == "number":
				value = int(value)
			clip = "fill.%s.%s.%s.%s" % [line["speaker"], part["vocab"], value, part["intonation"]]
		if not clip_seconds.has(clip):
			return estimate_seconds(line["speaker"], text)
		total += float(clip_seconds[clip]) + PART_GAP_S
	return total


## Estimated speaking time for a text (real clip durations replace it once audio exists).
func estimate_seconds(speaker: String, text: String) -> float:
	var words := text.split(" ", false).size()
	var pauses := 0
	for mark in [",", ".", "!", "?", ";", "—"]:
		pauses += text.count(mark)
	return words * float(seconds_per_word.get(speaker, 0.36)) + pauses * 0.12
