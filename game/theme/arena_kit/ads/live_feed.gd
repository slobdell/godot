class_name LiveFeed
extends Node
## The arena screens' live match feed (render, round 5; the lead: "Live during, ads between"). One broadcast camera
## follows the fighting and renders at FEED_HZ into a ring of small SubViewports that share the arena's world: the newest
## slot is what the screens show live, and the whole ring is the replay buffer, so a kill can be replayed from frames
## already on the GPU (no readback, no simulation rewind). Every AdBroadcast channel shows it while a match is fought
## and goes back to its ads between matches. Visual only. Measured with perf-scene's `no_live_feed` layer.

## Feed renders per second, and the ring per quality tier: [slots, size]. Low (web, phones) keeps the ads.
const FEED_HZ := 15.0
const TIERS := {
	FxQuality.Tier.LOW: [0, Vector2i(0, 0)],
	FxQuality.Tier.MEDIUM: [16, Vector2i(192, 384)],
	FxQuality.Tier.HIGH: [30, Vector2i(256, 512)],
}
## A replay plays the ring at this fraction of real time.
const REPLAY_SPEED := 0.5
## Only kills within this far of where the camera is looking are replayed (m), at most once per REPLAY_COOLDOWN (s),
## REPLAY_DELAY after the kill so the ring holds the moments after it too.
const REPLAY_RANGE := 45.0
const REPLAY_COOLDOWN := 9.0
const REPLAY_DELAY := 0.6
## The broadcast camera: height and distance behind its focus (m), how fast the focus follows the action, orbit speed.
const SHOT := Vector2(42.0, 24.0)
const FOCUS_RATE := 1.2
## The shot frames every vehicle this close to its centre (m); a frame needs MIN_IN_SHOT of them to be recorded.
const CLUSTER_RADIUS := 30.0
const MIN_IN_SHOT := 3
## Kills and hits pull the shot for this long (s); a far switch is a cut, at most every CUT_SECONDS; with no frame worth
## recording for STALE_SECONDS the screens go back to ads.
const EVENT_SECONDS := 4.0
const CUT_SECONDS := 3.0
const STALE_SECONDS := 2.0
const ORBIT_RAD_PER_S := 0.06
const FOV_DEG := 50.0
## A frame this much over the frame target is already late (the simulation is catching up): the feed renders no slot in
## it, because adding a scene render to a late frame is what a player sees as a hitch (render, round 5).
const LATE_FRAME := 1.3

## Record-order bookkeeping for the ring of slots. Pure.
class Ring:
	var size := 0
	var recorded := 0

	func _init(slots: int) -> void:
		size = slots

	## Advance to the next slot and return it (the slot this frame renders into).
	func record() -> int:
		recorded += 1
		return (recorded - 1) % size

	func live_slot() -> int:
		return (recorded - 1) % size if recorded > 0 else -1

	func oldest_first() -> Array:
		var count := mini(recorded, size)
		var result := []
		for i in count:
			result.append((recorded - count + i) % size)
		return result


## A replay: which slot shows at a time since it started. Pure.
class Replay:
	var slots: Array = []
	var rate := 7.5

	func _init(order: Array, frames_per_second: float) -> void:
		slots = order
		rate = frames_per_second

	func slot_at(seconds: float) -> int:
		return slots[clampi(int(seconds * rate), 0, slots.size() - 1)] if not slots.is_empty() else -1

	func finished_at(seconds: float) -> bool:
		return seconds * rate >= slots.size()


static func should_be_live(match_running: bool, match_finished: bool, tier_has_feed: bool) -> bool:
	return match_running and not match_finished and tier_has_feed


static func wants_replay(weight: float, distance_to_focus: float, since_last_replay: float) -> bool:
	return weight >= 0.9 and distance_to_focus <= REPLAY_RANGE and since_last_replay >= REPLAY_COOLDOWN


## perf-scene turns this off to measure what the feed costs.
var enabled := true
var ring: Ring
var slots: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var replaying := false
## Seconds of the feed's own clock, and when things last happened on it.
var now := 0.0
var focus := Vector3.ZERO
var replays_started := 0
## Frame number of the last slot rendered (perf-scene's hitch log asks whether a feed frame landed in a slow frame).
var last_render_frame := -1

