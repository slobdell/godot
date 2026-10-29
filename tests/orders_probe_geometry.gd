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
## The reach click's footprint that must be dry (a squad's leader and inner ring).
const DRY_CLICK_M := 12.0

var _starts_mode := ""
var _reach := -1.0
var _geometry_d := Vector3.ZERO
var _geometry_ground: Tank = null
var _geometry_map := ""


## On the order's tick, right after it: the squads' starts re-read where they stood AT the click (the hold task drifts a crew a
## metre between the placing and the click, and the layout reads the squads on the order's tick), the approach as the layout
## reads it (the click less the squads' centroid), then the run's geometry line (R44.13: the road from the click to the squads'
## START centroid, recorded once a run; the clear ground across that approach at the click). Nothing has moved yet on this tick.
func _after_order(units: Array) -> void:
	super(units)
	for squad: Dictionary in _squads:
		squad["start"] = _centre(squad["units"])
	var click := _click
	var ground := _geometry_ground
	var map := _geometry_map
	var centroid_d := Vector3.ZERO
	for squad: Dictionary in _squads:
		centroid_d += (squad["start"] as Vector3) / _squads.size()
	var d := Vector3(click.x - centroid_d.x, 0.0, click.z - centroid_d.z)
	d = d.normalized() if d.length() > 2.0 else _geometry_d
	var across := Vector3(-d.z, 0.0, d.x)
	# R44.9 (fit first): the clear ground across the approach at the click, as the layout reads it (RtsControls.gate_width, the
	# group scan), and the widest squad: the judge's "front the ground fits" is read from these.
	var clear: Array = [0.0, 0.0]
	var widest := 0.0
	# R44.13: the road = the navmesh drive from the click to the army's START centroid (the squads as they stand at the click,
	# identical in both arms, recorded once a run; no layout moves it): the judge reads slide off it.
	var road: Array = []
	var centroid := Vector3.ZERO
	for squad: Dictionary in _squads:
		centroid += (squad["start"] as Vector3) / _squads.size()
	if ground != null:
		var drive := SelectionSquads.drive_on(ground)
		var crosses := SelectionSquads.crosses_or_edge(SelectionSquads.crosses_on(ground))
		clear = RtsControls.gate_width(click, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)
		for p: Vector3 in Pathing.find_path(ground, click, Vector3(centroid.x, 0.0, centroid.z)):
			road.append(_xz(p))
	for squad: Dictionary in _squads:
		widest = maxf(widest, _controls._squad_width(squad))
	# G2 (round 45): per squad, whether its place is across a gap from the click as the guard reads it (water, a pit, a deck's
	# mouth, a wet straight leg, through a neck); the guard's counters (this run's one order: the process's totals) and its
	# last lay's fit and reach (the farthest seat of the fitted body from the click), for Bar G2's lines.
	var across_gap: Array = []
	for squad: Dictionary in _squads:
		var anchor: Variant = squad.get("anchor")
		across_gap.append(SelectionSquads.guard_across_gap(click, anchor, d) if anchor is Vector3 else false)
	print("ORDERS_GEOMETRY " + JSON.stringify({"map": map, "seed": int(_flag("seed", "34")), "arm": _flag("probe-arm", ""),
			"starts": _starts_mode, "reach": _reach, "click": _xz(click), "approach": [snappedf(d.x, 0.001), snappedf(d.z, 0.001)],
			"clear": [snappedf(float(clear[0]), 0.1), snappedf(float(clear[1]), 0.1)], "widest": snappedf(widest, 0.1), "road": road,
			"squads": _squads.map(func(s: Dictionary) -> Array: return _xz(s["start"])),
			"across_gap": across_gap, "guard": {"on": SelectionSquads.GROUP_GUARD, "relaid": SelectionSquads.guard_relaid,
			"held": SelectionSquads.guard_held, "unlaid": SelectionSquads.guard_unlaid, "fit_capped": SelectionSquads.guard_fit_capped,
			"restored": SelectionSquads.guard_restored,
			"fit": SelectionSquads.guard_last_fit, "reach_m": snappedf(SelectionSquads.guard_last_reach_m, 0.1)}}))


func _pick_click(map: String, army: Vector3, forward: Vector3) -> Vector3:
	var target := super(map, army, forward)
	_starts_mode = _flag("probe-starts", "spawn")
	_reach = float(_flag("probe-reach", "-1")) if _flag("probe-reach", "-1") != "" else -1.0
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
		# A click he would give lands on ground, not at a river's edge: pulled back along the approach, 4 m at a time, until a
		# hull's footprint there is dry and off any deck (dev read 6: the reach-80 click on Crossing sat 2 m from the water).
		var pulled := 0.0
		while SelectionSquads.wet_or_deck(click, DRY_CLICK_M) and pulled < 60.0:
			click = Vector3(click.x, 0.0, click.z) - d * 4.0
			if ground != null:
				click = SlotGround.standable(ground, click)
			click = Vector3(click.x, 0.0, click.z)
			pulled += 4.0
	_geometry_d = d
	_geometry_ground = ground
	_geometry_map = map
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
