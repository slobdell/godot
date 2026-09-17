class_name PerfScene
extends Node
## `make perf-scene` (M1, round 5): what a frame of the REAL game costs with a full battle on screen. Unlike the FX lab
## (a staged firefight), this rides a live skirmish: CPU against CPU at a 30-a-side budget, every brain, the HUD, the
## arena, and the whole theme. FxWorld adds it when `--perf-scene=<abs path.json>` is on the command line.
##
## The camera is its own: the default play zoom over the middle of every living vehicle, so the fight stays on screen
## and two runs frame the same thing. After a warm-up (the armies close), it alternates short phases:
##   all, no_vehicles, all, no_effects, all, no_pool_lights, … all
## A layer's cost is the average of the `all` phases either side of its phase minus the phase itself, which cancels the
## battle's own drift (vehicles die, the fight moves). Prints one `PERF_SCENE {json}` line per phase, a
## `PERF_SCENE_LAYERS {json}` summary, writes the JSON file, then `PERF_SCENE_DONE` and quits.
##
## CPU: probe nodes before and after FxWorld in the process order split `_process` time into the game and its UI (everything
## at default priority) and the effects (FxWorld). Two more around the physics order give `tick_script_ms` (every
## `_physics_process` in one tick: the simulation and the brains, not the physics server's own step) and `ticks_per_frame`
## (above 1 means the frame ran long and the simulation is catching up; at 8 it is falling behind). `physics_max_ms` is
## Godot's worst whole tick over the last second.
##
## Flags: --perf-scene=<abs json>  --perf-warmup=S (8)  --perf-seconds=S per phase (2.5)  --perf-cycles=N (2)
##        --perf-zoom=0..1 (0.42, RtsCamera's level)  --perf-layers=a,b (a subset)  --perf-shot=<abs png>
##        --perf-shot-every-phase (one shot per phase: <shot>-<index>-<phase>.png)

## Each layer toggle, in run order. Every one is measured against the `all` phases beside it. More on request
## (--perf-layers): no_venue (stands, gates, screens, crowd), ground_lite (the low-tier floor shader), no_msaa, lights_4
## (a 4-light pool), glow_lite (glow levels 2-3 only), no_fog,
## no_spill (the ad screens' light on the floor), scale_085 / scale_075 (3D render scale), glow_wide (glow levels 3+),
## ground_unlit / ground_lit (the high floor lit in its shader, or by the renderer), lod_4 / lod_8 (mesh LOD threshold px),
## no_bursts / no_tracers / no_beams / no_decals (one effect system each), sprays_6 (low tier's spark count),
## glow_one (glow level 3 only), no_ground / no_structures (the dressing's floor, or its walls, venue and towers),
## ground_chunked (the floor's tiling flipped), team_paint (hulls in a dulled team color; not restored, run it last),
## no_live_feed (the arena screens' live match feed and replay ring).
const LAYERS := ["no_vehicles", "no_effects", "no_pool_lights", "no_underglow", "no_arena", "no_hud", "no_shadows", "no_glow"]
## Frames after a phase switch that still show the previous state (and pay for re-enabling it).
const SETTLE_SECONDS := 0.4
const FOCUS_FOLLOW := 1.5
const PROBE := preload("res://game/theme/fx/bench/perf_probe.gd")

var out_path := ""
var shot_path := ""
## Screenshot every phase (<shot>-<index>-<phase>.png), for looking at what a layer changes.
var shot_every_phase := false
var warmup := 8.0
var phase_seconds := 2.5
var cycles := 2
var zoom := 0.42
var layers: Array = LAYERS.duplicate()

var _camera := Camera3D.new()
var _focus := Vector3.ZERO
var _focus_set := false
var _phases: Array = []
var _phase_index := -1
var _phase_time := 0.0
var _time := 0.0
var _samples := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _cpu := PackedFloat32Array()
var _sums := {}
var _frames := 0
var _results: Array = []
var _hidden: Array = []
var _shot_taken := false
var _done := false
## Timestamps (µs) from probe nodes placed around FxWorld in the process order: [start, before fx, after fx].
var _marks := PackedInt64Array([0, 0, 0])
var _cpu_sums := {"game_ui_ms": 0.0, "fx_ms": 0.0}
## Physics ticks this frame and the script time they took (µs), from probes first and last in the physics order.
var _tick_start := 0
var _tick_usec := 0
var _ticks := 0
var _tick_totals := {"ticks": 0, "usec": 0}


