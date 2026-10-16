class_name PackedPlan
extends RefCounted
## Round 30 (planner P2): the planner's answer: legs the drive can execute, a code, and a line for the trace.
##
## A leg is `Vector3(gear, steer, metres)`: gear +1 forward / -1 reverse, steer in [-1, 1] (the plant's `turn`: +1 is
## full lock to the RIGHT, the hull yaws that way in either gear), metres along the arc. Today's executor drives
## `Vector2(gear, metres)` on ONE lock per plan (`Movement._kturn_start_leg`); a leg here carries its own steer, which
## is the executor change P4 names.

const OK := "OK"
const NO_PATH := "NO_PATH"            # the search emptied its open list inside the window: nothing reaches the pose
const BUDGET := "BUDGET"              # the expansion budget ran out first (a bigger budget might find one)
const START_BLOCKED := "START_BLOCKED"  # the start pose overlaps another hull (the k-turn's own wall rule is lenient)
const GOAL_BLOCKED := "GOAL_BLOCKED"  # the goal pose is not clear: nothing could end there
const ALREADY_THERE := "ALREADY_THERE"

var code := NO_PATH
var legs: Array[Vector3] = []
var why := ""
var expansions := 0
## Round 32: each search's [expansions, how it ended] ("pop" / "empty"; empty for an answer at begin): the no-library
## session answers on the call the C++ session would (Planner.emulate_step).
var search_ends: Array = []
var cost_s := 0.0
## The throttles the legs are planned for (PlanRequest's; the executor drives them).
var throttle_fwd := 0.7
var throttle_rev := 0.7
var metres := 0.0
var cusps := 0
var end_x := 0.0
var end_z := 0.0
var end_fx := 0.0
var end_fz := -1.0
## Every pose along the plan at the search's sub-step, as [x, z, fx, fz, gear] (the lab and the tests draw and check these).
var poses: Array = []


func ok() -> bool:
	return code == OK or code == ALREADY_THERE


## The legs as a short string: "F1.0x6.5 R-1.0x4.0 F1.0x3.5" (gear, steer, metres).
func describe() -> String:
	var parts: PackedStringArray = []
	for leg in legs:
		parts.append("%s%s%.1fx%.1f" % ["F" if leg.x > 0.0 else "R", "" if leg.y < 0.0 else "+", leg.y, leg.z])
	return " ".join(parts)


## The plan drawn on its world at one metre per character: `#` wall, `H` another hull, `>` forward pose, `<` reverse
## pose, `S` start, `G` goal; rows are z increasing downward (south), columns x increasing (east).
func ascii(world: PlannerWorld, x0: float, z0: float, x1: float, z1: float, start_x: float, start_z: float, goal_x: float, goal_z: float) -> String:
	var cols := int(ceil(x1 - x0))
	var rows := int(ceil(z1 - z0))
	var grid: Array = []
	for r in rows:
		var row := PackedStringArray()
		for c in cols:
			var x := x0 + float(c) + 0.5
			var z := z0 + float(r) + 0.5
			var ch := "."
			if world != null and world.is_wall(x, z):
				ch = "#"
			elif world != null and world.is_hull(x, z):
				ch = "H"
			row.append(ch)
		grid.append(row)
	for pose: Array in poses:
		var c := int(floor(float(pose[0]) - x0))
		var r := int(floor(float(pose[1]) - z0))
		if c >= 0 and c < cols and r >= 0 and r < rows:
			(grid[r] as PackedStringArray)[c] = ">" if int(pose[4]) > 0 else "<"
	var marks := [[start_x, start_z, "S"], [goal_x, goal_z, "G"]]
	for mark: Array in marks:
		var c := int(floor(float(mark[0]) - x0))
		var r := int(floor(float(mark[1]) - z0))
		if c >= 0 and c < cols and r >= 0 and r < rows:
			(grid[r] as PackedStringArray)[c] = String(mark[2])
	var lines: PackedStringArray = []
	for r in rows:
		lines.append("".join(grid[r]))
	return "\n".join(lines)
