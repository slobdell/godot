extends SceneTree
## Generates the explosion flipbook atlas procedurally (we have no source art): 16 frames of a
## noisy fireball that flashes white-hot, cools through orange and red, and dissolves into smoke.
## Output is premultiplied alpha (burst.gdshader): fire = bright rgb with low alpha (adds light),
## smoke = dark rgb with alpha (occludes).
##   make fx-textures   (runs: godot --headless --script res://game/theme/fx/tools/make_flipbook.gd)

const OUT := "res://game/theme/fx/textures/explosion_flipbook.png"
const FRAME := 128
const COLUMNS := 4
const ROWS := 4


func _initialize() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = 2.2
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var image := Image.create_empty(FRAME * COLUMNS, FRAME * ROWS, false, Image.FORMAT_RGBA8)
	var count := COLUMNS * ROWS
	for f in count:
		var t := float(f) / float(count - 1)
		var ox := (f % COLUMNS) * FRAME
		var oy := (f / COLUMNS) * FRAME
		_draw_frame(image, noise, t, ox, oy)
	var err := image.save_png(ProjectSettings.globalize_path(OUT))
	print("flipbook: %s (%s)" % [OUT, error_string(err)])
	quit(err)


func _draw_frame(image: Image, noise: FastNoiseLite, t: float, ox: int, oy: int) -> void:
	# Fireball grows fast then slows; heat drains; smoke rises and thins.
	var radius := 0.28 + 0.62 * (1.0 - pow(1.0 - t, 2.5))
	var heat_scale := pow(1.0 - t, 1.4)
	var smoke_amount := smoothstep(0.08, 0.45, t) * (1.0 - smoothstep(0.55, 1.0, t))
	for y in FRAME:
		for x in FRAME:
			var px := (float(x) + 0.5) / FRAME * 2.0 - 1.0
			var py := (float(y) + 0.5) / FRAME * 2.0 - 1.0
			var d := sqrt(px * px + py * py) / radius
			var n := noise.get_noise_3d(px * 1.3, py * 1.3 - t * 0.6, t * 1.7) * 0.5 + 0.5
			var density := clampf(1.0 - d + (n - 0.5) * 0.9, 0.0, 1.0)
			# Edge feather so no frame ever touches its cell border.
			var edge := clampf((1.0 - sqrt(px * px + py * py)) * 6.0, 0.0, 1.0)
			density *= edge
			var heat := clampf(density * 1.6 * heat_scale - (1.0 - n) * 0.25 * t, 0.0, 1.0)
			var fire := _fire_color(heat) * heat
			var smoke_alpha := clampf(density * 1.3 - 0.15, 0.0, 1.0) * smoke_amount * 0.85
			smoke_alpha *= 1.0 - heat
			var smoke := Color(0.05, 0.045, 0.05) * smoke_alpha
			var rgb := Color(fire.r + smoke.r, fire.g + smoke.g, fire.b + smoke.b)
			var alpha := clampf(smoke_alpha + heat * 0.15, 0.0, 1.0)
			image.set_pixel(ox + x, oy + y, Color(minf(rgb.r, 1.0), minf(rgb.g, 1.0), minf(rgb.b, 1.0), alpha))


static func _fire_color(heat: float) -> Color:
	if heat > 0.75:
		return Color(1.0, 0.95, 0.7).lerp(Color(1.0, 1.0, 1.0), (heat - 0.75) / 0.25)
	if heat > 0.45:
		return Color(1.0, 0.55, 0.12).lerp(Color(1.0, 0.95, 0.7), (heat - 0.45) / 0.3)
	if heat > 0.15:
		return Color(0.7, 0.12, 0.04).lerp(Color(1.0, 0.55, 0.12), (heat - 0.15) / 0.3)
	return Color(0.2, 0.03, 0.02).lerp(Color(0.7, 0.12, 0.04), heat / 0.15)
