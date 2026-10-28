extends "res://tests/orders_probe.gd"
## Round 44 (orders O3), measurement: HIS GEOMETRY. His Locks click (O2): four squads in a row ALONG the way he clicked (the
## spawn row along the north edge, the click west along it), one squad standing off the row across the approach, the click
## 20 m past the front squad on open ground. The G1 v9 probe's squads started clumped at the base and clicked into streets;
## this probe re-stands the squads just before the click:
##   `--probe-starts=along`   a row along the approach, ROW_M apart, the front squad nearest the click (his row)
##   `--probe-starts=across`  a row across the approach (side by side, perpendicular to the click), ROW_M apart
##   `--probe-starts=his`     `along` of n - 1 squads with the LAST squad stood DETACHED_M off the row, DETACHED_AHEAD_M past the front (his Guns_4)
##   `--probe-starts=spawn`   where the army layout put them (the base probe)
##   `--probe-reach=M`        the click M metres beyond the squad nearest it along the approach (his: ~20), else the probe's click
## The approach is the line from the army's centre to the probe's own click (the deck, or `--probe-click`). Crews stand in a
## small wedge round their squad's spot, each snapped to standable ground, facing the approach. The rows are the base probe's;
## ORDERS_GEOMETRY {...} adds the run's click, starts mode and reach so the judge can read spread, backward squads, the
## nearest-in-front and the off-column push from `start` / `anchor`.
const ROW_M := 30.0  # his squads' centres stood 29 m apart along the north edge
const DETACHED_M := 20.0
const DETACHED_AHEAD_M := 15.0
const CREW_ACROSS_M := 10.0
const CREW_BACK_M := 8.0

var _starts_mode := ""
var _reach := -1.0


func _pick_click(map: String, army: Vector3, forward: Vector3) -> Vector3:
	var target := super(map, army, forward)
	_starts_mode = _flag("probe-starts", "spawn")
	_reach = float(_flag("probe-reach", "-1"))
	var d := Vector3(target.x - army.x, 0.0, target.z - army.z)
	if d.length() < 1.0:
		d = Vector3(forward.x, 0.0, forward.z)
	d = d.normalized()
	var across := Vector3(-d.z, 0.0, d.x)
	var ground: Tank = null
	for squad: Dictionary in _squads:
		ground = _tank(String(squad["units"][0]))
		if ground != null:
			break
	if _starts_mode != "spawn":
		var n := _squads.size()
		for i in n:
			var spot := army
			# The army spawns at its edge, so a row along the approach runs from the army's centre TOWARD the click (the rear
			# squad where the army stands, the front squad (n - 1) x ROW_M on); `--probe-reach` then puts the click past the front.
			match _starts_mode:
				"across":
					spot = army + across * ((i - (n - 1) * 0.5) * ROW_M)
				"along":
					spot = army + d * ((n - 1 - i) * ROW_M)
				"his":
					if i == n - 1:
						spot = army + d * ((n - 2) * ROW_M + DETACHED_AHEAD_M) + across * DETACHED_M  # his Guns_4: just ahead of the front squad, off the row
					else:
						spot = army + d * ((n - 2 - i) * ROW_M)
			_stand(_squads[i], spot, d, across, ground)
	var front := -INF
	for squad: Dictionary in _squads:
		squad["start"] = _centre(squad["units"])
		front = maxf(front, (squad["start"] as Vector3 - army).dot(d))
	var click := target
	if _reach >= 0.0:
		click = Orders.clamp_to_arena(army + d * (front + _reach))
		if ground != null:
			click = SlotGround.standable(ground, click)
		click = Vector3(click.x, 0.0, click.z)
	print("ORDERS_GEOMETRY " + JSON.stringify({"map": map, "seed": int(_flag("seed", "34")), "arm": _flag("probe-arm", ""),
			"starts": _starts_mode, "reach": _reach, "click": _xz(click), "approach": [snappedf(d.x, 0.001), snappedf(d.z, 0.001)],
			"squads": _squads.map(func(s: Dictionary) -> Array: return _xz(s["start"]))}))
	return click


## Stand `squad`'s crews in a small wedge round `spot`, facing `d`, each on standable ground.
func _stand(squad: Dictionary, spot: Vector3, d: Vector3, across: Vector3, ground: Tank) -> void:
	var units: Array = squad["units"]
	var yaw := atan2(-d.x, -d.z)
	for k in units.size():
		var t := _tank(String(units[k]))
		if t == null:
			continue
		var right := (k - (units.size() - 1) * 0.5) * CREW_ACROSS_M
		var back := absf(k - (units.size() - 1) * 0.5) * CREW_BACK_M
		var p := Orders.clamp_to_arena(spot + across * right - d * back)
		if ground != null:
			p = SlotGround.standable(ground, p)
		t.place(Vector3(p.x, t.global_position.y, p.z), yaw)
