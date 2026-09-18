extends Node3D
## Night arena environment: a smog-lit night sky over a city skyline (feel X4, round 6: the lead's low camera puts the
## horizon in every frame, and it used to be flat black), cool moonlight, depth fog, and HDR glow so neon and weapon
## fire bloom. Glow and moon shadows follow the FxQuality tier.

const SKY_SHADER := preload("res://game/theme/fx/shaders/night_sky.gdshader")

@onready var environment: Environment = $WorldEnvironment.environment
@onready var moon: DirectionalLight3D = $Moon
var skyline: CitySkyline


func _ready() -> void:
	use_night_sky(environment)
	skyline = CitySkyline.new()
	add_child(skyline)
	apply_quality()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.quality_changed.connect(apply_quality)


func apply_quality() -> void:
	environment.glow_enabled = FxQuality.value("glow")
	moon.shadow_enabled = FxQuality.value("shadows")


## The sky shader as the background. Ambient light stays the scene's colour and reflections stay off, so the sky is
## drawn but never sampled for light (no radiance maps to update).
static func use_night_sky(target: Environment) -> void:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	target.sky = sky
	target.background_mode = Environment.BG_SKY
