class_name FormationPicker
extends Control
## Round 18 (picker, P2/P3): the Formation button's panel. The lead, after playing round 17: *"trying to change the
## formation by way of toggling through button clicks takes too long and it's not apparent what the next formation is.
## I think we should instead have a widget that does a mouseover effect that shows the possible formations, and ...
## a mouseover effect on top of each formation ... that shows the sleek visualization of what the formation does."*
##
## Resting the mouse on the Formation button (or tapping it) opens a panel above it: every formation in
## FormationCatalog's order as its real shape, AUTO first drawn as the shape the leader is forming now, the one in use
## marked NOW and the one G would pick next marked G. One click picks it and the next order uses it. Hovering a card
## (a long press on a phone) plays it in the preview on the left (P3, FormationPreview).
##
## It closes on a pick, on leaving it (after a short grace, so a diagonal path from the button does not close it), on
## Escape, and on a click anywhere else, which it lets through: a move order given while it is open still lands.
##
## Cost: hidden and not processing while closed, so it adds nothing per frame to the HUD (round 18 P5). It processes
## only while the open delay counts or while it is open.

## The mouse rests this long on the button before the panel opens: crossing the button on the way to another control
## does not flash it.
const OPEN_DELAY_S := 0.22
## Outside the panel, the button and the bridge between them for this long before it closes.
const CLOSE_GRACE_S := 0.35
## A press held this long on a card previews it instead of picking it (touch has no hover).
const LONG_PRESS_S := 0.45
const COLUMNS := 4
## Sizes at 1080p (scaled with the window, as the selection panel is).
const CARD := Vector2(118.0, 100.0)
const GAP := 6.0
const PAD := 8.0
const HEADER := 24.0
const PREVIEW_WIDTH := 300.0
## Stretch (b): "squeezed here" (its words say it; the colour only underlines it).
const SQUEEZED_COLOR := Color(1.0, 0.62, 0.25)

var panel: SelectionPanel
var controls: RtsControls

var is_open := false
## Seconds the mouse has rested on the button while closed (-1 = not resting).
var _resting := -1.0
## Seconds the mouse has been outside the keep-open region while open.
var _away := 0.0
## The last mouse position seen, in viewport coordinates.
var _mouse := Vector2(-1, -1)
## The card under the mouse ("" = none) and the card pressed (for pick-on-release and the long press).
var _hovered := ""
var _pressed := ""
var _pressed_for := 0.0
var _long_pressed := ""
var _card_rects := {}  # id -> Rect2 (local)
var _preview_rect := Rect2()
## UI time (runs while the tree is paused): the preview's clock.
var _clock := 0.0
## For the HUD profile (P5): stays open with no mouse to keep it there.
var pinned := false
## The signature of what the cards drew last (lesson 242: by value, never by count); they redraw when it changes.
var _drawn: Array = []
## The preview's canvas (a child, redrawn every frame while open) and what it shows.
var _stage: Control = null
var _stage_shape := ""
## The selection the preview's members were read for, and them (looked up again only when the selection changes).
var _members_of: Array[String] = []
var _members: Array = []
## Stretch (b): FormationFit per card for the ground under the squad when the panel opened (or its selection changed):
## id -> {"fits", "moved_m", ...}, and the selection it was measured for. Never per frame.
var _fit := {}
var _fit_for: Array[String] = []
## How many times the fit has been measured (tests: once per open, never per frame).
var fit_measures := 0
## P3: built on first open, reused.
var _preview: FormationPreview = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)


# ---- Opening and closing ------------------------------------------------------------------------------------------