func _init() -> void:
	name = "PerfScene"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After FxWorld (1000) has committed this frame's lights.
	process_priority = 2000


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_path = flags.text("perf-scene")
	shot_path = flags.text("perf-shot")
	shot_every_phase = flags.has("perf-shot-every-phase")
	warmup = float(flags.text("perf-warmup", str(warmup)))
	phase_seconds = float(flags.text("perf-seconds", str(phase_seconds)))
	cycles = flags.integer("perf-cycles", cycles)
	zoom = float(flags.text("perf-zoom", str(zoom)))
	if flags.text("perf-layers") != "":
		layers = Array(flags.text("perf-layers").split(",", false))
	_phases = PerfScene.schedule(layers, cycles)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_camera.name = "PerfCamera"
	_camera.fov = RtsCamera.FOV_DEG
	add_child(_camera)
	for probe in [[-100000000, 0], [999, 1], [1001, 2], [-100000000, 3], [100000000, 4]]:
		var node := Node.new()
		node.name = "PerfProbe%d" % probe[1]
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.process_priority = probe[0]
		node.process_physics_priority = probe[0]
		node.set_script(PROBE)
		node.set_meta("slot", probe[1])
		node.set_meta("owner", self)
		add_child(node)
	print("PERF_SCENE_START gpu=%s renderer=%s window=%s tier=%s warmup=%.0f phases=%d x %.1f s" % [
			RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(),
			DisplayServer.window_get_size(), FxQuality.tier_name(), warmup, _phases.size(), phase_seconds])


## The phase list: `all` between every layer toggle, `cycles` times over, ending on `all`. Pure, for tests.
static func schedule(layer_names: Array, cycle_count: int) -> Array:
	var result: Array = []
	for cycle in maxi(cycle_count, 1):
		for layer in layer_names:
			result.append("all")
			result.append(layer)
	result.append("all")
	return result


## Each layer's cost in ms: the mean of the `all` phases on either side minus the layer's phase, averaged over cycles.
## `phases` are result dictionaries in run order ({"phase", `key`}). Pure, for tests.
static func layer_costs(phases: Array, key := "avg_ms") -> Dictionary:
	var totals := {}
	var counts := {}
	for i in phases.size():
		var phase_name: String = phases[i]["phase"]
		if phase_name == "all" or i == 0 or i == phases.size() - 1:
			continue
		if phases[i - 1]["phase"] != "all" or phases[i + 1]["phase"] != "all":
			continue
		var around := (float(phases[i - 1][key]) + float(phases[i + 1][key])) * 0.5
		totals[phase_name] = float(totals.get(phase_name, 0.0)) + around - float(phases[i][key])
		counts[phase_name] = int(counts.get(phase_name, 0)) + 1
	var result := {}
	for phase_name in totals:
		result[phase_name] = snappedf(float(totals[phase_name]) / float(counts[phase_name]), 0.01)
	return result


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_update_camera(delta)
	if _time < warmup:
		return
	if _phase_index < 0:
		_start_phase(0)
	_phase_time += delta
	if _phase_time >= SETTLE_SECONDS:
		_sample(delta)
	if not _shot_taken and shot_path != "" and (_phases[_phase_index] == "all" or shot_every_phase) and _phase_time > phase_seconds * 0.5:
		_shot_taken = true
		var path := shot_path.get_basename() + "-%02d-%s.png" % [_phase_index, _phases[_phase_index]] if shot_every_phase else shot_path
		get_viewport().get_texture().get_image().save_png(path)
		# The arena screens' live feed as it is right now (a readback: only for these shots).
		var feed := LiveFeed.for_node(self)
		if feed != null and feed.texture() != null:
			feed.texture().get_image().save_png(path.get_basename() + "-feed.png")
	if _phase_time >= phase_seconds:
		_finish_phase()
		if _phase_index + 1 < _phases.size():
			_start_phase(_phase_index + 1)
		else:
			_finish()


