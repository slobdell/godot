extends Node3D
## The FX lab (`make fx-bench`, browser `?fx-bench`): a deterministic worst-case firefight on the
## real arena with the cyberpunk theme, 10 v 10 tanks all firing, on a fixed camera path. It runs
## the same timeline once per configuration (each toggles one trick) and prints one line each:
##   FX_BENCH {"config": "...", "avg_ms": ..., "p95_ms": ..., "p99_ms": ..., "draw_calls": ..., ...}
## so a trick's cost is its delta against `all`. Visual-only: tanks are slot visuals, shells are
## plain nodes carrying the `fx.shell` slot, and hits go through Impact, exactly like a match.
##
## Flags: --fx-bench[=config,config]  --fx-bench-seconds=S  --fx-bench-loop (keep running `all`)
##        --fx-bench-out=<abs path.json>  --fx-no-prewarm  --fx-quality=low|medium|high
##        --fx-bench-shot=<abs dir> (screenshot of each config)

const ARENA_SCENE := preload("res://game/arena/arena.tscn")
const NAIVE_SHELL := "res://game/theme/fx/bench/naive_shell.tscn"
const TANKS_PER_TEAM := 10
const LINE_Z := 26.0
const SPACING := 6.0
## Seconds between each tank's shots (a real cannon reloads in ~2.5 s; this is a worst case).
const FIRE_INTERVAL := 0.7
const SHELL_SPEED := 70.0
const WARMUP_SECONDS := 1.0

## Every configuration, in run order. Each is a dictionary of overrides applied to a fresh
## `all` baseline (tier HIGH budgets).
const CONFIGS := {
	"arena_only": {"fire": false},
	"all": {},
	"lights_0": {"lights": 0},
	"lights_4": {"lights": 4},
	"lights_8": {"lights": 8},
	"lights_32": {"lights": 32},
	"no_splats": {"splats": false},
	"no_glow": {"glow": false},
	"single_ground": {"chunked": false},
	"single_ground_lights_8": {"chunked": false, "lights": 8},
	"msaa_off": {"msaa": Viewport.MSAA_DISABLED},
	"scale_0.7": {"render_scale": 0.7},
	"no_shadows": {"shadows": false},
	"no_muzzle_flash": {"muzzle": false},
	"unmerged_props": {"merge": false},
	"naive": {"naive": true, "lights": 0},
	"no_lasers": {"lasers": false},
	"no_shields": {"shields": false},
	# Art X2/X3: the textured floor against the round-1 procedural wet asphalt and a flat material.
	"ground_wet": {"ground": "wet"},
	"ground_flat": {"ground": "flat"},
	"ground_lite": {"ground": "lite"},
	# Art X5: the gladiator venue (Meshy stands, gates, towers, the instanced crowd).
	"no_venue": {"venue": false},
	"tier_low_no_venue": {"tier": FxQuality.Tier.LOW, "venue": false},
	"tier_low_ground_wet": {"tier": FxQuality.Tier.LOW, "ground": "wet"},
	"tier_low": {"tier": FxQuality.Tier.LOW},
	"tier_medium": {"tier": FxQuality.Tier.MEDIUM},
	"tier_high": {"tier": FxQuality.Tier.HIGH},
	# Feel X7 (round 3): 50 vehicles fighting with round 3's weapons through WeaponFx, moving (dust, drift marks), with
	# order markers. r3_no_weapons and r3_no_motion isolate the two costs; the tier configs check the budgets.
	"r3_all": {"round3": true},
	"r3_no_weapons": {"round3": true, "fire": false},
	"r3_no_motion": {"round3": true, "motion": false},
	"r3_tier_medium": {"round3": true, "tier": FxQuality.Tier.MEDIUM},
	"r3_tier_low": {"round3": true, "tier": FxQuality.Tier.LOW},
}

var flags: LaunchFlags
var results: Array = []

var _arena: Node3D
var _camera := Camera3D.new()
var _overlay := PerfOverlay.new()
var _tanks: Array[Node3D] = []
var _shells: Node3D = Node3D.new()
var _effects: Node3D = Node3D.new()
var _queue: Array = []
var _config_name := ""
var _config: Dictionary = {}
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _next_fire: PackedFloat32Array = []
var _samples: PackedFloat32Array = []
var _gpu_samples: PackedFloat32Array = []
var _cpu_samples: PackedFloat32Array = []
var _draws := 0.0
var _objects := 0.0
var _primitives := 0.0
var _lit := 0.0
var _tracers := 0.0
var _frames := 0
var _worst_warmup := 0.0
var _config_frames := 0
var _hitches_logged := 0
var _reported := false
var _summary := ""
var _seconds := 6.0
var _loop := false
var _default_slots: Dictionary
var _round3: Round3Firefight
var _shield_ratio: PackedFloat32Array = []
## Seconds between laser pulses (4 laser tanks).
const LASER_INTERVAL := 0.35


