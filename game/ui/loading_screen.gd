class_name LoadingScreen
extends CanvasLayer
## Control X4 (round 6): the screen between FIGHT and the match. The lead: *"At the start of the game there's a big lag
## between pressing "Fight" and the game loading, so we should likely invest in some loading UX indicators and
## screens."* Before this there was nothing: the faction menu froze on screen for the whole load.
##
## It lives on the tree's ROOT, not in a scene, so it survives GameLauncher's scene switch and stays up until the
## match has drawn its first frame. The load is staged (GameLauncher.start) and the screen is redrawn between stages;
## inside a stage the engine is busy on the main thread (the arena's venue build and navmesh bake are synchronous, and
## must stay so for determinism: trip-up 57), so the last frame drawn - this screen, naming the stage - stays up.
##
## It carries the game's voice rather than a grey bar: the matchup, the arena and what it is for, and a card teaching
## one command-card task by its symbol (the lead could not name "Screen"; the load is a free minute to teach it).
##
## Every load prints `LOAD_TIMING` (ms per stage, wall clock: UI only, never a decision), which is how X4's
## before/after is measured (`make load-timing`).

signal finished

const LAYER := 120
const FADE_S := 0.35
## Stage ids in order, and what the screen says during each.
const STAGES := [
	["scene", "Loading the arena"],
	# The arena and the armies are built inside one scene switch with no frame between them, so the frame on screen
	# for both is the one drawn as "arena" begins: it names both, rather than claiming the venue for five seconds.
	["arena", "Building the arena and rolling out the armies"],
	["armies", "Rolling out the armies"],
	["first_frame", "Lights up"],
]

## The screen showing now (one at a time).
static var current: LoadingScreen

var matchup := ""
var arena_title := ""
var arena_note := ""
## The task the card teaches (a TaskPalette id).
var tip := "support_by_fire"
var stage := ""
var progress := 0.0

var _started_ms := 0
var _stage_started_ms := 0
var _timings := {}
var _marks: PackedStringArray = []
var _canvas: Control
var _fading := -1.0


## Put a loading screen over everything, for a match launched with `flags`.
static func show_for(tree: SceneTree, flags: LaunchFlags) -> LoadingScreen:
	if current != null and is_instance_valid(current):
		current.queue_free()
	var screen := LoadingScreen.new()
	screen.matchup = LoadingScreen.matchup_of(flags)
	var arena := flags.text("arena", "")
	var file := FileAccess.open("%s/%s.json" % [Arena.LAYOUT_DIR, arena], FileAccess.READ) if arena != "" else null
	var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if data is Dictionary:
		screen.arena_title = String(data.get("title", arena.capitalize()))
		screen.arena_note = String(data.get("note", ""))
	else:
		screen.arena_title = arena.capitalize()
	var tasks := TaskPalette.card().filter(func(row: Dictionary) -> bool: return String(row["id"]) != "formation")
	screen.tip = String(tasks[absi(flags.integer("seed", 0)) % tasks.size()]["id"])
	tree.root.add_child(screen)
	current = screen
	return screen


## "CONDEMNED  vs  SYNDICATE" from the launch flags ("" for a doctrine-file army with no faction).
static func matchup_of(flags: LaunchFlags) -> String:
	var ours := flags.text("player-faction", "")
	var theirs := flags.text("enemy-faction", "")
	if ours == "" and theirs == "":
		return ""
	var name_of := func(faction: String) -> String:
		return String(Units.FACTION_NAMES.get(faction, faction.capitalize())).to_upper() if faction != "" else "YOUR ARMY"
	return "%s   vs   %s" % [name_of.call(ours), name_of.call(theirs)]


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_ms = Time.get_ticks_msec()
	_stage_started_ms = _started_ms
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it takes a click while it's up
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # trip-up 29
	_canvas.draw.connect(_draw_screen)


## Enter a stage: the time spent in the previous one is recorded, and the screen redraws naming the new one.
func enter(stage_id: String) -> void:
	_close_stage()
	stage = stage_id
	var index := STAGES.map(func(s: Array) -> String: return s[0]).find(stage_id)
	progress = float(maxi(index, 0)) / float(STAGES.size())
	_canvas.queue_redraw()


## Report progress inside the current stage (0..1), e.g. the threaded scene load.
func report(fraction: float) -> void:
	var index := STAGES.map(func(s: Array) -> String: return s[0]).find(stage)
	progress = (float(maxi(index, 0)) + clampf(fraction, 0.0, 1.0)) / float(STAGES.size())
	_canvas.queue_redraw()


## The match is on screen: print the timings and fade out.
func done() -> void:
	_close_stage()
	stage = ""
	progress = 1.0
	var total := Time.get_ticks_msec() - _started_ms
	var parts := PackedStringArray()
	for entry: Array in STAGES:
		parts.append("%s=%d" % [entry[0], int(_timings.get(entry[0], 0))])
	print("LOAD_TIMING total_ms=%d %s%s" % [total, " ".join(parts), (" marks=" + ",".join(_marks)) if not _marks.is_empty() else ""])
	_timings["total"] = total
	_fading = 0.0


