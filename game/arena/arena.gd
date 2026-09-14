extends Node3D
## The static battlefield. Bakes its navigation mesh at startup on EVERY peer,
## because pathing runs wherever an OrderController runs (server bots, agent clients).
##
## The bake parses COLLISION SHAPES (layer 1) in the "navigation_source" group,
## never render meshes: the dedicated-server export strips meshes.
##
## FAIRNESS: the arena is point-symmetric (rotating it 180° about the center gives
## the same arena), but a normal navmesh bake is NOT: the baker's polygonization
## depends on traversal order. Mirrored trips differed by up to 4.4 m, and the
## south base won 64% of 140 bot matches. So we bake only the southern half
## (z >= 0) and add the same mesh rotated 180° as a second region: the navigation
## is symmetric by construction. See _agents/squad_ai_design.md "Fairness".

signal navigation_ready

## Extra bake margin past the seam so the half-mesh isn't shrunk by the agent
## radius where it meets its mirror (NavigationMesh.border_size, for chunked bakes).
const SEAM_BORDER := 2.5
const HALF_EXTENT := Match.ARENA_HALF_SIZE + 40.0

@onready var navigation: NavigationRegion3D = $Navigation


func _ready() -> void:
	var nav_mesh := navigation.navigation_mesh
	nav_mesh.border_size = SEAM_BORDER
	nav_mesh.filter_baking_aabb = AABB(Vector3(-HALF_EXTENT, -5.0, -SEAM_BORDER),
			Vector3(HALF_EXTENT * 2.0, 20.0, HALF_EXTENT + SEAM_BORDER))
	navigation.bake_navigation_mesh(false)

	var mirror := NavigationRegion3D.new()
	mirror.name = "NavigationMirror"
	mirror.navigation_mesh = nav_mesh
	mirror.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	add_child(mirror)
	navigation_ready.emit()
