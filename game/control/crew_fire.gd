class_name CrewFire
extends RefCounted
## Round 23 (orders O3; contract C23.2). The per-crew read "this crew is being hit by something it cannot return",
## for the readout of a vehicle he holds with H: brains' `UnansweredFire.crew_reason(game_match, unit_name)`
## (UnansweredFire.WHY_HELD while the named crew, inside OR outside an element, is under fire it cannot answer by B1's
## own test for at least its grace; "" otherwise; no cost unless called). This is orders' one seam to it: the readout
## asks here, tests put a fake in `source`, and nothing here decides anything: the words are brains'.

## A Callable `(game_match: Match, unit_name: String) -> String` standing in for brains' read (tests); invalid = brains'.
static var source := Callable()


## The words for this crew right now ("" when nothing to say).
static func reason(game_match: Match, unit_name: String) -> String:
	if source.is_valid():
		return str(source.call(game_match, unit_name))
	return UnansweredFire.crew_reason(game_match, unit_name)
