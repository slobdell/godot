extends Node3D
## Base for cyberpunk vehicle parts (hull, turret, weapons): the part is ONE MeshInstance3D built by
## ColorMeshBuilder (two draw calls: lit + neon), rebuilt when colors change.
##
## Friend or foe is shown by ACCENT LIGHTS, never hull color (the lead, 2026-09-14: players paint the
## whole vehicle). So there are two colors:
##   team accents: set_team_color(team neon): trims, stripes, coils, underglow
##   paint:        set_paint(color): the full body (default: worn gunmetal)
## Adapter until gameplay's Tank.set_paint calls set_paint: set_team_color with a color that isn't
## one of the theme's team colors is treated as paint (the garage paints through set_team_color today).
## Optional slot methods: set_team_color, set_paint, setup(weapon), set_heat(ratio).

const DEFAULT_PAINT := Color(0.2, 0.21, 0.24)

var team_color := Color(0.75, 0.75, 0.8)
## Alpha 0 = no paint chosen (DEFAULT_PAINT).
var paint_color := Color(0, 0, 0, 0)
var mesh_instance := MeshInstance3D.new()
var heat := 0.0


func _ready() -> void:
	mesh_instance.name = "Mesh"
	add_child(mesh_instance)
	rebuild()


func set_team_color(color: Color) -> void:
	if is_team_color(color):
		team_color = color
	else:
		paint_color = Color(color, 1.0)
	if is_inside_tree():
		rebuild()


## Full-body paint (the garage's per-tank color).
func set_paint(color: Color) -> void:
	paint_color = Color(color, 1.0)
	if is_inside_tree():
		rebuild()


static func is_team_color(color: Color) -> bool:
	for team_neon in GameTheme.team_colors:
		if (team_neon as Color).is_equal_approx(color):
			return true
	return false


## The weapon profile (slot contract); parts that size themselves from it override this.
func setup(_weapon: Dictionary) -> void:
	pass


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


## The part's paint: the chosen color, or worn gunmetal.
func paint() -> Color:
	return paint_color if paint_color.a > 0.0 else DEFAULT_PAINT


func paint_dark() -> Color:
	return paint().darkened(0.45)


const RUBBER := Color(0.05, 0.05, 0.055)
const STEEL := Color(0.3, 0.3, 0.32)
const RUST := Color(0.32, 0.16, 0.08)
const HEADLIGHT := Color(1.0, 0.92, 0.75)
