class_name FxMultiMesh
extends RefCounted
## Every MultiMesh whose instances are written from `_process` (all of the effects, the crowd, the arena kit's props)
## must tell the renderer not to interpolate it. Since the simulation moved to 30 Hz with physics interpolation, the
## renderer interpolates MultiMesh transforms between physics ticks, and writing them outside `_physics_process` logs
## "[Physics interpolation] MultiMesh interpolation is being triggered from outside physics process" — noise that
## breaks control's clean-console gate (the lead's "a bunch of red error messages").
##
## Interpolating them would also be wrong: these transforms are already computed per frame from where things are DRAWN
## (FxWorld.visual_transform), so the renderer would interpolate an interpolation and smear every effect a frame behind.
##
## There are two switches and both matter:
##   * the NODE's `physics_interpolation_mode`, which the MultiMeshInstance3D pushes to the server whenever its
##     interpolation state changes — including when it enters the tree, which is what silently undid a server-side
##     flag set in `_init` (measured: with the server call alone the node still reports
##     `is_physics_interpolated_and_enabled() == true`, and one burst write per playtest still warned);
##   * the SERVER's flag on the multimesh, which **is reset whenever `instance_count` changes**, because that rebuilds
##     the buffers.
## So: `never_interpolated()` at every mesh node, `resize()` for every count change, and a test fails if anyone sets
## `instance_count` directly.


## Keep `instance` and its mesh out of physics interpolation, for good: call it once the node has its multimesh.
static func never_interpolated(instance: MultiMeshInstance3D) -> void:
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	FxMultiMesh.no_interpolation(instance.multimesh)


## Turn interpolation off for `multimesh` on the server (safe to call repeatedly; no-op where nothing renders).
static func no_interpolation(multimesh: MultiMesh) -> void:
	if multimesh != null and multimesh.get_rid().is_valid():
		RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)


## Set `multimesh`'s instance count and re-assert that it isn't interpolated (resizing it rebuilds the server buffers,
## which turns interpolation back on).
static func resize(multimesh: MultiMesh, count: int) -> void:
	multimesh.instance_count = count
	FxMultiMesh.no_interpolation(multimesh)