## The selection panel tells the picker when the mouse comes onto or leaves the Formation button.
func button_hovered(on: bool) -> void:
	if is_open:
		return
	_resting = 0.0 if on else -1.0
	set_process(on)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or controls == null or controls.selection.units.is_empty():
		return
	is_open = true
	_resting = -1.0
	_away = 0.0
	_hovered = ""
	_pressed = ""
	_long_pressed = ""
	if _preview == null:
		_preview = FormationPreview.new()
		# The animation draws into its own small canvas item, so the cards (which change only on a hover or a pick)
		# are not redrawn every frame with it.
		_stage = Control.new()
		_stage.name = "PreviewStage"
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.draw.connect(_draw_stage)
		add_child(_stage)
	visible = true
	set_process(true)
	_drawn = []
	_measure_fit()
	_layout()
	queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	_resting = -1.0
	_hovered = ""
	_pressed = ""
	_long_pressed = ""
	set_process(false)


## Pick a formation: the next orders ask for it (RtsControls.formation), and the panel closes.
func pick(id: String) -> void:
	if controls != null and FormationCatalog.INFO.has(id):
		controls.set_formation(id)
	close()


# ---- Data (tests read it; _draw shows it) -------------------------------------------------------------------------

## The cards in order: [{"id", "name", "tagline", "line", "shape", "current", "next"}]. `shape` is what the card draws:
## the formation itself, or for AUTO the shape the leader is forming now for this selection.
func cards() -> Array:
	var current := String(controls.formation) if controls != null else UnitCommand.AUTO
	var next := FormationCatalog.next_in_cycle(current)
	var result: Array = []
	for id: String in FormationCatalog.ORDER:
		var card := FormationCatalog.card(id)
		card["shape"] = auto_shape() if id == UnitCommand.AUTO else id
		card["current"] = id == current
		card["next"] = id == next
		card["fit"] = _fit.get(id, {})
		result.append(card)
	return result


## The shape AUTO stands for right now: the selected element's leader's pick when the selection is a squad; otherwise
## what an ad-hoc group's move takes (TacticsFormation.auto: a wedge up to a platoon).
func auto_shape() -> String:
	if controls == null:
		return FormationCatalog.shapes()[0]
	var readout := CommandIcons.formation_readout(UnitCommand.AUTO, controls.element_state())
	if String(readout["shape"]) != UnitCommand.AUTO:
		return String(readout["shape"])
	var picked := TacticsFormation.auto(maxi(controls.selection.units.size(), 2), "move", UnitCommand.AUTO)
	return picked if FormationCatalog.INFO.has(picked) else "wedge"


## The card the preview shows: the one under the mouse or long-pressed, else the one in use.
func preview_id() -> String:
	if _long_pressed != "":
		return _long_pressed
	if _hovered != "":
		return _hovered
	return String(controls.formation) if controls != null else UnitCommand.AUTO


func card_rect(id: String) -> Rect2:
	return _card_rects.get(id, Rect2())


## The Formation button, in viewport coordinates.
func button_rect() -> Rect2:
	if panel == null:
		return Rect2()
	var local := panel.command_rect("formation")
	return Rect2(panel.get_global_transform() * local.position, local.size * panel.get_global_transform().get_scale())


## Where the mouse may be without the panel starting to close: the panel, the button, and the strip between them (the
## panel's width, from its bottom down to the button's bottom), so the way from the button into any card is inside.
func keep_open_region() -> Array[Rect2]:
	var mine := get_global_rect()
	var button := button_rect()
	var left := minf(mine.position.x, button.position.x)
	var right := maxf(mine.end.x, button.end.x)
	var bridge := Rect2(left, mine.end.y - 1.0, right - left, maxf(button.end.y - mine.end.y + 1.0, 0.0))
	return [mine, button, bridge]


func _inside_keep_open(at: Vector2) -> bool:
	for rect in keep_open_region():
		if rect.has_point(at):
			return true
	return false


# ---- Per frame (only while the delay counts or the panel is open) -------------------------------------------------

func _process(delta: float) -> void:
	var started := HudClock.begin()
	_process_timed(delta)
	HudClock.end(&"formation_picker.process", started)


