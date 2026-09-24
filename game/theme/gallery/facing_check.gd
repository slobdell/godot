class_name FacingCheck
extends RefCounted
## Round 11 (fleet T5; the lead: "Syndicate has some backwards vehicles"). Which way a unit's DRAWN nose points, judged
## from the geometry alone -- independent of the two hand-typed tables that set it (tools/assets/build_factions.sh's
## `forward` axis and build_faction_parts.py's MODEL_YAW_DEG), which is why it can catch them.
##
## Two proxies, measured on the whole vehicle as drawn at rest (hull plus whatever turns, turret ahead), in the tank
## frame where forward is -Z (orientation.md trip-up 2):
##   taper  (rear end top - front end top) / box height: the mean top of the four 5% slices at each end. A nose is a hood,
##          a windshield, a plow or a wedge; a tail is a tailgate, a cargo box or a turret bustle.
##   mass   the mean z of every point above 60% of the box's height, / length. Vehicles carry their tall mass -- cabin,
##          turret, load -- behind the hood.
## The verdict needs BOTH: "forward" when taper > TAPER and mass > MASS, "backwards" when both are below minus those,
## and "unsure" otherwise. Unsure is not a pass: a cab-over truck with a flatbed has a tall FRONT, and those units must
## be checked by eye (tests/test_theme_unit_scale.gd keeps the list of who looked, and when).
##
## Measured when written (laptop, all 21 units): taper and mass both confidently forward on 14 units; the Syndicate IFV
## the only unit both called backwards (taper -0.19, mass -0.04) -- it was, and is turned round; the other six unsure.

const BINS := 20
const END_FRACTION := 0.2
const HIGH_FRACTION := 0.6
const TAPER := 0.1
const MASS := 0.02


## {"taper": float, "mass": float, "verdict": "forward" | "backwards" | "unsure"} for a spawned tank.
static func measure(tank: Node3D, unit_id: String) -> Dictionary:
	var parts := TurretFit.split(tank)
	var points: PackedVector3Array = parts["hull"]
	points.append_array(parts["turning"])
	var box: Array = Units.stat(unit_id, "hull_size")
	var length := float(box[2])
	var height := float(box[1])
	var tops := PackedFloat32Array()
	tops.resize(BINS)
	var high_z := 0.0
	var high := 0
	for p in points:
		var bin := clampi(int((p.z + length / 2.0) / length * BINS), 0, BINS - 1)  # 0 at the nose (-Z)
		tops[bin] = maxf(tops[bin], p.y)
		if p.y > height * HIGH_FRACTION:
			high_z += p.z
			high += 1
	# The MEAN of the end bins' tops, not their max: a barrel laid over the nose is one thin line and must not outvote
	# the hood under it.
	var ends := int(round(BINS * END_FRACTION))
	var front := 0.0
	var rear := 0.0
	for i in ends:
		front += tops[i] / ends
		rear += tops[BINS - 1 - i] / ends
	var taper := (rear - front) / maxf(height, 0.001)
	var mass := high_z / maxf(high, 1) / maxf(length, 0.001)
	var verdict := "unsure"
	if taper > TAPER and mass > MASS:
		verdict = "forward"
	elif taper < -TAPER and mass < -MASS:
		verdict = "backwards"
	return {"taper": taper, "mass": mass, "verdict": verdict}
