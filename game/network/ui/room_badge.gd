class_name RoomBadge
extends PanelContainer
## The host's room code, big enough to read across a room, plus a button that copies an invite
## link (in a browser: this page's address with ?join=CODE, so a friend just taps the link).

var code := ""
var copy_button: Button
var _code_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -16  # a margin from the screen edge (and from phone corner rounding)
	offset_left = -16
	offset_top = 72
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "ROOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_code_label = Label.new()
	_code_label.text = code
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 44)
	box.add_child(_code_label)
	copy_button = Button.new()
	copy_button.text = "COPY INVITE LINK"
	copy_button.custom_minimum_size = Vector2(220, 56)
	copy_button.focus_mode = Control.FOCUS_NONE
	copy_button.pressed.connect(_copy)
	box.add_child(copy_button)


func invite_link() -> String:
	if OS.has_feature("web"):
		var origin := str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
		return "%s?join=%s" % [origin, code]
	return code


func _copy() -> void:
	DisplayServer.clipboard_set(invite_link())
	copy_button.text = "COPIED"
