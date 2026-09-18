class_name FxWorld
extends Node3D
## The pooled effect systems every visual shares: a LightPool, the TracerSystem, and the
## BurstSystem (fireballs, muzzle stars, ground glows). Created on first use under the scene
## tree root, never on a headless peer (servers and tests render nothing, and art must never
## touch the simulation). Visual slot scenes and Impact talk to it through `FxWorld.get_instance()`.
##
## Once per frame it advances the clock, lets the systems write their buffers, and hands the
## light pool to the best requests. Everything is preallocated; combat allocates nothing here.

## Emitted when effect budgets change (FxQuality tier switch).
signal quality_changed
## Something the crowd should react to (art X5): weight 1 = a kill, ~0.15 = a hit. The arena's CrowdSystem listens.
signal spectacle(position: Vector3, weight: float)

static var _instance: FxWorld

var lights: LightPool
var tracers: TracerSystem
var bursts: BurstSystem
## Long-lived ground marks (scorches) in their own pool, so a firefight's sparks never recycle them.
var decals: BurstSystem
## Vehicles rocking from recoil, hits, and braking (visual only).
var jolts := VehicleJolt.new()
var streaks: StreakSystem
var underglow: UnderglowSystem
var beams: BeamSystem
var engines: EngineSystem
## Kill sites that keep burning (art stretch).
var fires := FireSites.new()
## Husks left where vehicles died (render stretch, round 5).
var wrecks := WreckField.new()
var shake := CameraShake.new()
var sfx: SfxSystem
## Machine-gun streams as held loops (a few voices for the nearest gunners).
var gunfire: GunfireLoops
## Effect families per K2 fire model (feel X1), fed by `link` from the running match's weapon events.
var weapons: WeaponFx
var link: MatchFxLink
## Ground markers, waypoint trails, selection pulses, and acknowledgements for the player's K1 orders.
var order_feedback: OrderFeedback
## Dust, drift marks, and lurches from vehicles on the move.
var motion: MotionFx
## The slow-motion moment on a match's final kill.
var kill_cam: KillCam
## Heat haze over burning wrecks (tier high).
var haze: HeatHaze
## Seconds since this FxWorld started; the clock every shader animation uses.
var now := 0.0
## Legacy muzzle flashes when a projectile appears, used only when no match drives weapon events (a networked client,
## or a scene without a Match); otherwise WeaponFx draws muzzles from weapon_fired.
var muzzle_flashes := true
var explosion_lights := true
## Draw every effect and light once, invisibly, on the first frames so shaders and light
## variants compile during loading instead of on the first shot (a visible hitch on the web).
var prewarm_enabled := true

const PREWARM_FRAMES := 3
const MESH_LOD_THRESHOLD_PX := 4.0

var _rng := RandomNumberGenerator.new()
var _prewarm_frames := 0
var _prewarm_marker: Node3D


## The shared FX systems, or null where nothing renders (headless). Safe to call from any _ready.
static func get_instance() -> FxWorld:
	if DisplayServer.get_name() == "headless":
		return null
	if is_instance_valid(_instance) and not _instance.is_queued_for_deletion():
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_instance = FxWorld.new()
	# Deferred: the root may be busy adding the main scene when the first visual asks.
	tree.root.add_child.call_deferred(_instance)
	return _instance


## Where `node` is DRAWN this frame (render, round 5, ahead of the 30 Hz simulation): with physics interpolation on,
## Godot renders a body at its interpolated transform while `global_transform` still returns the last physics tick's, so
## anything an effect places from a body in `_process` (underglow, blob shadows, tracers, order markers, dust) must use
## this or it jitters against the vehicle it belongs to. Identical to `global_transform` without interpolation.
static func visual_transform(node: Node3D) -> Transform3D:
	return node.get_global_transform_interpolated() if node.is_physics_interpolated_and_enabled() else node.global_transform


## The shared FX systems if they already exist; never creates them (use while tearing down).
static func existing() -> FxWorld:
	return _instance if is_instance_valid(_instance) else null


