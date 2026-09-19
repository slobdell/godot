class_name ArenaKitGallery
extends Node3D
## Arena kit gallery (`make arena-kit-gallery`, assets X1/X2): a container yard (20 ft and 40 ft, stacks of 1–3, open
## doors, each faction's paint and stencils) and giant ad screens on two channels under the cyberpunk arena's night lighting, placed through the real
## `prop.<type>` visual slots and `setup(obstacle)` the way the Arena places layout obstacles. Captures several views in
## one run, including the 200 m orthographic tactical overview (orientation trip-up 46). Visual only.
## Flags: --shots-dir=<abs dir> (saves arena-kit-<view>.png for every view, then quits) [--views=a,b] [--theme=NAME]
##        --measure: prints ARENA_KIT_MEASURE lines (draw calls and primitives from the yard view) with the kit hidden,
##        with containers, and with containers and screens, then quits (assets X6)

## [type, x, z, rotation_deg, extra obstacle keys]
const YARD := [
	# A two-high wall of 40 ft containers: blocks line of sight (game_design.md, stack height is a design lever).
	["container_40", -18.0, -22.0, 0.0, {"stack": 2}],
	["container_40", -5.6, -22.0, 0.0, {"stack": 2, "doors": "open"}],
	["container_40", 6.8, -22.0, 0.0, {"stack": 2}],
	# Stacks of one, two and three 20 ft containers, one with its doors open.
	["container_20", -16.0, -8.0, 0.0, {"stack": 1, "doors": "open"}],
	["container_20", -8.0, -8.0, 0.0, {"stack": 2}],
	["container_20", 0.0, -8.0, 0.0, {"stack": 3}],
	["container_20", 8.0, -8.0, 90.0, {"stack": 1, "doors": "ajar"}],
	# One row per owner.
	["container_20", -16.0, 4.0, 0.0, {"faction": "law"}],
	["container_20", -8.0, 4.0, 0.0, {"faction": "law", "stack": 2}],
	["container_20", 0.0, 4.0, 0.0, {"faction": "law", "stencil": "evidence", "doors": "open"}],
	["container_40", -12.0, 14.0, 0.0, {"faction": "syndicate"}],
	["container_40", 2.0, 14.0, 0.0, {"faction": "syndicate", "stencil": "organ_futures"}],
	["container_20", -16.0, 25.0, 12.0, {"faction": "gangs"}],
	["container_20", -7.0, 26.0, -8.0, {"faction": "gangs", "stack": 2}],
	["container_20", 2.0, 24.0, 20.0, {"faction": "condemned", "stencil": "prison"}],
	["container_20", 10.0, 25.0, 0.0, {"faction": "condemned", "stencil": "hazard", "stack": 2}],
	# Giant screens behind the yard, turned to face it; the right one runs a second channel.
	["ad_screen", -10.0, -36.0, 180.0, {}],
	["ad_screen", 12.0, -34.0, 200.0, {"channel": "odds"}],
	# Round 7: a city street (prop.block, CityBlock): blocks of different sizes and tiers either side of a 14 m road.
	["block", 52.0, -40.0, 0.0, {"size": [30, 34, 22], "tiers": 3, "seed": 1}],
	["block", 52.0, -10.0, 0.0, {"size": [30, 16, 26], "tiers": 1, "seed": 2}],
	["block", 52.0, 18.0, 0.0, {"size": [30, 24, 18], "tiers": 2, "seed": 3}],
	["block", 88.0, -38.0, 0.0, {"size": [26, 22, 26], "tiers": 2, "seed": 4}],
	["block", 88.0, -6.0, 0.0, {"size": [26, 40, 24], "tiers": 3, "seed": 5}],
	["block", 88.0, 22.0, 0.0, {"size": [26, 12, 20], "tiers": 1, "seed": 6}],
]
## view → [camera position, look-at point, fov (0 = orthographic, size in m)]
const VIEWS := {
	"close": [Vector3(13.5, 3.2, 10.5), Vector3(0.0, 1.6, 3.5), 45.0],
	"yard": [Vector3(26.0, 17.0, 34.0), Vector3(-3.0, 1.0, 1.0), 50.0],
	"doors": [Vector3(-8.5, 2.4, -2.5), Vector3(-13.6, 1.3, -8.0), 55.0],
	"screens": [Vector3(-2.0, 2.2, -14.0), Vector3(-6.0, 12.0, -36.0), 62.0],
	"gate": [Vector3(92.0, 9.0, 30.0), Vector3(126.0, 4.0, 0.0), 60.0],
	"overview": [Vector3(0.0, 200.0, 0.0001), Vector3.ZERO, 0.0],
	# Round 7: the whole venue from high and oblique (for SHAPE=hexagon).
	"venue": [Vector3(0.0, 150.0, 230.0), Vector3(0.0, 0.0, -10.0), 55.0],
	# Round 7: the city street at the lead's camera (21 degrees, 49 m, FOV 35) and from higher up.
	"city": [Vector3(70.0, 17.6, 49.0), Vector3(70.0, 0.0, 3.0), 35.0],
	"city_high": [Vector3(20.0, 60.0, 60.0), Vector3(70.0, 0.0, -10.0), 50.0],
}

