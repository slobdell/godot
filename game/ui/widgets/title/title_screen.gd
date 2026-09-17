extends Node3D
## Animated title screen in the HUD style (`make title`, browser `?title`): the cyberpunk arena at
## night behind a glitching "TANK SQUAD" title, breathing conductors wiring a chamfered menu, and a
## small skirmish (tanks trading tracers and laser pulses) under a slow orbiting camera.
## Menu buttons start a mode: on the web by reloading with that URL query, on desktop by switching to the game
## scene with that flag. (Not the default entry scene: that's a shared-file decision for the lead.)
## Flags: --screenshot=<abs png> [--screenshot-delay=S]

const ARENA := preload("res://game/arena/arena.tscn")
const MAIN_SCENE := "res://game/main.tscn"
## Flags that describe the session, not the mode, and so survive choosing a mode.
const SESSION_FLAGS := ["ui-touch", "shell-playtest", "announcer", "music"]
const MENU := [
	["SKIRMISH", "skirmish", "Command your squads vs the CPU"],
	["MULTIPLAYER", "connect", "Join the game server"],
	["FX LAB", "fx-bench", "Lighting and effects benchmark"],
	["PLAY TEST DRIVE", "", "Drive one tank vs a bot"],
]

var camera := Camera3D.new()
var ui := CanvasLayer.new()
var title := GlitchTitle.new()
var subtitle: Label
var conductors := Conductors.new()
var menu := VBoxContainer.new()
var hint: Label
var _frames: Array[CyberFrame] = []
var _time := 0.0
var _tanks: Array[Node3D] = []
var _next_shot := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 9
	add_child(ARENA.instantiate())
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	for i in 6:
		var team := i % 2
		var tank := _tank(team, "weapon.laser" if i % 3 == 0 else "weapon.cannon")
		tank.position = Vector3(-18.0 + (i % 3) * 7.0, 0.0, -10.0 if team == 0 else 16.0) + Vector3(team * 9.0, 0, 0)
		tank.rotation.y = 0.0 if team == 0 else PI
		_tanks.append(tank)
	add_child(ui)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	var flags := LaunchFlags.from_environment()
	if flags.has("shell-playtest"):
		ShellPlaytest.ensure(get_tree(), flags.text("shell-playtest"))
	if flags.has("screenshot"):
		_capture(flags.text("screenshot"), float(flags.text("screenshot-delay", "4")))


