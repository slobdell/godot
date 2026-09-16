class_name Arena
extends Node3D
## The static battlefield, built from a LAYOUT (rules R6, contract C5): `arenas/<name>.json` =
## {name, half_size, obstacles: [{type, position [x, z], rotation_deg, size?}], spawns: {green, rust}, control_point?,
## hazards?: [{type, position [x, z], radius, damage_per_second}]} (stretch: fire pits hurt whatever stands in them).
## Pick one with `--arena=<name>` (default DEFAULT_LAYOUT). Obstacles become collision boxes under the
## "Obstacles" node (the radar reads them there) with a `prop.<type>` visual slot each; `arena.dressing` gets
## `setup(layout)` so stands and crowds can fit it.
##
## Bakes its navigation mesh at startup on EVERY peer, because pathing runs wherever an OrderController runs
## (server bots, agent clients). The bake parses COLLISION SHAPES (layer 1) in the "navigation_source" group,
## never render meshes: the dedicated-server export strips meshes.
##
## FAIRNESS: every layout must be point-symmetric (rotating it 180° about the center gives the same arena;
## validate() refuses anything else), but a normal navmesh bake is NOT: the baker's polygonization depends on
## traversal order. Mirrored trips differed by up to 4.4 m, and the south base won 64% of 140 bot matches. So we
## bake only the southern half (z >= 0) and add the same mesh rotated 180° as a second region: the navigation is
## symmetric by construction. See _agents/squad_ai_design.md "Fairness".

signal navigation_ready

const DEFAULT_LAYOUT := "foundry"
const LAYOUT_DIR := "res://arenas"
## Obstacle types with a built-in collision size [x, height, z] (meters, before rotation). Other types need "size".
const OBSTACLE_SIZES := {"crate": [4.5, 3.0, 4.5], "wall": [18.0, 3.0, 1.5]}
## Extra bake margin past the seam so the half-mesh isn't shrunk by the agent
## radius where it meets its mirror (NavigationMesh.border_size, for chunked bakes).
const SEAM_BORDER := 2.5
const HALF_EXTENT := Match.ARENA_HALF_SIZE + 40.0
## Mirror pairs must match to this many meters (and degrees).
const SYMMETRY_TOLERANCE := 0.01

## The layout the most recent Arena built. Match reads its spawns (static: spawn positions are static queries).
static var active: Dictionary = {}

## Set before the arena enters the tree to pick a layout in code (tests); else `--arena=`, else DEFAULT_LAYOUT.
@export var layout_name := ""
var layout: Dictionary = {}

@onready var navigation: NavigationRegion3D = $Navigation
@onready var obstacles_root: Node3D = $Obstacles


func _ready() -> void:
	var wanted := layout_name if layout_name != "" else LaunchFlags.from_environment().text("arena", DEFAULT_LAYOUT)
	var loaded := load_layout(wanted)
	if loaded.has("error"):
		push_error("arena: %s; using %s" % [loaded["error"], DEFAULT_LAYOUT])
		loaded = load_layout(DEFAULT_LAYOUT)
	layout = loaded["layout"]
	active = layout
	_build_obstacles()
	_build_hazards()
	var dressing := get_node_or_null("Dressing") as VisualSlot
	if dressing != null:
		dressing.invoke("setup", [layout])
	_bake()


func _exit_tree() -> void:
	if is_same(active, layout):
		active = {}  # no stale spawns or hazards for a match that runs without an arena


func _bake() -> void:
	var nav_mesh := navigation.navigation_mesh
	nav_mesh.border_size = SEAM_BORDER
	nav_mesh.filter_baking_aabb = AABB(Vector3(-HALF_EXTENT, -5.0, -SEAM_BORDER),
			Vector3(HALF_EXTENT * 2.0, 20.0, HALF_EXTENT + SEAM_BORDER))
	navigation.bake_navigation_mesh(false)

	var mirror := NavigationRegion3D.new()
	mirror.name = "NavigationMirror"
	mirror.navigation_mesh = nav_mesh
	mirror.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	add_child(mirror)
	navigation_ready.emit()


func _build_obstacles() -> void:
	for child in obstacles_root.get_children():
		child.free()
	var index := 0
	for obstacle: Dictionary in layout["obstacles"]:
		var size := obstacle_size(obstacle)
		var body := StaticBody3D.new()
		body.name = "%s_%d" % [String(obstacle["type"]).capitalize().replace(" ", ""), index]
		index += 1
		body.position = Vector3(obstacle["position"][0], 0.0, obstacle["position"][1])
		body.rotation.y = deg_to_rad(float(obstacle.get("rotation_deg", 0.0)))
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		collision.position.y = size.y / 2.0
		body.add_child(collision)
		var visual := VisualSlot.new()
		visual.name = "Visual"
		visual.slot = "prop." + String(obstacle["type"])
		if OBSTACLE_SIZES.has(obstacle["type"]):
			var standard: Array = OBSTACLE_SIZES[obstacle["type"]]
			visual.scale = Vector3(size.x / standard[0], size.y / standard[1], size.z / standard[2])
		body.add_child(visual)
		obstacles_root.add_child(body)


