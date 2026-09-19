class_name Arena
extends Node3D
## The static battlefield, built from a LAYOUT (rules R6, contract C5): `arenas/<name>.json` =
## {name, half_size, obstacles: [{type, position [x, z], rotation_deg, size?}], spawns: {green, rust}, control_point?,
## hazards?: [{type, position [x, z], radius, damage_per_second}]} (stretch: fire pits hurt whatever stands in them).
##
## LAYOUT v2 (arena X1, round 5, contract M2; `"schema": 2`) adds, all optional except spawn_zones:
##   props: [{type, position [x, z], rotation_deg?, stack?, <look keys>}]  the arena kit (ArenaKit.PROPS: containers
##     that stack 1-3 high, ad screens, barricades, wrecks, floodlights, signs). Fixed sizes; unknown types are errors.
##   spawn_zones: {green: {center [x, z], size [width, depth]}, rust: ...}  every spawn inside, clear of cover.
##   lanes: [{name, points [[x, z], ...] (green's end first), width}]    routes between the bases, for the AI.
##   regions: [{name, kind (ArenaKit.REGION_KINDS), position [x, z], radius}]  centre, open ground, cover clusters...
##   shape: {kind (ArenaShape.KINDS: square, hexagon, octagon), wall_height_m?, edges?: [{spans: [{kind, to_m}]}]}
##     (round 7) the perimeter. Read by control (camera cutaway) and feel (walls, stands, gates) through
##     Arena.perimeter() / perimeter_edges(), once at load. Absent = a square, which is every layout today.
##   terrain: [{kind (ArenaTerrain.KINDS: water, pit, bridge), name, rect [centre_x, centre_z, width, depth]}]
##     (round 7) ground a unit cannot cross but can fire over. The floor is rebuilt as the arena MINUS every
##     water/pit and PLUS every bridge deck, so the hole in the navmesh is the impassability; a 0.9 m rim stops
##     hulls without blocking sight. Axis-aligned only. Point-symmetric like everything else.
##   objectives: [{name, position [x, z], radius}]  (X3, round 6) what the match is fought over. Off-centre ones must
##     come in mirrored PAIRS. Absent = the single central control point, which is what Match hard-codes today.
## load_layout() returns the NORMALIZED layout: colliding props are appended to `obstacles` (with `size` resolved and
## `kit: true`), so every C4/C5 consumer that reads obstacles or the Obstacles node sees the kit unchanged.
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
## X6: the arenas `--arena=random` chooses from: only layouts that passed the swap-bases fairness control
## (_agents/arenas.md). A choice is seeded, so every peer given the same --seed builds the same arena.
const ROTATION := ["yard", "boulevard", "pit", "boneyard"]
const LAYOUT_DIR := "res://arenas"
## Obstacle types with a built-in collision size [x, height, z] (meters, before rotation). Other types need "size".
const OBSTACLE_SIZES := {"crate": [4.5, 3.0, 4.5], "wall": [18.0, 3.0, 1.5]}
## Extra bake margin past the seam so the half-mesh isn't shrunk by the agent
## radius where it meets its mirror (NavigationMesh.border_size, for chunked bakes).
const SEAM_BORDER := 2.5
## The stock Ground slab's thickness, and how far past the arena edge a carved floor still reaches.
const GROUND_THICKNESS := 1.0
const GROUND_MARGIN := 40.0
const HALF_EXTENT := Match.ARENA_HALF_SIZE + 40.0
## Mirror pairs must match to this many meters (and degrees).
const SYMMETRY_TOLERANCE := 0.01
## A spawn point must be this far from every obstacle's footprint: the widest spawn jitter plus half a hull.
const SPAWN_CLEARANCE := Match.SPAWN_JITTER_MAX_X + 2.5

## The layout the most recent Arena built. Match reads its spawns (static: spawn positions are static queries).
static var active: Dictionary = {}

