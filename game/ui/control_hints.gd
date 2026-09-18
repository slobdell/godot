class_name ControlHints
extends Control
## Control X6 (round 5): the controls a first-time player can discover without reading anything else. A short column
## of hints in the bottom-left corner (the one corner the command card, radar, messages and alerts leave free), at
## most three at a time, in the order a new player needs them. Each goes for good the first time the player does
## what it says, remembered in `store_path`, so a returning player sees none. It only watches input, never takes it.

## id -> [keys, what it does], in the order they're offered.
const HINTS := {
	"select": ["1-5", "pick an element"],
	"order": ["RIGHT-CLICK", "move there / attack it"],
	"pause": ["SPACE", "pause to plan"],
	"attack_move": ["A + CLICK", "attack-move"],
	"tasks": ["E / R", "screen / support by fire"],
	"alert": ["Q", "jump to trouble"],
	"tilt": ["PGUP / PGDN", "tilt the camera (O: map view)"],
}
const SHOWN_AT_ONCE := 3
const FONT_1080 := 17.0
const MIN_FONT := 13

## Where learned hints are remembered; "" remembers nothing (a playtest that must not teach the real player's profile).
var store_path := "user://control_hints.cfg"

var _learned := {}
var _config := ConfigFile.new()


func _ready() -> void:
	name = "ControlHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if store_path != "" and _config.load(store_path) == OK:
		for id: String in HINTS:
			if bool(_config.get_value("learned", id, false)):
				_learned[id] = true
	_refresh()


## The hint ids on screen now, top to bottom.
func shown() -> Array:
	var result: Array = []
	for id: String in HINTS:
		if not _learned.has(id):
			result.append(id)
			if result.size() >= SHOWN_AT_ONCE:
				break
	return result


func learn(id: String) -> void:
	if _learned.has(id) or not HINTS.has(id):
		return
	_learned[id] = true
	if store_path != "":
		_config.set_value("learned", id, true)
		_config.save(store_path)
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				learn("select")
			KEY_SPACE:
				learn("pause")
			KEY_A:
				if not key.ctrl_pressed and not key.meta_pressed:
					learn("attack_move")
			KEY_E, KEY_R:
				learn("tasks")
			KEY_Q:
				learn("alert")
			KEY_PAGEUP, KEY_PAGEDOWN, KEY_O:
				learn("tilt")
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		learn("order")


func font_size() -> int:
	return maxi(MIN_FONT, roundi(FONT_1080 * CyberStyle.ui_scale(get_viewport_rect().size)))


## Where the hint column sits (empty when there's nothing to show).
func panel_rect() -> Rect2:
	var ids := shown()
	if ids.is_empty():
		return Rect2()
	var screen := get_viewport_rect().size
	var px := font_size()
	var line := px * 1.55
	var width := minf(screen.x * 0.23, px * 22.0)
	var height := line * ids.size() + px * 0.8
	return Rect2(Vector2(px * 0.9, screen.y - height - px * 0.9), Vector2(width, height))


func _refresh() -> void:
	visible = not shown().is_empty()
	queue_redraw()


func _draw() -> void:
	var rect := panel_rect()
	if not rect.has_area():
		return
	var px := font_size()
	var font := CyberStyle.font()
	draw_rect(rect, Color(CyberStyle.HUD_BACKGROUND, 0.6))
	var y := rect.position.y + px * 0.4 + px
	var keys_width := px * 7.0
	for id: String in shown():
		var hint: Array = HINTS[id]
		draw_string(font, Vector2(rect.position.x + px * 0.5, y), String(hint[0]), HORIZONTAL_ALIGNMENT_LEFT, keys_width, px,
				CyberStyle.YELLOW)
		draw_string(font, Vector2(rect.position.x + px * 0.5 + keys_width, y), String(hint[1]), HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - keys_width - px, roundi(px * 0.85), Color(CyberStyle.TEXT, 0.85))
		y += px * 1.55