## Hazards get a `prop.<type>` visual only when the theme has one (art's request list in slot_contracts.md);
## the damage is Match's (Match._apply_hazards), so a hazard works on a headless server with no art at all.
func _build_hazards() -> void:
	var index := 0
	for hazard: Dictionary in hazards():
		var slot := "prop." + String(hazard["type"])
		if not GameTheme.slots.has(slot):
			continue
		var visual := VisualSlot.new()
		visual.name = "Hazard_%d" % index
		index += 1
		visual.slot = slot
		visual.position = hazard["position"]
		add_child(visual)
		visual.invoke("setup", [hazard])


## The layout's hazards: [{type, position: Vector3, radius, damage_per_second}] (the AI should route around them).
func hazards() -> Array:
	return hazards_of(layout)


static func hazards_of(data: Dictionary) -> Array:
	var result: Array = []
	for hazard: Dictionary in data.get("hazards", []):
		result.append({"type": hazard["type"], "position": Vector3(hazard["position"][0], 0.0, hazard["position"][1]),
				"radius": float(hazard["radius"]), "damage_per_second": float(hazard["damage_per_second"])})
	return result


## C4: every obstacle as cover for the AI: [{position: Vector3 (ground center), size: Vector3 (before rotation),
## rotation: float (radians about +Y), height: float, type: String}].
func cover_features() -> Array:
	var features: Array = []
	for obstacle: Dictionary in layout.get("obstacles", []):
		var size := obstacle_size(obstacle)
		features.append({"position": Vector3(obstacle["position"][0], 0.0, obstacle["position"][1]), "size": size,
				"rotation": deg_to_rad(float(obstacle.get("rotation_deg", 0.0))), "height": size.y, "type": obstacle["type"]})
	return features


static func obstacle_size(obstacle: Dictionary) -> Vector3:
	var size: Array = obstacle.get("size", OBSTACLE_SIZES.get(obstacle.get("type", ""), [1.0, 1.0, 1.0]))
	return Vector3(size[0], size[1], size[2])


## The layout's spawn point for `slot` on the `green` (south) or rust (north) side, or null if it lists none.
static func spawn_spot(south: bool, slot: int) -> Variant:
	var spots: Array = active.get("spawns", {}).get("green" if south else "rust", [])
	if spots.is_empty():
		return null
	var spot: Array = spots[slot % spots.size()]
	return Vector3(spot[0], 0.0, spot[1])


## Names of the layouts in LAYOUT_DIR.
static func layout_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for file_name in DirAccess.get_files_at(LAYOUT_DIR):
		if file_name.ends_with(".json"):
			names.append(file_name.get_basename())
	names.sort()
	return names


## {"layout": Dictionary} or {"error": String}. `name` is a file in LAYOUT_DIR or a full path.
static func load_layout(name: String) -> Dictionary:
	var path := name if name.contains("://") else "%s/%s.json" % [LAYOUT_DIR, name]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "no arena layout '%s' (have %s)" % [name, ", ".join(layout_names())]}
	var data: Variant = JSON.parse_string(file.get_as_text())
	var error := validate(data)
	if error != "":
		return {"error": "arena %s: %s" % [name, error]}
	return {"layout": data}


