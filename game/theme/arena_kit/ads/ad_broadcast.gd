class_name AdBroadcast
extends Node
## A broadcast channel for the arena's giant screens (assets X2). It lays one ad out in a small 2D viewport (the art with
## a slow pan and zoom, flipbook frames, the brand, headline and fine print overlaid in real fonts, a scrolling ticker)
## and every screen on the channel shows that viewport through one shared material, so ten screens cost one layout.
## Between ads it glitches; big moments (FxWorld.spectacle) glitch it too. Each ad's average color becomes the light
## the screens throw on the ground. Visual only: nothing here reads or changes the simulation.
##
## The playlist is ads.json (tools/assets/build_ads.py; placeholders until the lead picks real art and copy). The "live"
## card shows whatever the match posts with `post_live({headline, fine_print})`; on its own the channel finds the
## running Match once and posts confirmed kills and the odds (it only listens to `tank_destroyed`).

const PLAYLIST := "res://game/theme/arena_kit/ads/ads.json"
const SCREEN_SHADER := preload("res://game/theme/arena_kit/ads/ad_screen.gdshader")
const SPILL_SHADER := preload("res://game/theme/arena_kit/ads/ad_spill.gdshader")
const DISPLAY_FONT := preload("res://assets/fonts/Oswald-Variable.ttf")
const MONO_FONT := preload("res://assets/fonts/ShareTechMono-Regular.ttf")
## The layout is designed at 320 × 640 and rendered at the tier's size.
const LAYOUT := Vector2i(320, 640)
const FEED_SIZE := {FxQuality.Tier.LOW: Vector2i(192, 384), FxQuality.Tier.MEDIUM: Vector2i(256, 512), FxQuality.Tier.HIGH: Vector2i(320, 640)}
const GLITCH_SECONDS := 0.5
const LIGHT_RATE := 3.0

var channel_name := "arena"
var ads: Array = []
var index := 0
## 0..1: how hard the screens tear and split right now.
var glitch := 0.0
var viewport := SubViewport.new()
var screen_material := ShaderMaterial.new()
var spill_material := ShaderMaterial.new()

var _clock := 0.0
var _transition := -1.0
var _pulse := 0.0
var _light := Color(0.2, 0.2, 0.25)
var _live := {}
var _art := TextureRect.new()
var _atlas := AtlasTexture.new()
var _brand := Label.new()
var _headline := Label.new()
var _bar := ColorRect.new()
var _fine := Label.new()
var _ticker := Label.new()
var _frame_skip := 0
var _kills := [0, 0]
var _match_search := 0.0
var _match_tries := 0
var _watched: Node


## The channel named `name` in `node`'s viewport, created on first use.
static func channel(node: Node, name := "arena") -> AdBroadcast:
	var viewport := node.get_viewport() if node.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	var channels: Dictionary = viewport.get_meta("ad_channels", {})
	if channels.has(name) and is_instance_valid(channels[name]):
		return channels[name]
	var created := AdBroadcast.new(name, channels.size() * 3)
	channels[name] = created
	viewport.set_meta("ad_channels", channels)
	viewport.add_child.call_deferred(created)
	return created


static func load_playlist() -> Array:
	var text := FileAccess.get_file_as_string(PLAYLIST)
	var data: Variant = JSON.parse_string(text)
	return (data as Dictionary).get("ads", []) if data is Dictionary else []


func _init(name := "arena", start := 0) -> void:
	channel_name = name
	self.name = "AdBroadcast_" + name
	ads = load_playlist()
	_build_layout()
	screen_material.shader = SCREEN_SHADER
	screen_material.set_shader_parameter("feed", viewport.get_texture())
	spill_material.shader = SPILL_SHADER
	if not ads.is_empty():
		show_ad(start % ads.size())
		_light = Color(current()["average_color"])
	_push_uniforms()


func _ready() -> void:
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.spectacle.connect(_on_spectacle)
		fx.quality_changed.connect(_apply_quality)
	_apply_quality()


func _process(delta: float) -> void:
	advance(delta)
	_find_match(delta)
	# Phones redraw the feed at half the frame rate; the shader's flicker hides it.
	if FxQuality.tier() == FxQuality.Tier.LOW:
		_frame_skip = (_frame_skip + 1) % 2
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if _frame_skip == 0 else SubViewport.UPDATE_DISABLED


