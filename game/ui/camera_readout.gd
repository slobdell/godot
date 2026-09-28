class_name CameraReadout
extends Control
## Round 6, after the lead rejected two camera defaults chosen from still frames ("the game is unplayable now"): the
## camera's live values on screen, with the keys that change them, so he can find the camera in play and send it back.
## P copies the pose (RtsCamera.pose_text) to the clipboard and prints it; the defaults are then made from it.
## `--camera-readout=on` shows it (see `wanted`).
##
## Round 14 (garage G4, a carve-out; round 13's tour at 20:9: "there's debug text over the HUD"): OFF for a player,
## ON under `--camera-readout=on` (`make skirmish`, the lead's launch, passes it: his tool stays where he had it). It
## sat at a fixed (12, 222) x ui_scale, which at 20:9 with the touch HUD is on top of the score box and the FX /
## QUALITY buttons; it now sits between the HUD's two message columns, level with their top, and its text shrinks to
## fit that gap.

const FONT_1080 := 16.0

var rig: RtsCamera
## Round 7: for the range-framing factor and the selection's reach (optional).
var controls: RtsControls
## The last pose P copied, shown for a few seconds as confirmation.
var _copied := ""
var _copied_left := 0.0


## Whether a skirmish shows the readout: only when asked for (`--camera-readout=on`).
static func wanted(flags: LaunchFlags) -> bool:
	return flags.text("camera-readout", "off") == "on"


## Where the readout's text starts and how big it is, on a `screen` of that size for text `widest_at_1px` wide at 1 px.
## The gap it uses is the one between HudSkin._place_messages's two columns (the same formula, read from there: the
## info column is `column_width` wide at x = margin, from y = 0.22 x height; the warning column mirrors it on the right).
static func placement(screen: Vector2, widest_at_1px: float) -> Dictionary:
	var s := CyberStyle.ui_scale(screen)
	var margin := 12.0 * s
	var column_width := clampf((screen.x - screen.y) / 2.0 - margin * 2.0, 220.0 * s, screen.x * 0.26)
	var left := margin + column_width + margin * 1.5
	var right := screen.x - margin - column_width - margin * 1.5
	var px := FONT_1080 * s
	if widest_at_1px > 0.0:
		px = minf(px, (right - left - 12.0) / widest_at_1px)
	px = maxf(px, 9.0)
	return {"at": Vector2(left + 6.0, screen.y * 0.22 + px * 1.1), "px": roundi(px), "right": right}


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
	if rig.frame_short:
		result.append("COLUMN TOO LONG FOR THIS TILT: part of the selection is off screen (PgUp tilts up)")
	if _copied_left > 0.0:
		result.append("Copied: " + _copied)
	return result


func _draw() -> void:
	var shown := lines()
	if shown.is_empty():
		return
	var font := CyberStyle.font()
	var at_100 := 0.0
	for line in shown:
		at_100 = maxf(at_100, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x)
	var place := placement(get_viewport_rect().size, at_100 / 100.0)
	var px: int = place["px"]
	var at: Vector2 = place["at"]
	var width := 0.0
	for line in shown:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	draw_rect(Rect2(at - Vector2(6.0, px * 1.1), Vector2(width + 12.0, px * 1.4 * shown.size() + 6.0)), Color(CyberStyle.HUD_BACKGROUND, 0.8))
	for i in shown.size():
		var color: Color = CyberStyle.CYAN if i == 0 else (CyberStyle.YELLOW if i == 2 else Color(CyberStyle.TEXT, 0.8))
		draw_string(font, at + Vector2(0, i * px * 1.4), shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
