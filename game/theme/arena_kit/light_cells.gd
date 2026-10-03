class_name LightCells
extends RefCounted
## Round 16 (render R3): static MultiMeshes split into ground cells so a pooled light re-draws only the props near it.
##
## The Compatibility renderer draws an object AGAIN, whole, for every OmniLight whose sphere meets its box. A kind of
## prop drawn as one MultiMesh across the arena (the containers, the barricades) therefore paid a full extra pass for
## every explosion anywhere on the map: measured 0.71 ms GPU at his window for the two yards alone, of 1.42 ms for all
## static geometry (laptop, frozen staged frame, `make render-split` layers lights_spare_yards / lights_vehicles_only).
## A light adds exactly nothing beyond its range, so a cell it cannot reach looks the same without the pass: the
## picture is unchanged and the passes it did not need are gone. The price is a draw call per occupied cell instead of
## one per kind. Only LIT opaque kinds are split; unlit, additive or index-phased kinds stay whole.

## Cell edge (m). The biggest pooled light reaches 22 m, so a light touches one to four cells.
const CELL_M := 64.0


## The cell key of a ground position.
static func cell_of(origin: Vector3) -> Vector2i:
	return Vector2i(floori(origin.x / CELL_M), floori(origin.z / CELL_M))


## `entries` ([kind, Transform3D, data]) grouped by cell, in their original order within each cell.
static func group(entries: Array) -> Dictionary:
	var cells := {}
	for entry: Array in entries:
		var key := LightCells.cell_of((entry[1] as Transform3D).origin)
		(cells.get_or_add(key, []) as Array).append(entry)
	return cells


## The draw's key and node name for `kind` in `cell` (no '@': Godot strips it from node names). The draw also carries
## metas "kind" and "cell".
static func draw_name(kind: String, cell: Vector2i) -> String:
	return "%s_cell_%d_%d" % [kind, cell.x, cell.y]