var _replay: Replay
var _replay_started := 0.0
var _pending_replay_at := -1.0
var _last_replay := -1000.0
var _orbit := 0.0
var _since_render := 0.0
var _match: Node
var _finished := false
var _environment: Environment
var _target := Vector3.ZERO
var _shot_left := 0.0
var _in_shot := 0
var _last_cut := -1000.0
var _last_recorded := -1000.0
## Recent kills and hits: [{position, time, weight}], newest last.
var _events: Array = []


## The feed for `node`'s viewport, created on first use; null where nothing renders.
static func for_node(node: Node) -> LiveFeed:
	if DisplayServer.get_name() == "headless":
		return null
	var root := (Engine.get_main_loop() as SceneTree).root
	if root.has_meta("live_feed"):
		var existing: Variant = root.get_meta("live_feed")
		if is_instance_valid(existing):
			return existing
	var feed := LiveFeed.new()
	feed.name = "LiveFeed"
	root.set_meta("live_feed", feed)
	root.add_child.call_deferred(feed)
	return feed


func _ready() -> void:
	_build()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.spectacle.connect(_on_spectacle)
		fx.quality_changed.connect(_build)


## Whether screens should show the feed right now.
func is_live() -> bool:
	if ring == null:
		return false  # not built yet (the channel asked before the feed entered the tree)
	return enabled and LiveFeed.should_be_live(_match_running(), _finished, not slots.is_empty()) and ring.recorded > 0 \
			and (replaying or now - _last_recorded <= STALE_SECONDS)


## The texture screens show: the replay frame while replaying, else the newest slot.
func texture() -> Texture2D:
	if ring == null or slots.is_empty() or ring.recorded == 0:
		return null
	var slot := _replay.slot_at(now - _replay_started) if replaying else ring.live_slot()
	return slots[slot].get_texture()


func _process(delta: float) -> void:
	now += delta
	if ring == null or slots.is_empty() or not enabled or not _match_running() or _finished:
		return
	_follow_action(delta)
	if replaying:
		if _replay.finished_at(now - _replay_started):
			replaying = false
		return
	if _pending_replay_at >= 0.0 and now >= _pending_replay_at:
		_pending_replay_at = -1.0
		if ring.recorded >= 4:
			_replay = Replay.new(ring.oldest_first(), FEED_HZ * REPLAY_SPEED)
			_replay_started = now
			_last_replay = now
			replaying = true
			replays_started += 1
			return
	_since_render += delta
	if _since_render < 1.0 / FEED_HZ:
		return
	# Never add a scene render to a frame that is already late: when the simulation is catching up (several ticks in one
	# frame) a feed frame turns a slow frame into a visible hitch. The feed waits for a frame with room in it.
	if delta > LATE_FRAME * 1.0 / maxf(float(FrameTarget.value("fps")), 1.0):
		return
	_since_render = fmod(_since_render, 1.0 / FEED_HZ)
	if not LiveFeed.worth_recording(_in_shot):
		return  # empty ground: the screens hold the last good frame (or go back to ads once it's stale)
	_last_recorded = now
	var slot := ring.record()
	last_render_frame = Engine.get_frames_drawn()
	cameras[slot].global_transform = _shot()
	slots[slot].render_target_update_mode = SubViewport.UPDATE_ONCE


func _build() -> void:
	for viewport in slots:
		viewport.queue_free()
	slots.clear()
	cameras.clear()
	var tier: Array = TIERS[FxQuality.tier()]
	ring = Ring.new(maxi(int(tier[0]), 1))
	replaying = false
	if int(tier[0]) <= 0:
		return
	for i in int(tier[0]):
		var viewport := SubViewport.new()
		viewport.name = "Slot%d" % i
		viewport.size = tier[1]
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.mesh_lod_threshold = 8.0
		var camera := Camera3D.new()
		camera.fov = FOV_DEG
		# Portrait screens: FOV_DEG across, so the shot is as wide as the scrap rather than a tall sliver.
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.far = 260.0
		camera.environment = _feed_environment()
		viewport.add_child(camera)
		camera.current = true
		add_child(viewport)
		slots.append(viewport)
		cameras.append(camera)


## The arena's environment without glow (the screen shader adds its own bloom-free LED look; glow per slot would double
## the feed's cost).
func _feed_environment() -> Environment:
	if _environment == null:
		for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			var source := (world as WorldEnvironment).environment
			if source != null:
				_environment = source.duplicate() as Environment
				_environment.glow_enabled = false
				break
	return _environment