func _process_timed(delta: float) -> void:
	_clock += delta
	if not is_open:
		if _resting < 0.0:
			set_process(false)
			return
		_resting += delta
		if _resting >= OPEN_DELAY_S:
			open()
		return
	if controls == null or controls.selection.units.is_empty() or panel == null or not panel.visible:
		close()
		return
	if controls.selection.units != _fit_for:
		_measure_fit()
	if _inside_keep_open(_mouse) or pinned:
		_away = 0.0
	else:
		_away += delta
		if _away >= CLOSE_GRACE_S:
			close()
			return
	if _pressed != "" and _long_pressed == "":
		_pressed_for += delta
		if _pressed_for >= LONG_PRESS_S:
			_long_pressed = _pressed
	_layout()
	var signature := [size, _hovered, _long_pressed, String(controls.formation), auto_shape()]
	if signature != _drawn:
		_drawn = signature
		queue_redraw()
	if _stage != null:
		_stage.queue_redraw()  # the preview is animated; the cards are not


# ---- Input --------------------------------------------------------------------------------------------------------

## Watches every event while open (and the mouse while the delay counts): Escape closes it and is spent; a click
## anywhere outside it and the button closes it and goes on to whatever is under it.
func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_mouse = motion.position
		return
	if not is_open:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		_mouse = button.position
		if not get_global_rect().has_point(button.position) and not button_rect().has_point(button.position):
			close()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hovered = _card_at(motion.position)
		accept_event()
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	accept_event()  # nothing on the panel reaches the map behind it
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	var id := _card_at(button.position)
	if button.pressed:
		_pressed = id
		_pressed_for = 0.0
		_long_pressed = ""
		return
	var was_long := _long_pressed != ""
	var pressed := _pressed
	_pressed = ""
	if was_long:
		return  # a long press previewed the card; lifting the finger does not pick it
	if id != "" and id == pressed:
		pick(id)


func _card_at(local: Vector2) -> String:
	for id: String in _card_rects:
		if (_card_rects[id] as Rect2).has_point(local):
			return id
	return ""


# ---- Layout and drawing -------------------------------------------------------------------------------------------

func _scale() -> float:
	return panel._scale() if panel != null else 1.0


## Above the Formation button, its right edge on the button's (the shortest way into the cards), the preview on the
## left, kept on screen.
func _layout() -> void:
	var s := _scale()
	var rows := ceili(FormationCatalog.ORDER.size() / float(COLUMNS))
	var grid := Vector2(CARD.x * COLUMNS + GAP * (COLUMNS - 1), CARD.y * rows + GAP * (rows - 1)) * s
	size = Vector2(PAD * 3.0 * s + PREVIEW_WIDTH * s + grid.x, PAD * 2.0 * s + HEADER * s + grid.y)
	var button := panel.command_rect("formation") if panel != null else Rect2()
	var screen := get_viewport_rect().size
	var x := button.end.x - size.x
	if panel != null:
		x = clampf(x, -panel.position.x + 4.0, screen.x - panel.position.x - size.x - 4.0)
	position = Vector2(x, -size.y - 4.0 * s)
	var top := Vector2(PAD * 2.0 * s + PREVIEW_WIDTH * s, PAD * s + HEADER * s)
	_card_rects.clear()
	for i in FormationCatalog.ORDER.size():
		var cell := Vector2(i % COLUMNS, i / COLUMNS)
		_card_rects[FormationCatalog.ORDER[i]] = Rect2(top + cell * (CARD + Vector2(GAP, GAP)) * s, CARD * s)
	_preview_rect = Rect2(Vector2(PAD * s, PAD * s + HEADER * s), Vector2(PREVIEW_WIDTH * s, grid.y))


func preview_rect() -> Rect2:
	return _preview_rect


func _draw() -> void:
	var started := HudClock.begin()
	_draw_timed()
	HudClock.end(&"formation_picker.draw", started)