## Set before the arena enters the tree to pick a layout in code (tests); else `--arena=`, else DEFAULT_LAYOUT.
@export var layout_name := ""
## Set before the arena enters the tree to supply a layout DIRECTLY, beating `layout_name` (tests that build a
## layout the repo does not ship). Deliberately not a temp file under arenas/: that would show up in
## `layout_names()` and make every all-layouts test depend on which test ran first.
@export var layout_override: Dictionary = {}
var layout: Dictionary = {}

@onready var navigation: NavigationRegion3D = $Navigation
@onready var obstacles_root: Node3D = $Obstacles
## Props with no collision (signs): visual only, never a navigation source.
var decor_root: Node3D


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	var loaded := {}
	if not layout_override.is_empty():
		var problem := validate(layout_override)
		loaded = {"error": problem} if problem != "" else {"layout": normalize(layout_override)}
	else:
		var wanted := layout_name if layout_name != "" else flags.text("arena", DEFAULT_LAYOUT)
		wanted = resolve_name(wanted, flags.integer("seed", -1) if flags.has("seed") else -1)
		loaded = load_layout(wanted)
	if loaded.has("error"):
		push_error("arena: %s; using %s" % [loaded["error"], DEFAULT_LAYOUT])
		loaded = load_layout(DEFAULT_LAYOUT)
	layout = loaded["layout"]
	active = layout
	_build_terrain()
	_build_obstacles()
	_build_decor()
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


## Round 7: water, pits and the bridges over them. The FLOOR is rebuilt as the arena minus every carving footprint
## plus every deck, because the hole in the navmesh is what makes the water impassable; the rim and the pan are
## deliberately NOT navigation sources, so they stop hulls without ever reaching the bake.
func _build_terrain() -> void:
	var terrain: Array = layout.get("terrain", [])
	if terrain.is_empty():
		return
	var half := float(layout["half_size"]) + GROUND_MARGIN
	# The stock Ground is one slab covering everything; a carved layout replaces it wholesale.
	var ground := get_node_or_null("Ground") as StaticBody3D
	if ground != null:
		var stock := ground.get_node_or_null("Collision") as CollisionShape3D
		if stock != null:
			stock.disabled = true
		for slab: Array in ArenaTerrain.slabs(half, terrain):
			ground.add_child(_slab(Vector3(slab[0], -GROUND_THICKNESS / 2.0, slab[1]),
					Vector3(slab[2], GROUND_THICKNESS, slab[3])))
	var rims := StaticBody3D.new()
	rims.name = "TerrainRims"
	var pans := StaticBody3D.new()
	pans.name = "TerrainPans"
	for entry: Dictionary in terrain:
		if not ArenaTerrain.carves(String(entry["kind"])):
			continue
		for slab: Array in ArenaTerrain.rim_slabs(entry, terrain):
			rims.add_child(_slab(Vector3(slab[0], ArenaTerrain.RIM_HEIGHT / 2.0, slab[1]),
					Vector3(slab[2], ArenaTerrain.RIM_HEIGHT, slab[3])))
		var depth := float(ArenaTerrain.KINDS[entry["kind"]]["pan_depth"])
		var rect: Array = entry["rect"]
		pans.add_child(_slab(Vector3(rect[0], -depth - GROUND_THICKNESS / 2.0, rect[1]),
				Vector3(rect[2], GROUND_THICKNESS, rect[3])))
	add_child(rims)
	add_child(pans)
	# Only if feel has the slot: VisualSlot pushes an engine error for a slot the theme lacks, and an arena that
	# errors because its water has no art yet is worse than water with no art. Same guard the kit props use.
	if GameTheme.slots.has("arena.terrain"):
		var dressing := VisualSlot.new()
		dressing.name = "TerrainVisual"
		dressing.slot = "arena.terrain"
		add_child(dressing)
		dressing.invoke("setup", [terrain])


