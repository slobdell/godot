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
## so a junction is open pavement. Nor does it run under kerb furniture (arena's catch on the first frames: the
## avenue's kerb line ran straight into a two-high container, telling him the road went on where a box stood): a
## piece within FOOTPRINT_CLEAR_M of any collider footprint in the layout is dropped too, so the line stops at the box.
## Nothing here stands up, so arena's rule "no furniture at the kerb between buildings" (it hides a throat) is kept by
## construction. Chokepoints (cold light, stencils) -- the Terminus has none
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
## Paint stops this far short of a collider's footprint (arena's suggested rule).
const FOOTPRINT_CLEAR_M := 0.3
## A junction's warm pool: this radius (m), at ~3000 K.
const POOL_RADIUS_M := 7.0
const KERB_COLOR := Color(1.0, 0.93, 0.78)
const DASH_COLOR := Color(1.0, 0.78, 0.30)
const POOL_COLOR := Color(1.0, 0.71, 0.42)
const POOL_SHADER := preload("res://game/theme/arena_kit/city/lane_pool.gdshader")

var lanes: Array = []
## [[center: Vector2, size: Vector3, rotation_deg: float]...]: what paint must stop short of.
var footprints: Array = []
var kerbs: MultiMeshInstance3D
var dashes: MultiMeshInstance3D
var pools: MultiMeshInstance3D


func _init(layout_lanes: Array = [], layout_footprints: Array = []) -> void:
	name = "LaneMarks"
	lanes = layout_lanes
	footprints = layout_footprints


## Every collider footprint a layout places: its colliding kit props (containers, footings, barricades...) and its
## `obstacles` list, as [center, size, rotation_deg].
static func footprints_of(layout: Dictionary) -> Array:
	var out: Array = []
	for prop: Dictionary in layout.get("props", []):
		var type := String(prop.get("type", ""))
		if not ArenaKit.PROPS.has(type) or not ArenaKit.collides(type):
			continue
		out.append([Vector2(float(prop["position"][0]), float(prop["position"][1])), ArenaKit.size_of(prop),
				float(prop.get("rotation_deg", 0.0))])
	for obstacle: Dictionary in layout.get("obstacles", []):
		if not obstacle.has("size") or not obstacle.has("position"):
			continue
		var size: Array = obstacle["size"]
		out.append([Vector2(float(obstacle["position"][0]), float(obstacle["position"][1])),
				Vector3(float(size[0]), float(size[1]), float(size[2])), float(obstacle.get("rotation_deg", 0.0))])
	return out


func _ready() -> void:
	var plan := plan_for(lanes, footprints)
	kerbs = _strips("Kerbs", plan["kerbs"], KERB_WIDTH_M, _paint(KERB_COLOR, 0.35))
	dashes = _strips("Dashes", plan["dashes"], DASH_WIDTH_M, _paint(DASH_COLOR, 0.45))
	pools = _pools(plan["corners"])


## Pure: where every piece of paint and every pool goes, for a list of lanes. {kerbs: [[from, to]...], dashes: [...],
## corners: [Vector2...]} in the ground plane (x, z).
static func plan_for(layout_lanes: Array, layout_footprints: Array = []) -> Dictionary:
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
					if not _inside_other(mid, li, layout_lanes, 0.0) \
							and not _near_footprint(a + along * s + offset, a + along * e + offset, layout_footprints):
						kerb_pieces.append([a + along * s + offset, a + along * e + offset])
					s = e
			# Dashes: on the centre line, at the pitch, counted along the whole lane so they do not restart per segment.
			var d := fposmod(-travelled, DASH_PITCH_M)
			while d + DASH_LENGTH_M <= length:
				var mid := a + along * (d + DASH_LENGTH_M / 2.0)
				if not _inside_other(mid, li, layout_lanes, 1.0) \
						and not _near_footprint(a + along * d, a + along * (d + DASH_LENGTH_M), layout_footprints):
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


## Does the piece from `p` to `q` come within FOOTPRINT_CLEAR_M of any footprint? (Its ends and middle are sampled:
## pieces are <= 2.2 m, far shorter than any footprint, so a box cannot slip between the samples.)
static func _near_footprint(p: Vector2, q: Vector2, layout_footprints: Array) -> bool:
	for fp: Array in layout_footprints:
		for t in [0.0, 0.5, 1.0]:
			if ArenaKit.distance_to_footprint(p.lerp(q, t), fp[0], fp[1], float(fp[2])) < FOOTPRINT_CLEAR_M:
				return true
	return false


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
	FxMultiMesh.resize(multi, pieces.size())
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
	FxMultiMesh.never_interpolated(instance)  # static paint: the renderer must not interpolate it (fx_multimesh.gd)
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
	FxMultiMesh.resize(multi, corners.size())
	for i in corners.size():
		var p: Vector2 = corners[i]
		multi.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, LIFT_M + 0.01, p.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Pools"
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FxMultiMesh.never_interpolated(instance)
	add_child(instance)
	return instance
