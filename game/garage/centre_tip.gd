class_name CentreTip
extends Control
## Round 15 (H1; round 14's tour: "I didn't do anything and lost" — every first fight with no orders was lost 7–0 on
## the control point, and nothing before the fight said the centre scores). One line on a card at the top of the
## player's first fight from the garage, under the planning banner: it is there for the whole planning pause (where the
## orders are given) and SHOW_SECONDS of play after it, and a tap anywhere on it dismisses it. Once per fresh profile
## (GarageSettings.take_centre_tip). The results screen's time-out line ends with the same words (H6), so the loss
## teaches the thing the tip said.
##
## Why at the fight, not in the garage's tip bar: the player this is for taps FIGHT first, before the bar's three tips
## have advanced, and the centre means nothing until the arena is on screen.

## The tip, word for word what ResultsScreen says after a time-out lost on the point.
const LINE := "The centre scores — hold it or lose on time."
## Round 19: every dealt map scores two side rings, not a centre (board's finding); the tip says what the map scores.
const RINGS_LINE := "The rings score — hold them or lose on time."
const SHOW_SECONDS := 12.0
## The card's top, as a share of the screen height: under the planning banner (RtsControls draws it at 0.14).
const TOP_FRACTION := 0.2
const FONT_1080 := 30.0

## The words on this card (LINE, or RINGS_LINE on a map with several scoring zones: show_over picks).
var line := LINE
var _played := 0.0
var _label: Label
var _close: Label


func _init() -> void:
	name = "CentreTip"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CyberStyle.CARD
	style.border_color = CyberStyle.YELLOW
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = CyberStyle.label(line, FONT_1080, CyberStyle.YELLOW)
	_label.name = "Line"
	_close = CyberStyle.label("  X", FONT_1080, CyberStyle.TEXT)
	_close.name = "Close"
	row.add_child(_label)
	row.add_child(_close)
	panel.add_child(row)
	add_child(panel)
	_layout.call_deferred()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var screen := get_viewport_rect().size
	var s := CyberStyle.ui_scale(screen)
	var px := roundi(FONT_1080 * s)
	for label: Label in [_label, _close]:
		label.add_theme_font_size_override("font_size", px)
	var panel := get_child(0) as PanelContainer
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(14.0 * s)
	panel.reset_size()
	size = panel.get_combined_minimum_size()
	panel.size = size
	position = Vector2((screen.x - size.x) / 2.0, screen.y * TOP_FRACTION)


func _process(delta: float) -> void:
	advance(delta, get_tree().paused)


## Time passes; the card goes once SHOW_SECONDS of unpaused play have passed (the planning pause does not count).
func advance(seconds: float, paused: bool) -> void:
	if not paused:
		_played += seconds
	if _played >= SHOW_SECONDS:
		dismiss()


func dismiss() -> void:
	if is_queued_for_deletion() or (get_parent() != null and get_parent().is_queued_for_deletion()):
		return
	print("GARAGE_CENTRE_TIP dismissed after %.1f s of play" % _played)
	var layer := get_parent()
	(layer if layer is CanvasLayer and layer.name == "CentreTipLayer" else self).queue_free()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		dismiss()


## The tip for a map that scores `zones` zones: the centre for one, the rings for more.
static func line_for(zones: int) -> String:
	return RINGS_LINE if zones > 1 else LINE


## Put the tip over the fight that just started under `main` (GarageMode's handover); returns it.
static func show_over(main: Node) -> CentreTip:
	var layer := CanvasLayer.new()
	layer.name = "CentreTipLayer"
	layer.layer = 15
	var tip := CentreTip.new()
	var game_match: Variant = main.get("game_match")
	if game_match is Match:
		tip.line = CentreTip.line_for((game_match as Match).objectives.size())
	layer.add_child(tip)
	main.add_child(layer)
	print("GARAGE_CENTRE_TIP shown: %s" % tip.line)
	return tip
