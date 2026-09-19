class_name CameraReadout
extends Control
## Round 6, after the lead rejected two camera defaults chosen from still frames ("the game is unplayable now"): the
## camera's live values on screen, with the keys that change them, so he can find the camera in play and send it back.
## P copies the pose (RtsCamera.pose_text) to the clipboard and prints it; the defaults are then made from it.
## Top-left, under the status panel and the quality buttons. `--camera-readout=off` hides it.

const FONT_1080 := 16.0

var rig: RtsCamera
## Round 7: for the range-framing factor and the selection's reach (optional).
var controls: RtsControls
## The last pose P copied, shown for a few seconds as confirmation.
var _copied := ""
var _copied_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func copied(pose: String) -> void:
	_copied = pose
	_copied_left = 4.0


func _process(delta: float) -> void:
	_copied_left = maxf(0.0, _copied_left - delta)
	queue_redraw()


## The lines drawn (tests read them).
func lines() -> Array[String]:
	var result: Array[String] = []
	if rig == null:
		return result
	var distance := RtsCamera.distance_for(rig.zoom)
	result.append("CAMERA  pitch %d°   distance %d m   FOV %d°   yaw %d°   auto-frame %s   yaw-follow %s   range %s" % [
			roundi(RtsCamera.tilt_at(rig.pitch, distance)), roundi(distance), roundi(RtsCamera.fov),
			roundi(rad_to_deg(rig.yaw)), "ON" if rig.auto_frame else "OFF", "ON" if rig.yaw_follow else "OFF",
			("x%.2f (%d m)" % [controls.range_frame, roundi(controls.selection_reach())]) if controls != null else "-"])
	result.append("PgUp/PgDn tilt · wheel or - = distance · [ ] FOV · , . turn · V auto-frame · Y yaw-follow · ; ' range · P copy pose")
	if _copied_left > 0.0:
		result.append("Copied: " + _copied)
	return result


func _draw() -> void:
	var shown := lines()
	if shown.is_empty():
		return
	var s := CyberStyle.ui_scale(get_viewport_rect().size)
	var px := roundi(FONT_1080 * s)
	var font := CyberStyle.font()
	var width := 0.0
	for line in shown:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var at := Vector2(12.0 * s, 222.0 * s)
	draw_rect(Rect2(at - Vector2(6.0, px * 1.1), Vector2(width + 12.0, px * 1.4 * shown.size() + 6.0)), Color(CyberStyle.HUD_BACKGROUND, 0.8))
	for i in shown.size():
		var color: Color = CyberStyle.CYAN if i == 0 else (CyberStyle.YELLOW if i == 2 else Color(CyberStyle.TEXT, 0.8))
		draw_string(font, at + Vector2(0, i * px * 1.4), shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
