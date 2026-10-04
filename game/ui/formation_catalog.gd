class_name FormationCatalog
extends RefCounted
## Round 18 (picker, P1): THE list of formations a player can pick, in one place, for every picker: the play view's
## Formation panel, the tactical map's picker, and G. The set, the order, the name, the tagline and the one-line
## description live here, so a formation can never be in one picker and missing from another. The SHAPE is not here:
## every glyph and preview is drawn from TacticsFormation's geometry (CommandIcons.formation_points), the same slots
## the squads drive to.
##
## The lead (2026-10-04): *"trying to change the formation by way of toggling through button clicks takes too long and
## it's not apparent what the next formation is."*

## AUTO first (the leader picks the shape), then the shapes in the order a player reaches for them.
const ORDER := [UnitCommand.AUTO, "wedge", "line", "column", "vee", "echelon_left", "echelon_right", "coil"]

## What G steps through: the common travelling shapes, a subset of ORDER in the same order. The echelons and coil are
## one click away in the panel; putting them in the cycle would make G eight presses round (decided round 18: G is the
## quick key for the four everyday shapes, the panel is for all of them).
const CYCLE := [UnitCommand.AUTO, "wedge", "line", "column", "vee"]

## Plain-language names, taglines, and one-liners for players who aren't military experts (the lead, round 2):
## [name, tagline, description].
const INFO := {
	UnitCommand.AUTO: ["Auto", "leader decides", "The squad leader picks the shape for the ground and the threat."],
	"column": ["Column", "fast in lanes", "Single file. Quick through narrow gaps; only the leader shoots forward."],
	"wedge": ["Wedge", "all-round", "An arrowhead. Strong in every direction: the best default."],
	"vee": ["Vee", "guns forward", "Leader at the back, flanks forward. Most guns face a known enemy."],
	"line": ["Line", "max firepower", "Side by side. Everyone shoots forward, but the flanks are weak."],
	"echelon_right": ["Echelon R", "guard right", "A diagonal back to the right. Protects the right flank."],
	"echelon_left": ["Echelon L", "guard left", "A diagonal back to the left. Protects the left flank."],
	"coil": ["Coil", "halt, all-round", "A ring facing outward. Stopped and watching every direction."],
}


## Every pickable shape, without AUTO (the tactical map's picker sets a squad's shape, which has no "auto").
static func shapes() -> Array[String]:
	var result: Array[String] = []
	for id: String in ORDER:
		if id != UnitCommand.AUTO:
			result.append(id)
	return result


## {"id", "name", "tagline", "line"} for one formation ({} for an unknown id).
static func card(id: String) -> Dictionary:
	if not INFO.has(id):
		return {}
	var info: Array = INFO[id]
	return {"id": id, "name": String(info[0]), "tagline": String(info[1]), "line": String(info[2])}


## What G picks after `current`. A formation outside the cycle (picked in the panel) steps to the cycle's next one after
## its place in ORDER, so G from an echelon or coil goes back round to AUTO rather than jumping somewhere arbitrary.
static func next_in_cycle(current: String) -> String:
	var at := CYCLE.find(current)
	if at >= 0:
		return CYCLE[(at + 1) % CYCLE.size()]
	var place := ORDER.find(current)
	for id: String in CYCLE:
		if ORDER.find(id) > place:
			return id
	return CYCLE[0]
