class_name Challenges
extends RefCounted
## Stretch: challenge missions. Each is a fixed army against a scripted opponent that teaches ONE counter
## ("IFVs shred scouts"), played from the army builder's CHALLENGES panel. The first win pays a one-time
## reward; replays pay nothing (so a solved puzzle can't be farmed), and the lesson shows on the results screen.
##
## Armies are army JSON v2 (contract C2), written by unit ROLE so they survive catalog changes: "units" lists
## roles, resolved to the catalog's unit for that role (every unit, locked or not: a challenge is also a preview).
## Opponent squads carry no formation (a doctrine formation means "hold", orientation trip-up #53); they move by
## directive and objective (team-relative meters from the arena center; forward = toward the player).

const REWARD := 150

const LIST := {
	"scout_hunt": {
		"title": "Scout Hunt", "counter": "IFVs beat scouts",
		"brief": "Five scouts are racing at you. Tank turrets are too slow to track them; the IFV's fast turret isn't.",
		"lesson": "IFVs shred scouts: a fast turret and an autocannon follow what a tank's turret can't.",
		"player": [{"name": "Alpha", "formation": "line", "units": ["ifv", "ifv"]}, {"name": "Bravo", "formation": "wedge", "units": ["tank"]}],
		"enemy": [{"name": "Raiders", "units": ["scout", "scout", "scout", "scout", "scout"],
				"directive": {"role": "assault", "aggression": 0.9, "caution": 0.2, "target_priority": "nearest"}}],
	},
	"turret_lag": {
		"title": "Turret Lag", "counter": "Scouts beat tanks",
		"brief": "Three tanks hold the center. Your scouts are fast: circle them and stay out of their slow turrets' arcs.",
		"lesson": "Scouts beat tanks: keep moving across a tank's front and its turret never catches up.",
		"player": [{"name": "Alpha", "formation": "vee", "units": ["scout", "scout", "scout"]}, {"name": "Bravo", "formation": "vee", "units": ["scout", "scout"]}],
		"enemy": [{"name": "Wall", "units": ["tank", "tank", "tank"],
				"directive": {"role": "anchor", "objective": {"right": 0.0, "forward": -8.0, "radius": 10.0}}}],
	},
	"hold_the_front": {
		"title": "Hold the Front", "counter": "Tanks beat IFVs",
		"brief": "Four IFVs are coming. Their autocannons can't get through a tank's front armor: face them and trade.",
		"lesson": "Tanks beat IFVs: low-penetration autocannons bounce off frontal armor while the cannon hits hard.",
		"player": [{"name": "Alpha", "formation": "line", "units": ["tank", "tank", "tank"]}],
		"enemy": [{"name": "Pack", "units": ["ifv", "ifv", "ifv", "ifv"],
				"directive": {"role": "assault", "aggression": 0.8, "caution": 0.3}}],
	},
	"spot_for_the_guns": {
		"title": "Spot for the Guns", "counter": "Artillery beats what holds still",
		"brief": "Tanks are dug in at the center. Your artillery can't see that far: send the scouts forward to spot.",
		"lesson": "Artillery punishes units that sit still, but it only hits what a teammate can see.",
		"player": [{"name": "Alpha", "formation": "line", "units": ["artillery", "artillery"]}, {"name": "Bravo", "formation": "vee", "units": ["scout", "scout"]}],
		"enemy": [{"name": "Dug_In", "units": ["tank", "tank", "tank"],
				"directive": {"role": "anchor", "caution": 0.7, "objective": {"right": 0.0, "forward": -12.0, "radius": 8.0}}}],
	},
	"rush_the_battery": {
		"title": "Rush the Battery", "counter": "Scouts beat artillery",
		"brief": "Artillery shells everything at range, but it can't fire at what's too close. Get in fast.",
		"lesson": "Scouts beat artillery: close the distance and the mortars can't aim that short.",
		"player": [{"name": "Alpha", "formation": "wedge", "units": ["scout", "scout", "scout", "scout"]}],
		"enemy": [{"name": "Battery", "units": ["artillery", "artillery"], "directive": {"role": "support", "objective": {"right": 0.0, "forward": -40.0, "radius": 10.0}}},
				{"name": "Guard", "units": ["tank"], "directive": {"role": "anchor", "objective": {"right": 0.0, "forward": -30.0, "radius": 10.0}}}],
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in LIST:
		result.append(id)
	return result


static func info(id: String) -> Dictionary:
	return LIST.get(id, {})


## The catalog's unit for `role` (the first with that role, locked or not), or "" if the catalog has none.
static func unit_for(catalog: ArmyCatalog, role: String) -> String:
	var found := catalog.units_with_role(role)
	return found[0] if not found.is_empty() else ""


## An army JSON v2 dictionary for one side of challenge `id` ("player" holds for orders; "enemy" moves by directive).
static func army(id: String, side: String, catalog: ArmyCatalog) -> Dictionary:
	var spec: Dictionary = LIST[id]
	var squads := []
	for squad_spec: Dictionary in spec[side]:
		var squad := {"name": squad_spec["name"], "units": []}
		for role: String in squad_spec["units"]:
			var unit_id := unit_for(catalog, role)
			if unit_id != "":
				squad["units"].append({"unit": unit_id})
		if side == "player":
			squad["formation"] = squad_spec.get("formation", Formations.DEFAULT)
			squad["verb"] = "hold"
			squad["directive"] = {"role": "assault"}
		else:
			squad["directive"] = squad_spec.get("directive", {"role": "assault"}).duplicate(true)
		if not squad["units"].is_empty():
			squads.append(squad)
	return {"name": "%s: %s" % [spec["title"], "You" if side == "player" else "Opponent"], "squads": squads}


## Can every role in the challenge be played with this catalog?
static func playable(id: String, catalog: ArmyCatalog) -> bool:
	for side in ["player", "enemy"]:
		for squad_spec: Dictionary in LIST[id][side]:
			for role: String in squad_spec["units"]:
				if unit_for(catalog, role) == "":
					return false
	return true
