class_name EndShots
extends Node
## `make end-shots` (round 38, feedback F1): the end of a match he commands, filmed per look for the directions page. A real
## commanded skirmish (the planning pause lifted, his army left where it starts, the CPU coming at it) runs until the fight
## is on, then the harness ends it as his round-37 game ended: the enemy reaches the rings' points (`--end-shots-outcome=loss`;
## `win` gives them to him). Writing the score is the harness's only touch on the match, after which everything is the
## game's own end. It films the end from his camera, then clicks the field (F2: a click after the end) and films the answer.
##
## Flags: --end-shots=<abs dir> --end-shots-outcome=loss|win (loss) --end-shots-after=S (sim seconds of fight first, 25)
##        --end-shots-frames=N (clip frames at 12 fps, 72); the look is the game's own --end-look.
## Prints END_SHOTS_START, END_SHOTS_CLICK, END_SHOTS_DONE frames=<n> look=<look> headline=<..>.

const CLIP_FPS := 12.0
## The click lands this far into the clip (s), on the field below the middle of the screen.
const CLICK_AT_S := 3.5
const CLICK_AT := Vector2(0.62, 0.66)
const STILLS_S := [0.6, 2.0, 3.2, 4.4]

var out_dir := ""
var outcome := "loss"
var fight_seconds := 25.0
var clip_frames := 72
var _match: Match
var _hud: Hud


static func wanted() -> bool:
	return LaunchFlags.from_environment().has("end-shots")


func _init() -> void:
	name = "EndShots"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("end-shots")
	outcome = flags.text("end-shots-outcome", outcome)
	fight_seconds = float(flags.text("end-shots-after", str(fight_seconds)))
	clip_frames = flags.integer("end-shots-frames", clip_frames)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _run() -> void:
	while not _find():
		await get_tree().process_frame
	var controls := _hud.get_node_or_null("TacticalMap")
	if controls != null and controls.has_method("set_paused"):
		controls.call("set_paused", false, "")
	get_tree().paused = false
	print("END_SHOTS_START arena=%s outcome=%s" % [Arena.active.get("name", "?"), outcome])
	while _match.sim_seconds < fight_seconds:
		await get_tree().process_frame
	var side := Match.Team.RUST if outcome == "loss" else Match.Team.GREEN
	_match.control_point = true
	_match.control_score[side] = Match.CONTROL_POINTS_TO_WIN
	while _hud.end_card == null:
		await get_tree().process_frame
	var card := _hud.end_card
	var folder := out_dir.path_join("clip")
	DirAccess.make_dir_recursive_absolute(folder)
	var clicked := false
	var still := 0
	for frame in clip_frames:
		await _seconds(1.0 / CLIP_FPS)
		var t := (frame + 1) / CLIP_FPS
		if not clicked and t >= CLICK_AT_S:
			clicked = true
			_click(get_viewport().get_visible_rect().size * CLICK_AT)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(folder.path_join("frame_%03d.png" % frame))
		if still < STILLS_S.size() and t >= float(STILLS_S[still]):
			image.save_png(out_dir.path_join("still_%d_%.1fs.png" % [still + 1, t]))
			still += 1
	print("END_SHOTS_DONE frames=%d look=%s headline=%s reason=\"%s\" notices=%d" % [clip_frames, card.look, card.headline,
			card.reason, card.notices()])
	get_tree().quit()


func _find() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	_match = scene.get_node_or_null("Match") as Match
	_hud = scene.get_node_or_null("HUD") as Hud
	return _match != null and _hud != null and _match.tanks != null and _match.tanks.get_child_count() > 0 \
			and _hud.get_node_or_null("TacticalMap") != null


func _click(at: Vector2) -> void:
	print("END_SHOTS_CLICK at=(%d,%d)" % [int(at.x), int(at.y)])
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
