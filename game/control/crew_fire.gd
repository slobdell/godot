class_name CrewFire
extends RefCounted
## Round 23 (orders O3; contract C23.2). The per-crew read "this crew is being hit by something it cannot return",
## for the readout of a vehicle he holds with H: brains provides
## `UnansweredFire.crew_reason(game_match: Match, unit_name: String) -> String` (UnansweredFire.WHY_HELD while the
## named crew, inside OR outside an element, is under fire it cannot answer; "" otherwise; no cost unless called).
## Until it lands this is the stub the contract names: `reason` reads brains' static when `UnansweredFire` has it,
## and "" when it does not. Tests set `source` to a fake. Nothing here decides anything: the words are brains'.

## A Callable `(game_match: Match, unit_name: String) -> String` standing in for brains' read (tests); invalid =
## brains' own when it exists, else "".
static var source := Callable()
## -1 unknown, 0 brains' `crew_reason` is not on this build, 1 it is.
static var _found := -1


## The words for this crew right now ("" when nothing to say, or nothing to ask yet).
static func reason(game_match: Match, unit_name: String) -> String:
	if source.is_valid():
		return str(source.call(game_match, unit_name))
	if not available():
		return ""
	var script: Script = UnansweredFire  # a static called by name: the class name itself refuses `call`
	return str(script.call("crew_reason", game_match, unit_name))


## Whether brains' per-crew read is on this build (C23.2 landed).
static func available() -> bool:
	if _found < 0:
		_found = 0
		var script: Script = UnansweredFire
		for method: Dictionary in script.get_script_method_list():
			if String(method["name"]) == "crew_reason":
				_found = 1
				break
	return _found == 1
