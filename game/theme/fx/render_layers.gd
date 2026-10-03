class_name RenderLayers
extends RefCounted
## Render's switch table (round 16, R2): every piece of the picture by name, so its cost can be measured by REMOVAL
## within one run (contract C16.3) -- `RenderSplit` alternates `all` with each of these, and play's perf harness can
## call the same table (`RenderLayers.apply(tree, name)`) for any name it does not know itself.
##
## A layer hides or stops one thing and records how to put it back; nothing here is a setting that ships. Layers that
## STOP work rather than hide it (`no_ads`, `no_live_feed`, `no_show`) measure the work a frame does for something that
## is still on screen; the picture freezes or reverts while they run, which is fine for a measurement and never for
## a frame he sees.
##
##   var undo := RenderLayers.apply(get_tree(), "no_water")   # [] when the scene has no such thing
##   RenderLayers.restore(undo)

const NAMES := [
	"no_venue",       # stands, gates, ad screens, neon signs, crowd (arena_dressing.set_venue_visible)
	"no_stands",      # the stands alone (kit modules and their instanced copies)
	"no_crowd",       # the crowd's MultiMesh
	"no_screens",     # the ad screens' quads and their ground spill
	"no_ads",         # the ad channels' 2D viewports stop redrawing (what the screens show freezes)
	"no_live_feed",   # the live feed's camera viewports stop rendering
	"no_airship",     # both airships, hull and screens
	"no_water",       # water and pit surfaces (TerrainVisual)
	"no_sky",         # night sky dome + city skyline
	"no_ground",      # the arena floor
	"no_perimeter",   # walls, towers, beams and glow pools (structures that are not venue, blocks or airship)
	"no_blocks",      # city blocks (the Terminus)
	"no_fogvis",      # the fog-of-war ground sheet
	"no_haze",        # heat haze over burning wrecks
	"no_show",        # the light show writes identity (Show.driving = false)
	"no_effects",     # tracers, bursts, decals, streaks, beams, haze, order marks, dust
	"no_pool_lights", # the pooled OmniLights
	"no_vehicles",    # every unit's visual
	"no_hud",         # every CanvasLayer
	"no_glow",
	"no_shadows",
	"no_env_fog",     # the environment's fog
]

## The priced levers (round 16, R8): each CHANGES THE PICTURE and is OFF unless the lead taps it on his page. Measured
## here like any layer; shipped only through `--render-levers=<names>` (RenderLevers), never as a default.
const LEVERS := ["scale_085", "scale_075", "glow_one", "crowd_medium", "lights_2", "unlit_stands", "no_env_fog", "no_haze"]

## Within-run A/B layers (round 16): not removals but the code as it was before a render change, swapped in for one
## phase, so a change's saving is read against `all` on the same frame. Ask for them by name; not in NAMES.
const BEFORE := {
	"ground_r15": "res://game/theme/fx/shaders/reference/arena_ground_unlit_r15.gdshader",
	"fogvis_r15": "res://game/theme/fx/shaders/reference/fog_of_war_r15.gdshader",
	"haze_world_box": "",
	"sky_r15": "",
	"yards_r15": "",
	"instanced_r15": "",
}