func _update_camera(delta: float) -> void:
	var tanks := _living_tanks()
	if tanks.is_empty():
		return
	var middle := Vector3.ZERO
	for tank in tanks:
		middle += FxWorld.visual_transform(tank).origin
	middle /= tanks.size()
	middle.y = 0.0
	if not _focus_set:
		_focus = middle
		_focus_set = true
	_focus = _focus.lerp(middle, clampf(delta * FOCUS_FOLLOW, 0.0, 1.0))
	_camera.global_transform = RtsCamera.pose_for(_focus, 0.0, zoom)
	if not _camera.current:
		_camera.current = true


func _living_tanks() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root := _tanks_root()
	if root == null:
		return result
	for child in root.get_children():
		if child is Tank and (child as Tank).is_alive():
			result.append(child as Node3D)
	return result


func _tanks_root() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var game_match := scene.get_node_or_null("Match")
	return game_match.get("tanks") if game_match != null else null


func _start_phase(index: int) -> void:
	_restore()
	_ticks = 0
	_tick_usec = 0
	_phase_index = index
	_phase_time = 0.0
	if shot_every_phase:
		_shot_taken = false
	_samples.clear()
	_gpu.clear()
	_cpu.clear()
	_sums = {"draw_calls": 0.0, "objects": 0.0, "primitives": 0.0, "pool_lights": 0.0, "tracers": 0.0, "burst_area": 0.0, "burst_area_max": 0.0}
	_frames = 0
	_cpu_sums = {"game_ui_ms": 0.0, "fx_ms": 0.0}
	var fx_world := FxWorld.existing()
	if fx_world != null:
		fx_world.profile = true
		fx_world.profile_usec.clear()
	_tick_totals = {"ticks": 0, "usec": 0}
	_apply(_phases[index])