func _slab(at: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	return shape


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
		body.add_child(_prop_visual(obstacle, size))
		obstacles_root.add_child(body)
		(body.get_node("Visual") as VisualSlot).invoke("setup", [obstacle])


## A `prop.<type>` slot for an obstacle or prop. Legacy sized obstacles scale their standard art; a kit prop the theme
## doesn't have yet borrows its fallback slot scaled to the prop's box, so collision is never invisible.
func _prop_visual(obstacle: Dictionary, size: Vector3) -> VisualSlot:
	var type := String(obstacle["type"])
	var visual := VisualSlot.new()
	visual.name = "Visual"
	visual.slot = "prop." + type
	var standard: Variant = OBSTACLE_SIZES.get(type)
	if ArenaKit.is_kit(type) and not GameTheme.slots.has(visual.slot):
		# Render dresses new kit slots (M2); until then a stand-in, or nothing for pure decoration.
		visual.slot = String(ArenaKit.PROPS[type].get("fallback", ""))
		standard = OBSTACLE_SIZES.get(visual.slot.trim_prefix("prop."))
	if standard != null:
		visual.scale = Vector3(size.x / standard[0], size.y / standard[1], size.z / standard[2])
	return visual


func _build_decor() -> void:
	if decor_root == null:
		decor_root = Node3D.new()
		decor_root.name = "Decor"
		add_child(decor_root)
	for child in decor_root.get_children():
		child.free()
	for prop: Dictionary in layout.get("props", []):
		if ArenaKit.collides(prop["type"]):
			continue
		var holder := Node3D.new()
		holder.name = "%s_%d" % [String(prop["type"]).capitalize().replace(" ", ""), decor_root.get_child_count()]
		holder.position = Vector3(prop["position"][0], 0.0, prop["position"][1])
		holder.rotation.y = deg_to_rad(float(prop.get("rotation_deg", 0.0)))
		holder.add_child(_prop_visual(prop, ArenaKit.size_of(prop)))
		decor_root.add_child(holder)
		(holder.get_node("Visual") as VisualSlot).invoke("setup", [prop])


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
## rotation: float (radians about +Y), height: float, type: String}]; M2 adds cover ("hard" | "low"), blocks_sight
## (taller than Perception.EYE_HEIGHT) and stack (1 for anything that isn't a container stack).
func cover_features() -> Array:
	var features: Array = []
	for obstacle: Dictionary in layout.get("obstacles", []):
		var size := obstacle_size(obstacle)
		var type := String(obstacle["type"])
		features.append({"position": Vector3(obstacle["position"][0], 0.0, obstacle["position"][1]), "size": size,
				"rotation": deg_to_rad(float(obstacle.get("rotation_deg", 0.0))), "height": size.y, "type": type,
				"cover": ArenaKit.cover_of(type) if ArenaKit.is_kit(type) else ("hard" if size.y >= Perception.EYE_HEIGHT else "low"),
				"blocks_sight": size.y >= Perception.EYE_HEIGHT, "stack": int(obstacle.get("stack", 1))})
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


## Round 7, contract D: the wall's INNER FACE as a convex polygon, world x/z, counter-clockwise. Handed to control
## and feel ONCE AT LOAD — control does its own ray-vs-polygon maths for the camera cutaway, feel builds walls,
## stands and gates from it instead of assuming a square. A per-frame call across a stream boundary would be a
## standing performance obligation and would make the arena's shape answerable to control's frame budget.
static func perimeter(data: Dictionary = active) -> PackedVector2Array:
	if data.is_empty():
		return PackedVector2Array()
	var shape: Dictionary = data.get("shape", {})
	return ArenaShape.vertices(String(shape.get("kind", ArenaShape.DEFAULT_KIND)), float(data["half_size"]))


## Every perimeter edge as {from, to, length_m, wall_height_m, spans: [{kind, from_m, to_m}]}. The spans say what
## is behind each STRETCH of wall, because control's occlusion test asks a positional question — a base side is
## stands, then the gate its army enters through, then stands again, and one value per edge cannot say that.
## Always contiguous, always covering the whole edge, so a consumer never handles a gap.
static func perimeter_edges(data: Dictionary = active) -> Array:
	if data.is_empty():
		return []
	return ArenaShape.edges(data.get("shape", {}), float(data["half_size"]))


## X1 (round 6): a TEST FIXTURE, not a shipping arena -- `arenas/maze.json` is one. It loads with `--arena=<name>`
## like any layout, but nothing that presents the game to a player should offer it: it has no art pass, no balance,
## and the announcer has no recording of its name.
##
## This is a flag rather than a note in prose because consumers need to *ask*. The maze broke the announcer's
## "every arena the booth can name" test on the day it landed, and the fix is not to record a name for it -- the
## booth should never say it -- but for that test to be able to tell a fixture from an arena.
static func is_fixture(data: Dictionary) -> bool:
	return bool(data.get("fixture", false))


## Every layout a player can be shown, fixtures excluded. Anything that offers arenas to a human wants this, not
## layout_names().
static func shipping_layout_names() -> PackedStringArray:
	var out := PackedStringArray()
	for layout_name in layout_names():
		var loaded := load_layout(layout_name)
		if loaded.has("layout") and not is_fixture(loaded["layout"]):
			out.append(layout_name)
	return out


## X3 (round 6): the layout's objectives as [{name, position: Vector3, radius: float}].
##
## **`Match` does not read this yet** -- it hard-codes `CONTROL_CENTER = Vector3.ZERO` and `CONTROL_RADIUS = 16.0`,
## and a layout's `control_point` reaches only the *dressing*, so today it is decorative. This helper exists so that
## change is a pure read-through with no behaviour change on any existing arena: a layout with no `objectives` list
## reports exactly the single central zone Match already hard-codes. See arena's request to combat in
## _agents/workstreams.md.
##
## Off-centre objectives must come in mirrored pairs (validate() enforces it): a single one off the centre line is
## owned by whichever base is nearer, which is the fairness invariant this whole file exists to protect.
static func objectives_of(data: Dictionary) -> Array:
	var result: Array = []
	for objective: Dictionary in data.get("objectives", []):
		result.append({"name": String(objective["name"]),
				"position": Vector3(objective["position"][0], 0.0, objective["position"][1]),
				"radius": float(objective["radius"])})
	if result.is_empty() and data.get("control_point") is Dictionary:
		result.append({"name": "control point", "position": Match.CONTROL_CENTER,
				"radius": float((data["control_point"] as Dictionary).get("radius", Match.CONTROL_RADIUS))})
	return result


## M2: a layout's lanes as [{name, points: PackedVector3Array (green's end first), width}] (Arena.active for the live one).
static func lanes_of(data: Dictionary) -> Array:
	var result: Array = []
	for lane: Dictionary in data.get("lanes", []):
		var points := PackedVector3Array()
		for point: Array in lane["points"]:
			points.append(Vector3(point[0], 0.0, point[1]))
		result.append({"name": String(lane["name"]), "points": points, "width": float(lane["width"])})
	return result


## M2: a layout's regions as [{name, kind, position: Vector3, radius}], only those of `kind` unless it's "".
static func regions_of(data: Dictionary, kind: String = "") -> Array:
	var result: Array = []
	for region: Dictionary in data.get("regions", []):
		if kind == "" or region["kind"] == kind:
			result.append({"name": String(region["name"]), "kind": String(region["kind"]),
					"position": Vector3(region["position"][0], 0.0, region["position"][1]), "radius": float(region["radius"])})
	return result


## M2: the spawn zone of the south (green) or north side: {center: Vector3, size: Vector2 (x width, z depth)}, or {}
## for a v1 layout.
static func spawn_zone_of(data: Dictionary, south: bool) -> Dictionary:
	var zone: Variant = data.get("spawn_zones", {}).get("green" if south else "rust")
	if not zone is Dictionary:
		return {}
	return {"center": Vector3(zone["center"][0], 0.0, zone["center"][1]), "size": Vector2(zone["size"][0], zone["size"][1])}


## The layout as the game runs it: v1 unchanged; v2's colliding props appended to `obstacles` with their size
## resolved and `kit: true`. Idempotent.
static func normalize(data: Dictionary) -> Dictionary:
	var runtime := data.duplicate(true)
	runtime["schema"] = int(data.get("schema", 1))
	var obstacles: Array = runtime["obstacles"].filter(func(o: Dictionary) -> bool: return not o.has("kit"))
	for prop: Dictionary in runtime.get("props", []):
		if not ArenaKit.collides(prop["type"]):
			continue
		var obstacle := prop.duplicate(true)
		var size := ArenaKit.size_of(prop)
		obstacle["size"] = [size.x, size.y, size.z]
		obstacle["kit"] = true
		obstacles.append(obstacle)
	runtime["obstacles"] = obstacles
	return runtime


## X6: "random" becomes a ROTATION arena (chosen by `seed`, or at random when it's negative); any other name is itself.
## Arena owns this roll (orchestrator ruling, 2026-09-17): launchers pass "random" through and read Arena.active["name"]
## back. A roll without a seed can't be replayed, so every launcher that shows or records a seed passes it as --seed.
static func resolve_name(name: String, seed_value: int) -> String:
	if name != "random":
		return name
	if seed_value < 0:
		return ROTATION[randi() % ROTATION.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "arena"])
	return ROTATION[rng.randi() % ROTATION.size()]


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
	return {"layout": normalize(data)}


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
		if ArenaKit.is_kit(obstacle["type"]) and not obstacle.has("kit"):
			return "'%s' is an arena kit prop: place it under 'props'" % obstacle["type"]
		if not obstacle.has("size") and not OBSTACLE_SIZES.has(obstacle["type"]):
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
	var v2_error := _validate_v2(data)
	if v2_error != "":
		return v2_error
	return _validate_spawn_clearance(data)


