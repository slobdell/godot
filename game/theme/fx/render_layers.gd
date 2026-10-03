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

## Within-run A/B layers (round 16): not removals but the code as it was before a render change, swapped in for one
## phase, so a change's saving is read against `all` on the same frame. Ask for them by name; not in NAMES.
const BEFORE := {
	"ground_r15": "res://game/theme/fx/shaders/reference/arena_ground_unlit_r15.gdshader",
	"fogvis_r15": "res://game/theme/fx/shaders/reference/fog_of_war_r15.gdshader",
	"haze_world_box": "",
	"sky_r15": "",
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
		"haze_world_box":
			if fx != null:
				_put(fx.haze, "tight_box", false, undo)
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


static func _structure_children(dressing: Node) -> Array:
	var structures: Variant = dressing.get("structures") if dressing != null else null
	return (structures as Node).get_children() if structures is Node else []


static func _hide(node: Node3D, undo: Array) -> void:
	_put(node, "visible", false, undo)


static func _put(target: Object, property: String, value: Variant, undo: Array) -> void:
	undo.append([target, property, target.get(property)])
	target.set(property, value)