func _ready() -> void:
	flags = LaunchFlags.from_environment()
	if not flags.has("theme"):
		GameTheme.use("cyberpunk")
	_default_slots = GameTheme.slots
	_seconds = float(flags.text("fx-bench-seconds", "6"))
	_loop = flags.has("fx-bench-loop") or OS.has_feature("web")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_shells.name = "Shells"
	_effects.name = "Effects"
	add_child(_shells)
	add_child(_effects)
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)
	add_child(_overlay)
	_build_tanks()

	var requested := flags.text("fx-bench")
	if requested == "":
		_queue = CONFIGS.keys()
	else:
		for config_name in requested.split(",", false):
			if CONFIGS.has(config_name):
				_queue.append(config_name)
			else:
				push_warning("fx-bench: unknown config '%s'" % config_name)
	if flags.has("fx-no-prewarm"):
		var fx := FxWorld.get_instance()
		if fx != null:
			fx.prewarm_enabled = false
	print("FX_BENCH_START configs=%s seconds=%s quality=%s renderer=%s gpu=%s" % [_queue, _seconds,
			FxQuality.tier_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	_start_next()


func _process(delta: float) -> void:
	if _config_name == "":
		return
	_time += delta
	_update_camera()
	if _config.get("round3", false):
		_round3.step(delta, _camera.global_position)
	elif _config.get("fire", true):
		_fire_due()
	_move_shells(delta)
	if _config.get("shields", true):
		for i in _tanks.size():
			if _shield_ratio[i] < 1.0:
				_shield_ratio[i] = minf(1.0, _shield_ratio[i] + delta * 0.15)
				(_tanks[i].get_child(0) as VisualSlot).invoke("set_shield", [_shield_ratio[i]])
	if delta > 0.05 and _config_frames > 3 and _hitches_logged < 5:
		_hitches_logged += 1
		var fx_now := FxWorld.existing()
		print("FX_BENCH_HITCH %.1f ms at t=%.2f config=%s shells=%d bursts=%d beams=%d lights=%d" % [delta * 1000.0, _time, _config_name,
				_shells.get_child_count(), fx_now.bursts.started if fx_now else -1, fx_now.beams.active_count() if fx_now else -1,
				fx_now.lights.lit_count if fx_now else -1])
	if _time < WARMUP_SECONDS:
		# The first frames of a config pay for its setup (rebuilding the floor, resizing the pool);
		# after that, a spike here is a first-shot hitch (shader or light-variant compile).
		_config_frames += 1
		if _config_frames > 3:
			_worst_warmup = maxf(_worst_warmup, delta)
		return
	var rid := get_viewport().get_viewport_rid()
	_samples.append(delta * 1000.0)
	_gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var fx := FxWorld.existing()
	if fx != null:
		_lit += fx.lights.lit_count
		_tracers += fx.tracers.active_count()
	_frames += 1
	if _time >= WARMUP_SECONDS + _seconds:
		_finish_config()


func _start_next() -> void:
	if _queue.is_empty():
		_finish_all()
		return
	_config_name = _queue.pop_front()
	_config = CONFIGS[_config_name]
	_reset_timeline()
	_apply(_config)
	_overlay.extra = ("%s\nlooping: %s" % [_summary, _config_name]) if _reported else "FX LAB: %s" % _config_name


func _apply(config: Dictionary) -> void:
	var fx := FxWorld.get_instance()
	var tier: int = config.get("tier", FxQuality.Tier.HIGH)
	FxQuality.set_tier(tier, "bench")
	var settings := FxQuality.current()
	if fx != null:
		fx.apply_quality()
		fx.lights.resize(config.get("lights", settings["lights"]))
		fx.tracers.splats_enabled = config.get("splats", settings["splats"])
		fx.muzzle_flashes = config.get("muzzle", true)
		fx.explosion_lights = true
	var environment := _find_environment()
	if environment != null:
		environment.glow_enabled = config.get("glow", settings["glow"])
	var viewport := get_viewport()
	viewport.msaa_3d = config.get("msaa", settings["msaa"])
	viewport.scaling_3d_scale = config.get("render_scale", settings["render_scale"])
	for light in _arena.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = config.get("shadows", settings["shadows"])
	var merge: bool = config.get("merge", true)
	if merge != StaticBatcher.enabled:
		StaticBatcher.enabled = merge
		var props: Array[VisualSlot] = []
		for node in _arena.find_children("*", "", true, false):
			if node is VisualSlot and (node.slot.begins_with("prop.") or node.slot == "arena.dressing"):
				props.append(node)
		for slot in props:
			slot.fill(slot.slot)
	var dressing := _arena.get_node_or_null("Dressing") as VisualSlot
	if dressing != null:
		dressing.invoke("set_chunked", [config.get("chunked", true)])
		var tier_ground := "lite" if int(config.get("tier", FxQuality.Tier.HIGH)) < FxQuality.Tier.HIGH else "textured"
		dressing.invoke("set_ground_style", [config.get("ground", tier_ground)])
		dressing.invoke("set_venue_visible", [config.get("venue", true)])
	var round3: bool = config.get("round3", false)
	if round3 and _round3 == null:
		_round3 = Round3Firefight.new()
		_round3.name = "Round3"
		add_child(_round3)
		_round3.build()
	for tank in _tanks:
		tank.visible = not round3
	if _round3 != null:
		_round3.visible = round3
		if round3 and fx != null:
			_round3.weapons_on = config.get("fire", true)
			_round3.motion_on = config.get("motion", true)
			_round3.reset(fx)
	var slots := _default_slots.duplicate()
	if config.get("naive", false):
		slots["fx.shell"] = NAIVE_SHELL
	GameTheme.slots = slots


func _finish_config() -> void:
	var result := {
		"config": _config_name,
		"frames": _frames,
		"avg_ms": snappedf(_mean(_samples), 0.01),
		"p95_ms": snappedf(_percentile(_samples, 0.95), 0.01),
		"p99_ms": snappedf(_percentile(_samples, 0.99), 0.01),
		"max_ms": snappedf(_percentile(_samples, 1.0), 0.01),
		# Medians: the driver occasionally reports a garbage GPU time for one frame.
		"gpu_ms": snappedf(_percentile(_gpu_samples, 0.5), 0.01),
		"cpu_render_ms": snappedf(_percentile(_cpu_samples, 0.5), 0.01),
		"draw_calls": roundi(_draws / maxi(_frames, 1)),
		"objects": roundi(_objects / maxi(_frames, 1)),
		"primitives": roundi(_primitives / maxi(_frames, 1)),
		"lights_lit": snappedf(_lit / maxi(_frames, 1), 0.1),
		"tracers": snappedf(_tracers / maxi(_frames, 1), 0.1),
		"warmup_worst_ms": snappedf(_worst_warmup * 1000.0, 0.1),
	}
	results.append(result)
	print("FX_BENCH ", JSON.stringify(result))
	if flags.has("fx-bench-shot"):
		var image := get_viewport().get_texture().get_image()
		image.save_png(flags.text("fx-bench-shot").path_join("fx_%s.png" % _config_name))
	if _queue.is_empty() and not _reported:
		_report()
	if _loop and _queue.is_empty():
		_queue.append("all")  # keep the firefight running for the on-screen overlay (phone tests)
	_start_next()


func _finish_all() -> void:
	_config_name = ""
	if not _reported:
		_report()
	if not OS.has_feature("web"):
		get_tree().quit()


## Print the summary, write the JSON, and log FX_BENCH_DONE once, after the first full pass.
func _report() -> void:
	_reported = true
	var summary := "FX LAB results (%s)\n" % RenderingServer.get_video_adapter_name()
	for result in results:
		summary += "%-24s %6.2f ms  p95 %6.2f  draws %4d  lights %4.1f\n" % [result["config"], result["avg_ms"],
				result["p95_ms"], result["draw_calls"], result["lights_lit"]]
	print(summary)
	_summary = summary
	_overlay.extra = summary
	if flags.has("fx-bench-out"):
		var file := FileAccess.open(flags.text("fx-bench-out"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(),
					"renderer": RenderingServer.get_current_rendering_method(), "results": results}, "  "))
	print("FX_BENCH_DONE")


# ---- The scripted firefight ----------------------------------------------------------------

func _build_tanks() -> void:
	for team in 2:
		for i in TANKS_PER_TEAM:
			var tank := Node3D.new()
			tank.name = "BenchTank_%d_%d" % [team, i]
			var x := (i - (TANKS_PER_TEAM - 1) / 2.0) * SPACING
			var z := LINE_Z if team == 0 else -LINE_Z
			tank.position = Vector3(x, 0.0, z)
			tank.rotation.y = 0.0 if team == 0 else PI
			tank.set_meta("team", team)
			add_child(tank)
			var hull := VisualSlot.new()
			hull.slot = "tank.hull"
			tank.add_child(hull)
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0.0, 1.22, 0.2)
			tank.add_child(turret)
			for slot_name in ["tank.turret", "weapon.laser" if i % 5 == 2 else "weapon.cannon"]:
				var slot := VisualSlot.new()
				slot.slot = slot_name
				turret.add_child(slot)
			for slot in [hull, turret.get_child(0), turret.get_child(1)]:
				(slot as VisualSlot).invoke("set_team_color", [GameTheme.team_color(team)])
			_tanks.append(tank)