## Moves the channel `delta` seconds forward (called every frame; tests call it directly).
func advance(delta: float) -> void:
	if ads.is_empty():
		return
	_clock += delta
	var ad := current()
	if _transition >= 0.0:
		_transition += delta
		var half := GLITCH_SECONDS / 2.0
		if _transition >= half and _transition - delta < half:
			show_ad((index + 1) % ads.size())
			ad = current()
		if _transition >= GLITCH_SECONDS:
			_transition = -1.0
	elif _clock >= float(ad["seconds"]):
		_transition = 0.0
	var ramp := 0.0 if _transition < 0.0 else 1.0 - absf(_transition / (GLITCH_SECONDS / 2.0) - 1.0)
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	glitch = clampf(maxf(ramp, _pulse), 0.0, 1.0)
	# Ken Burns: a slow push in with a drift, so a still never looks frozen.
	var progress := clampf(_clock / float(ad["seconds"]), 0.0, 1.0)
	_art.scale = Vector2.ONE * lerpf(1.04, 1.14, progress)
	_art.position = Vector2(lerpf(-6.0, 6.0, progress), lerpf(4.0, -8.0, progress)) - (_art.scale - Vector2.ONE) * Vector2(LAYOUT) / 2.0
	var frames: Array = ad.get("frames", [1, 1])
	var count := int(frames[0]) * int(frames[1])
	if count > 1 and _atlas.atlas != null:
		var frame := int(_clock * float(ad.get("fps", 6))) % count
		var cell := Vector2(_atlas.atlas.get_size()) / Vector2(frames[0], frames[1])
		_atlas.region = Rect2(Vector2(frame % int(frames[0]), frame / int(frames[0])) * cell, cell)
	_ticker.position.x = fposmod(-_clock * 38.0, maxf(1.0, _ticker.size.x / 2.0))
	_light = _light.lerp(Color(ad["average_color"]), 1.0 - exp(-delta * LIGHT_RATE))
	_push_uniforms()


func show_ad(new_index: int) -> void:
	index = clampi(new_index, 0, ads.size() - 1)
	_clock = 0.0
	var ad := current()
	var texture := load(ad["image"]) as Texture2D
	var frames: Array = ad.get("frames", [1, 1])
	if int(frames[0]) * int(frames[1]) > 1:
		_atlas.atlas = texture
		_atlas.region = Rect2(Vector2.ZERO, Vector2(texture.get_size()) / Vector2(frames[0], frames[1]))
		_art.texture = _atlas
	else:
		_art.texture = texture
	var accent := Color(ad["accent"])
	_brand.text = String(ad["brand"])
	_brand.add_theme_color_override("font_color", accent)
	_bar.color = accent
	var live: bool = ad.get("kind", "") == "live"
	_headline.text = String(_live.get("headline", ad["headline"])) if live else String(ad["headline"])
	_fine.text = String(_live.get("fine_print", ad["fine_print"])) if live else String(ad["fine_print"])
	_pin_labels()


## Live match content for the "live" card: {headline, fine_print}. Shows at once if the card is up.
func post_live(data: Dictionary) -> void:
	_live = data.duplicate()
	if not ads.is_empty() and current().get("kind", "") == "live":
		show_ad(index)


func current() -> Dictionary:
	return ads[index] if not ads.is_empty() else {}


func current_id() -> String:
	return String(current().get("id", ""))


func index_of(id: String) -> int:
	for i in ads.size():
		if ads[i]["id"] == id:
			return i
	return -1


func headline_text() -> String:
	return _headline.text


func fine_print_text() -> String:
	return _fine.text


func light_color() -> Color:
	return _light


## Live card content from a match: confirmed kills per team and the odds they imply.
func watch_match(game_match: Node) -> void:
	if _watched != null or not game_match.has_signal("tank_destroyed"):
		return
	_watched = game_match
	game_match.connect("tank_destroyed", _on_tank_destroyed)
	post_live({"headline": "GREEN  0\nRUST  0", "fine_print": "Odds even. Wagers close at the first kill."})