## Hide one layer. Everything hidden is recorded as [object, property, old value] so `_restore` puts it back.
func _apply(phase: String) -> void:
	var fx := FxWorld.existing()
	var scene := get_tree().current_scene
	match phase:
		"no_vehicles":
			var root := _tanks_root()
			if root != null:
				for child in root.get_children():
					if child is Node3D:
						_override(child, "visible", false)
		"no_effects":
			if fx != null:
				for system in [fx.tracers, fx.bursts, fx.decals, fx.streaks, fx.beams, fx.haze, fx.order_feedback, fx.motion]:
					if system is Node3D:
						_override(system, "visible", false)
		"no_pool_lights":
			if fx != null:
				_override(fx.lights, "enabled", false)
		"no_underglow":
			if fx != null:
				_override(fx.underglow, "visible", false)
				_override(fx.underglow, "lights_enabled", false)
		"no_arena":
			var dressing := scene.get_node_or_null("Arena/Dressing") if scene != null else null
			if dressing != null:
				_override(dressing, "visible", false)
		"no_hud":
			for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
				if not (layer is PerfOverlay):
					_override(layer, "visible", false)
					_override(layer, "process_mode", Node.PROCESS_MODE_DISABLED)
		"no_shadows":
			for light in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				_override(light, "shadow_enabled", false)
		"no_venue", "ground_lite", "ground_unlit", "ground_lit":
			var dressing_slot := scene.get_node_or_null("Arena/Dressing") if scene != null else null
			var dressing: Node = dressing_slot.get("visual") if dressing_slot != null else null
			if dressing != null and phase == "no_venue":
				dressing.call("set_venue_visible", false)
				_hidden.append([dressing, "@set_venue_visible", true])
			elif dressing != null and dressing.has_method("set_ground_style"):
				dressing.call("set_ground_style", {"ground_lite": "lite", "ground_unlit": "unlit", "ground_lit": "textured"}[phase])
				_hidden.append([dressing, "@_apply_ground_quality", null])
		"no_msaa":
			_override(get_viewport(), "msaa_3d", Viewport.MSAA_DISABLED)
		"lights_4":
			if fx != null:
				_hidden.append([fx.lights, "@resize", fx.lights.lights.size()])
				fx.lights.resize(4)
		"glow_lite":
			for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					for level in [1, 5]:
						_override(environment, "glow_levels/%d" % level, 0.0)
		"scale_085", "scale_075":
			_override(get_viewport(), "scaling_3d_scale", 0.85 if phase == "scale_085" else 0.75)
		"glow_wide":
			# Only the wide (low-resolution, cheap) glow levels.
			for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					for level in [1, 2]:
						_override(environment, "glow_levels/%d" % level, 0.0)
		"lod_4", "lod_8":
			_override(get_viewport(), "mesh_lod_threshold", 4.0 if phase == "lod_4" else 8.0)
		"no_bursts", "no_tracers", "no_beams", "no_decals":
			if fx != null:
				var system: Node3D = {"no_bursts": fx.bursts, "no_tracers": fx.tracers, "no_beams": fx.beams, "no_decals": fx.decals}[phase]
				_override(system, "visible", false)
		"sprays_6":
			if fx != null:
				fx.bursts.set_spray_count(6)
				_hidden.append([fx.bursts, "@set_spray_count", FxQuality.value("sprays")])
		"ground_chunked":
			var dressing_slot3 := scene.get_node_or_null("Arena/Dressing") if scene != null else null
			var ground: Variant = (dressing_slot3.get("visual") as Node).get("ground") if dressing_slot3 != null and dressing_slot3.get("visual") != null else null
			if ground is ChunkedGround:
				(ground as ChunkedGround).chunked = not (ground as ChunkedGround).chunked
				(ground as ChunkedGround).build()
				_hidden.append([ground, "@toggle_chunked", null])
		"glow_one":
			for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					_override(environment, "glow_levels/5", 0.0)
		"no_ground", "no_structures":
			var dressing_slot2 := scene.get_node_or_null("Arena/Dressing") if scene != null else null
			var dressing2: Node = dressing_slot2.get("visual") if dressing_slot2 != null else null
			if dressing2 != null:
				var part: Variant = dressing2.get("ground" if phase == "no_ground" else "structures")
				if part is Node3D:
					_override(part, "visible", false)
		"no_live_feed":
			var feed := LiveFeed.for_node(self)
			if feed != null:
				_override(feed, "enabled", false)
		"team_paint":
			# A look for the lead's team-read question (M3): hulls coated in a dulled team color. Not restored: run it last.
			for tank in _living_tanks():
				var team := int(tank.get("team"))
				var neon := GameTheme.team_color(team)
				tank.call("set_paint", Color.from_hsv(neon.h, 0.55, 0.42))
		"no_spill":
			for node in get_tree().root.find_children("Spill", "MeshInstance3D", true, false):
				_override(node, "visible", false)
		"no_fog":
			for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					_override(environment, "fog_enabled", false)
		"no_glow":
			for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var environment := (world as WorldEnvironment).environment
				if environment != null:
					_override(environment, "glow_enabled", false)


func _override(target: Object, property: String, value: Variant) -> void:
	_hidden.append([target, property, target.get(property)])
	target.set(property, value)


func _restore() -> void:
	for entry in _hidden:
		if not is_instance_valid(entry[0]):
			continue
		var property: String = entry[1]
		if property.begins_with("@"):
			# A method that restores the layer: [object, "@method", argument or null].
			if entry[2] == null:
				(entry[0] as Object).call(property.substr(1))
			else:
				(entry[0] as Object).call(property.substr(1), entry[2])
		else:
			(entry[0] as Object).set(property, entry[2])
	_hidden.clear()


