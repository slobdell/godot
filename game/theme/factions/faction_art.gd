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
## Round 11 (fleet T2; the lead: "the barrel of the tank is detached at the tip, there's a floating piece of the barrel
## that stays fixed in front of the tank"). Round 10 listed ONE weapon part here ("gangs/artillery") as a stray stick
## while its own comment said every generated weapon part is one, and four more were still drawn -- the Law tank's
## 14-triangle, 1.8 cm stick 0.74 m off its centreline among them. The list is gone: a weapon part is refused by
## what it IS (`is_stray_stick`), so the next generated stick is refused rather than waiting to be blacklisted. A unit
## with a GUN_CUT never shows its weapon part either: its real gun is cut out of the hull.
##
## A stick: its THINNEST side under STICK_ASPECT of its length. Measured over every weapon part in the tree
## (natural size, before the tank's fit): the generated sticks are 0.4-1.9% (Law tank 0.4%, gang catapult 0.6%,
## Law special 0.6%, Law IFV 1.5%, gang IFV 1.7%, Syndicate tank 1.9%); the real weapons are 4.7% (the Condemned
## IFV's barrel, with its breech), 15% (the scout's guns) and 39% (the lancer's coil). 3% sits between them.
const STICK_ASPECT := 0.03


## True when `bounds` (a weapon part's natural AABB) is a sliver no one reads as a gun.
static func is_stray_stick(bounds: AABB) -> bool:
	var sides := [bounds.size.x, bounds.size.y, bounds.size.z]
	sides.sort()
	return float(sides[2]) > 0.0 and float(sides[0]) / float(sides[2]) < STICK_ASPECT


## Round 11 (fleet T2): gun fragments the splitter left in a HULL mesh, dropped at runtime (triangles whose centroid
## is in any box, the model's natural space, as GUN_CUTS). They do not turn, so as the turret traverses they stay
## pointing ahead: the lead's "floating piece of the barrel that stays fixed in front of the tank". The turret part
## carries its own whole gun, so nothing is lost. Measured with `make assets-profile` and seen with
## `make facing-audit TINT=1` (turret magenta, weapon yellow: a barrel still in hull colours is one of these).
const HULL_TRIMS := {
	# The Law tank's barrel tip: 142 triangles, |x| <= 0.03, y 1.36-1.48, z -0.65..-1.70, and nothing else of the hull
	# in that box (unit_law_tank_hull.glb profile, CLIP). Its turret's own barrel is magenta and turns.
	"law/tank": [AABB(Vector3(-0.1, 1.33, -1.72), Vector3(0.2, 0.2, 1.1))],
}