func _init() -> void:
	name = "FxWorld"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After gameplay and cameras have moved this frame.
	process_priority = 1000
	_rng.seed = 1
	lights = LightPool.new(FxQuality.value("lights"))
	lights.min_priority = FxQuality.value("light_floor")
	tracers = TracerSystem.new()
	bursts = BurstSystem.new(FxQuality.value("effects"))
	bursts.set_spray_count(FxQuality.value("sprays"))
	bursts.overdraw_budget = FxQuality.value("overdraw")
	decals = BurstSystem.new(FxQuality.value("decals"))
	decals.name = "Decals"
	streaks = StreakSystem.new()
	underglow = UnderglowSystem.new()
	beams = BeamSystem.new()
	tracers.splats_enabled = FxQuality.value("splats")
	for system in [lights, tracers, bursts, decals, streaks, underglow, beams]:
		add_child(system)
	sfx = SfxSystem.new()
	add_child(sfx)
	gunfire = GunfireLoops.new()
	gunfire.muted = sfx.muted
	gunfire.use_streams(sfx.streams)
	add_child(gunfire)
	engines = EngineSystem.new()
	engines.muted = sfx.muted
	engines.use_streams(sfx.streams)
	add_child(engines)
	weapons = WeaponFx.new(self)
	link = MatchFxLink.new(weapons)
	add_child(link)
	order_feedback = OrderFeedback.new()
	add_child(order_feedback)
	motion = MotionFx.new(self)
	add_child(motion)
	kill_cam = KillCam.new(self)
	add_child(kill_cam)
	haze = HeatHaze.new()
	add_child(haze)
	add_child(FxAutoQuality.new())
	shake.enabled = not LaunchFlags.from_environment().has("no-shake")
	add_child(shake)
	if LaunchFlags.from_environment().has("perf"):
		add_child(PerfOverlay.new())
	if LaunchFlags.from_environment().has("perf-scene"):
		add_child(PerfScene.new())
	if LaunchFlags.from_environment().has("crowd-look"):
		add_child(CrowdLook.new())


func _ready() -> void:
	FrameTarget.apply_frame_cap()
	_apply_viewport()
	get_viewport().size_changed.connect(_apply_viewport)


func _process(delta: float) -> void:
	now += delta
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3.ZERO
	if _prewarm_frames < PREWARM_FRAMES and prewarm_enabled and camera != null:
		_prewarm(camera)
	_mark("start")
	bursts.update(now)
	decals.update(now)
	_mark("bursts")
	jolts.camera_position = eye if camera != null else null
	jolts.update(now)
	_mark("jolts")
	order_feedback.update(now)
	_mark("orders")
	if link.is_attached():
		motion.update(link.unit_nodes(), eye, now, delta)
	_mark("motion")
	weapons.flush(now)
	_mark("weapons")
	tracers.update(lights, now)
	_mark("tracers")
	underglow.update(lights)
	_mark("underglow")
	beams.update(lights, now)
	fires.update(now, bursts, lights)
	haze.update(fires.sites, eye, now)
	_mark("beams_fires_haze")
	lights.commit(eye, now)
	_mark("lights")
	if camera != null:
		engines.update(eye, delta)
	gunfire.update(eye, now)
	_mark("engines_gunfire")


## Per-system CPU time for perf-scene (`profile` on): µs spent in each step of _process, summed until read.
var profile := false
var profile_usec := {}
var _profile_last := 0


func _mark(step: String) -> void:
	if not profile:
		return
	var t := Time.get_ticks_usec()
	if step == "start":
		profile_usec["frames"] = int(profile_usec.get("frames", 0)) + 1
	else:
		profile_usec[step] = int(profile_usec.get(step, 0)) + t - _profile_last
	_profile_last = t


## Put one of each effect (near-invisible) and every pooled light just in front of the camera, so
## every FX shader, including ones first used mid-fight (shields, flames, beams), compiles at load.
func _prewarm(camera: Camera3D) -> void:
	_prewarm_frames += 1
	if _prewarm_marker == null:
		_prewarm_marker = Node3D.new()
		_prewarm_marker.name = "PrewarmTracer"
		add_child(_prewarm_marker)
		tracers.add(_prewarm_marker, Color(0, 0, 0))
		var shield := ShieldEffect.new(Vector3.ONE * 0.02)
		_prewarm_marker.add_child(shield)
		shield.set_shield(0.5)
		for shader in [preload("res://game/theme/fx/shaders/flame_cone.gdshader"), preload("res://game/theme/fx/shaders/ground_glow.gdshader"),
				preload("res://game/theme/fx/shaders/vehicle_glow.gdshader")]:
			var piece := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * 0.02
			var material := ShaderMaterial.new()
			material.shader = shader
			quad.material = material
			piece.mesh = quad
			_prewarm_marker.add_child(piece)
		beams.add(_prewarm_marker, Vector3.ZERO, Vector3(0, 0, -0.1), Color(0, 0, 0), now)
	var spot := camera.global_transform * Vector3(0, 0, -6)
	_prewarm_marker.global_position = spot
	beams.add(_prewarm_marker, spot, spot + camera.global_basis.x * 0.05, Color(0, 0, 0), now)
	for kind in BurstSystem.Kind.values():
		bursts.spawn(kind, spot, 0.01, 0.05, Color(0, 0, 0, 0), now)
	decals.spawn(BurstSystem.Kind.SCORCH, spot, 0.01, 0.05, Color(0, 0, 0, 0), now)
	for i in lights.lights.size():
		lights.request(spot, Color(0, 0, 0), 0.001, 0.5, 100.0)
	if _prewarm_frames >= PREWARM_FRAMES:
		tracers.remove(_prewarm_marker)
		beams.remove(_prewarm_marker)
		_prewarm_marker.queue_free()


