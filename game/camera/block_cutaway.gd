class_name BlockCutaway
extends Node
## Round 9, the second half of the lead's Terminus item: **the building between the camera and what it is looking at
## is not drawn.** His words: *"the camera often ends up inside a building and we can't see what's going on inside the
## alleyways. We need to make it so the camera is forced outside the solid for these cases."*
##
## `RtsCamera.clear_pose` answers the first half — the camera is never left inside a solid (703 of 4328 poses at his
## pose on the Terminus before, 0 after). It does NOT answer the second: measured over those same 703 poses, the sight
## line from the camera to the ground it is aimed at was blocked by a building in **700 before and 518 after**. A
## camera correctly outside every building, looking at the side of one, is still a player who cannot see his alley.
## This is that 518.
##
## **Why visibility and not a fade.** Contract S6 (the `show` stream's arena light show) draws the same blocks:
## the orchestrator's seam is *control owns alpha and visibility, show owns emission and channels, neither writes the
## other's*. A per-block alpha would have to be an `instance uniform` on `city_block.gdshader` — **show's file** — so
## taking it would mean either editing their shader or blocking overnight on them adding one. Hiding the block's
## `VisualSlot` needs no uniform at all, cannot collide with anything show writes, and is one boolean to revert.
## **control therefore reserves NOTHING on the block material** (`_agents/lighting.md`), and a block mid-cue keeps its
## cue: it is simply not drawn while it is in the way, and drawn again, mid-cue, when it is not.
##
## **Only buildings, never cover.** A container or a barricade between the camera and the fight is *information* — it
## is the thing that makes the fight readable, and hiding it would hide why a unit stopped where it did. Only solids
## at least `MIN_HEIGHT_M` tall are ever cut, which on today's arenas means city blocks and nothing else.
##
## The collision body is untouched: only the art stops being drawn. Shells, cover, radar and the navmesh never notice.

## A solid this tall is a building; anything shorter is cover, and cover is never cut.
const MIN_HEIGHT_M := 6.0
## The sight line is aimed at a vehicle's height above the ground the camera is pointed at, not at the ground itself:
## a block whose roof just clips the ground point is not what is hiding the tank standing there.
const AIM_HEIGHT_M := 1.5
## A block is only cut when the camera is actually behind it. Below this the camera is practically inside the block's
## own footprint and `clear_pose` has already dealt with it.
const MIN_SIGHT_M := 2.0

var camera: Camera3D
## The arena's `Obstacles` node (every kit prop and obstacle is one StaticBody3D under it).
var obstacles_root: Node3D

## [{"body": StaticBody3D, "visual": Node3D, "centre": Vector3 (local), "half": Vector3}], rebuilt when the arena is.
var _solids: Array = []
var _built_for := 0
var _cut: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the view must be right while the match is paused, too


## Which blocks are not being drawn right now, by node name. `show` reads this rather than guessing (contract S6):
## a cue on a cut block is still running, it is simply not on screen this frame.
func cut_blocks() -> Array[String]:
	return _cut.duplicate()


func _process(_delta: float) -> void:
	if camera == null:
		return
	if obstacles_root == null or not is_instance_valid(obstacles_root):
		# The arena may not have built its bodies when this node was wired up, and a match can swap arenas under it.
		# Finding the root lazily is the difference between cutting nothing forever and cutting from the first frame
		# the buildings exist: the live run reported `cut: []` on every frame for exactly this reason while the same
		# code cut correctly in a test that wired it after the arena was ready.
		obstacles_root = get_tree().root.find_child("Obstacles", true, false) as Node3D
		_built_for = -1
		if obstacles_root == null:
			return
	if obstacles_root.get_child_count() != _built_for:
		_gather()
	var aim: Variant = aim_point()
	var keep: Array[String] = []
	for solid: Dictionary in _solids:
		var body: Node3D = solid["body"]
		var visual: Node3D = solid["visual"]
		if not is_instance_valid(body) or not is_instance_valid(visual):
			continue
		var hide := aim != null and _in_the_way(solid, aim as Vector3)
		if visual.visible == hide:
			visual.visible = not hide
		if hide:
			keep.append(String(body.name))
	_cut = keep


## The point on the ground the camera is looking at, at a vehicle's height, or null when it is not looking down at
## the ground at all. Derived from the camera's own transform, so it needs no rig, no viewport and no order.
func aim_point() -> Variant:
	var forward := -camera.global_basis.z
	if forward.y > -0.01:
		return null
	var at := camera.global_position
	return at + forward * ((AIM_HEIGHT_M - at.y) / forward.y)


func _in_the_way(solid: Dictionary, aim: Vector3) -> bool:
	var body: Node3D = solid["body"]
	var from := camera.global_position
	if from.distance_to(aim) < MIN_SIGHT_M:
		return false
	var centre: Vector3 = body.global_position + (solid["centre"] as Vector3).rotated(Vector3.UP, body.global_rotation.y)
	return RtsCamera.segment_hits_box(from, aim, centre, solid["half"], body.global_rotation.y)


## The arena's tall solids and the box each one really occupies, read from its own collision shapes rather than from
## the layout: a block built as four tiled slabs (Arena._obstacle_shapes, because the navmesh baker ignores a box
## large on both axes) is one building to the eye, and the union of its slabs is that building.
func _gather() -> void:
	_solids = []
	_built_for = obstacles_root.get_child_count()
	for child in obstacles_root.get_children():
		var body := child as Node3D
		var visual := body.get_node_or_null("Visual") as Node3D if body != null else null
		if body == null or visual == null:
			continue
		var low := Vector3.INF
		var high := -Vector3.INF
		for shape_node in body.get_children():
			var shape := shape_node as CollisionShape3D
			var box := shape.shape as BoxShape3D if shape != null else null
			if box == null:
				continue
			low = low.min(shape.position - box.size / 2.0)
			high = high.max(shape.position + box.size / 2.0)
		if low == Vector3.INF or (high.y - low.y) < MIN_HEIGHT_M:
			continue
		_solids.append({"body": body, "visual": visual, "centre": (low + high) / 2.0, "half": (high - low) / 2.0})


## Draw everything again (leaving a match, or turning the cutaway off).
func restore() -> void:
	for solid: Dictionary in _solids:
		var visual: Node3D = solid["visual"]
		if is_instance_valid(visual):
			visual.visible = true
	_cut = []