func _match_running() -> bool:
	if _match != null and is_instance_valid(_match) and not _match.is_queued_for_deletion():
		return true
	_match = null
	_finished = false
	var fx := FxWorld.existing()
	var found: Node = fx.link.attached_match() if fx != null else null
	if found != null and found.has_signal("finished"):
		_match = found
		found.connect("finished", func(_result: Dictionary) -> void: _finished = true)
		ring.recorded = 0
		return true
	return false


## Where the action is: kills and hits pull the focus (weighted, fading), else the middle of the living vehicles.
func _follow_action(delta: float) -> void:
	_orbit += delta * ORBIT_RAD_PER_S
	_shot_left -= delta
	if _shot_left > 0.0:
		focus = focus.lerp(_target, clampf(delta * FOCUS_RATE, 0.0, 1.0))
		return
	_shot_left = 0.5
	var points: Array = []
	var teams: Array = []
	var tanks: Node = _match.get("tanks") if _match != null else null
	if tanks != null:
		for tank in tanks.get_children():
			if tank is Node3D and (tank as Node3D).visible and tank.get("team") != null:
				points.append(FxWorld.visual_transform(tank as Node3D).origin)
				teams.append(int(tank.get("team")))
	var events: Array = []
	for event: Dictionary in _events:
		events.append({"position": event["position"], "age": now - float(event["time"]), "weight": event["weight"]})
	var shot := LiveFeed.best_shot(points, teams, events)
	_target = shot["point"]
	_in_shot = int(shot["count"])
	# A far switch is a broadcast cut, not a pan across empty ground.
	if Vector2(_target.x - focus.x, _target.z - focus.z).length() > CLUSTER_RADIUS and now - _last_cut >= CUT_SECONDS:
		focus = _target
		_last_cut = now
	else:
		focus = focus.lerp(_target, clampf(delta * FOCUS_RATE, 0.0, 1.0))


## The best shot: the vehicle whose neighbourhood (CLUSTER_RADIUS) scores highest for vehicles in it, both teams being
## there, and fresh kills and hits nearby; framed on the centroid of that neighbourhood. `events` are
## {position, age (s), weight}. Returns {point, count, score}. Pure.
static func best_shot(points: Array, teams: Array, events: Array) -> Dictionary:
	var best := {"point": Vector3.ZERO, "count": 0, "score": -1.0}
	for i in points.size():
		var center: Vector3 = points[i]
		var count := 0
		var sides := {}
		var sum := Vector3.ZERO
		for j in points.size():
			var p: Vector3 = points[j]
			if Vector2(p.x - center.x, p.z - center.z).length() <= CLUSTER_RADIUS:
				count += 1
				sides[teams[j]] = true
				sum += Vector3(p.x, 0.0, p.z)
		var score := float(count) + (3.0 if sides.size() > 1 else 0.0)
		for event: Dictionary in events:
			var at: Vector3 = event["position"]
			if Vector2(at.x - center.x, at.z - center.z).length() <= CLUSTER_RADIUS:
				score += 2.5 * float(event["weight"]) * maxf(0.0, 1.0 - float(event["age"]) / EVENT_SECONDS)
		if score > float(best["score"]):
			best = {"point": sum / count, "count": count, "score": score}
	return best


static func worth_recording(vehicles_in_shot: int) -> bool:
	return vehicles_in_shot >= MIN_IN_SHOT


func _shot() -> Transform3D:
	var back := Vector3(sin(_orbit), 0.0, cos(_orbit)) * SHOT.y
	return Transform3D(Basis.IDENTITY, focus + back + Vector3.UP * SHOT.x).looking_at(focus, Vector3.UP)


func _on_spectacle(position: Vector3, weight: float) -> void:
	# Kills and hits pull the shot (best_shot weighs them); the biggest are replayed.
	var pull := clampf(weight, 0.0, 1.0)
	var at := Vector3(position.x, 0.0, position.z)
	if pull >= 0.3:
		_events.append({"position": at, "time": now, "weight": pull})
		while not _events.is_empty() and (_events.size() > 24 or now - float(_events[0]["time"]) > EVENT_SECONDS):
			_events.pop_front()
	if not replaying and _pending_replay_at < 0.0 \
			and LiveFeed.wants_replay(weight, Vector2(position.x - focus.x, position.z - focus.z).length(), now - _last_replay):
		_pending_replay_at = now + REPLAY_DELAY