static func hull_trim(unit_id: String) -> Array:
	var faction := String(Units.stat(unit_id, "faction", ""))
	var role := art_role(Units.role_of(unit_id))
	return HULL_TRIMS.get("%s/%s" % [faction, role], [])
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
				var stray: bool = part == "weapon" and GUN_CUTS.has("%s/%s" % [faction, role])
				result["unit.%s.%s" % [unit_id, part]] = scene if ResourceLoader.exists(scene) and not stray else NO_PART
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
## (natural) space (or by several, `boxes`, when no one box separates it) and yaws with the tank's turret about `pivot`, so the concept-approved model stays exactly as
## approved (no regeneration). "<faction>/<role>" -> {box: AABB, pivot: Vector3, rest_yaw_deg?, drop?} (`drop`, model
## units: lowers a gun generated hovering over its hull onto it; round 11): `rest_yaw_deg` turns a
## gun that was modelled pointing backwards to point forward at turret yaw 0 (the simulation's "aim ahead"). Authored
## and checked with `make facing-audit UNITS=... TURRET=70` (the audit holds the turret there).
const GUN_CUTS := {
	# Round 11 (fleet; the lead: "the tank barrel and the turret in general associated with the gang's rigger is
	# disconnected and floating relative to the rigger"). Two defects, measured (unit_gangs_tank_hull.glb profile and
	# `make facing-audit UNITS=gang_tank TINT=1 VIEW=side|top TURRET=70 BEND=35`): the gun as generated stands on
	# NOTHING -- its lowest part is y 1.12-1.15 and the tanker's top under it is below y 1.00, a 0.47 m gap at the rig's
	# scale -- so `drop` seats it on the tanker; and the box reached z +1.9, taking a 20-triangle fitting at the tanker's
	# tail (z +1.33..+1.40) that the 180 rest yaw flipped onto the CAB and swung out on its own as the gun traversed. The
	# barrel ends at z +0.98, so the box now stops at +1.28. (The gun already rides the trailer, not the tractor:
	# DozerPart._cut_trailer moves the GunPivot under the TrailerPivot and takes the swing back out of its lay.)
	"gangs/tank": {"box": AABB(Vector3(-0.5, 1.12, -0.3), Vector3(1.0, 0.6, 1.58)), "pivot": Vector3(0.0, 1.12, 0.45),
			"rest_yaw_deg": 180.0, "drop": 0.045},
	# The rocket pod on the truck's bed (the bed tops out near 1.2 m; the pod and its turntable stand above it).
	"law/artillery": {"box": AABB(Vector3(-0.9, 1.2, 0.1), Vector3(1.8, 1.3, 2.1)), "pivot": Vector3(0.0, 1.2, 0.9),
			"rest_yaw_deg": 180.0},
	# R5 (round 10; the lead: "the turret placement on our vehicles is wrong (at least with the condemned and the
	# gangs)"): the gun truck's twin machine gun stands on a post in the BED, generated into the hull, while the parts
	# that traversed were a 3 cm "barrel" stick and a plate over the cab. Measured with `make assets-profile`
	# (unit_gangs_ifv_hull.glb, +z is the model's FRONT, the wrapper yaws it 180): the gun and its shield plate are the
	# narrow mass at z -1.72..-0.28, |x| <= 0.42, above the bed rails (y >= 1.55); the post is at z ~ -0.95. It points
	# forward as modelled, so no rest yaw.
	"gangs/ifv": {"box": AABB(Vector3(-0.45, 1.55, -1.74), Vector3(0.9, 0.65, 1.47)), "pivot": Vector3(0.0, 1.55, -0.95)},
	# Round 11 (fleet T1; the lead: "The turret on the Law's IFV is not spinning"). It never could: the remote weapon
	# station the player sees -- cupola, box and 25 mm barrel -- was generated INTO the hull, and the part the splitter
	# labelled "turret" was a few roof-rail fragments, drawn buried (`make facing-audit TINT=1`). Measured with
	# `make assets-profile IN=...unit_law_ifv_hull.glb` (model space, -Z forward, roof ~1.49 m): the station stands on
	# the roof at z 0.00..+0.86 with its barrel out to z -0.88 at y 1.69-1.76, all within |x| <= 0.43, above y 1.52
	# (the light bar ahead of it tops out at 1.51; the stowage behind it at 1.49). The ring is at z +0.33. It points
	# forward as modelled.
	"law/ifv": {"box": AABB(Vector3(-0.46, 1.52, -0.95), Vector3(0.92, 0.5, 1.87)), "pivot": Vector3(0.0, 1.52, 0.33)},
	# Round 11 (fleet T1): the suppressor's sonic array -- a mast of loudspeaker horns -- is hull mesh too; its
	# "turret" part was a cluster of spikes drawn 2 m down inside the horns. Profile (unit_law_special_hull.glb): the
	# array and its mast stand on the roof (~1.16 m) at z -0.05..+0.92, |x| <= 0.55, from y 1.22 up; the mast is at
	# z +0.40. A radial array, so no rest yaw.
	"law/special": {"box": AABB(Vector3(-0.6, 1.22, -0.08), Vector3(1.2, 1.0, 1.02)), "pivot": Vector3(0.0, 1.22, 0.40)},
	# Round 11 (fleet T1): the Syndicate tank's railgun -- twin rails floating over the rear deck, the faction's hover
	# idiom -- is hull mesh; its "turret" part was a deck-sized slab (with a second pair of rails) that swept the whole
	# rear deck as it turned. Profile (unit_syndicate_tank_hull.glb): the rails are |x| <= 0.24, y 1.12-1.22,
	# z -1.28..+0.28, clear of the deck (<= 1.01). They yaw about their breech end's third, z 0.0.
	"syndicate/tank": {"box": AABB(Vector3(-0.3, 1.08, -1.34), Vector3(0.6, 0.22, 1.66)), "pivot": Vector3(0.0, 1.08, 0.0)},
	# Round 11 (fleet T1): the Syndicate IFV's gun is the pod floating over its roof (hull mesh: |x| <= 0.08,
	# y 0.91-1.10, z -0.37..+0.38). Round 10 wrote here that its roof gun "is its real turret part (it traverses)";
	# `make facing-audit TINT=1` shows the part that traversed was a 0.5 m fragment drawn under the roof, and the pod
	# never moved. Symmetric fore and aft, so no rest yaw; the model's own 180 (it was generated facing +Z) turns the
	# cut with it.
	"syndicate/ifv": {"box": AABB(Vector3(-0.14, 0.88, -0.42), Vector3(0.28, 0.26, 0.84)), "pivot": Vector3(0.0, 0.88, 0.0)},
	# Round 11 (fleet T1): the gang catapult is a tow-truck crane on the bed -- post, boom and a hanging bucket -- all
	# hull mesh; its "turret" part was a few 10 cm fragments. The boom rests cocked BACK over the tail with the bucket
	# hanging off it, which is how a throwing arm rests, so no rest yaw: it traverses with the turret and lobs over the
	# cab. Profile (unit_gangs_artillery_hull.glb, 360 px/m ruled view): post at z -0.03..+0.33 from the bed (0.81) up;
	# boom to the tip at z +1.6, y 1.95; bucket at z +1.55..+2.0, y 0.70-1.4, hanging past the tail. Three boxes because
	# a crate sits on the bed between post and bucket (z +0.58..+1.08, y <= 1.04) and stays on the hull.
	"gangs/artillery": {"boxes": [
			AABB(Vector3(-0.5, 1.05, -0.05), Vector3(1.0, 1.0, 2.1)),  # the boom, its stay and everything above the crate
			AABB(Vector3(-0.3, 0.84, -0.05), Vector3(0.6, 0.21, 0.4)),  # the post's foot, down to the bed
			AABB(Vector3(-0.5, 0.6, 1.4), Vector3(1.0, 0.45, 0.65)),  # the bucket's lower half, past the bed's end
		], "pivot": Vector3(0.0, 0.84, 0.15)},
}


