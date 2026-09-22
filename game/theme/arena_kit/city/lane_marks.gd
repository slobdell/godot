class_name LaneMarks
extends Node3D
## Research rows B10 and C11 (round 10, feel with arena's list, 2026-09-22): the streets READ as streets from his camera.
##
## Three things, all flush with the ground, no collider, no light added, one MultiMesh each (3 draws):
##   * KERB PAINT along both edges of every certified lane (`layout.lanes`, arena's R4 lanes): "certified lanes read
##     warm -- painted kerbs, unbroken pavement" (B10). Warm white, faintly emissive so it reads at night.
##   * CENTRE DASHES at a fixed pitch: the SCALE ANCHORS of C11. At his telephoto pose the eye has no depth cue
##     between a vehicle and a throat 80 m away; a dash every DASH_PITCH_M metres is a ruler laid down the street.
##   * A WARM POOL at every junction of two lanes: "a light behind every corner so a street's entrance silhouettes from
##     his camera" (B10) -- a hull entering a street is seen against the pool beyond it. A pool is a flat additive
##     decal, not a light: the Compatibility renderer pays per light, and B10's row says zero lights added.
## Paint never crosses another street: a kerb or dash piece that falls inside another lane's carriageway is dropped,
## so a junction is open pavement. Nothing here stands up, so arena's rule "no furniture at the kerb between
## buildings" (it hides a throat) is kept by construction. Chokepoints (cold light, stencils) -- the Terminus has none
## after CP2 (arena), so nothing is lit cold. `--no-lane-marks` builds none, for the A/B pair.

## Paint sits this high over the floor (the ground is at 0): enough to beat z-fighting at 49 m, invisible side-on.
const LIFT_M := 0.03
## The kerb line: this wide, set in this far from the lane's edge.
const KERB_WIDTH_M := 0.22
const KERB_INSET_M := 0.35
## Kerb paint is laid in pieces this long, so a piece inside another street can be dropped.
const KERB_PIECE_M := 1.0
## Centre dashes: 2.2 m of paint every 8.6 m. The pitch is the roster's K-scaled real one (a US 10 ft dash on a 40 ft
## cycle, x SCALE_K ~ 0.71), so the ruler agrees with the vehicles' own scale.
const DASH_LENGTH_M := 2.2
const DASH_PITCH_M := 8.6
const DASH_WIDTH_M := 0.18
## A junction's warm pool: this radius (m), at ~3000 K.
const POOL_RADIUS_M := 7.0
const KERB_COLOR := Color(1.0, 0.93, 0.78)
const DASH_COLOR := Color(1.0, 0.78, 0.30)
const POOL_COLOR := Color(1.0, 0.71, 0.42)
const POOL_SHADER := preload("res://game/theme/arena_kit/city/lane_pool.gdshader")

var lanes: Array = []
var kerbs: MultiMeshInstance3D
var dashes: MultiMeshInstance3D
var pools: MultiMeshInstance3D


func _init(layout_lanes: Array = []) -> void:
	name = "LaneMarks"
	lanes = layout_lanes


func _ready() -> void:
	var plan := plan_for(lanes)
	kerbs = _strips("Kerbs", plan["kerbs"], KERB_WIDTH_M, _paint(KERB_COLOR, 0.35))
	dashes = _strips("Dashes", plan["dashes"], DASH_WIDTH_M, _paint(DASH_COLOR, 0.45))
	pools = _pools(plan["corners"])