## Round 7: a shaped perimeter for the gallery, with feel's agreed gates in the middle of each base side (the edge
## facing each base) and stands everywhere else.
static func venue_shape(kind: String, apothem: float) -> Dictionary:
	var edges := ArenaShape.edges({"kind": kind}, apothem)
	var authored := []
	for edge: Dictionary in edges:
		var length := float(edge["length_m"])
		var mid: Vector2 = ((edge["from"] as Vector2) + (edge["to"] as Vector2)) / 2.0
		if absf(mid.x) < 1.0:  # the side facing a base
			authored.append({"spans": [{"kind": "stands", "to_m": length / 2.0 - 15.0}, {"kind": "gate", "to_m": length / 2.0 + 15.0},
					{"kind": "stands", "to_m": length}]})
		else:
			authored.append({"spans": [{"kind": "stands", "to_m": length}]})
	return {"kind": kind, "edges": authored}


var camera := Camera3D.new()
var _flags: LaunchFlags


func _ready() -> void:
	_flags = LaunchFlags.from_environment()
	if not _flags.has("theme"):
		GameTheme.use("cyberpunk")
	for slot_name in ["arena.environment", "arena.dressing"]:
		var slot := VisualSlot.new()
		slot.slot = slot_name
		add_child(slot)
		if slot_name == "arena.dressing" and _flags.has("gallery-shape"):
			slot.invoke("setup", [{"name": "gallery", "half_size": 120.0, "obstacles": [],
					"shape": ArenaKitGallery.venue_shape(_flags.text("gallery-shape"), 120.0)}])
	var yard := Node3D.new()
	yard.name = "Yard"
	add_child(yard)
	for entry: Array in YARD:
		var body := Node3D.new()
		body.position = Vector3(entry[1], 0.0, entry[2])
		body.rotation.y = deg_to_rad(entry[3])
		yard.add_child(body)
		var visual := VisualSlot.new()
		visual.slot = "prop." + String(entry[0])
		body.add_child(visual)
		var obstacle: Dictionary = {"type": entry[0], "position": [entry[1], entry[2]], "rotation_deg": entry[3]}
		obstacle.merge(entry[4])
		visual.invoke("setup", [obstacle])
	add_child(camera)
	camera.current = true
	_view("yard")
	var overlay := PerfOverlay.new()
	add_child(overlay)
	overlay.extra = "ARENA KIT GALLERY (%s)" % GameTheme.theme_name
	if _flags.has("measure"):
		_measure()
	elif _flags.has("shots-dir"):
		_capture_all(_flags.text("shots-dir"))


func _view(view: String) -> void:
	var spec: Array = VIEWS[view]
	camera.position = spec[0]
	camera.look_at(spec[1], Vector3.UP if view != "overview" else Vector3.FORWARD)
	if float(spec[2]) > 0.0:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = spec[2]
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 90.0
	camera.far = 600.0


func _capture_all(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var views := _flags.text("views", ",".join(VIEWS.keys())).split(",")
	await get_tree().create_timer(2.0).timeout
	var failed := 0
	for view in views:
		_view(view)
		for i in 6:
			await RenderingServer.frame_post_draw
		var path := folder.path_join("arena-kit-%s.png" % view)
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("screenshot saved: " if err == OK else "screenshot failed: ", path)
		failed += int(err != OK)
	get_tree().quit(failed)


func _measure() -> void:
	_view("yard")
	await get_tree().create_timer(2.0).timeout
	var yard := get_node("Yard") as Node3D
	var screens := find_children("AdScreen*", "Node3D", true, false) + yard.get_children().filter(
			func(body: Node) -> bool: return body.get_child(0) is VisualSlot and (body.get_child(0) as VisualSlot).slot == "prop.ad_screen")
	for stage in ["none", "containers", "containers+screens"]:
		ContainerYard.for_node(self).visible = stage != "none"
		for node: Node3D in screens:
			node.visible = stage == "containers+screens"
		for i in 8:
			await RenderingServer.frame_post_draw
		print("ARENA_KIT_MEASURE stage=%s draws=%d primitives=%d" % [stage,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