## Layout v2's keys: props, spawn zones, lanes, regions.
static func _validate_v2(data: Dictionary) -> String:
	if data.has("schema") and (not _is_number(data["schema"]) or not int(data["schema"]) in [1, 2]):
		return "schema must be 1 or 2"
	var props: Variant = data.get("props", [])
	if typeof(props) != TYPE_ARRAY:
		return "'props' must be a list"
	for prop in props:
		if typeof(prop) != TYPE_DICTIONARY or typeof(prop.get("type")) != TYPE_STRING:
			return "every prop needs a string 'type'"
		if not ArenaKit.is_kit(prop["type"]):
			return "unknown prop type '%s' (the kit has %s)" % [prop["type"], ", ".join(PackedStringArray(ArenaKit.PROPS.keys()))]
		if not _is_point(prop.get("position")):
			return "prop %s needs 'position' [x, z]" % prop["type"]
		if absf(float(prop["position"][0])) > Match.DRIVABLE_LIMIT or absf(float(prop["position"][1])) > Match.DRIVABLE_LIMIT:
			return "prop %s at %s is outside the arena" % [prop["type"], prop["position"]]
		if prop.has("rotation_deg") and not _is_number(prop["rotation_deg"]):
			return "rotation_deg must be a number"
		if prop.has("size"):
			return "prop %s has a fixed size (ArenaKit.PROPS); drop 'size' or use an obstacle" % prop["type"]
		if prop.has("stack"):
			var most := ArenaKit.max_stack(prop["type"])
			if typeof(prop["stack"]) not in [TYPE_INT, TYPE_FLOAT] or float(prop["stack"]) != floorf(float(prop["stack"])) \
					or int(prop["stack"]) < 1 or int(prop["stack"]) > most:
				return "prop %s: stack must be a whole number from 1 to %d" % [prop["type"], most]
	for prop: Dictionary in props:
		if not ArenaKit.collides(prop["type"]):
			continue
		var twin: bool = props.any(func(other: Dictionary) -> bool:
			return ArenaKit.collides(other["type"]) and int(other.get("stack", 1)) == int(prop.get("stack", 1)) \
					and _mirrors(_as_obstacle(prop), _as_obstacle(other)))
		if not twin:
			return "not point-symmetric: prop %s at %s has no 180° mirror at %s" % [prop["type"], prop["position"],
					[-float(prop["position"][0]), -float(prop["position"][1])]]
	var schema := int(data.get("schema", 1)) if _is_number(data.get("schema", 1)) else 1
	if data.has("spawn_zones") or schema >= 2:
		var zones: Variant = data.get("spawn_zones")
		if typeof(zones) != TYPE_DICTIONARY:
			return "schema 2 needs spawn_zones {green: {center [x, z], size [width, depth]}, rust: ...}"
		for side in ["green", "rust"]:
			var zone: Variant = zones.get(side)
			if typeof(zone) != TYPE_DICTIONARY or not _is_point(zone.get("center")) or not _is_point(zone.get("size")) \
					or float(zone["size"][0]) <= 0.0 or float(zone["size"][1]) <= 0.0:
				return "spawn_zones.%s needs center [x, z] and a positive size [width, depth]" % side
		if absf(float(zones["green"]["center"][0]) + float(zones["rust"]["center"][0])) > SYMMETRY_TOLERANCE \
				or absf(float(zones["green"]["center"][1]) + float(zones["rust"]["center"][1])) > SYMMETRY_TOLERANCE \
				or not is_equal_approx(float(zones["green"]["size"][0]), float(zones["rust"]["size"][0])) \
				or not is_equal_approx(float(zones["green"]["size"][1]), float(zones["rust"]["size"][1])):
			return "not point-symmetric: spawn_zones.rust must mirror spawn_zones.green"
		for side in ["green", "rust"]:
			var zone: Dictionary = zones[side]
			for spot: Array in data["spawns"][side]:
				if absf(float(spot[0]) - float(zone["center"][0])) > float(zone["size"][0]) / 2.0 + SYMMETRY_TOLERANCE \
						or absf(float(spot[1]) - float(zone["center"][1])) > float(zone["size"][1]) / 2.0 + SYMMETRY_TOLERANCE:
					return "spawns.%s point %s is outside its spawn zone" % [side, spot]
	var shape_error := ArenaShape.validate(data.get("shape", {}), float(data["half_size"]))
	if shape_error != "":
		return shape_error
	var terrain: Variant = data.get("terrain", [])
	if typeof(terrain) != TYPE_ARRAY:
		return "'terrain' must be a list"
	for entry in terrain:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("kind")) != TYPE_STRING or typeof(entry.get("name")) != TYPE_STRING:
			return "every terrain entry needs a string 'kind' and 'name'"
		if not ArenaTerrain.is_kind(entry["kind"]):
			return "unknown terrain kind '%s' (have %s)" % [entry["kind"], ", ".join(PackedStringArray(ArenaTerrain.KINDS.keys()))]
		var rect: Variant = entry.get("rect")
		if typeof(rect) != TYPE_ARRAY or rect.size() != 4 or not rect.all(func(v: Variant) -> bool: return _is_number(v)):
			return "terrain %s needs 'rect' [centre_x, centre_z, width, depth]" % entry["name"]
		if float(rect[2]) <= 0.0 or float(rect[3]) <= 0.0:
			return "terrain %s needs a positive width and depth" % entry["name"]
	for entry: Dictionary in terrain:
		# Point-symmetric like everything else: a river on one side and not the other decides the match.
		var twin: bool = terrain.any(func(other: Dictionary) -> bool:
			return other["kind"] == entry["kind"] \
					and absf(float(other["rect"][0]) + float(entry["rect"][0])) <= SYMMETRY_TOLERANCE \
					and absf(float(other["rect"][1]) + float(entry["rect"][1])) <= SYMMETRY_TOLERANCE \
					and is_equal_approx(float(other["rect"][2]), float(entry["rect"][2])) \
					and is_equal_approx(float(other["rect"][3]), float(entry["rect"][3])))
		if not twin:
			return "not point-symmetric: terrain %s at %s has no 180° mirror" % [entry["name"], [entry["rect"][0], entry["rect"][1]]]
		if not ArenaTerrain.is_deck(String(entry["kind"])):
			continue
		# A deck must actually bridge something, and be wide enough to leave navmesh after the agent radius.
		var narrow: float = minf(float(entry["rect"][2]), float(entry["rect"][3]))
		if narrow < ArenaTerrain.MIN_DECK_M:
			return "bridge %s is %.1f m across: under %.1f m the %0.1f m agent radius leaves no navmesh on it" \
					% [entry["name"], narrow, ArenaTerrain.MIN_DECK_M, 2.0]
		var crosses: bool = terrain.any(func(other: Dictionary) -> bool:
			return ArenaTerrain.carves(String(other["kind"])) \
					and ArenaTerrain.overlaps(ArenaTerrain.bounds(entry), ArenaTerrain.bounds(other)))
		if not crosses:
			return "bridge %s crosses no water or pit (a bridge over nothing is just floor)" % entry["name"]
	if data.has("fixture") and typeof(data["fixture"]) != TYPE_BOOL:
		return "'fixture' must be true or false"
	var objectives: Variant = data.get("objectives", [])
	if typeof(objectives) != TYPE_ARRAY:
		return "'objectives' must be a list"
	for objective in objectives:
		if typeof(objective) != TYPE_DICTIONARY or typeof(objective.get("name")) != TYPE_STRING or not _is_point(objective.get("position")):
			return "every objective needs a string 'name' and a 'position' [x, z]"
		if absf(float(objective["position"][0])) > Match.DRIVABLE_LIMIT or absf(float(objective["position"][1])) > Match.DRIVABLE_LIMIT:
			return "objective %s at %s is outside the arena" % [objective["name"], objective["position"]]
		if not _is_number(objective.get("radius")) or float(objective["radius"]) <= 0.0:
			return "objective %s needs a positive 'radius'" % objective["name"]
	# An off-centre objective is unfair on its own -- whichever base is nearer owns it -- so they come in mirrored
	# PAIRS, or sit on the centre. This is the whole reason the schema is a list and not a position.
	for objective: Dictionary in objectives:
		var twin: bool = objectives.any(func(other: Dictionary) -> bool:
			return is_equal_approx(float(other["radius"]), float(objective["radius"])) \
					and absf(float(other["position"][0]) + float(objective["position"][0])) <= SYMMETRY_TOLERANCE \
					and absf(float(other["position"][1]) + float(objective["position"][1])) <= SYMMETRY_TOLERANCE)
		if not twin:
			return "not point-symmetric: objective %s at %s has no 180° mirror at %s (an off-centre objective must " \
					% [objective["name"], objective["position"], [-float(objective["position"][0]), -float(objective["position"][1])]] \
					+ "come in a mirrored pair, or the nearer base owns it)"
	var lanes: Variant = data.get("lanes", [])
	if typeof(lanes) != TYPE_ARRAY:
		return "'lanes' must be a list"
	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY or typeof(lane.get("name")) != TYPE_STRING or typeof(lane.get("points")) != TYPE_ARRAY \
				or lane["points"].size() < 2 or not lane["points"].all(func(v: Variant) -> bool: return _is_point(v)):
			return "every lane needs a string 'name' and at least two 'points' [x, z]"
		if not _is_number(lane.get("width")) or float(lane["width"]) <= 0.0:
			return "lane %s needs a positive 'width'" % lane["name"]
	for lane: Dictionary in lanes:
		if not lanes.any(func(other: Dictionary) -> bool: return _lane_mirrors(lane, other)):
			return "not point-symmetric: lane %s has no 180° mirror (the same route seen from the other base)" % lane["name"]
	var regions: Variant = data.get("regions", [])
	if typeof(regions) != TYPE_ARRAY:
		return "'regions' must be a list"
	for region in regions:
		if typeof(region) != TYPE_DICTIONARY or typeof(region.get("name")) != TYPE_STRING or not _is_point(region.get("position")):
			return "every region needs a string 'name' and a 'position' [x, z]"
		if not String(region.get("kind", "")) in ArenaKit.REGION_KINDS:
			return "region %s: unknown kind '%s' (have %s)" % [region["name"], region.get("kind", ""), ", ".join(PackedStringArray(ArenaKit.REGION_KINDS))]
		if not _is_number(region.get("radius")) or float(region["radius"]) <= 0.0:
			return "region %s needs a positive 'radius'" % region["name"]
	for region: Dictionary in regions:
		var mirrored: bool = regions.any(func(other: Dictionary) -> bool:
			return other["kind"] == region["kind"] and is_equal_approx(float(other["radius"]), float(region["radius"])) \
					and absf(float(other["position"][0]) + float(region["position"][0])) <= SYMMETRY_TOLERANCE \
					and absf(float(other["position"][1]) + float(region["position"][1])) <= SYMMETRY_TOLERANCE)
		if not mirrored:
			return "not point-symmetric: region %s (%s) has no 180° mirror" % [region["name"], region["kind"]]
	return ""