func _sample(delta: float) -> void:
	var rid := get_viewport().get_viewport_rid()
	_samples.append(delta * 1000.0)
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_sums["draw_calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_sums["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_sums["primitives"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var now := Time.get_ticks_usec()
	if _marks[0] > 0:
		_cpu_sums["game_ui_ms"] += (_marks[1] - _marks[0]) / 1000.0
		_cpu_sums["fx_ms"] += (_marks[2] - _marks[1]) / 1000.0
	_tick_totals["ticks"] += _ticks
	_tick_totals["usec"] += _tick_usec
	_ticks = 0
	_tick_usec = 0
	var fx := FxWorld.existing()
	if fx != null:
		_sums["pool_lights"] += fx.lights.lit_count
		_sums["tracers"] += fx.tracers.active_count()
		_sums["burst_area"] += fx.bursts.alive_area
		_sums["burst_area_max"] = maxf(_sums.get("burst_area_max", 0.0), fx.bursts.alive_area)
	_frames += 1


func _finish_phase() -> void:
	var frames := maxi(_frames, 1)
	var result := {
		"phase": _phases[_phase_index],
		"t": snappedf(_time, 0.1),
		"frames": _frames,
		"avg_ms": snappedf(PerfScene.mean(_samples), 0.01),
		"p95_ms": snappedf(PerfScene.percentile(_samples, 0.95), 0.01),
		"gpu_ms": snappedf(PerfScene.percentile(_gpu, 0.5), 0.01),
		"cpu_render_ms": snappedf(PerfScene.percentile(_cpu, 0.5), 0.01),
		"draw_calls": roundi(_sums["draw_calls"] / frames),
		"objects": roundi(_sums["objects"] / frames),
		"primitives": roundi(_sums["primitives"] / frames),
		"pool_lights": snappedf(_sums["pool_lights"] / frames, 0.1),
		"real_lights": _real_lights(),
		"tracers": snappedf(_sums["tracers"] / frames, 0.1),
		"burst_area": roundi(_sums["burst_area"] / frames),
		"burst_area_max": roundi(_sums["burst_area_max"]),
		"vehicles": _living_tanks().size(),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_max_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"process_game_ui_ms": snappedf(_cpu_sums["game_ui_ms"] / frames, 0.01),
		"process_fx_ms": snappedf(_cpu_sums["fx_ms"] / frames, 0.01),
		"fx_steps_ms": _fx_steps(frames),
		"feed_live": LiveFeed.for_node(self).is_live() if LiveFeed.for_node(self) != null else false,
		"feed_replays": LiveFeed.for_node(self).replays_started if LiveFeed.for_node(self) != null else 0,
		"ticks_per_frame": snappedf(float(_tick_totals["ticks"]) / frames, 0.01),
		"tick_script_ms": snappedf(float(_tick_totals["usec"]) / maxf(float(_tick_totals["ticks"]), 1.0) / 1000.0, 0.01),
	}
	_results.append(result)
	print("PERF_SCENE " + JSON.stringify(result))
	if _phase_index == 0 and LaunchFlags.from_environment().has("perf-census"):
		print("PERF_SCENE_CENSUS " + JSON.stringify(_census()))


## What is drawing, for finding draw calls (--perf-census): visible 3D instances grouped by their nearest named owner
## under the scene (e.g. "Match/Tanks", "Arena/Dressing") and class, plus visible CanvasItems per CanvasLayer.
func _census() -> Dictionary:
	var counts := {}
	for node in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree():
			continue
		var path := str(visual.get_path()).split("/")
		var owner_name := "/".join(path.slice(2, mini(5, path.size() - 1)))
		var key := "%s [%s]" % [owner_name, visual.get_class()]
		counts[key] = int(counts.get(key, 0)) + 1
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not (layer as CanvasLayer).visible:
			continue
		var items := 0
		for item in layer.find_children("*", "CanvasItem", true, false):
			if (item as CanvasItem).is_visible_in_tree():
				items += 1
		counts["2D %s" % layer.get_path()] = items
	var scene := get_tree().current_scene
	var dressing := scene.get_node_or_null("Arena/Dressing") if scene != null else null
	if dressing != null:
		for node in dressing.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance.is_visible_in_tree() and instance.mesh != null:
				var key := "dressing mesh: %s x%d surfaces" % [instance.mesh.resource_path if instance.mesh.resource_path != "" else instance.name.rstrip("0123456789"), instance.mesh.get_surface_count()]
				counts[key] = int(counts.get(key, 0)) + 1
	var root := _tanks_root()
	if root != null and root.get_child_count() > 0:
		var tank := root.get_child(0)
		for node in tank.find_children("*", "VisualInstance3D", true, false):
			var visual := node as VisualInstance3D
			if visual.is_visible_in_tree():
				var mesh_surfaces := -1
				if visual is MeshInstance3D and (visual as MeshInstance3D).mesh != null:
					mesh_surfaces = (visual as MeshInstance3D).mesh.get_surface_count()
				counts["one tank: %s [%s] surfaces=%d" % [str(tank.get_path_to(visual)), visual.get_class(), mesh_surfaces]] = 1
	return counts


## FxWorld's per-step CPU time this phase (ms per frame, over every frame of the phase).
func _fx_steps(frames: int) -> Dictionary:
	var fx := FxWorld.existing()
	var result := {}
	if fx != null:
		var counted := maxf(float(fx.profile_usec.get("frames", frames)), 1.0)
		for step in fx.profile_usec:
			if step != "frames":
				result[step] = snappedf(float(fx.profile_usec[step]) / 1000.0 / counted, 0.001)
	return result


## Real lights switched on anywhere in the scene (pooled, fixtures, the moon).
func _real_lights() -> int:
	var count := 0
	for light in get_tree().root.find_children("*", "Light3D", true, false):
		if (light as Light3D).is_visible_in_tree():
			count += 1
	return count


func _finish() -> void:
	_done = true
	_restore()
	var all_phases := _results.filter(func(r: Dictionary) -> bool: return r["phase"] == "all")
	var summary := {
		"gpu": RenderingServer.get_video_adapter_name(),
		"window": str(DisplayServer.window_get_size()),
		"tier": FxQuality.tier_name(),
		"all_avg_ms": snappedf(PerfScene.mean(PackedFloat32Array(all_phases.map(func(r: Dictionary) -> float: return r["avg_ms"]))), 0.01),
		"all_p95_ms": snappedf(PerfScene.mean(PackedFloat32Array(all_phases.map(func(r: Dictionary) -> float: return r["p95_ms"]))), 0.01),
		"all_gpu_ms": snappedf(PerfScene.mean(PackedFloat32Array(all_phases.map(func(r: Dictionary) -> float: return r["gpu_ms"]))), 0.01),
		"holds_60fps_at_vehicles": PerfScene.holds_60fps_at(_results),
		"layer_cost_ms": PerfScene.layer_costs(_results),
		"layer_cost_gpu_ms": PerfScene.layer_costs(_results, "gpu_ms"),
		"layer_draw_calls": PerfScene.layer_costs(_results, "draw_calls"),
	}
	print("PERF_SCENE_LAYERS " + JSON.stringify(summary))
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"summary": summary, "phases": _results}, "  "))
	print("PERF_SCENE_DONE")
	get_tree().quit()