func _draw_timed() -> void:
	if not is_open:
		return
	var s := _scale()
	var font := CyberStyle.font()
	var batch := DrawBatch.new()
	var rect := Rect2(Vector2.ZERO, size)
	batch.fill(rect, Color(CyberStyle.HUD_BACKGROUND, 0.97))
	batch.outline(rect, Color(CyberStyle.YELLOW, 0.8), 1.5)
	batch.text(font, Vector2(PAD * s, PAD * s + 15.0 * s), "FORMATION", roundi(15.0 * s), CyberStyle.YELLOW)
	var hint := "tap to pick, hold to see it" if DisplayServer.is_touchscreen_available() else "click to pick  ·  G: next"
	var hint_px := roundi(12.0 * s)
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_px).x
	batch.text(font, Vector2(size.x - PAD * s - hint_width, PAD * s + 14.0 * s), hint, hint_px, Color(CyberStyle.TEXT, 0.7))
	var shown := preview_id()
	var shown_card := {}
	for card: Dictionary in cards():
		var id := String(card["id"])
		var box: Rect2 = _card_rects[id]
		var hot := id == _hovered or id == _long_pressed
		if id == shown:
			shown_card = card
		batch.fill(box, Color(CyberStyle.CARD, 1.0 if hot else 0.95))
		if bool(card["current"]):
			batch.outline(box, CyberStyle.YELLOW, 2.5)
		else:
			batch.outline(box, Color(CyberStyle.CYAN, 0.9 if hot else 0.4), 2.0 if hot else 1.0)
		var tint := CyberStyle.YELLOW if bool(card["current"]) else CyberStyle.CYAN
		var glyph := Rect2(box.position + Vector2((box.size.x - box.size.y * 0.52) / 2.0, box.size.y * 0.1),
				Vector2.ONE * box.size.y * 0.52)
		batch.texture(CommandIcons.formation_texture(String(card["shape"])), glyph, Color(tint, 1.0 if hot or bool(card["current"]) else 0.8))
		var name := String(card["name"])
		if id == UnitCommand.AUTO and String(card["shape"]) != UnitCommand.AUTO:
			name = "Auto: %s" % FormationCatalog.card(String(card["shape"])).get("name", "")
		_centered(batch, font, Rect2(box.position.x, box.end.y - box.size.y * 0.3, box.size.x, box.size.y * 0.16), name,
				14.0 * s, CyberStyle.TEXT)
		# Stretch (b): whether it fits HERE, in words (colour is never the only signal); the tagline otherwise.
		var fit: Dictionary = card["fit"]
		var bottom := String(card["tagline"])
		var bottom_color := Color(CyberStyle.TEXT, 0.6)
		if not fit.is_empty():
			bottom = "fits here" if bool(fit["fits"]) else "squeezed here"
			bottom_color = Color(CyberStyle.TEXT, 0.75) if bool(fit["fits"]) else SQUEEZED_COLOR
		_centered(batch, font, Rect2(box.position.x, box.end.y - box.size.y * 0.14, box.size.x, box.size.y * 0.12),
				bottom, 11.0 * s, bottom_color)
		if bool(card["current"]):
			batch.text(font, box.position + Vector2(4.0 * s, 13.0 * s), "NOW", roundi(11.0 * s), CyberStyle.YELLOW)
		if bool(card["next"]):
			var tag_px := roundi(12.0 * s)
			batch.text(font, Vector2(box.end.x - 12.0 * s, box.position.y + 14.0 * s), "G", tag_px, Color(CyberStyle.YELLOW, 0.9))
	# The preview's box and words; the animation draws over it (P3).
	batch.fill(_preview_rect, Color(0, 0, 0, 0.35))
	batch.outline(_preview_rect, Color(CyberStyle.CYAN, 0.3), 1.0)
	if not shown_card.is_empty():
		var title := String(shown_card["name"])
		if String(shown_card["id"]) == UnitCommand.AUTO and String(shown_card["shape"]) != UnitCommand.AUTO:
			title = "Auto (now: %s)" % FormationCatalog.card(String(shown_card["shape"])).get("name", "")
		title += "  ·  " + String(shown_card["tagline"])
		batch.text(font, _preview_rect.position + Vector2(6.0 * s, 16.0 * s), title.to_upper(), roundi(14.0 * s), CyberStyle.YELLOW,
				_preview_rect.size.x - 12.0 * s)
		var line_px := roundi(12.0 * s)
		var words := _wrap(font, _description(shown_card), line_px, _preview_rect.size.x - 12.0 * s)
		for i in words.size():
			var y := _preview_rect.end.y - 6.0 * s - (words.size() - 1 - i) * line_px * 1.25
			batch.text(font, Vector2(_preview_rect.position.x + 6.0 * s, y), words[i], line_px, CyberStyle.TEXT)
	batch.flush(self)
	if _stage != null:
		var lines := _wrap(font, _description(shown_card), roundi(12.0 * s), _preview_rect.size.x - 12.0 * s).size()
		var stage := Rect2(_preview_rect.position + Vector2(0, 22.0 * s),
				_preview_rect.size - Vector2(0, 22.0 * s + 10.0 * s + lines * 12.0 * s * 1.25))
		_stage.position = stage.position
		_stage.size = stage.size
		_stage_shape = String(shown_card.get("shape", ""))


