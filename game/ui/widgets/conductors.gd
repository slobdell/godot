class_name Conductors
extends Control
## Breathing circuit traces that wire HUD widgets together (references/hud_breathing_conductors.md).
## Each trace is a crisp 1 px polyline with solder-pad dots whose glow halo swells and fades on its
## own 10–25 s sine; the core line only shifts teal → cyan at a constant 59% alpha.
##
## Efficiency (spec §5, Godot version): the blur is baked ONCE into two tiny shared textures (a
## gaussian cross-section strip and a round dot sprite). Per frame each segment is one textured quad
## with a scalar alpha, plus the core polyline: no blur, no per-frame allocation, and layout changes
## never re-bake anything. Redraws are capped at 30 fps; the breathing is far slower than that.

const GLOW_ALPHA_MAX := 180.0 / 255.0
const CORE_ALPHA := 150.0 / 255.0
const REDRAW_SECONDS := 1.0 / 30.0
## Spec: glow stroke 8·scale before a 12·scale blur → a halo ~16·scale px from the line.
const GLOW_HALF_WIDTH_1080 := 16.0
const PROFILE_SIZE := 64

static var _profile: ImageTexture
static var _dot: ImageTexture

## Each: {points: PackedVector2Array (px), freq: rad/ms, phase: rad, dot_start: r1080, dot_end: r1080}
var traces: Array[Dictionary] = []
## Milliseconds clock (spec §3); swap for a fixed clock in tests and screenshots.
var clock_ms: Callable = func() -> float: return float(Time.get_ticks_msec())

var _since_redraw := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_since_redraw += delta
	if _since_redraw >= REDRAW_SECONDS:
		_since_redraw = 0.0
		queue_redraw()


func clear() -> void:
	traces.clear()
	queue_redraw()


## One trace. `points` in this control's pixels; H/V runs joined by 45° bends look right.
func add(points: PackedVector2Array, freq: float, phase: float, dot_start := 6.0, dot_end := 4.0) -> void:
	traces.append({"points": points, "freq": freq, "phase": phase, "dot_start": dot_start, "dot_end": dot_end})
	queue_redraw()


## A bundle of `count` parallel traces from `from` (heading `first_dir`) to `to` (arriving heading
## `last_dir`), `spacing_1080` apart, with nested 45° elbows (the PCB "bus corner", spec §4).
## Each line gets its own frequency and phase from the incommensurate spec tables.
func add_bus(from: Vector2, first_dir: Vector2, to: Vector2, last_dir: Vector2, count: int, spacing_1080 := 24.0) -> void:
	var scale_1080 := CyberStyle.ui_scale(get_viewport_rect().size) if is_inside_tree() else 1.0
	var spacing := spacing_1080 * scale_1080
	for i in count:
		var offset := (i - (count - 1) / 2.0) * spacing
		var index := traces.size()
		add(bus_route(from, first_dir, to, last_dir, offset), FREQUENCIES[index % FREQUENCIES.size()],
				PHASES[index % PHASES.size()], 4.0 if count <= 3 else 6.0, 4.0)


## Frequencies (rad/ms) and phases from the spec's tables, cycled for extra traces.
const FREQUENCIES := [0.00045, 0.0005, 0.00042, 0.0004, 0.00025, 0.0005 * 1.07, 0.0006, 0.00053, 0.00047, 0.0004 * 0.93, 0.00055, 0.00049, 0.00056]
const PHASES := [0.5, 2.1, 4.8, 1.2, 3.5, 5.9, 0.8, 4.2, 0.3, 2.7, 5.1, 3.9, 1.5]


## The polyline for one line of a bus, offset `offset` px to the left of travel.
static func bus_route(from: Vector2, first_dir: Vector2, to: Vector2, last_dir: Vector2, offset: float) -> PackedVector2Array:
	var h1 := first_dir.normalized()
	var h2 := last_dir.normalized()
	var n1 := Vector2(h1.y, -h1.x)
	var n2 := Vector2(h2.y, -h2.x)
	var start := from + n1 * offset
	var end := to + n2 * offset
	if absf(h1.dot(h2)) > 0.99:
		return PackedVector2Array([start, end])  # a straight run
	# Corner where the incoming and outgoing runs meet, then a 45° cut sized so parallel
	# diagonals keep the bus spacing (nested elbows).
	var corner := _intersect(start, h1, end, h2)
	var base_corner := _intersect(from, h1, to, h2)
	var base_cut := minf(base_corner.distance_to(from), base_corner.distance_to(to)) * 0.5
	var m := (n1 + n2).normalized()
	var m_h1 := m.dot(h1)
	var cut := base_cut
	if absf(m_h1) > 0.001:
		cut = base_cut + (m.dot(corner - base_corner) - offset * signf(m.dot(n1))) / m_h1
	cut = clampf(cut, 0.0, minf(corner.distance_to(start), corner.distance_to(end)))
	return PackedVector2Array([start, corner - h1 * cut, corner + h2 * cut, end])