## The lead's number: the most vehicles at which 60 fps held, from the full-scene (`all`) phases. Phases are grouped by
## vehicle count and each count's MEDIAN frame is used (one noisy phase shouldn't decide it); a count holds when its
## median and every smaller count's median are under a 60 Hz frame (16.7 ms). 0 if even the fewest didn't. Pure.
static func holds_60fps_at(phases: Array) -> int:
	var by_count := {}
	for r: Dictionary in phases:
		if r["phase"] == "all":
			# Packed arrays are values (orientation trip-up 48): append to a copy, then store it back.
			var frames: PackedFloat32Array = by_count.get(int(r["vehicles"]), PackedFloat32Array())
			frames.append(float(r["avg_ms"]))
			by_count[int(r["vehicles"])] = frames
	var counts := by_count.keys()
	counts.sort()
	var held := 0
	for count: int in counts:
		if PerfScene.percentile(by_count[count], 0.5) > 1000.0 / 60.0:
			break
		held = count
	return held


static func mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


static func percentile(values: PackedFloat32Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(floor(fraction * (sorted.size() - 1))), 0, sorted.size() - 1)]


## Called by the probes (perf_probe.gd) as the frame's process pass (slots 0-2) or a physics tick (3, 4) reaches them.
func mark(slot: int) -> void:
	var now := Time.get_ticks_usec()
	if slot < 3:
		_marks[slot] = now
	elif slot == 3:
		_tick_start = now
	else:
		_tick_usec += now - _tick_start
		_ticks += 1
