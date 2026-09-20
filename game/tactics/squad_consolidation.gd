class_name SquadConsolidation
extends RefCounted
## Round 8 (the lead): *"not all units belong to a squad. There seem to be orphaned units that don't get selected at all
## when I cycle through the numbers on my keyboard."* The army generator splits each unit type into squads of at most
## five (Spears, Spears2, Spears3, Spears4 of one scout), so a faction army at the baseline budget came out as 6-11
## squads (gangs 11, condemned 9, law 6), and the player's selection gestures reach squads 1-5: everything past the fifth
## was unreachable from his seat — disobedient by definition. tests/test_every_unit_selectable.gd asserts the absence.
##
## The PLAYER's army is folded into at most MAX_SQUADS squads before it spawns, so the squads, the elements formed from
## them, control groups 1-5 and the tactical map's keys are one list. Pure: a doctrine in, a doctrine out.
##   1. A family (a name and its numbered overflow: Spears, Spears2, ...) is one squad: the unit type the player knows.
##   2. While there are still too many, the smallest squad joins the smallest one of the same directive role (else the
##      smallest of any), in doctrine order.
##   3. While there are fewer than MAX_SQUADS and one has more than SPLIT_OVER units, the largest splits in two ("Eyes",
##      "Eyes II"): condemned folded into two squads of ~21, which is an army, not a squad.
## The CPU's armies are left alone: its elements are formed per squad and many small ones suit its commander.

const MAX_SQUADS := 5
const SPLIT_OVER := 8


static func for_player(doctrine: Dictionary, max_squads := MAX_SQUADS) -> Dictionary:
	var result := doctrine.duplicate(true)
	var squads: Array = []
	var by_family := {}
	for squad: Dictionary in doctrine.get("squads", []):
		var family := family_of(String(squad.get("name", "")))
		if by_family.has(family):
			((by_family[family] as Dictionary)["units"] as Array).append_array((squad["units"] as Array).duplicate(true))
			continue
		var kept := squad.duplicate(true)
		kept["name"] = family
		by_family[family] = kept
		squads.append(kept)
	while squads.size() > max_squads:
		var smallest := _smallest(squads, -1, "")
		var role := String((squads[smallest] as Dictionary).get("directive", {}).get("role", ""))
		var into := _smallest(squads, smallest, role)
		if into < 0:
			into = _smallest(squads, smallest, "")
		((squads[into] as Dictionary)["units"] as Array).append_array((squads[smallest] as Dictionary)["units"])
		squads.remove_at(smallest)
	while squads.size() < max_squads:
		var largest := -1
		for i in squads.size():
			var size := ((squads[i] as Dictionary)["units"] as Array).size()
			if size > SPLIT_OVER and (largest < 0 or size > ((squads[largest] as Dictionary)["units"] as Array).size()):
				largest = i
		if largest < 0:
			break
		var whole: Dictionary = squads[largest]
		var units: Array = whole["units"]
		var half := units.size() / 2
		var second := whole.duplicate(true)
		second["units"] = units.slice(units.size() - half)
		whole["units"] = units.slice(0, units.size() - half)
		second["name"] = _unused_name(squads, String(whole["name"]))
		squads.insert(largest + 1, second)
	result["squads"] = squads
	return result


## "Eyes II", or "Eyes III" if that is taken.
static func _unused_name(squads: Array, base: String) -> String:
	var taken := {}
	for squad: Dictionary in squads:
		taken[String(squad["name"])] = true
	for numeral: String in ["II", "III", "IV", "V", "VI"]:
		if not taken.has("%s %s" % [base, numeral]):
			return "%s %s" % [base, numeral]
	return "%s %d" % [base, squads.size() + 1]


## "Spears3" -> "Spears"; a name that is all digits, or has none, is its own family.
static func family_of(name: String) -> String:
	var end := name.length()
	while end > 1 and name[end - 1] >= "0" and name[end - 1] <= "9":
		end -= 1
	return name.substr(0, end)


## Index of the squad with the fewest units (earliest on a tie), skipping `except`, of directive `role` unless "".
static func _smallest(squads: Array, except: int, role: String) -> int:
	var best := -1
	for i in squads.size():
		if i == except:
			continue
		var squad: Dictionary = squads[i]
		if role != "" and String(squad.get("directive", {}).get("role", "")) != role:
			continue
		if best < 0 or (squad["units"] as Array).size() < ((squads[best] as Dictionary)["units"] as Array).size():
			best = i
	return best
