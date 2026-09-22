class_name AnnouncerHistory
extends RefCounted
## What the booth said in *earlier* matches, so it doesn't open the same way every night.
##
## The director's own anti-repetition (`_used`) only lasts one match, which is why the lead heard the same welcome
## from the PA across several matches (brief X1). This keeps the last [constant DEPTH] matches' line ids in
## `user://announcer_history.json` and hands the director a weight multiplier per line: a line heard last match is
## ~30× less likely than a fresh one, which is enough to lose to a slightly less specific line but not to a much
## less specific one (the director's specificity weighting is 8× per matched tag).
##
## Presentation only. It is never read by the simulation, and it is keyed by line id, so re-recording audio for a
## line keeps its history.

const PATH := "user://announcer_history.json"
const SCHEMA := 1
## How many past matches are remembered; older ones are forgotten entirely. The caller's and the Veteran's lines use
## only the last [constant PENALTY].size() of them; the PA's use them all (see [method weight]).
const DEPTH := 40
## Weight multiplier by how many matches ago a line was last heard (index 0 = the match just before this one).
## Measured against the brief's target (an opener heard again within five matches under ~10%): the first four
## entries sum to 0.44, so with N equally good lines the chance of repeating one of the last four is about
## 0.44 / (N - 4), which needs roughly a dozen lines per slot rather than the ten the PA had.
const PENALTY := [0.02, 0.05, 0.12, 0.25, 0.45, 0.65, 0.82, 0.92]
## C9 (round 10, research brief 3): the PA's one wrong detail is remembered across sessions, not minutes: a second
## hearing is a 100 % repeat. Her lines fade back over an evening of matches instead (never faster than [constant
## PENALTY]): 0.02 last match, 0.28 five matches ago, 0.6 after twelve, 0.85 after twenty-four.
const PA_FADE_MATCHES := 12.0
const PA_FLOOR := 0.02

## Oldest first; each entry is an Array of line ids.
var matches: Array = []
var path := ""

## line id -> matches ago (1 = the previous match). Rebuilt whenever `matches` changes.
var _ago := {}


## Loads the history at `file_path` (an empty one when the file is missing or unreadable).
static func load_from(file_path: String) -> AnnouncerHistory:
	var history := AnnouncerHistory.new()
	history.path = file_path
	if not FileAccess.file_exists(file_path):
		return history
	# A parser instance, not JSON.parse_string: this file is user data and can be half-written or hand-edited, and
	# the static call pushes an engine error for malformed text (which the test runner treats as a failure, and a
	# player would see in the log). A memory we can't read is simply a booth with no past.
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return history
	var data: Variant = parser.data
	if typeof(data) == TYPE_DICTIONARY and int(data.get("schema", 0)) == SCHEMA:
		for entry in data.get("matches", []):
			if typeof(entry) == TYPE_ARRAY:
				history.matches.append(Array(entry))
	history._reindex()
	return history


## Adds the lines of a finished match and drops anything past DEPTH.
func remember(line_ids: Array) -> void:
	matches.append(line_ids.duplicate())
	while matches.size() > DEPTH:
		matches.pop_front()
	_reindex()


func save() -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema": SCHEMA, "matches": matches}))
	file.close()
	return true


## How many matches ago this line was last heard: 1 = the previous match, 0 = never within DEPTH.
func matches_ago(line_id: String) -> int:
	return int(_ago.get(line_id, 0))


## What to multiply a line's chance by tonight.
func weight(line_id: String) -> float:
	var ago := matches_ago(line_id)
	if ago <= 0:
		return 1.0
	var recent := 1.0 if ago > PENALTY.size() else float(PENALTY[ago - 1])
	if line_id.begins_with("pa."):
		# Never weaker than everybody's curve in the last few matches (that is what stops two nights opening alike),
		# and still held back long after the others are forgotten.
		return minf(recent, maxf(PA_FLOOR, 1.0 - exp(-float(ago - 1) / PA_FADE_MATCHES)))
	return recent


func _reindex() -> void:
	_ago = {}
	for index in matches.size():
		var ago := matches.size() - index
		for id in matches[index]:
			# The most recent use wins (the loop runs oldest first).
			_ago[id] = ago
