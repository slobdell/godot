class_name LobbyPanel
extends Control
## Touch-first multiplayer lobby (netcode): HOST A MATCH, or type a room code on an on-screen
## keypad and JOIN. No keyboard needed (phones), and every target is at least 48 px. Styling is
## deliberately plain: look & feel can reskin it (it only uses Buttons, Labels and containers).
## LobbyMode decides what hosting and joining do.

signal host_requested
signal join_requested(code: String)

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # server/broker/src/protocol.mjs ROOM_ALPHABET
const CODE_LENGTH := 5
const MIN_TARGET_PX := 48

var code := ""
var host_button: Button
var join_button: Button
var delete_button: Button
var key_buttons: Array[Button] = []

var _code_label: Label
var _status_label: Label
var _labels: Array[Label] = []
var _layout: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # offsets too (trip-up #29)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_layout = VBoxContainer.new()
	_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_layout)

	_add_label("MULTIPLAYER", 1.0)
	host_button = _add_button(_layout, "HOST A MATCH")
	host_button.pressed.connect(func() -> void: host_requested.emit())
	_add_label("or join a friend's room", 0.45)
	_code_label = _add_label("", 0.9)
	var grid := GridContainer.new()
	grid.columns = 8
	_layout.add_child(grid)
	for character in ALPHABET:
		var key := _add_button(grid, character)
		key.pressed.connect(type_character.bind(character))
		key_buttons.append(key)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(row)
	delete_button = _add_button(row, "DEL")
	delete_button.pressed.connect(delete_character)
	join_button = _add_button(row, "JOIN")
	join_button.pressed.connect(func() -> void:
		if code.length() == CODE_LENGTH:
			join_requested.emit(code))
	_status_label = _add_label("", 0.4)
	get_viewport().size_changed.connect(_fit)
	_refresh()
	_fit()


func type_character(character: String) -> void:
	if code.length() < CODE_LENGTH and ALPHABET.contains(character):
		code += character
	_refresh()


func delete_character() -> void:
	code = code.left(maxi(code.length() - 1, 0))
	_refresh()


func set_status(text: String) -> void:
	_status_label.text = text


func _refresh() -> void:
	var shown := ""
	for i in CODE_LENGTH:
		shown += (code[i] if i < code.length() else "_") + (" " if i < CODE_LENGTH - 1 else "")
	_code_label.text = shown
	join_button.disabled = code.length() != CODE_LENGTH


## Size everything from the screen: a keypad key is a twelfth of the short side (never under 48 px).
func _fit() -> void:
	var screen := get_viewport_rect().size
	var unit := maxf(MIN_TARGET_PX, floorf(minf(screen.x / 9.5, screen.y / 12.5)))
	_layout.add_theme_constant_override("separation", int(unit * 0.15))
	for key in key_buttons + [delete_button]:
		key.custom_minimum_size = Vector2(unit, unit)
		key.add_theme_font_size_override("font_size", int(unit * 0.45))
	join_button.custom_minimum_size = Vector2(unit * 3.0, unit)
	join_button.add_theme_font_size_override("font_size", int(unit * 0.45))
	host_button.custom_minimum_size = Vector2(unit * 8.0, unit * 1.1)
	host_button.add_theme_font_size_override("font_size", int(unit * 0.5))
	for label in _labels:
		label.add_theme_font_size_override("font_size", int(unit * float(label.get_meta("scale"))))


func _add_label(text: String, scale: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta("scale", scale)
	_layout.add_child(label)
	_labels.append(label)
	return label


func _add_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button