static func _intersect(p: Vector2, u: Vector2, q: Vector2, v: Vector2) -> Vector2:
	var denominator := u.x * v.y - u.y * v.x
	if absf(denominator) < 0.0001:
		return (p + q) / 2.0
	var t := ((q.x - p.x) * v.y - (q.y - p.y) * v.x) / denominator
	return p + u * t


## Breathing fraction 0..1 for a trace at time t (ms).
static func fraction(t_ms: float, freq: float, phase: float) -> float:
	return (sin(t_ms * freq + phase) + 1.0) / 2.0


func _draw() -> void:
	if traces.is_empty():
		return
	_ensure_textures()
	var scale_1080 := CyberStyle.ui_scale(get_viewport_rect().size)
	var half := GLOW_HALF_WIDTH_1080 * scale_1080
	var now: float = clock_ms.call()
	# Glow first, under every core line (spec §6).
	var glow_colors := PackedFloat32Array()
	glow_colors.resize(traces.size())
	for i in traces.size():
		var trace := traces[i]
		var f := fraction(now, trace["freq"], trace["phase"])
		glow_colors[i] = f
		var glow := Color(CyberStyle.GLOW_CYAN, f * GLOW_ALPHA_MAX)
		var points: PackedVector2Array = trace["points"]
		for k in points.size() - 1:
			_draw_glow_segment(points[k], points[k + 1], half, glow)
			if k > 0:
				# Round the joint so bends don't show a notch between the two quads.
				draw_texture_rect(_dot, Rect2(points[k] - Vector2(half, half), Vector2(half, half) * 2.0), false, Color(glow, glow.a * 0.6))
		for end_index in [0, points.size() - 1]:
			var radius: float = (trace["dot_start"] if end_index == 0 else trace["dot_end"]) * scale_1080 + half
			draw_texture_rect(_dot, Rect2(points[end_index] - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, glow)
	for i in traces.size():
		var trace := traces[i]
		var core := Color(CyberStyle.CONDUCTOR_OFF.lerp(CyberStyle.CONDUCTOR_ON, glow_colors[i]), CORE_ALPHA)
		var points: PackedVector2Array = trace["points"]
		draw_polyline(points, core, 1.0, true)
		draw_circle(points[0], float(trace["dot_start"]) * scale_1080, core)
		draw_circle(points[points.size() - 1], float(trace["dot_end"]) * scale_1080, core)


func _draw_glow_segment(a: Vector2, b: Vector2, half: float, color: Color) -> void:
	var along := b - a
	if along.length_squared() < 0.01:
		return
	var normal := Vector2(-along.y, along.x).normalized() * half
	var quad := PackedVector2Array([a + normal, b + normal, b - normal, a - normal])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	draw_polygon(quad, PackedColorArray([color, color, color, color]), uvs, _profile)


## Bake the glow once: a gaussian cross-section (v across the line) and a round dot halo.
static func _ensure_textures() -> void:
	if _profile != null:
		return
	var strip := Image.create_empty(4, PROFILE_SIZE, false, Image.FORMAT_RGBA8)
	var dot := Image.create_empty(PROFILE_SIZE, PROFILE_SIZE, false, Image.FORMAT_RGBA8)
	var sigma := 0.33
	for y in PROFILE_SIZE:
		var v := (y + 0.5) / PROFILE_SIZE * 2.0 - 1.0
		var a := exp(-(v * v) / (2.0 * sigma * sigma))
		for x in 4:
			strip.set_pixel(x, y, Color(1, 1, 1, a))
		for x in PROFILE_SIZE:
			var u := (x + 0.5) / PROFILE_SIZE * 2.0 - 1.0
			var r2 := u * u + v * v
			dot.set_pixel(x, y, Color(1, 1, 1, exp(-r2 / (2.0 * sigma * sigma)) * (1.0 if r2 < 1.0 else 0.0)))
	_profile = ImageTexture.create_from_image(strip)
	_dot = ImageTexture.create_from_image(dot)