## "" or why `data` isn't a valid, point-symmetric layout.
static func validate(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("name")) != TYPE_STRING:
		return "a layout is an object with a string 'name'"
	if not _is_number(data.get("half_size")) or not is_equal_approx(float(data["half_size"]), Match.ARENA_HALF_SIZE):
		return "half_size must be %.0f (the perimeter, radar, and fog are sized for it)" % Match.ARENA_HALF_SIZE
	var obstacles: Variant = data.get("obstacles")
	if typeof(obstacles) != TYPE_ARRAY:
		return "'obstacles' must be a list"
	for obstacle in obstacles:
		if typeof(obstacle) != TYPE_DICTIONARY or typeof(obstacle.get("type")) != TYPE_STRING:
			return "every obstacle needs a string 'type'"
		if not _is_point(obstacle.get("position")):
			return "obstacle %s needs 'position' [x, z]" % obstacle["type"]
		if absf(float(obstacle["position"][0])) > Match.DRIVABLE_LIMIT or absf(float(obstacle["position"][1])) > Match.DRIVABLE_LIMIT:
			return "obstacle at %s is outside the arena" % [obstacle["position"]]
		if obstacle.has("rotation_deg") and not _is_number(obstacle["rotation_deg"]):
			return "rotation_deg must be a number"
		if obstacle.has("size"):
			var size: Variant = obstacle["size"]
			if typeof(size) != TYPE_ARRAY or size.size() != 3 or not size.all(func(v: Variant) -> bool: return _is_number(v) and float(v) > 0.0):
				return "size must be [x, height, z] in meters"
		elif not OBSTACLE_SIZES.has(obstacle["type"]):
			return "obstacle type '%s' has no built-in size: give it 'size'" % obstacle["type"]
	for obstacle: Dictionary in obstacles:
		if not obstacles.any(func(other: Dictionary) -> bool: return _mirrors(obstacle, other)):
			return "not point-symmetric: %s at %s has no 180° mirror at %s" % [obstacle["type"], obstacle["position"],
					[-float(obstacle["position"][0]), -float(obstacle["position"][1])]]
	var spawns: Variant = data.get("spawns")
	if typeof(spawns) != TYPE_DICTIONARY:
		return "'spawns' must be {green: [[x, z], ...], rust: [...]}"
	for side in ["green", "rust"]:
		var spots: Variant = spawns.get(side)
		# X5 (round 4): a full army is Match.SPAWN_SLOTS now, not five squads of five.
		if typeof(spots) != TYPE_ARRAY or spots.size() < Match.SPAWN_SLOTS or not spots.all(func(v: Variant) -> bool: return _is_point(v)):
			return "spawns.%s needs at least %d [x, z] points (a full army)" % [side, Match.SPAWN_SLOTS]
	if spawns["green"].size() != spawns["rust"].size():
		return "spawns.green and spawns.rust must have the same length"
	for i in spawns["green"].size():
		var green: Array = spawns["green"][i]
		var rust: Array = spawns["rust"][i]
		if absf(float(green[0]) + float(rust[0])) > SYMMETRY_TOLERANCE or absf(float(green[1]) + float(rust[1])) > SYMMETRY_TOLERANCE:
			return "not point-symmetric: spawns.rust[%d] must be the mirror of spawns.green[%d]" % [i, i]
	var hazards_data: Variant = data.get("hazards", [])
	if typeof(hazards_data) != TYPE_ARRAY:
		return "'hazards' must be a list"
	for hazard in hazards_data:
		if typeof(hazard) != TYPE_DICTIONARY or typeof(hazard.get("type")) != TYPE_STRING or not _is_point(hazard.get("position")):
			return "every hazard needs a string 'type' and a 'position' [x, z]"
		if not _is_number(hazard.get("radius")) or float(hazard["radius"]) <= 0.0:
			return "hazard %s needs a positive 'radius'" % hazard["type"]
		if not _is_number(hazard.get("damage_per_second")) or float(hazard["damage_per_second"]) < 0.0:
			return "hazard %s needs 'damage_per_second' >= 0" % hazard["type"]
	for hazard: Dictionary in hazards_data:
		var mirrored: bool = hazards_data.any(func(other: Dictionary) -> bool:
			return other["type"] == hazard["type"] and is_equal_approx(float(other["radius"]), float(hazard["radius"])) \
					and is_equal_approx(float(other["damage_per_second"]), float(hazard["damage_per_second"])) \
					and absf(float(other["position"][0]) + float(hazard["position"][0])) <= SYMMETRY_TOLERANCE \
					and absf(float(other["position"][1]) + float(hazard["position"][1])) <= SYMMETRY_TOLERANCE)
		if not mirrored:
			return "not point-symmetric: hazard %s at %s has no 180° mirror" % [hazard["type"], hazard["position"]]
	if data.has("control_point") and typeof(data["control_point"]) != TYPE_DICTIONARY:
		return "control_point must be an object like {\"radius\": 16}"
	return ""


## Whether `b` is `a` rotated 180° about the arena center (a box looks the same turned 180°).
static func _mirrors(a: Dictionary, b: Dictionary) -> bool:
	if a["type"] != b["type"] or obstacle_size(a) != obstacle_size(b):
		return false
	if absf(float(a["position"][0]) + float(b["position"][0])) > SYMMETRY_TOLERANCE \
			or absf(float(a["position"][1]) + float(b["position"][1])) > SYMMETRY_TOLERANCE:
		return false
	var turn := fposmod(float(a.get("rotation_deg", 0.0)) - float(b.get("rotation_deg", 0.0)), 180.0)
	return turn <= SYMMETRY_TOLERANCE or turn >= 180.0 - SYMMETRY_TOLERANCE


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _is_point(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 2 and _is_number(value[0]) and _is_number(value[1])
