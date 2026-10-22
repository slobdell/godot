class_name FeedbackFight
extends Node
## `make feedback-fight` (round 37, feedback): the looks he picked (FeedbackLook) in a REAL fight, nothing staged, so he
## can judge them in motion. A CPU-v-CPU skirmish runs as he
## plays it, spectated so it starts without the planning pause (gangs, who bring the Resupply Tanker, against the Law, who bring the Sonic Emitter; `--render-preset=laptop`
## from the Makefile), and the camera waits at his pose (21 deg, FOV 35, 49 m) for each slot's moment to happen on its
## own, then follows it for a short clip:
##
##   hit     a vehicle just struck on the flank or the rear (the clip follows it while more rounds land)
##   pinned  the most suppressed crew in sight
##   repair  a Tanker mending a hurt friend (the patient)
##   cone    an Emitter blowing (between it and where it points)
##
## Flags: --feedback-fight=<abs dir>  --feedback-fight-look=<FeedbackLook spec, default RECOMMENDED>
##        --feedback-fight-slots=hit,repair (all four)  --feedback-fight-clips=N per slot (2)  --feedback-fight-frames=N per clip (36)  --feedback-fight-max-s=S (300)
## Prints FEEDBACK_FIGHT_CLIP <name> subject=<unit> events=<n> and FEEDBACK_FIGHT_DONE clips=<n> missing=<slots>.

const SLOTS := ["hit", "pinned", "repair", "cone"]
const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const CLIP_FPS := 12.0
## How often the fight is searched for a moment (s).
const LOOK_EVERY_S := 0.25

var out_dir := ""
var clips_per_slot := 2
var clip_frames := 36
var max_seconds := 300.0
var _match: Match
var _rig: RtsCamera
var _taken := {}
var _clips := 0
## Flank/rear hits seen during the current clip, and the unit the clip follows (for the hit count).
var _events := 0
var _subject_names := {}
var _ended := false
## target name -> the times (FxWorld.now) of its recent flank / rear hits, for the hit clip's subject.
var _flanked := {}
var _arcing := {}
const FLANKED_S := 2.0
## A clip of the hit slot waits for a target struck on the flank or rear this many times in FLANKED_S: a crew that is
## being flanked, not one stray round, so more hits land while the clip rolls.
const FLANKED_HITS := 2
const STATE_EVERY_S := 5.0
var _next_state := 0.0


static func wanted() -> bool:
	return LaunchFlags.from_environment().has("feedback-fight")


func _init() -> void:
	name = "FeedbackFight"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("feedback-fight")
	clips_per_slot = flags.integer("feedback-fight-clips", clips_per_slot)
	clip_frames = flags.integer("feedback-fight-frames", clip_frames)
	max_seconds = float(flags.integer("feedback-fight-max-s", int(max_seconds)))
	FeedbackLook.use(flags.text("feedback-fight-look"))
	var wanted_slots := flags.text("feedback-fight-slots", ",".join(SLOTS)).split(",", false)
	for slot: String in SLOTS:
		_taken[slot] = 0 if wanted_slots.has(slot) else clips_per_slot
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _run() -> void:
	while not _find():
		await get_tree().process_frame
	_match.projectile_impact.connect(_on_impact)
	_match.weapon_fired.connect(_on_fired)
	_match.finished.connect(func(_result: Dictionary) -> void: _ended = true)
	print("FEEDBACK_FIGHT_START look=%s arena=%s" % [FeedbackLook._on, Arena.active.get("name", "?")])
	var started := Time.get_ticks_msec()
	while _missing().size() > 0 and _match_running() and (Time.get_ticks_msec() - started) / 1000.0 < max_seconds:
		var moment := _moment()
		_state()
		if moment.is_empty():
			await _seconds(LOOK_EVERY_S)
			continue
		await _film(moment)
	print("FEEDBACK_FIGHT_DONE clips=%d missing=%s" % [_clips, ",".join(_missing())])
	get_tree().quit()


func _find() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	_match = scene.get_node_or_null("Match") as Match
	_rig = scene.find_child("RtsCamera", true, false) as RtsCamera
	return _match != null and _rig != null and _match.tanks != null and _match.tanks.get_child_count() > 0 \
			and FxWorld.existing() != null


func _match_running() -> bool:
	return is_instance_valid(_match) and not _ended


func _missing() -> Array[String]:
	var found: Array[String] = []
	for slot: String in SLOTS:
		if int(_taken[slot]) < clips_per_slot:
			found.append(slot)
	return found


## The first slot still wanting a clip whose moment is happening now: {slot, subject (Tank), aim (Callable -> Vector3)}.
func _moment() -> Dictionary:
	var fx := FxWorld.existing()
	var feedback := fx.feedback
	var now := fx.now
	var missing := _missing()
	for node in _match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive() or not feedback._shown(tank):
			continue
		if missing.has("hit") and _flank_count(tank.name, now) >= FLANKED_HITS:
			return {"slot": "hit", "subject": tank, "aim": _on.bind(tank)}
		if missing.has("repair"):
			var link := feedback.mending_of(tank.name)
			if not link.is_empty() and link["node"] != tank and is_instance_valid(link["node"]):
				return {"slot": "repair", "subject": tank, "aim": _between.bind(tank, link["node"])}
	if missing.has("pinned"):
		var worst: Tank = null
		for node in _match.tanks.get_children():
			var tank := node as Tank
			if tank != null and tank.is_alive() and feedback.pinned_of(tank.name) >= 0.6 \
					and (worst == null or tank.suppression > worst.suppression):
				worst = tank
		if worst != null:
			return {"slot": "pinned", "subject": worst, "aim": _on.bind(worst)}
	if missing.has("cone"):
		for cone: Dictionary in feedback.reader.active_cones(now):
			var shooter := _match.tanks.get_node_or_null(String(cone["shooter"])) as Tank
			if shooter != null and shooter.is_alive() and feedback._shown(shooter):
				return {"slot": "cone", "subject": shooter, "aim": _along_cone.bind(shooter, float(cone["range"]) * 0.4)}
	return {}


