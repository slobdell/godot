extends "res://game/theme/cyberpunk/cyber_prop.gd"
## A towering arena screen (`prop.ad_screen`, assets X2): a 7 × 14 m LED panel on a steel housing and two legs over a
## concrete plinth, a red aircraft beacon on top, and the light it throws on the ground in front. The panel shows its
## broadcast channel (AdBroadcast) through the channel's shared material. Faces -Z (the side players see). Visual only;
## any collision is gameplay's (a layout obstacle's plinth footprint).
##
## `setup(obstacle)` reads `channel` (default "arena"): screens on one channel show the same ad.

const PANEL := Vector2(7.0, 14.0)
const PANEL_BOTTOM := 6.0
const PLINTH := Vector3(7.4, 1.4, 1.4)
const SPILL := Vector2(34.0, 22.0)

@export var channel_name := "arena"

var panel: MeshInstance3D
var spill: MeshInstance3D
var broadcast: AdBroadcast


func setup(obstacle: Dictionary) -> void:
	channel_name = String(obstacle.get("channel", channel_name))
	if is_inside_tree():
		_apply_channel()


func _ready() -> void:
	_build()
	_apply_channel()


func _apply_channel() -> void:
	broadcast = AdBroadcast.channel(self, channel_name)
	panel.material_override = broadcast.screen_material
	spill.material_override = broadcast.spill_material


func _build() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	var concrete := CyberMaterials.surface(Color(0.2, 0.2, 0.21), 0.85, 0.0)
	var steel := CyberMaterials.surface(Color(0.1, 0.1, 0.11), 0.55, 0.7)
	# Render (round 5): the housing was near-black, so a screen seen from behind read as a flat black slab.
	var housing := CyberMaterials.surface(Color(0.16, 0.16, 0.17), 0.7, 0.45)
	var rib := CyberMaterials.surface(Color(0.24, 0.23, 0.22), 0.65, 0.5)
	var top := PANEL_BOTTOM + PANEL.y
	CyberMaterials.box(structure, PLINTH, Vector3(0, PLINTH.y / 2.0, 0.2), concrete)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(structure, Vector3(0.45, top - PLINTH.y, 0.45), Vector3(sx * 2.6, PLINTH.y + (top - PLINTH.y) / 2.0, 0.6), steel)
	for y in [PLINTH.y + 1.6, PANEL_BOTTOM - 0.6]:
		CyberMaterials.box(structure, Vector3(5.7, 0.3, 0.3), Vector3(0, y, 0.6), steel)
	CyberMaterials.box(structure, Vector3(PANEL.x + 0.5, PANEL.y + 0.5, 0.7), Vector3(0, PANEL_BOTTOM + PANEL.y / 2.0, 0.42), housing)
	# The back: structural ribs and a row of small amber service lights, so the rear reads as machinery.
	for i in 6:
		var y := PANEL_BOTTOM + 1.0 + i * (PANEL.y - 2.0) / 5.0
		CyberMaterials.box(structure, Vector3(PANEL.x + 0.3, 0.22, 0.18), Vector3(0, y, 0.84), rib)
	for x in [-2.6, 0.0, 2.6]:
		CyberMaterials.box(structure, Vector3(0.22, PANEL.y, 0.2), Vector3(x, PANEL_BOTTOM + PANEL.y / 2.0, 0.86), rib)
		CyberMaterials.box(structure, Vector3(0.18, 0.18, 0.08), Vector3(x, PANEL_BOTTOM + 0.6, 0.98), CyberMaterials.neon(Color(1.0, 0.6, 0.15), 3.0, 0.2), false)
	# A service catwalk under the panel and the beacon on top.
	CyberMaterials.box(structure, Vector3(PANEL.x + 0.8, 0.12, 1.1), Vector3(0, PANEL_BOTTOM - 0.35, -0.1), steel)
	CyberMaterials.box(structure, Vector3(0.35, 0.35, 0.35), Vector3(0, top + 0.5, 0.42), CyberMaterials.neon(CyberMaterials.RED, 5.0, 0.6), false)
	StaticBatcher.merge(structure)
	panel = MeshInstance3D.new()
	spill = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PANEL
	panel.name = "Panel"
	panel.mesh = quad
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A QuadMesh faces +Z; turned half a turn it faces the players at -Z and still reads left to right.
	panel.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, PANEL_BOTTOM + PANEL.y / 2.0, 0.05))
	add_child(panel)
	var plane := PlaneMesh.new()
	plane.size = SPILL
	spill.name = "Spill"
	spill.mesh = plane
	spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The plane's UV.y runs from -Z (0) to +Z (1): its bright edge sits at the screen's foot.
	spill.position = Vector3(0, 0.05, -SPILL.y / 2.0 - 0.6)
	add_child(spill)
