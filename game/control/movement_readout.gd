class_name MovementReadout
extends RefCounted
## Control X5 (round 6): orders you can see landing. A unit that is *yielding* to a friend or *blocked* must say so on
## the HUD instead of looking idle (the lead, round 5: the units "aren't very responsive"; a unit that acknowledges and
## explains itself feels responsive even when it takes a second to move).
##
## The facts come from nav's N1 contract, `Movement.state(unit) -> {"phase": "pathing" | "driving" | "yielding" |
## "blocked" | "arrived", "eta_s", "remaining_m", "path_points", "blocked_by"}`. Until nav's CP1 is on `main` there is
## no Movement to ask, so `provider` is a Callable (unit name -> that Dictionary) that the mode wires to Movement when it
## exists; with none, every read is {} and nothing is drawn. This file is the whole seam: when CP1 lands, only
## `from_movement()` changes, if its call shape differs from the contract's.

## Phases the HUD calls out over a vehicle, with the word it shows. `driving`, `pathing` and `arrived` are what a
## player expects of an order and need no words.
const CALLOUTS := {"yielding": "YIELDING", "blocked": "BLOCKED"}
## ETAs longer than this aren't shown ("arrives in 40 s" is noise; the waypoint line already says it's far).
const ETA_SHOWN_MAX_S := 30.0

## unit name -> N1 state Dictionary; invalid = no movement system to ask.
var provider := Callable()


## The provider for nav's N1 Movement API when the class exists (CP1), else an invalid Callable. The class is looked up
## by name, so this compiles on a branch where nav has not merged yet.
static func from_movement(game_match: Node) -> Callable:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) != "Movement":
			continue
		var script := load(String(entry["path"])) as Script
		if script == null:
			return Callable()
		return func(unit_name: String) -> Dictionary:
			var tank: Node = (game_match.get("tanks") as Node).get_node_or_null(NodePath(unit_name)) if game_match != null else null
			if tank == null:
				return {}
			var reading: Variant = script.call("state", tank)
			return reading if reading is Dictionary else {}
	return Callable()


func state(unit_name: String) -> Dictionary:
	if not provider.is_valid():
		return {}
	var reading: Variant = provider.call(unit_name)
	return reading if reading is Dictionary else {}


## The word to float over a vehicle ("" = nothing to say).
func callout(unit_name: String) -> String:
	return String(CALLOUTS.get(String(state(unit_name).get("phase", "")), ""))


## One line for the unit card: "Blocked by Green_Alpha_2", "Giving way", "Arrives in 4 s", or "".
func card_line(unit_name: String, describe_unit: Callable = Callable()) -> String:
	var reading := state(unit_name)
	match String(reading.get("phase", "")):
		"blocked":
			var by := String(reading.get("blocked_by", ""))
			if by == "":
				return "Blocked"
			return "Blocked by %s" % (describe_unit.call(by) if describe_unit.is_valid() else by)
		"yielding":
			return "Giving way to a friend"
		"pathing", "driving":
			var eta := float(reading.get("eta_s", -1.0))
			if eta >= 0.0 and eta <= ETA_SHOWN_MAX_S:
				return "Arrives in %d s" % maxi(1, roundi(eta))
	return ""