func _on(tank: Tank) -> Vector3:
	return FxWorld.visual_transform(tank).origin


func _between(a: Tank, b: Node) -> Vector3:
	return (_on(a) + FxWorld.visual_transform(b as Tank).origin) * 0.5


## Down the Emitter's cone while it blows (its last puff's direction), else ahead of the hull.
func _along_cone(tank: Tank, metres: float) -> Vector3:
	for cone: Dictionary in FxWorld.existing().feedback.reader.active_cones(FxWorld.existing().now):
		if String(cone["shooter"]) == String(tank.name):
			return _on(tank) + (cone["direction"] as Vector3) * metres
	return _on(tank) + -FxWorld.visual_transform(tank).basis.z * metres


func _film(moment: Dictionary) -> void:
	var slot := String(moment["slot"])
	var subject: Tank = moment["subject"]
	var aim: Callable = moment["aim"]
	_taken[slot] = int(_taken[slot]) + 1
	var clip_name := "%s_fight_%d" % [slot, int(_taken[slot])]
	var folder := out_dir.path_join(clip_name)
	DirAccess.make_dir_recursive_absolute(folder)
	_events = 0
	_subject_names = {subject.name: true}
	var yaw := _rig.yaw
	# The spectator's director picks its own shots between clips; during one it would cut away mid-clip.
	var director := get_tree().current_scene.find_child("CinematicCamera", true, false)
	if director != null:
		director.set_process(false)
	var shot := 0
	for frame in clip_frames:
		if is_instance_valid(subject) and subject.is_alive():
			_pose(aim.call(), yaw)
		await _seconds(1.0 / CLIP_FPS)
		await _frames(1)
		get_viewport().get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % frame))
		shot += 1
		if not is_instance_valid(subject):
			break
	if director != null:
		director.set_process(true)
	_clips += 1
	var fx := FxWorld.existing()
	print("FEEDBACK_FIGHT_CLIP %s subject=%s unit=%s frames=%d flank_or_rear_hits=%d counts=%s" % [clip_name,
			subject.name if is_instance_valid(subject) else "?", subject.unit_id if is_instance_valid(subject) else "?",
			shot, _events, fx.feedback.last_counts if fx != null else {}])


func _on_impact(event: Dictionary) -> void:
	if not ["side", "rear"].has(FeedbackReader.hit_kind(event)) or _arcing.erase(int(event.get("projectile_id", -1))):
		return
	var target := String(event.get("target", ""))
	if _subject_names.has(target):
		_events += 1
	var times: Array = _flanked.get(target, [])
	times.append(FxWorld.existing().now)
	_flanked[target] = times


## Artillery falls from above: FeedbackFx draws no flank for it, so it does not pick a hit clip either.
func _on_fired(event: Dictionary) -> void:
	if String(event.get("fire_model", "")) == "arc":
		_arcing[int(event.get("projectile_id", -1))] = true
		if _arcing.size() > 512:
			_arcing.clear()


func _flank_count(target: String, now: float) -> int:
	var times: Array = _flanked.get(target, [])
	while not times.is_empty() and now - float(times[0]) > FLANKED_S:
		times.pop_front()
	return times.size()


## Every STATE_EVERY_S: what the fight holds for each slot right now, so a slot that never got its clip says why.
func _state() -> void:
	var fx := FxWorld.existing()
	if fx.now < _next_state:
		return
	_next_state = fx.now + STATE_EVERY_S
	var pinned := 0
	var mending := 0
	var menders := 0
	var hurt_near_mender := 0
	var tanks := _match.tanks.get_children()
	var field := FeedbackReader.menders(tanks)
	for node in tanks:
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		if fx.feedback.pinned_of(tank.name) > 0.0:
			pinned += 1
		if not fx.feedback.mending_of(tank.name).is_empty():
			mending += 1
		if Units.stat(tank.unit_id, "repair_hp_per_second", 0.0) > 0.0:
			menders += 1
		if tank.health < tank.max_health:
			for mender: Dictionary in field:
				var offset: Vector3 = mender["position"] - tank.global_position
				if mender["node"] != tank and int(mender["team"]) == tank.team \
						and Vector2(offset.x, offset.z).length() <= float(mender["radius"]):
					hurt_near_mender += 1
					break
	print("FEEDBACK_FIGHT_STATE t=%.0f alive=%d pinned=%d menders=%d hurt_in_reach=%d mending=%d cones=%d" % [fx.now,
			tanks.filter(func(t: Node) -> bool: return t is Tank and (t as Tank).is_alive()).size(), pinned, menders,
			hurt_near_mender, mending, fx.feedback.reader.active_cones(fx.now).size()])


## His pose over `point`: the rig's own smoothing is skipped (snap) so every frame is framed, never mid-pan.
func _pose(point: Vector3, yaw: float) -> void:
	_rig.stop_tracking("feedback-fight")
	_rig.auto_frame = false
	_rig.vision = Callable()
	_rig.vision_region = null
	_rig.follow_target = null
	_rig.yaw_follow = false
	_rig.edge_pan = false
	_rig.focus = Vector3(point.x, 0.0, point.z)
	_rig.yaw = yaw
	_rig.zoom = RtsCamera.level_for(DISTANCE_M)
	_rig.pitch = PITCH_DEG
	_rig.snap()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