## No spawn point may sit in or against cover: a vehicle spawned inside a container is stuck for the match.
static func _validate_spawn_clearance(data: Dictionary) -> String:
	var blockers: Array = data["obstacles"].filter(func(o: Dictionary) -> bool: return not o.has("kit"))
	for prop: Dictionary in data.get("props", []):
		if ArenaKit.collides(prop["type"]):
			blockers.append(_as_obstacle(prop))
	for side in ["green", "rust"]:
		for spot: Array in data["spawns"][side]:
			var point := Vector2(float(spot[0]), float(spot[1]))
			for obstacle: Dictionary in blockers:
				var clearance := ArenaKit.distance_to_footprint(point, Vector2(float(obstacle["position"][0]), float(obstacle["position"][1])),
						obstacle_size(obstacle), float(obstacle.get("rotation_deg", 0.0)))
				if clearance < SPAWN_CLEARANCE:
					return "spawns.%s point %s is %.1f m from %s at %s (spawns need %.1f m clear)" % [side, spot, clearance,
							obstacle["type"], obstacle["position"], SPAWN_CLEARANCE]
	return ""


## A prop as an obstacle dictionary with its size resolved (for symmetry and clearance checks).
static func _as_obstacle(prop: Dictionary) -> Dictionary:
	var obstacle := prop.duplicate()
	var size := ArenaKit.size_of(prop)
	obstacle["size"] = [size.x, size.y, size.z]
	return obstacle


## Whether `b` is lane `a` seen from the other base: every point negated, in reverse order, the same width.
static func _lane_mirrors(a: Dictionary, b: Dictionary) -> bool:
	var count: int = a["points"].size()
	if b["points"].size() != count or not is_equal_approx(float(a["width"]), float(b["width"])):
		return false
	for i in count:
		var p: Array = a["points"][i]
		var q: Array = b["points"][count - 1 - i]
		if absf(float(p[0]) + float(q[0])) > SYMMETRY_TOLERANCE or absf(float(p[1]) + float(q[1])) > SYMMETRY_TOLERANCE:
			return false
	return true


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
