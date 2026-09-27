class_name MusicHistory
extends RefCounted
## Which tracks were heard, and in what order, across matches, so the soundtrack doesn't open the same way twice.
##
## Round 12 (the lead): *"I can't tell if it's playing the same music over and over on opening — if there are
## comparable moods across tracks … it would be good if we can randomize the selection."* A fair draw from three
## openings repeats the last one a third of the time; he plays one match per launch, so a memory that only lasts a
## process would not help. This keeps a counter per track in `user://music_history.json`: the director picks among
## the tracks heard *least recently*, so every opening comes round before any comes round again (a shuffle bag whose
## order is the match's own dice).
##
## Presentation only, like [AnnouncerHistory]: never read by the simulation, keyed by track id so re-importing a
## better take keeps its place.

const PATH := "user://music_history.json"
const SCHEMA := 1

var path := ""
## How many tracks have been heard in all; each one heard takes the next number.
var serial := 0
## track id -> the serial it was last heard at.
var last := {}


## Loads the memory at `file_path` (an empty one when the file is missing or unreadable).
static func load_from(file_path: String) -> MusicHistory:
	var history := MusicHistory.new()
	history.path = file_path
	if not FileAccess.file_exists(file_path):
		return history
	# A parser instance, not JSON.parse_string: a half-written file must not push an engine error (trip-up 16).
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return history
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY or int(data.get("schema", 0)) != SCHEMA \
			or typeof(data.get("last", null)) != TYPE_DICTIONARY:
		return history
	history.serial = int(data.get("serial", 0))
	for id: Variant in data["last"]:
		history.last[str(id)] = int(data["last"][id])
	return history


## A track started playing.
func heard(track_id: String) -> void:
	serial += 1
	last[track_id] = serial


## When a track was last heard: a larger number is more recent; -1 is never.
func last_heard(track_id: String) -> int:
	return int(last.get(track_id, -1))


func save() -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema": SCHEMA, "serial": serial, "last": last}))
	file.close()
	return true