func _process(delta: float) -> void:
	_time += delta
	var angle := _time * 0.05 + 0.4
	camera.position = Vector3(sin(angle) * 42.0, 13.0 + sin(_time * 0.2) * 2.0, cos(angle) * 42.0)
	camera.look_at(Vector3(0, 2.0, 3.0), Vector3.UP)
	_next_shot -= delta
	if _next_shot <= 0.0:
		_next_shot = _rng.randf_range(0.25, 0.7)
		_fire()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.02, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	ui.add_child(conductors)
	conductors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(title)
	subtitle = CyberStyle.label("CYBERPUNK GLADIATOR ARENA", 30.0, CyberStyle.CYAN)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(subtitle)
	menu.theme = CyberUiTheme.get_theme()
	ui.add_child(menu)
	for entry in MENU:
		var button := Button.new()
		button.text = entry[0]
		button.tooltip_text = entry[2]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(start.bind(entry[1]))
		menu.add_child(button)
	hint = CyberStyle.label("", 18.0, Color(CyberStyle.TEXT, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hint)
	var frame := CyberFrame.new()
	frame.fill_color = Color(CyberStyle.CARD, 0.55)
	ui.add_child(frame)
	ui.move_child(frame, ui.get_children().find(menu))
	_frames.append(frame)


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var s := CyberStyle.ui_scale(screen)
	title.position = Vector2(0, screen.y * 0.12)
	title.size = Vector2(screen.x, 180.0 * s)
	subtitle.add_theme_font_size_override("font_size", roundi(30.0 * s))
	subtitle.position = Vector2(0, title.position.y + 170.0 * s)
	subtitle.size = Vector2(screen.x, 40.0 * s)
	# The menu fits between the subtitle and the footer; buttons shrink (down to a 48 px tap target
	# at 1080p) before anything overlaps.
	var top := subtitle.position.y + 80.0 * s
	var bottom := screen.y - 70.0 * s - 30.0 * s  # footer + the frame's padding
	var gap := 14.0 * s
	var button_height := clampf((bottom - top - (MENU.size() - 1) * gap) / MENU.size(), 48.0 * s, 64.0 * s)
	var button_size := Vector2(420.0 * s, button_height)
	menu.add_theme_constant_override("separation", roundi(gap))
	for button in menu.get_children():
		(button as Button).custom_minimum_size = button_size
		(button as Button).add_theme_font_size_override("font_size", roundi(button_height * 0.44))
	var menu_height := MENU.size() * button_size.y + (MENU.size() - 1) * gap
	menu.position = Vector2((screen.x - button_size.x) / 2.0, clampf(screen.y * 0.5, top, bottom - menu_height))
	menu.size = Vector2(button_size.x, menu_height)
	var frame := _frames[0]
	frame.position = menu.position - Vector2(36.0, 30.0) * s
	frame.size = menu.size + Vector2(72.0, 60.0) * s
	hint.add_theme_font_size_override("font_size", roundi(18.0 * s))
	hint.text = "TAP A MODE  ·  FX %s  ·  look & feel preview" % FxQuality.tier_name().to_upper()
	hint.position = Vector2(0, screen.y - 46.0 * s)
	hint.size = Vector2(screen.x, 30.0 * s)
	conductors.clear()
	var left := frame.position.x
	var right := frame.position.x + frame.size.x
	var mid_y := frame.position.y + frame.size.y * 0.5
	conductors.add_bus(Vector2(left, mid_y), Vector2.LEFT, Vector2(screen.x * 0.12, screen.y), Vector2.DOWN, 3)
	conductors.add_bus(Vector2(right, mid_y), Vector2.RIGHT, Vector2(screen.x * 0.88, screen.y), Vector2.DOWN, 3)
	conductors.add_bus(Vector2(left, frame.position.y + 20.0 * s), Vector2.LEFT, Vector2(screen.x * 0.2, subtitle.position.y + 20.0 * s), Vector2.UP, 2)
	conductors.add_bus(Vector2(right, frame.position.y + 20.0 * s), Vector2.RIGHT, Vector2(screen.x * 0.8, subtitle.position.y + 20.0 * s), Vector2.UP, 2)


## Start a mode: reload the page with its query on the web; on desktop, switch to the game scene in this process with
## that flag. (It used to quit and relaunch the executable, which dropped every flag the session was started with and,
## launched from a terminal or `make`, could leave the player looking at a closed window.)
func start(flag: String) -> void:
	var fx := FxWorld.existing()
	if fx != null:
		fx.sfx.play_ui("ui_blip")
	print("TITLE_START %s" % (flag if flag != "" else "offline"))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.search = '%s'" % (("?" + flag) if flag != "" else ""))
		return
	Main.next_flags = flags_for(flag, LaunchFlags.from_environment())
	get_tree().change_scene_to_file(MAIN_SCENE)


## The flags the chosen mode starts with: its own flag, plus the few that belong to the session rather than to a
## mode (the touch UI, a playtest driving this run). "" is the offline test drive.
static func flags_for(flag: String, current: LaunchFlags) -> LaunchFlags:
	var next := LaunchFlags.new()
	if flag != "":
		next.values[flag] = ""
	for kept: String in SESSION_FLAGS:
		if current.has(kept):
			next.values[kept] = current.values[kept]
	return next


func _tank(team: int, weapon_slot: String) -> Node3D:
	var tank := Node3D.new()
	add_child(tank)
	var hull := VisualSlot.new()
	hull.slot = "tank.hull"
	tank.add_child(hull)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.22, 0.2)
	tank.add_child(turret)
	var body := VisualSlot.new()
	body.slot = "tank.turret"
	turret.add_child(body)
	var weapon := VisualSlot.new()
	weapon.name = "Weapon"
	weapon.slot = weapon_slot
	turret.add_child(weapon)
	tank.set_meta("team", team)
	for slot in [hull, body, weapon]:
		slot.invoke("set_team_color", [GameTheme.team_color(team)])
	return tank


func _fire() -> void:
	var shooter := _tanks[_rng.randi_range(0, _tanks.size() - 1)]
	var team: int = shooter.get_meta("team")
	var targets := _tanks.filter(func(t: Node3D) -> bool: return t.get_meta("team") != team)
	var target: Node3D = targets[_rng.randi_range(0, targets.size() - 1)]
	var weapon := shooter.get_node("Turret/Weapon") as VisualSlot
	var muzzle := weapon.global_transform * Vector3(0, 0.05, -3.2)
	var hit := target.global_position + Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1))
	var fx := FxWorld.get_instance()
	if fx == null:
		return
	if weapon.slot == "weapon.laser":
		weapon.invoke("set_firing", [true])
		var beam := VisualSlot.new()
		beam.slot = "fx.laser_beam"
		add_child(beam)
		beam.invoke("setup", [muzzle, hit])
		get_tree().create_timer(0.2).timeout.connect(beam.queue_free)
		(target.get_child(0) as VisualSlot).invoke("set_shield", [_rng.randf_range(0.2, 0.8)])
	else:
		fx.muzzle_flash(muzzle, GameTheme.team_glow(team))
		get_tree().create_timer(0.35).timeout.connect(func() -> void: fx.explosion(hit, _rng.randf() < 0.15))


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: " if err == OK else "screenshot failed: ", path)
	get_tree().quit(err)
