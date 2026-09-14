class_name CommandReplay
extends RefCounted
## Lockstep-style replay for the deterministic core: a match IS its command log. A replay file
## holds the log plus the state hash at every checkpoint, so replaying it both re-creates the match
## and proves the simulation (or the file) wasn't changed: the "server replays the log to see who
## diverged" step of the lockstep design (_agents/streams/references/netcode_designs.md).
##
## File (JSON): {"version": 1, "tanks": N, "ticks": T, "seed": S, "commands": [[tick, tank, throttle, turn], ...],
##               "checkpoints": {"300": "hash", ...}, "hash": "final hash"}

const VERSION := 1


static func save(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	return OK


## {"error": String} or the replay with integer commands.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "no replay at %s" % path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
		return {"error": "%s is not a version %d replay" % [path, VERSION]}
	var commands: Array = []
	for entry in parsed.get("commands", []):
		if not entry is Array or entry.size() != 4:
			return {"error": "malformed command %s" % [entry]}
		# JSON numbers parse as floats; the simulation must only ever see ints.
		commands.append([int(entry[0]), int(entry[1]), clampi(int(entry[2]), -127, 127), clampi(int(entry[3]), -127, 127)])
	parsed["commands"] = commands
	parsed["tanks"] = int(parsed.get("tanks", 0))
	parsed["ticks"] = int(parsed.get("ticks", 0))
	return parsed