func _reset_timeline() -> void:
	for shell in _shells.get_children():
		shell.free()
	_time = 0.0
	_rng.seed = 12345
	_next_fire.resize(_tanks.size())
	_shield_ratio.resize(_tanks.size())
	for i in _tanks.size():
		_next_fire[i] = WARMUP_SECONDS * 0.2 + float(i) / _tanks.size() * FIRE_INTERVAL
		_shield_ratio[i] = 1.0
	_samples.clear()
	_gpu_samples.clear()
	_cpu_samples.clear()
	_draws = 0.0
	_objects = 0.0
	_primitives = 0.0
	_lit = 0.0
	_tracers = 0.0
	_frames = 0
	_worst_warmup = 0.0
	_config_frames = 0
	_hitches_logged = 0


func _fire_due() -> void:
	for i in _tanks.size():
		if _time < _next_fire[i]:
			continue
		var tank := _tanks[i]
		var team: int = tank.get_meta("team")
		var turret := tank.get_node("Turret") as Node3D
		var laser := (turret.get_child(1) as VisualSlot).slot == "weapon.laser"
		_next_fire[i] += LASER_INTERVAL if laser else FIRE_INTERVAL
		var target_index := (1 - team) * TANKS_PER_TEAM + _rng.randi_range(0, TANKS_PER_TEAM - 1)
		var target := _tanks[target_index]
		var aim := target.global_position - turret.global_position
		turret.global_rotation.y = atan2(-aim.x, -aim.z)
		var muzzle := turret.global_transform * Vector3(0.0, 0.05, -3.2)
		if laser:
			if _config.get("lasers", true):
				_pulse(turret.get_child(1) as VisualSlot, muzzle, target.global_position + Vector3(0, 1.0, 0))
				_hit_shield(target_index, 0.08)
			continue
		# Some shots miss and fly on to hit the ground past the target.
		var miss := _rng.randf() < 0.3
		var impact_point := target.global_position + Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1))
		if miss:
			impact_point += Vector3(_rng.randf_range(-6, 6), -1.0, (target.global_position.z - muzzle.z) * 0.3)
		var shell := _spawn_shell(team, muzzle, impact_point, _rng.randf() < 0.15)
		if not miss:
			shell.target_index = target_index


