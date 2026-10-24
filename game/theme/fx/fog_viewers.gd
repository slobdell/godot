class_name FogViewers
extends RefCounted
## Round 39 (feedback F1, C39.5, his "never hide an enemy inside a range the player was shown"): the fog of war is the
## range he is shown, so lit ground must stop where his crews' sight stops NOW.
##
## VisibilityField takes one crew's look per tick and publishes the picture once a cycle (REFRESH_TICKS, or one tick per
## crew past fifteen crews), so a look can be two cycles old when it leaves the screen. A crew that drives off leaves its
## old circle lit behind it, and with R1 ON its sight also shrinks from ~110 % to ~85 % within a second of moving. Measured
## (tests/test_feedback_sight_shown.gd, laptop, 906557c06): a 25-crew army showed lit ground over a hidden enemy on 303
## of 540 ticks, up to 24.5 m past the crew's real sight (13.0 m with R1 OFF: the lag alone).
##
## The fix is where it is drawn: every frame the fog's shader gets each living crew's position and sight radius as it is
## now, and lit ground outside every crew's current circle is drawn as remembered ground instead. The field's picture
## still decides line of sight (walls, buildings); the circles only take light away, never add it. `shown` is the same
## sum in GDScript, for tests; keep the two in step (game/theme/fx/shaders/fog_of_war.gdshader `clip_to_sight`).

## Crews the shader takes (the army cap is Units.MAX_SQUADS x 5 = 50). Past it, the clip is off: the field alone.
const MAX := 64
## Remembered ground in the field's picture (VisibilityField.SEEN_VALUE as the shader reads it).
const SEEN_V := VisibilityField.SEEN_VALUE / 255.0
## The clip's soft band inside each circle, metres, so its edge is not a hard pixel step.
const SOFT_M := 1.5
## Frames a visual keeps looking for its field before it gives up (modes with no field never pay for the search).
const FIND_FRAMES := 30


## The field whose picture is `texture` (the visual only gets the texture through its slot), or null.
static func find_field(tree: SceneTree, texture: Texture2D) -> VisibilityField:
	if tree == null or texture == null:
		return null
	for node in tree.root.find_children("*", "VisibilityField", true, false):
		if (node as VisibilityField).texture == texture:
			return node as VisibilityField
	return null


## Each living crew of the field's team as (x, z, sight radius as it is now, 0).
static func pack(field: VisibilityField) -> PackedVector4Array:
	var out := PackedVector4Array()
	if field == null or field.game_match == null:
		return out
	for tank in field.game_match.sorted_team_tanks(field.team):
		if tank.is_alive():
			out.append(Vector4(tank.global_position.x, tank.global_position.z, tank.sight_radius, 0.0))
	return out


## Hands the crews to a fog material: `viewers` and `viewer_count` (-1 = no clip).
static func apply(material: ShaderMaterial, field: VisibilityField) -> void:
	var viewers := pack(field)
	var count := viewers.size() if viewers.size() <= MAX else -1  # past MAX: the field alone, as before round 39
	viewers.resize(MAX)
	material.set_shader_parameter("viewers", viewers)
	material.set_shader_parameter("viewer_count", count)


## The value the fog draws at `at` (world xz) for the field's value `v` (0..1): the shader's `clip_to_sight`.
static func shown(v: float, at: Vector2, viewers: PackedVector4Array, count: int) -> float:
	if count < 0 or v <= SEEN_V:
		return v
	var best := INF
	for i in mini(count, viewers.size()):
		var o := viewers[i]
		best = minf(best, at.distance_to(Vector2(o.x, o.y)) - o.z)
		if best <= -SOFT_M:
			break
	var inside := 1.0 - smoothstep(-SOFT_M, 0.0, best)
	return lerpf(minf(v, SEEN_V), v, inside)