## The gun cut for a unit's art, or {} when its gun is a real turret part.
static func gun_cut(unit_id: String) -> Dictionary:
	var faction := String(Units.stat(unit_id, "faction", ""))
	var role := art_role(Units.role_of(unit_id))
	return GUN_CUTS.get("%s/%s" % [faction, role], {})


## Round 9 (the lead, twice: "the semi trucks for the road gangs are still one long box itself of a truck / trailer
## combination"): the same mechanism as GUN_CUTS with a different law for the pivot's yaw. The trailer is cut out of
## the approved hull mesh at the fifth wheel and follows tractor-trailer kinematics from the DRAWN motion each frame
## (DozerPart._drive_trailer). Contract S2: this is art. The tractor is the simulated body, the collider is still the
## one `hull_size` box, and a shell can hit empty air inside a jackknife -- the accepted cost of not touching the sim.
##
## "<faction>/<role>" -> {
##   boxes:         model-space AABBs; a triangle whose centroid is in ANY of them is trailer. More than one box
##                  because the cut is not a plane: the tanker's front cap overhangs the tractor's drive tandem, so
##                  the barrel above the wheels is trailer while the wheels under it are tractor.
##   pivot:         the fifth wheel, model space. The hinge is about +Y, so only x and z matter.
##   wheelbase:     pivot to the trailer bogie's centre, MODEL space (scaled to world by the hull's fit, so it stays
##                  right when the roster is resized -- CP2).
##   jackknife_deg: |trailer - tractor| is clamped here. MEASURED against the mesh, not chosen:
##                  test_the_war_rig_bends_at_the_fifth_wheel finds the largest angle with no tractor/trailer
##                  overlap and fails if this constant is not below it.
## }
## Authored with `make assets-profile IN=...unit_gangs_tank_hull.glb` (slice table + a ruled side view whose pixels
## are metres). The rig, in model space: plow -1.80, steer axle -1.13, cab rear wall -0.19, a triangle-free gap,
## tanker front cap -0.01, drive tandem axles +0.19 and +0.39, trailer bogie +1.55, tanker rear +1.80.
const TRAILER_CUTS := {
	"gangs/tank": {
		"boxes": [
			# Everything aft of the drive tandem's rear wheels, full height: barrel, belly box, bogie, fenders.
			AABB(Vector3(-0.6, -0.2, 0.58), Vector3(1.2, 2.4, 1.5)),
			# The tanker's front section ABOVE the drive wheels: the barrel from its front cap back to the first box.
			# Its floor (0.39) is the underside of the trailer frame; below that is the tractor's tandem and frame.
			AABB(Vector3(-0.6, 0.39, -0.05), Vector3(1.2, 2.0, 0.63)),
		],
		"pivot": Vector3(0.0, 0.38, 0.25),
		"wheelbase": 1.30,
		"jackknife_deg": 65.0,
	},
}