## The card's one line, and where the squad stands now, what the fit says (stretch b).
func _description(card: Dictionary) -> String:
	var words := String(card.get("line", ""))
	var fit: Dictionary = card.get("fit", {})
	if fit.is_empty():
		return words
	if bool(fit["fits"]):
		return words + " Here: fits at its own spacing."
	if String(fit["shape"]) != String(card["shape"]) and String(card["id"]) != UnitCommand.AUTO:
		return words + " Here: squeezed (too many for it: they form %s)." % String(fit["shape"])
	return words + " Here: squeezed (a vehicle stands %d m off its place)." % roundi(float(fit["moved_m"]))


## Stretch (b): FormationFit for every card, for the selection as it stands now. Once per open (and when the selection
## changes while open): it asks the real seating code, which grounds every slot against the navigation mesh.
func _measure_fit() -> void:
	var started := HudClock.begin()
	fit_measures += 1
	_fit = {}
	_fit_for = controls.selection.units.duplicate() if controls != null else ([] as Array[String])
	if controls != null and controls.orders != null and _fit_for.size() >= 2:
		for id: String in FormationCatalog.ORDER:
			_fit[id] = FormationFit.check(controls.orders, _fit_for, id)
	_drawn = []
	HudClock.end(&"formation_picker.fit", started)


func _draw_stage() -> void:
	if not is_open or _preview == null or _stage_shape == "":
		return
	var started := HudClock.begin()
	_preview.draw(_stage, Rect2(Vector2.ZERO, _stage.size), _stage_shape, _clock, _preview_members(), GameTheme.ui["friendly"])
	HudClock.end(&"formation_picker.preview", started)


## The selected vehicles the preview draws ([{"name", "unit", "role"}]): four tanks draw four tanks.
func _preview_members() -> Array:
	if controls == null or controls.game_match == null:
		return []
	if controls.selection.units == _members_of:
		return _members
	_members_of = controls.selection.units.duplicate()
	var tanks: Array[Tank] = []
	for unit_name in _members_of:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null:
			tanks.append(tank)
	_members = GroupFormation.members_of(tanks, false)
	return _members


func _centered(batch: DrawBatch, font: Font, box: Rect2, text: String, font_size: float, color: Color) -> void:
	var px := maxi(8, roundi(font_size))
	while px > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x - 6.0:
		px -= 1
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	batch.text(font, Vector2(box.get_center().x - width / 2.0, box.end.y), text, px, color)


func _wrap(font: Font, text: String, px: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" "):
		var trial := word if current == "" else current + " " + word
		if current != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			lines.append(current)
			current = word
		else:
			current = trial
	if current != "":
		lines.append(current)
	return lines