## Pure: where every piece of paint and every pool goes, for a list of lanes. {kerbs: [[from, to]...], dashes: [...],
## corners: [Vector2...]} in the ground plane (x, z).
static func plan_for(layout_lanes: Array) -> Dictionary:
	var kerb_pieces: Array = []
	var dash_pieces: Array = []
	for li in layout_lanes.size():
		var lane: Dictionary = layout_lanes[li]
		var points: Array = lane["points"]
		var half := float(lane["width"]) / 2.0
		var travelled := 0.0
		for k in range(1, points.size()):
			var a := Vector2(float(points[k - 1][0]), float(points[k - 1][1]))
			var b := Vector2(float(points[k][0]), float(points[k][1]))
			var along := (b - a).normalized()
			var side := Vector2(-along.y, along.x)
			var length := a.distance_to(b)
			# Kerbs: both edges, in pieces.
			for edge in [-1.0, 1.0]:
				var offset: Vector2 = side * edge * (half - KERB_INSET_M)
				var s := 0.0
				while s < length:
					var e := minf(s + KERB_PIECE_M, length)
					var mid: Vector2 = a + along * ((s + e) / 2.0) + offset
					if not _inside_other(mid, li, layout_lanes, 0.0):
						kerb_pieces.append([a + along * s + offset, a + along * e + offset])
					s = e
			# Dashes: on the centre line, at the pitch, counted along the whole lane so they do not restart per segment.
			var d := fposmod(-travelled, DASH_PITCH_M)
			while d + DASH_LENGTH_M <= length:
				var mid := a + along * (d + DASH_LENGTH_M / 2.0)
				if not _inside_other(mid, li, layout_lanes, 1.0):
					dash_pieces.append([a + along * d, a + along * (d + DASH_LENGTH_M)])
				d += DASH_PITCH_M
			travelled += length
	return {"kerbs": kerb_pieces, "dashes": dash_pieces, "corners": corners_of(layout_lanes)}


## Every point where two different lanes' centre lines meet (a crossing, a T or a shared end), deduplicated.
static func corners_of(layout_lanes: Array) -> Array:
	var found: Array = []
	for i in layout_lanes.size():
		for j in range(i + 1, layout_lanes.size()):
			var pa: Array = layout_lanes[i]["points"]
			var pb: Array = layout_lanes[j]["points"]
			for k in range(1, pa.size()):
				for m in range(1, pb.size()):
					var hit: Variant = Geometry2D.segment_intersects_segment(
							Vector2(pa[k - 1][0], pa[k - 1][1]), Vector2(pa[k][0], pa[k][1]),
							Vector2(pb[m - 1][0], pb[m - 1][1]), Vector2(pb[m][0], pb[m][1]))
					if hit == null:
						continue
					var p: Vector2 = hit
					var fresh := true
					for q: Vector2 in found:
						if q.distance_to(p) < 1.0:
							fresh = false
							break
					if fresh:
						found.append(p)
	return found


## Is `p` on the carriageway of any lane other than `own` (inflated by `margin`)?
static func _inside_other(p: Vector2, own: int, layout_lanes: Array, margin: float) -> bool:
	for li in layout_lanes.size():
		if li == own:
			continue
		var lane: Dictionary = layout_lanes[li]
		var points: Array = lane["points"]
		var reach := float(lane["width"]) / 2.0 + margin
		for k in range(1, points.size()):
			var a := Vector2(float(points[k - 1][0]), float(points[k - 1][1]))
			var b := Vector2(float(points[k][0]), float(points[k][1]))
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < reach:
				return true
	return false


func _paint(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	return material


## One MultiMesh of flat strips, one instance per [from, to] piece.
func _strips(node_name: String, pieces: Array, width: float, material: Material) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 1.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = pieces.size()
	for i in pieces.size():
		var from: Vector2 = pieces[i][0]
		var to: Vector2 = pieces[i][1]
		var dir := to - from
		var yaw := atan2(dir.x, dir.y)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, 1.0, dir.length()))
		var mid := (from + to) / 2.0
		multi.set_instance_transform(i, Transform3D(basis, Vector3(mid.x, LIFT_M, mid.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _pools(corners: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(POOL_RADIUS_M * 2.0, POOL_RADIUS_M * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var material := ShaderMaterial.new()
	material.shader = POOL_SHADER
	material.set_shader_parameter("color", POOL_COLOR)
	quad.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = corners.size()
	for i in corners.size():
		var p: Vector2 = corners[i]
		multi.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, LIFT_M + 0.01, p.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Pools"
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
