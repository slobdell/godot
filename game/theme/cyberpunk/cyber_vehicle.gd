extends Node3D
## Base for cyberpunk vehicle parts (hull, turret, weapons): the part is ONE MeshInstance3D built by
## ColorMeshBuilder (two draw calls: lit + neon), rebuilt when the team color arrives. Team color is
## the team's neon (GameTheme.team_colors in this theme); paint is derived from it, dark and worn.
## Optional slot methods: set_team_color(color), set_heat(ratio) (masked parts glow hotter).

var team_color := Color(0.75, 0.75, 0.8)
var mesh_instance := MeshInstance3D.new()
var heat := 0.0


func _ready() -> void:
	mesh_instance.name = "Mesh"
	add_child(mesh_instance)
	rebuild()


func set_team_color(color: Color) -> void:
	team_color = color
	if is_inside_tree():
		rebuild()


## Heat 0..1: barrels and vents glow from their color to orange-white (per instance, no new material).
func set_heat(ratio: float) -> void:
	heat = clampf(ratio, 0.0, 1.0)
	mesh_instance.set_instance_shader_parameter("heat", heat)


func rebuild() -> void:
	var builder := ColorMeshBuilder.new()
	build(builder)
	mesh_instance.mesh = builder.commit()
	mesh_instance.set_instance_shader_parameter("heat", heat)


## Override: add boxes to the builder.
func build(_builder: ColorMeshBuilder) -> void:
	pass


## The part's paint: gunmetal with a hint of the team hue.
func paint() -> Color:
	return Color(0.2, 0.21, 0.24).lerp(team_color, 0.22)


func paint_dark() -> Color:
	return paint().darkened(0.45)


const RUBBER := Color(0.05, 0.05, 0.055)
const STEEL := Color(0.3, 0.3, 0.32)
const RUST := Color(0.32, 0.16, 0.08)
const HEADLIGHT := Color(1.0, 0.92, 0.75)