## Apply the current FxQuality tier's budgets to every system and the 3D viewport. Scenes that
## own tier-dependent settings (the environment's glow and shadows) listen to quality_changed.
func apply_quality() -> void:
	lights.resize(FxQuality.value("lights"))
	lights.min_priority = FxQuality.value("light_floor")
	bursts.resize(FxQuality.value("effects"))
	bursts.set_spray_count(FxQuality.value("sprays"))
	bursts.overdraw_budget = FxQuality.value("overdraw")
	decals.resize(FxQuality.value("decals"))
	motion.resize()
	tracers.splats_enabled = FxQuality.value("splats")
	_apply_viewport()
	quality_changed.emit()


## 3D render scale (the UI stays crisp) and MSAA on the main viewport.
func _apply_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# The frame target decides how many lines of 3D a window renders (locked 30: native to 1080p; performance 60: ~720).
	viewport.scaling_3d_scale = FrameTarget.render_scale_for(FrameTarget.target(), FxQuality.value("render_scale"),
			viewport.get_visible_rect().size.y as int)
	viewport.msaa_3d = FxQuality.value("msaa")
	# Render X5: switch mesh detail levels when an edge would move less than 4 px (Godot's default is 1). At 60 vehicles
	# this drew 374k -> 237k primitives and saved ~0.6 ms GPU on the UHD 620 with no visible change at play distance.
	viewport.mesh_lod_threshold = MESH_LOD_THRESHOLD_PX


## A projectile visual appeared: draw it as a tracer and flash its muzzle.
func add_tracer(source: Node3D, color: Color, style := "default") -> void:
	tracers.add(source, color, style)
	if muzzle_flashes and not link.live:
		muzzle_flash(source.global_position, color)


func remove_tracer(source: Node3D) -> void:
	tracers.remove(source)


func muzzle_flash(position: Vector3, color: Color) -> void:
	sfx.play_at("cannon_shot", position)
	bursts.spawn(BurstSystem.Kind.STAR, position, 2.4, 0.09, color, now)
	bursts.spawn(BurstSystem.Kind.GROUND_GLOW, position, 5.0, 0.2, color * 0.6, now)
	lights.flash(position, color.lightened(0.3), 5.0, 8.0, 0.1, LightPool.PRIORITY_MUZZLE, now)


## A laser pulse from `from` to `to`: the batched beam, a muzzle star, and a hit spark with a ground
## glow. `source` is the beam visual (removed when it's freed).
func laser(source: Object, from: Vector3, to: Vector3, color: Color) -> void:
	beams.add(source, from, to, color, now)
	# The shot's own sound is played by WeaponFx, which knows which weapon fired (a railgun is not a laser).
	bursts.spawn(BurstSystem.Kind.STAR, from, 1.6, 0.08, color, now)
	bursts.spawn(BurstSystem.Kind.STAR, to, 2.2, 0.14, color.lightened(0.4), now)
	bursts.spawn(BurstSystem.Kind.GROUND_GLOW, to, 6.0, 0.35, color * 0.8, now)


## A hit (big = a tank destroyed): flipbook fireball, sparks star, ground glow, light pulse. `glow` scales the ground glow
## and light (effect families that add their own layers turn it down so lights don't stack into a white-out).
func explosion(position: Vector3, big := false, glow := 1.0) -> void:
	var size := 7.0 if big else 3.2
	var fire := Color(1.0, 0.85, 0.7)
	bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3(0, size * 0.25, 0), size,
			1.1 if big else 0.6, fire, now)
	bursts.spawn(BurstSystem.Kind.STAR, position, size * 0.9, 0.12, Color(1.0, 0.7, 0.35), now)
	bursts.spawn(BurstSystem.Kind.GROUND_GLOW, position, size * 2.6, 0.9 if big else 0.5, Color(0.8, 0.32, 0.08) * glow, now)
	if big:
		# A second, offset fireball so a kill reads bigger than a hit.
		var offset := Vector3(_rng.randf_range(-1.2, 1.2), 1.6, _rng.randf_range(-1.2, 1.2))
		bursts.spawn(BurstSystem.Kind.FIREBALL, position + offset, size * 0.8, 1.3, fire, now + 0.12)
	if explosion_lights:
		lights.flash(position + Vector3(0, 1.5, 0), Color(1.0, 0.55, 0.2), (10.0 if big else 6.0) * glow,
				(22.0 if big else 12.0) * lerpf(0.5, 1.0, glow), 0.8 if big else 0.4, LightPool.PRIORITY_EXPLOSION, now)
	sfx.play_at("explosion_big" if big else "explosion_small", position)
	spectacle.emit(position, 1.0 if big else 0.15)
	if big:
		fires.ignite(position, now, bursts)
	# Kills jolt the view; ordinary hits only register up close.
	shake.add(0.55 if big else 0.12, position, 30.0 if big else 14.0)
