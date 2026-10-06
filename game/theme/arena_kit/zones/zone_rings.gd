class_name ZoneRings
extends Node3D
## Round 19 (board, S2): every zone the match SCORES, drawn on the floor where it is (zone_ring.gdshader), with its
## name standing over it in the holder's colour. The lead: *"there's very little indication that holding the center is
## what scores points, or that standing in the ring scores points"*. Until now the only ring on the ground was the
## dressing's at the arena's centre, which on the twelve dealt maps scores nothing (their zones are the two side
## rings, `Arena.objectives_of`).
##
## Reads `Match.score_snapshot()` and updates on `score_changed` only (uniform writes; the shader animates itself):
## one draw per zone and one label, nothing per unit. Visual only.

const SHADER := preload("res://game/theme/arena_kit/zones/zone_ring.gdshader")
const DISPLAY_FONT := preload("res://assets/fonts/ShareTechMono-Regular.ttf")  # the kit's type (C19.5)
## Metres above the floor: over the ground's own markings, under any hull.
const LIFT_M := 0.07
const MARGIN_M := 2.0
const LABEL_HEIGHT_M := 7.5

## The local player's team: its zones read in the friendly colour, the other side's in the enemy colour.
var team := Match.Team.GREEN
var game_match: Match:
	set(value):
		if game_match != null and game_match.score_changed.is_connected(apply):
			game_match.score_changed.disconnect(apply)
		game_match = value
		if game_match != null:
			game_match.score_changed.connect(apply)
			if is_inside_tree():
				apply(game_match.score_snapshot())

var _materials: Array[ShaderMaterial] = []
var _labels: Array[Label3D] = []


func _ready() -> void:
	name = "ZoneRings"
	if game_match != null:
		apply(game_match.score_snapshot())


func side_color(side_team: int) -> Color:
	return GameTheme.ui["friendly"] if side_team == team else GameTheme.ui["enemy"]


## Builds the rings on the first snapshot, then writes each zone's state into its material.
func apply(snap: Dictionary) -> void:
	if snap.is_empty() or not bool(snap.get("control", false)):
		visible = false
		return
	visible = true
	var zones: Array = snap["objectives"]
	if _materials.size() != zones.size():
		_build(zones)
	for i in zones.size():
		var zone: Dictionary = zones[i]
		var material := _materials[i]
		var owner := int(zone["owner"])
		var progress := float(zone["progress"])
		var capturer := Match.Team.GREEN if progress > 0.0 else Match.Team.RUST
		material.set_shader_parameter("fill", absf(progress))
		material.set_shader_parameter("fill_color", side_color(capturer))
		material.set_shader_parameter("held", 1.0 if owner >= 0 else 0.0)
		material.set_shader_parameter("held_color", side_color(maxi(owner, 0)))
		material.set_shader_parameter("contested", 1.0 if bool(zone.get("contested", false)) else 0.0)
		var label := _labels[i]
		label.modulate = side_color(owner) if owner >= 0 else Color(1, 1, 1, 0.85)
		label.text = String(zone["label"]).trim_prefix("the ").to_upper()
		if owner >= 0:
			label.text += "\nSCORING"
		elif bool(zone.get("contested", false)):
			label.text += "\nCONTESTED"


func _build(zones: Array) -> void:
	for child in get_children():
		child.queue_free()
	_materials.clear()
	_labels.clear()
	for zone: Dictionary in zones:
		var radius := float(zone.get("radius", Match.CONTROL_RADIUS))
		var centre: Vector3 = zone["position"]
		var mesh := PlaneMesh.new()
		mesh.size = Vector2.ONE * (radius + MARGIN_M) * 2.0
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("radius_m", radius)
		material.set_shader_parameter("size_m", (radius + MARGIN_M) * 2.0)
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		ring.mesh = mesh
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = Vector3(centre.x, _floor_y(centre) + LIFT_M, centre.z)
		_materials.append(material)
		var label := Label3D.new()
		label.name = "Name"
		label.font = DISPLAY_FONT
		label.font_size = 96
		label.pixel_size = 0.03
		label.outline_size = 18
		label.outline_modulate = Color(0, 0, 0, 0.8)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.shaded = false
		label.double_sided = true
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		label.global_position = Vector3(centre.x, _floor_y(centre) + LABEL_HEIGHT_M, centre.z)
		_labels.append(label)


## The floor under a zone's centre (a pit or a deck sits off zero): straight down from above, world layer only.
func _floor_y(at: Vector3) -> float:
	if not is_inside_tree() or get_world_3d() == null:
		return 0.0
	var space := get_world_3d().direct_space_state
	if space == null:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 30.0, at.z), Vector3(at.x, -30.0, at.z), 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.9 or float((hit["position"] as Vector3).y) > 4.0:
		return 0.0
	return float((hit["position"] as Vector3).y)
