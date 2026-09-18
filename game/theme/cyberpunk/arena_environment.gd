extends Node3D
## Night arena environment: a smog-lit night sky over a city skyline (feel X4, round 6: the lead's low camera puts the
## horizon in every frame, and it used to be flat black), cool moonlight, depth fog, and HDR glow so neon and weapon
## fire bloom. Glow and moon shadows follow the FxQuality tier.


@onready var environment: Environment = $WorldEnvironment.environment
@onready var moon: DirectionalLight3D = $Moon
var skyline: CitySkyline


var sky: NightSky


func _ready() -> void:
	sky = NightSky.new()
	add_child(sky)
	skyline = CitySkyline.new()
	add_child(skyline)
	apply_quality()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.quality_changed.connect(apply_quality)


func apply_quality() -> void:
	environment.glow_enabled = FxQuality.value("glow")
	moon.shadow_enabled = FxQuality.value("shadows")
