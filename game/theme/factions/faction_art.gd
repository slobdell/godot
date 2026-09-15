class_name FactionArt
extends RefCounted
## Contract K4 (round 3, assets X4): which model fills `unit.<faction>.<role>.hull/turret/weapon`. Gallery only this
## round (`make vehicle-gallery FACTION=<id>`); factions aren't playable yet. The Condemned are today's roster; the new
## factions' models are built from the lead's approved concepts into game/theme/factions/<faction>/generated/ and
## worn in the cyberpunk look (dozer_part.gd: team neon, paint, underglow).

const FACTIONS := ["condemned", "gangs", "law", "syndicate"]
const NEW_FACTIONS := ["gangs", "law", "syndicate"]
const ROLES := ["scout", "ifv", "tank", "artillery", "special"]
## The Condemned's unit in each role (catalog v2 ids; the Lancer is their special).
const CONDEMNED := {"scout": "scout", "ifv": "ifv", "tank": "tank", "artillery": "artillery", "special": "lancer"}
const PART_WRAPPER := preload("res://game/theme/cyberpunk/dozer_part.gd")


static func generated_scene(faction: String, role: String, part: String) -> String:
	return "res://game/theme/factions/%s/generated/unit_%s_%s_%s.tscn" % [faction, faction, role, part]


static func has_art(faction: String, role: String) -> bool:
	if faction == "condemned":
		return CONDEMNED.has(role)
	return ResourceLoader.exists(generated_scene(faction, role, "hull"))


## A new node showing that part, or null when it doesn't exist (a fixed-mount scout has no turret, a role not built yet).
static func instantiate(faction: String, role: String, part: String) -> Node3D:
	if faction == "condemned":
		if not CONDEMNED.has(role):
			return null
		var unit: String = CONDEMNED[role]
		var slot := "unit.%s.%s" % [unit, part]
		if not GameTheme.slots.has(slot):
			slot = {"hull": "tank.hull", "turret": "tank.turret", "weapon": "weapon.cannon"}[part]
		var packed := GameTheme.scene(slot)
		return packed.instantiate() as Node3D if packed != null else null
	var path := generated_scene(faction, role, part)
	if not ResourceLoader.exists(path):
		return null
	var wrapper := Node3D.new()
	wrapper.set_script(PART_WRAPPER)
	wrapper.set("model_scene", load(path))
	wrapper.set("part", "cannon" if part == "weapon" else part)
	return wrapper