static func apply(tree: SceneTree, layer: String) -> Array:
	var undo: Array = []
	var root := tree.root
	var scene := tree.current_scene
	var fx := FxWorld.existing()
	var dressing := _dressing(scene)
	match layer:
		"no_venue":
			if dressing != null and dressing.has_method("set_venue_visible"):
				dressing.call("set_venue_visible", false)
				undo.append([dressing, "@set_venue_visible", true])
		"no_stands":
			for node in _structure_children(dressing):
				if _is_stands(node):
					_hide(node, undo)
		"no_crowd":
			for crowd in root.find_children("*", "CrowdSystem", true, false):
				if (crowd as CrowdSystem).multimesh_instance != null:
					_put((crowd as CrowdSystem).multimesh_instance, "visible", false, undo)
		"no_screens":
			for node in root.find_children("AdScreen*", "Node3D", true, false):
				_hide(node, undo)
			for node in root.find_children("Spill", "MeshInstance3D", true, false):
				_hide(node, undo)
		"no_ads":
			for channel in root.find_children("AdBroadcast_*", "Node", true, false):
				var vp: SubViewport = channel.get("viewport")
				if vp != null:
					_put(channel, "process_mode", Node.PROCESS_MODE_DISABLED, undo)
					_put(vp, "render_target_update_mode", SubViewport.UPDATE_DISABLED, undo)
		"no_live_feed":
			for feed in root.find_children("*", "LiveFeed", true, false):
				_put(feed, "enabled", false, undo)
		"no_airship":
			for node in root.find_children("*", "SyndicateAdAirship", true, false):
				_hide(node, undo)
			for node in root.find_children("*", "SyndicateAirship", true, false):
				_hide(node, undo)
		"no_water":
			for visual in root.find_children("*", "TerrainVisual", true, false):
				for part in [visual.get("water"), visual.get("pits")]:
					if part is Node3D:
						_hide(part, undo)
		"no_sky":
			for node in root.find_children("*", "NightSky", true, false):
				_hide(node, undo)
			for node in root.find_children("*", "CitySkyline", true, false):
				_hide(node, undo)
		"no_ground":
			if dressing != null and dressing.get("ground") is Node3D:
				_hide(dressing.get("ground"), undo)
		"no_perimeter":
			for node in _structure_children(dressing):
				var n := String(node.name)
				if node is CityBlock or node is SyndicateAirship or node is SyndicateAdAirship or _is_stands(node) \
						or n.begins_with("Gate") or n.begins_with("AdScreen") or n == "NeonSigns" or node is CrowdSystem \
						or (n.begins_with("Instanced_") and "gate" in n.to_lower()) or n.begins_with("Barricade"):
					continue
				_hide(node, undo)
		"no_blocks":
			for node in root.find_children("*", "CityBlock", true, false):
				_hide(node, undo)
		"no_fogvis":
			var fog := scene.get_node_or_null("FogOfWar") if scene != null else null
			if fog is Node3D:
				_hide(fog, undo)
		"no_haze":
			if fx != null:
				_hide(fx.haze, undo)
		"no_show":
			for show in root.find_children("*", "Show", true, false):
				_put(show, "driving", false, undo)
		"no_effects":
			if fx != null:
				for system in [fx.tracers, fx.bursts, fx.decals, fx.streaks, fx.beams, fx.haze, fx.order_feedback, fx.motion]:
					if system is Node3D:
						_hide(system, undo)
		"no_pool_lights":
			if fx != null:
				_put(fx.lights, "enabled", false, undo)
		"no_vehicles":
			var game_match := scene.get_node_or_null("Match") if scene != null else null
			var tanks: Node = game_match.get("tanks") if game_match != null else null
			if tanks != null:
				for child in tanks.get_children():
					if child is Node3D:
						_hide(child, undo)
		"no_hud":
			for layer_node in root.find_children("*", "CanvasLayer", true, false):
				if not (layer_node is PerfOverlay):
					_put(layer_node, "visible", false, undo)
		"no_glow", "no_env_fog":
			for world in root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					_put(environment, "glow_enabled" if layer == "no_glow" else "fog_enabled", false, undo)
		"no_shadows":
			for light in root.find_children("*", "DirectionalLight3D", true, false):
				_put(light, "shadow_enabled", false, undo)
		"ground_r15":
			var floor_material: Variant = (dressing.get("ground") as Node).get("material") if dressing != null and dressing.get("ground") is Node else null
			if floor_material is ShaderMaterial:
				_put(floor_material, "shader", load(BEFORE[layer]), undo)
		"fogvis_r15":
			var fog_sheet := scene.get_node_or_null("FogOfWar") if scene != null else null
			var sheet: Variant = fog_sheet.get("visual") if fog_sheet != null else null
			var fog_material: Variant = (sheet as GeometryInstance3D).material_override if sheet is GeometryInstance3D else null
			if fog_material is ShaderMaterial:
				_put(fog_material, "shader", load(BEFORE[layer]), undo)
		"sky_r15", "sky_prio_lo":
			# The sky dome, skyline and city ground at render priority 0, as before round 16 (they now draw last).
			for node in root.find_children("*", "NightSky", true, false) + root.find_children("*", "CitySkyline", true, false) \
					+ root.find_children("CityGround", "MeshInstance3D", true, false):
				var sky_material: Variant = (node as GeometryInstance3D).material_override
				if sky_material is Material:
					_put(sky_material, "render_priority", 0 if layer == "sky_r15" else -128, undo)
		"stands_no_normal", "stands_no_orm":
			# Experiment (round 16, R4): what the stands' normal map / ORM texture costs at his pose.
			for node in _structure_children(dressing):
				if not _is_stands(node):
					continue
				for mesh_node in [node] + node.find_children("*", "GeometryInstance3D", true, false):
					for material in _materials_of(mesh_node):
						if material is BaseMaterial3D:
							if layer == "stands_no_normal":
								_put(material, "normal_enabled", false, undo)
							else:
								_put(material, "roughness_texture", null, undo)
								_put(material, "metallic_texture", null, undo)
								_put(material, "ao_enabled", false, undo)
		"lights_spare_venue":
			# Experiment (round 16): the pooled OmniLights no longer touch the stands and the crowd. In the Compatibility
			# renderer every light whose sphere meets an object's box draws that WHOLE object again, and the stands and
			# crowd are each one MultiMesh around the arena -- so one explosion anywhere re-drew all of them.
			const SPARE := 1 << 19
			var spared: Array = root.find_children("*", "CrowdSystem", true, false).map(func(c: Node) -> Node: return (c as CrowdSystem).multimesh_instance)
			for node in _structure_children(dressing):
				if _is_stands(node):
					spared.append(node)
					spared.append_array(node.find_children("*", "GeometryInstance3D", true, false))
			for node in spared:
				if node is VisualInstance3D:
					_put(node, "layers", SPARE, undo)
			if fx != null:
				for light: OmniLight3D in fx.lights.lights:
					_put(light, "light_cull_mask", light.light_cull_mask & ~SPARE, undo)
		"lights_vehicles_only":
			# Experiment (round 16): the upper bound of what the pooled lights' extra passes over STATIC geometry cost --
			# everything but the vehicles and the effects is taken out of their reach.
			const SPARE_ALL := 1 << 19
			var game_match_node := scene.get_node_or_null("Match") if scene != null else null
			var tanks_root: Node = game_match_node.get("tanks") if game_match_node != null else null
			for node in root.find_children("*", "GeometryInstance3D", true, false):
				if (tanks_root != null and tanks_root.is_ancestor_of(node)) or (fx != null and fx.is_ancestor_of(node)):
					continue
				_put(node, "layers", SPARE_ALL, undo)
			if fx != null:
				for light: OmniLight3D in fx.lights.lights:
					_put(light, "light_cull_mask", light.light_cull_mask & ~SPARE_ALL, undo)
		"lights_spare_yards", "lights_spare_perimeter", "lights_spare_terrain", "lights_spare_blocks":
			# Experiment (round 16): which static group's light passes cost (see lights_vehicles_only).
			const SPARE_SOME := 1 << 19
			var wanted_paths: Array = {"lights_spare_yards": ["/root/KitYard", "/root/ContainerYard"],
					"lights_spare_perimeter": ["Structures/Perimeter", "Structures/Tower", "Structures/Instanced_kit_floodlight",
						"Structures/Instanced_kit_gate", "Structures/Gate", "Structures/Barricade"],
					"lights_spare_terrain": ["TerrainVisual", "LaneMarks"],
					"lights_spare_blocks": ["Arena/Obstacles"]}[layer]
			for node in root.find_children("*", "GeometryInstance3D", true, false):
				var path := String(node.get_path())
				for wanted: String in wanted_paths:
					if wanted in path:
						_put(node, "layers", SPARE_SOME, undo)
						break
			if fx != null:
				for light: OmniLight3D in fx.lights.lights:
					_put(light, "light_cull_mask", light.light_cull_mask & ~SPARE_SOME, undo)
		"yards_r15":
			# The yards as round 15 drew them: ONE MultiMesh per lit kind across the whole arena, built here from the
			# yard's own entries with the same mesh and material, the per-cell draws hidden.
			for yard_name in ["KitYard", "ContainerYard"]:
				var yard := root.get_node_or_null(yard_name)
				if yard == null:
					continue
				var by_kind := {}
				for draw_node in yard.get_children():
					var cell_draw := draw_node as MultiMeshInstance3D
					if cell_draw == null or not cell_draw.has_meta("cell") or not cell_draw.visible:
						continue
					by_kind[cell_draw.get_meta("kind")] = cell_draw.multimesh
					_put(cell_draw, "visible", false, undo)
				var entries: Dictionary = yard.get("_entries")
				for kind: String in by_kind:
					var source: MultiMesh = by_kind[kind]
					var whole := MultiMesh.new()
					whole.transform_format = MultiMesh.TRANSFORM_3D
					whole.use_custom_data = source.use_custom_data
					whole.use_colors = source.use_colors
					whole.mesh = source.mesh
					var mine := entries.values().filter(func(e: Array) -> bool: return e[0] == kind)
					FxMultiMesh.resize(whole, mine.size())
					for i in mine.size():
						whole.set_instance_transform(i, mine[i][1])
						if whole.use_custom_data:
							whole.set_instance_custom_data(i, mine[i][2])
					var merged := MultiMeshInstance3D.new()
					merged.name = "R15_" + kind
					merged.multimesh = whole
					FxMultiMesh.never_interpolated(merged)
					yard.add_child(merged)
					undo.append([merged, "visible", false])  # left hidden in the tree when restored (a measurement only)
		"instanced_r15":
			# The venue's instanced kit models as round 15 drew them: one MultiMesh per mesh around the whole arena,
			# rebuilt from the per-cell draws' recorded transforms, the cell draws hidden.
			var by_mesh := {}
			for node in _structure_children(dressing):
				var cell_draw := node as MultiMeshInstance3D
				if cell_draw == null or not String(cell_draw.name).contains("_cell_") or not cell_draw.visible:
					continue
				var mesh: Mesh = cell_draw.multimesh.mesh
				(by_mesh.get_or_add(mesh, []) as Array).append_array(cell_draw.get_meta("transforms", []))
				_put(cell_draw, "visible", false, undo)
			for mesh: Mesh in by_mesh:
				var all_placed: Array = by_mesh[mesh]
				var whole := MultiMesh.new()
				whole.transform_format = MultiMesh.TRANSFORM_3D
				whole.mesh = mesh
				FxMultiMesh.resize(whole, all_placed.size())
				for i in all_placed.size():
					whole.set_instance_transform(i, all_placed[i])
				var merged := MultiMeshInstance3D.new()
				merged.name = "R15_instanced"
				merged.multimesh = whole
				FxMultiMesh.never_interpolated(merged)
				(dressing.get("structures") as Node).add_child(merged)
				undo.append([merged, "visible", false])
		"scale_085", "scale_075":
			_put(root, "scaling_3d_scale", 0.85 if layer == "scale_085" else 0.75, undo)
		"glow_one":
			# Glow on its tight level (3) only: the wide halo (level 5) goes.
			for world in root.find_children("*", "WorldEnvironment", true, false):
				var env := (world as WorldEnvironment).environment
				if env != null:
					_put(env, "glow_levels/5", 0.0, undo)
		"crowd_medium":
			for crowd in root.find_children("*", "CrowdSystem", true, false):
				var crowd_mm: MultiMesh = (crowd as CrowdSystem).multimesh_instance.multimesh
				if crowd_mm != null:
					_put(crowd_mm, "visible_instance_count", mini(crowd_mm.instance_count, int(CrowdSystem.PER_TIER[FxQuality.Tier.MEDIUM])), undo)
		"lights_2":
			if fx != null:
				undo.append([fx.lights, "@resize", fx.lights.lights.size()])
				fx.lights.resize(2)
		"unlit_stands":
			for node in _structure_children(dressing):
				if not _is_stands(node):
					continue
				for mesh_node in [node] + node.find_children("*", "GeometryInstance3D", true, false):
					for material in _materials_of(mesh_node):
						if material is BaseMaterial3D:
							_put(material, "shading_mode", BaseMaterial3D.SHADING_MODE_UNSHADED, undo)
		"haze_world_box":
			if fx != null:
				_put(fx.haze, "tight_box", false, undo)
				_put(fx.haze.get("_material"), "render_priority", 0, undo)
		_:
			push_warning("RenderLayers: no layer called '%s' (known: %s)" % [layer, ", ".join(NAMES)])
	return undo


