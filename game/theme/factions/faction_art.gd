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


## Round 7 (the lead: "the turrets on the gang tanks didn't rotate"): hulls whose gun was generated as part of the hull
## mesh, with only a nub as the turret part. The gun is cut out of the hull at runtime by a box in the hull model's own
## (natural) space and yaws with the tank's turret about `pivot`, so the concept-approved model stays exactly as
## approved (no regeneration). "<faction>/<role>" -> {box: AABB, pivot: Vector3, rest_yaw_deg?}: `rest_yaw_deg` turns a
## gun that was modelled pointing backwards to point forward at turret yaw 0 (the simulation's "aim ahead"). Authored
## and checked with `make facing-audit UNITS=... TURRET=70` (the audit holds the turret there).
const GUN_CUTS := {
	"gangs/tank": {"box": AABB(Vector3(-0.5, 1.12, -0.3), Vector3(1.0, 0.6, 2.2)), "pivot": Vector3(0.0, 1.12, 0.45),
			"rest_yaw_deg": 180.0},
	# The rocket pod on the truck's bed (the bed tops out near 1.2 m; the pod and its turntable stand above it).
	"law/artillery": {"box": AABB(Vector3(-0.9, 1.2, 0.1), Vector3(1.8, 1.3, 2.1)), "pivot": Vector3(0.0, 1.2, 0.9),
			"rest_yaw_deg": 180.0},
	# Not the Syndicate IFV: its roof gun is its real turret part (it traverses). An early render taken while the tank
	# was driving its turret home made it look baked in; a cut there hid the gun and turned a slab of roof instead.
}


## The gun cut for a unit's art, or {} when its gun is a real turret part.
static func gun_cut(unit_id: String) -> Dictionary:
	var faction := String(Units.stat(unit_id, "faction", ""))
	var role := art_role(Units.role_of(unit_id))
	return GUN_CUTS.get("%s/%s" % [faction, role], {})


static var _cut_cache := {}


## `mesh` (whose vertices `to_model` carries into model space) split by `box`: [the triangles outside, the triangles
## inside], each an ArrayMesh with the source's surface materials, or null when empty. Cached per mesh and box.
static func split_mesh(mesh: Mesh, to_model: Transform3D, box: AABB) -> Array:
	var key := "%d|%s|%s" % [mesh.get_instance_id(), str(to_model), str(box)]
	if _cut_cache.has(key):
		return _cut_cache[key]
	var outside := ArrayMesh.new()
	var inside := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(verts.size())
			for i in verts.size():
				indices[i] = i
		var keep := PackedInt32Array()
		var cut := PackedInt32Array()
		for t in range(0, indices.size() - 2, 3):
			var centroid := to_model * ((verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0)
			var target := cut if box.has_point(centroid) else keep
			target.append_array([indices[t], indices[t + 1], indices[t + 2]])
		for pair in [[outside, keep], [inside, cut]]:
			var part_indices: PackedInt32Array = pair[1]
			if part_indices.is_empty():
				continue
			var copy := arrays.duplicate()
			copy[Mesh.ARRAY_INDEX] = part_indices
			(pair[0] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy)
			(pair[0] as ArrayMesh).surface_set_material((pair[0] as ArrayMesh).get_surface_count() - 1, mesh.surface_get_material(s))
	var result := [outside if outside.get_surface_count() > 0 else null, inside if inside.get_surface_count() > 0 else null]
	_cut_cache[key] = result
	return result
