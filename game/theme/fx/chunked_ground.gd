class_name ChunkedGround
extends Node3D
## The arena floor split into square tiles sharing one material. The Compatibility renderer lets
## at most 8 real lights touch one object and draws each light as an extra pass over the whole
## object, so a single 320 m plane would cap the whole floor at 8 lights and re-draw all of it per
## light. Tiles limit both to the tiles a light actually reaches (and help frustum culling).

@export var size := 320.0
@export var tile := 40.0
@export var material: Material
## false = one big plane (the FX lab's comparison case).
@export var chunked := true


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.free()
	var tiles := int(ceil(size / tile)) if chunked else 1
	var step := size / tiles
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(step, step)
	mesh.material = material
	for x in tiles:
		for z in tiles:
			var piece := MeshInstance3D.new()
			piece.name = "Tile_%d_%d" % [x, z]
			piece.mesh = mesh
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.position = Vector3(-size / 2.0 + step * (x + 0.5), 0.0, -size / 2.0 + step * (z + 0.5))
			add_child(piece)


func tile_count() -> int:
	return get_child_count()
