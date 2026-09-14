extends Node3D
## Night arena environment: near-black sky, cool moonlight, depth fog, and HDR glow so neon and
## weapon fire bloom. Glow and moon shadows follow the FxQuality tier.

@onready var environment: Environment = $WorldEnvironment.environment
@onready var moon: DirectionalLight3D = $Moon


func _ready() -> void:
	apply_quality()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.quality_changed.connect(apply_quality)


func apply_quality() -> void:
	environment.glow_enabled = FxQuality.value("glow")
	moon.shadow_enabled = FxQuality.tier() == FxQuality.Tier.HIGH