## A laser pulse exactly as Match.show_beam does it: a fresh slot, setup once, freed after 0.2 s.
func _pulse(weapon: VisualSlot, from: Vector3, to: Vector3) -> void:
	weapon.invoke("set_firing", [true])
	var beam := VisualSlot.new()
	beam.slot = "fx.laser_beam"
	_effects.add_child(beam)
	beam.invoke("setup", [from, to])
	get_tree().create_timer(0.2).timeout.connect(beam.queue_free)


func _hit_shield(index: int, amount: float) -> void:
	if not _config.get("shields", true):
		return
	_shield_ratio[index] = maxf(0.0, _shield_ratio[index] - amount)
	(_tanks[index].get_child(0) as VisualSlot).invoke("set_shield", [_shield_ratio[index]])


func _spawn_shell(team: int, from: Vector3, to: Vector3, big: bool) -> BenchShell:
	var shell := BenchShell.new()
	shell.team = team
	shell.target = to
	shell.big = big
	shell.position = from
	var slot := VisualSlot.new()
	slot.slot = "fx.shell"
	shell.add_child(slot)
	_shells.add_child(shell)
	shell.look_at(to, Vector3.UP)
	return shell


func _move_shells(delta: float) -> void:
	for shell: BenchShell in _shells.get_children():
		var to_target := shell.target - shell.position
		var step := SHELL_SPEED * delta
		if to_target.length() <= step:
			var impact: Node3D = NaiveImpact.new() if _config.get("naive", false) else Impact.new()
			impact.set("big", shell.big)
			if shell.target_index >= 0:
				_hit_shield(shell.target_index, 0.25)
			_effects.add_child(impact)
			impact.global_position = shell.target
			shell.free()
		else:
			shell.position += to_target.normalized() * step


func _update_camera() -> void:
	# Orbit the fight, alternating the tactical top-down height and a low 3D pass.
	var angle := _time * 0.18
	var height := 34.0 + 14.0 * cos(_time * 0.35)
	var distance := 40.0 + 12.0 * cos(_time * 0.35)
	_camera.position = Vector3(sin(angle) * distance, height, cos(angle) * distance)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _find_environment() -> Environment:
	for node in _arena.find_children("*", "WorldEnvironment", true, false):
		return (node as WorldEnvironment).environment
	return null


static func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


static func _percentile(values: PackedFloat32Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(fraction * sorted.size())) - 1, 0, sorted.size() - 1)]


class BenchShell extends Node3D:
	var team := 0
	var target_index := -1
	var target := Vector3.ZERO
	var big := false