## A timestamp inside the current stage (ms since the screen went up), printed with LOAD_TIMING, for finding where a
## stall goes. Static so code that doesn't know about loading can call it: `LoadingScreen.mark("armies_loaded")`.
static func mark(label: String) -> void:
	if current != null and is_instance_valid(current) and current.stage != "":
		current._marks.append("%s@%d" % [label, Time.get_ticks_msec() - current._started_ms])


func timings() -> Dictionary:
	return _timings.duplicate()


func _close_stage() -> void:
	var now := Time.get_ticks_msec()
	if stage != "":
		_timings[stage] = int(_timings.get(stage, 0)) + now - _stage_started_ms
	_stage_started_ms = now


func _process(delta: float) -> void:
	if _fading < 0.0:
		return
	_fading += delta
	_canvas.modulate.a = clampf(1.0 - _fading / FADE_S, 0.0, 1.0)
	if _fading >= FADE_S:
		if current == self:
			current = null
		finished.emit()
		queue_free()


func _draw_screen() -> void:
	var size := _canvas.size
	var s := maxf(size.y / 1080.0, 0.5)
	var font := CyberStyle.font()
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), CyberStyle.BACKGROUND)
	var center_x := size.x / 2.0
	var y := size.y * 0.24
	if matchup != "":
		_centered(font, matchup, center_x, y, roundi(46.0 * s), CyberStyle.WHITE)
		y += 64.0 * s
	if arena_title != "":
		_centered(font, arena_title.to_upper(), center_x, y, roundi(30.0 * s), CyberStyle.CYAN)
		y += 40.0 * s
	if arena_note != "":
		var note_px := roundi(19.0 * s)
		for line in _wrap(font, arena_note, note_px, minf(size.x - 64.0 * s, 1100.0 * s)).slice(0, 3):
			_centered(font, line, center_x, y, note_px, Color(CyberStyle.TEXT, 0.8))
			y += note_px * 1.4
	# The task card: a symbol from the command card and what it asks of a squad.
	var row := TaskPalette.row(tip)
	var card := Rect2(center_x - 400.0 * s, maxf(size.y * 0.47, y + 30.0 * s), 800.0 * s, 160.0 * s)
	_canvas.draw_rect(card, Color(CyberStyle.CARD, 0.95))
	_canvas.draw_rect(card, Color(CyberStyle.CYAN, 0.5), false, 1.5)
	var glyph := Rect2(card.position + Vector2(20.0, 20.0) * s, Vector2.ONE * 110.0 * s)
	_canvas.draw_texture_rect(CommandIcons.task_texture(tip), glyph, false, CyberStyle.CYAN)
	var text_x := glyph.end.x + 24.0 * s
	var title := "%s   [%s]" % [String(row.get("name", tip)).to_upper(), row.get("hotkey", "")]
	_canvas.draw_string(font, Vector2(text_x, card.position.y + 50.0 * s), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
			roundi(26.0 * s), CyberStyle.YELLOW)
	var line_px := roundi(18.0 * s)
	var line_y := card.position.y + 84.0 * s
	for line in _wrap(font, String(row.get("line", "")), line_px, card.end.x - text_x - 20.0 * s).slice(0, 2):
		_canvas.draw_string(font, Vector2(text_x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_px, CyberStyle.TEXT)
		line_y += line_px * 1.35
	var where := "On the command card when a whole squad is selected." if String(row.get("kind", "")) == "task" \
			else "On the command card whenever units are selected."
	_canvas.draw_string(font, Vector2(text_x, card.end.y - 16.0 * s), where, HORIZONTAL_ALIGNMENT_LEFT,
			card.end.x - text_x - 20.0 * s, roundi(15.0 * s), Color(CyberStyle.TEXT, 0.6))
	# Progress: the bar and the stage it is in.
	var bar := Rect2(center_x - 360.0 * s, size.y * 0.78, 720.0 * s, 10.0 * s)
	_canvas.draw_rect(bar, Color(CyberStyle.CYAN, 0.15))
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), CyberStyle.CYAN)
	var words := ""
	for entry: Array in STAGES:
		if entry[0] == stage:
			words = String(entry[1])
	if words != "":
		_centered(font, words.to_upper() + " ...", center_x, bar.end.y + 36.0 * s, roundi(18.0 * s), Color(CyberStyle.TEXT, 0.85))


func _wrap(font: Font, text: String, px: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current_line := ""
	for word in text.split(" "):
		var trial := word if current_line == "" else current_line + " " + word
		if current_line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			lines.append(current_line)
			current_line = word
		else:
			current_line = trial
	if current_line != "":
		lines.append(current_line)
	return lines


func _centered(font: Font, text: String, x: float, y: float, px: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_canvas.draw_string(font, Vector2(x - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
