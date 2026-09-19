class_name FactionArt
extends RefCounted
## Contract K4 (round 3, assets X4): which model fills `unit.<faction>.<role>.hull/turret/weapon`
## (`make vehicle-gallery FACTION=<id>`). Round 5 (render X6): the art ships and plays: `unit_slots()` gives gameplay's
## `unit.<unit id>.*` slots for every faction unit whose parts exist (wrappers in factions/<faction>/parts/, written by
## tools/assets/build_faction_parts.py). The Condemned are today's roster; the new
## factions' models are built from the lead's approved concepts into game/theme/factions/<faction>/generated/ and
## worn in the cyberpunk look (dozer_part.gd: team neon, paint, underglow).

const FACTIONS := ["condemned", "gangs", "law", "syndicate"]
const NEW_FACTIONS := ["gangs", "law", "syndicate"]
const ROLES := ["scout", "ifv", "tank", "artillery", "special"]
## The Condemned's unit in each role (catalog v2 ids; the Lancer is their special).
const CONDEMNED := {"scout": "scout", "ifv": "ifv", "tank": "tank", "artillery": "artillery", "special": "lancer"}
const PART_WRAPPER := preload("res://game/theme/cyberpunk/dozer_part.gd")
const NO_PART := "res://game/theme/cyberpunk/units/no_part.tscn"
## The catalog roles that have their own art role; any other role (support, suppressor, lancer) is the faction's special.
const ART_ROLES := ["scout", "ifv", "tank", "artillery"]


static func part_scene(faction: String, role: String, part: String) -> String:
	return "res://game/theme/factions/%s/parts/%s_%s.tscn" % [faction, role, part]


## The art role a catalog unit wears.
static func art_role(catalog_role: String) -> String:
	return catalog_role if ART_ROLES.has(catalog_role) else "special"


## Visual slots for the new factions' units: `unit.<id>.hull/turret/weapon` → wrapper scenes, for every unit whose hull
## art is in this build. A hull without its own turret or weapon model carries them in its mesh, so those slots are
## deliberately empty (no_part) rather than falling back to the Condemned dozer's. Builds without the faction art (the
## web export) get no entries and draw the Condemned through C6's fallback.
static func unit_slots() -> Dictionary:
	var result := {}
	for faction in NEW_FACTIONS:
		for unit_id in Units.roster(faction):
			var role := art_role(Units.role_of(unit_id))
			var hull := part_scene(faction, role, "hull")
			if not ResourceLoader.exists(hull):
				continue
			result["unit.%s.hull" % unit_id] = hull
			for part in ["turret", "weapon"]:
				var scene := part_scene(faction, role, part)
				result["unit.%s.%s" % [unit_id, part]] = scene if ResourceLoader.exists(scene) else NO_PART
	return result


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


## Feel (round 6): the natural length (m, along -Z) of a unit's hull model, before any fitting: turret and weapon parts
## scale by the same factor as their hull (dozer_part.gd `_fit_to_hull`). 0 when the unit has no hull art of its own.
static var _hull_lengths := {}


static func hull_length(unit_id: String) -> float:
	if _hull_lengths.has(unit_id):
		return _hull_lengths[unit_id]
	var result := 0.0
	var slot := "unit.%s.hull" % unit_id
	if GameTheme.slots.has(slot):
		var part := GameTheme.scene(slot).instantiate()
		var packed: PackedScene = part.get("model_scene")
		if packed != null:
			var model := packed.instantiate() as Node3D
			result = FactionArt.natural_bounds(model).size.z
			model.free()
		part.free()
	_hull_lengths[unit_id] = result
	return result


## Union of a detached model's mesh AABBs in its own space.
static func natural_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var xform := Transform3D.IDENTITY
		var node: Node = instance
		while node != null and node != model:
			if node is Node3D:
				xform = (node as Node3D).transform * xform
			node = node.get_parent()
		var box := xform * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