## `--no-trailer` switches every trailer cut off, so the frame cost of the hinge is an A/B **in one tree** rather
## than a comparison of two checkouts on two days (the shape nav's `--nav-off=` already uses). Read once: a flag
## lookup per vehicle per spawn is not free at 60 vehicles.
static var _trailers_off := -1


static func trailers_off() -> bool:
	if _trailers_off < 0:
		_trailers_off = 1 if LaunchFlags.from_environment().has("no-trailer") else 0
	return _trailers_off == 1


## The trailer cut for a unit's art, or {} when it has no trailer.
static func trailer_cut(unit_id: String) -> Dictionary:
	if trailers_off():
		return {}
	var faction := String(Units.stat(unit_id, "faction", ""))
	var role := art_role(Units.role_of(unit_id))
	return TRAILER_CUTS.get("%s/%s" % [faction, role], {})


## The trailer's new world yaw after `delta`, from the standard off-tracking law: the trailer heading chases the
## tractor's at a rate set by the tractor's speed along its own forward over the trailer's wheelbase,
##
##     d(yaw_trailer)/dt = (v / L) * sin(yaw_tractor - yaw_trailer)
##
## which is why a trailer cuts the corner going forward (steady state on a circle of radius R is asin(L / R) of lag)
## and DIVERGES in reverse, v being negative -- that divergence is what jackknifing is. `limit` clamps the hinge where
## the cab is (FactionArt.TRAILER_CUTS jackknife_deg). Pure and static so the law can be tested without a tank.
## Note yaw here is Godot's: about +Y, positive turns LEFT (orientation.md trip-up 2). Only the DIFFERENCE of two
## yaws is used, so the convention cancels.
static func trailer_follow(trailer_yaw: float, tractor_yaw: float, speed: float, wheelbase: float,
		delta: float, limit: float) -> float:
	var chased := trailer_yaw + (speed / maxf(wheelbase, 0.01)) * sin(tractor_yaw - trailer_yaw) * delta
	return tractor_yaw + clampf(wrapf(chased - tractor_yaw, -PI, PI), -limit, limit)


static var _cut_cache := {}


## `mesh` (whose vertices `to_model` carries into model space) split by `box`: [the triangles outside, the triangles
## inside], each an ArrayMesh with the source's surface materials, or null when empty. Cached per mesh and box.
static func split_mesh(mesh: Mesh, to_model: Transform3D, box: AABB) -> Array:
	return split_mesh_boxes(mesh, to_model, [box])


## As split_mesh, but "inside" means inside ANY of `boxes` -- a cut whose shape is not a single box (the War Rig's
## trailer overhangs the tractor's drive tandem, so no one box separates them).
static func split_mesh_boxes(mesh: Mesh, to_model: Transform3D, boxes: Array) -> Array:
	var key := "%d|%s|%s" % [mesh.get_instance_id(), str(to_model), str(boxes)]
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
			var target := cut if _in_any(boxes, centroid) else keep
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


static func _in_any(boxes: Array, point: Vector3) -> bool:
	for box in boxes:
		if (box as AABB).has_point(point):
			return true
	return false
