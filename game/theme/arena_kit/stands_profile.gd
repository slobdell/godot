class_name StandsProfile
extends RefCounted
## The grandstand's height profile outside the wall, as data (feel, round 7), for control's wall cutaway: points of
## (metres out from the wall's INNER face, height in metres), nearest first, beginning with the wall's own top.
##
## Until round 7 control measured feel's `kit_stands` by hand into `RtsCamera.STANDS_PROFILE`; the moment the venue
## changes shape or module that copy goes stale without a sound (lesson 66). This is computed from the model the
## dressing actually places and from the dressing's own placement constants, so it moves when the art moves.
## It agrees with the old hand measurement at the back (22.2 m out, 15.7 m) and NOT at the front: the kit stands
## 9.6 m tall from 4.2 m out where the hand values had 7 m at 2.3 m, rising in a straight line. The kit is right;
## control's switch to this caught a camera case that only passed on the too-low front.

## The dressing places each module this far behind the wall's inner face: the wall's thickness plus a 0.3 m gap
## (ArenaDressing: `half + WALL_THICK / 2 + size.z / 2 + 0.3`, where `half` is the wall's centre line, 1 m out).
const WALL_THICK := 2.0
const WALL_HEIGHT := 3.0
const GAP := 0.3
const KIT := "res://game/theme/arena_kit/generated/kit_stands.tscn"

static var _cached := PackedVector2Array()


## [(out_m, height_m)]: the wall's top, then the stands' highest point in every `step` metres of depth.
static func points(step := 2.0) -> PackedVector2Array:
	if not _cached.is_empty():
		return _cached
	var out := PackedVector2Array([Vector2(WALL_THICK, WALL_HEIGHT)])
	if not ResourceLoader.exists(KIT):
		return out
	var model := (load(KIT) as PackedScene).instantiate() as Node3D
	var tops := {}
	var z_min := INF
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var to_model := Transform3D.IDENTITY
		var current: Node = instance
		while current != null and current != model:
			if current is Node3D:
				to_model = (current as Node3D).transform * to_model
			current = current.get_parent()
		for s in instance.mesh.get_surface_count():
			for v: Vector3 in instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := to_model * v
				z_min = minf(z_min, p.z)
				var bin := int(floor(p.z / step))
				tops[bin] = maxf(float(tops.get(bin, 0.0)), p.y)
	model.free()
	var bins := tops.keys()
	bins.sort()
	var peak := 0.0
	for bin: int in bins:
		# The model's seats face -Z, toward the arena: its front (smallest z) is nearest the wall.
		var out_m := WALL_THICK + GAP + (float(bin) * step + step - z_min)
		peak = maxf(peak, float(tops[bin]))  # what hides the arena is the highest thing so far out, not each slice
		out.append(Vector2(snappedf(out_m, 0.01), snappedf(peak, 0.01)))
	_cached = out
	return out