static func restore(undo: Array) -> void:
	for i in range(undo.size() - 1, -1, -1):
		var entry: Array = undo[i]
		if not is_instance_valid(entry[0]):
			continue
		var property: String = entry[1]
		if property.begins_with("@"):
			(entry[0] as Object).call(property.substr(1), entry[2])
		else:
			(entry[0] as Object).set(property, entry[2])


static func _dressing(scene: Node) -> Node:
	var slot := scene.get_node_or_null("Arena/Dressing") if scene != null else null
	return slot.get("visual") if slot != null else null


## A stands module, or the MultiMesh StaticInstancer made of its repeats (named after the mesh).
static func _is_stands(node: Node) -> bool:
	var n := String(node.name)
	return n.begins_with("Stands") or (n.begins_with("Instanced_") and "stand" in n.to_lower())


## Every material a mesh node draws with (override, then each surface's), deduplicated.
static func _materials_of(node: Node) -> Array:
	var found: Array = []
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override != null:
		found.append((node as GeometryInstance3D).material_override)
	if mesh != null:
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material != null and not found.has(material):
				found.append(material)
	return found


static func _structure_children(dressing: Node) -> Array:
	var structures: Variant = dressing.get("structures") if dressing != null else null
	return (structures as Node).get_children() if structures is Node else []


static func _hide(node: Node3D, undo: Array) -> void:
	_put(node, "visible", false, undo)


static func _put(target: Object, property: String, value: Variant, undo: Array) -> void:
	undo.append([target, property, target.get(property)])
	target.set(property, value)