func _on_tank_destroyed(victim: Node, _killer: String) -> void:
	var team := int(victim.get("team"))
	var winner := 1 - clampi(team, 0, 1)
	_kills[winner] += 1
	var names := ["GREEN", "RUST"]
	var leader := 0 if _kills[0] >= _kills[1] else 1
	var odds := "Odds even." if _kills[0] == _kills[1] else "%s %d:1." % [names[leader], maxi(2, roundi(float(_kills[leader] + 1) / float(_kills[1 - leader] + 1)))]
	var profile: Dictionary = Units.PROFILES.get(String(victim.get("unit_id")), {})
	var unit := String(profile.get("display_name", "vehicle"))
	unit = unit if unit == unit.to_upper() else unit.to_lower()  # "an IFV", "a scout"
	var article := "an" if "AEIOUaeiou".contains(unit.left(1)) else "a"
	post_live({"headline": "GREEN  %d\nRUST  %d" % _kills, "fine_print": "%s lost %s %s. %s" % [names[team % 2].capitalize(), article, unit, odds]})


## Looks for the running Match a few times after the channel appears (skirmish builds it after the dressing).
func _find_match(delta: float) -> void:
	if _watched != null or _match_tries >= 10:
		return
	_match_search -= delta
	if _match_search > 0.0:
		return
	_match_search = 2.0
	_match_tries += 1
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "Node", true, false):
		if node is Match:
			watch_match(node)
			return


func _on_spectacle(_position: Vector3, weight: float) -> void:
	if weight >= 0.9:
		_pulse = maxf(_pulse, 0.7)


func _apply_quality() -> void:
	viewport.size = FEED_SIZE[FxQuality.tier()]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _push_uniforms() -> void:
	screen_material.set_shader_parameter("glitch", glitch)
	spill_material.set_shader_parameter("color", _light)
	# Dark ads still light the ground with their hue: the spill's brightness is normalized, and dips with the glitch
	# like a signal dropping.
	var peak := maxf(maxf(_light.r, _light.g), maxf(_light.b, 0.05))
	spill_material.set_shader_parameter("energy", 0.9 / peak * 0.6 * (1.0 - glitch * 0.6))


func _build_layout() -> void:
	viewport.name = "Feed"
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.size = FEED_SIZE[FxQuality.Tier.HIGH]
	viewport.size_2d_override = LAYOUT
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root := Control.new()
	root.size = Vector2(LAYOUT)
	root.clip_contents = true
	viewport.add_child(root)
	var ground := ColorRect.new()
	ground.color = Color(0.01, 0.01, 0.02)
	ground.size = Vector2(LAYOUT)
	root.add_child(ground)
	_art.size = Vector2(LAYOUT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(_art)
	# A dark wash behind the copy so it reads over any art.
	var wash := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.85))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill_from = Vector2(0, 0)
	fill.fill_to = Vector2(0, 1)
	wash.texture = fill
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.position = Vector2(0, 300)
	wash.size = Vector2(LAYOUT.x, LAYOUT.y - 300)
	root.add_child(wash)
	_style(_brand, _display(500, 3), 19, Vector2(18, 18))
	root.add_child(_brand)
	_style(_headline, _display(700, 1), 46, Vector2(16, 360))
	_headline.add_theme_constant_override("line_spacing", -12)
	_headline.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(_headline)
	_bar.size = Vector2(56, 4)
	_bar.position = Vector2(18, 540)
	root.add_child(_bar)
	_style(_fine, MONO_FONT, 12, Vector2(18, 552))
	_fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fine.add_theme_color_override("font_color", Color(0.78, 0.78, 0.74))
	root.add_child(_fine)
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0, 0.9)
	strip.position = Vector2(0, LAYOUT.y - 30)
	strip.size = Vector2(LAYOUT.x, 30)
	root.add_child(strip)
	var line := " ◆ ".join(ads.map(func(ad: Dictionary) -> String: return String(ad["brand"]))) + " ◆ TANK SQUAD ARENA ◆ "
	_style(_ticker, MONO_FONT, 14, Vector2(0, LAYOUT.y - 25))
	_ticker.text = line + line
	_ticker.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	strip.add_child(_ticker)
	_ticker.position = Vector2(0, 5)


func _display(weight: int, spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = DISPLAY_FONT
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = spacing
	return variation


func _style(label: Label, font: Font, size: int, at: Vector2) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.position = at
	label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))


## Labels outside containers grow with their text (orientation trip-up 42): pin their boxes after every change.
func _pin_labels() -> void:
	_headline.size = Vector2(LAYOUT.x - 32, 176)
	_headline.position = Vector2(16, 530 - 176)
	_fine.size = Vector2(LAYOUT.x - 36, 52)
	_brand.size = Vector2(LAYOUT.x - 36, 30)
