extends SceneTree
## Round 9, squad X2/X3: the defile passage and co-arrival measurement A8 and A9 are judged by.
##
## An element is ordered across THE MAZE (`arenas/maze.json`: eight container bands with staggered gaps 7-12 m wide,
## the nav test fixture) and every tick is sampled. It reports, per run:
##
##   crossings          pairs of units that swapped sides while abreast -- A8's falsifier, in a real match
##   inversions         pairs whose order ALONG the heading reversed -- the other half of it
##   recovery_s         seconds from clearing the last gap until every member is back inside its slot's tolerance
##   gaps               how many bands the element got through (a run that never reaches a defile measures nothing)
##   dispersion_s       spread of arrival times at the objective line -- A9's falsifier
##   stationary_min     the smallest share of the element that was stationary on any tick of a bounding phase
##   off_slot_p90_m     how far off its slot the element's members were, 90th percentile
##
## TWO ARMS, ALWAYS, and the control is a LOCOMOTION control rather than a faction one (metrics' CP1 finding: the
## shuffle is a property of wheels, not of weight, so a tracked-only measurement would flatter A8):
##
##   --arm=wheeled   five Condemned wheeled hulls (ifv, lancer, artillery, burner, scout)
##   --arm=tracked   five Condemned `tank` -- the SAME faction and the same doctrine table, so the only thing that
##                   differs between the arms is the plant
##
## `--deform=off` turns A8 off (`TacticsFormation.DEFORM_ENABLED`) so the A/B isolates the deformation rather than the
## tree, and `--technique=bounding_overwatch` forces the movement technique through a lab doctrine table — without it
## the table picks `traveling` for an empty map and A9's phase machine never runs, so `stationary_min` reads -1.
##
## `--formation=` FORCES THE SHAPE, and it has to, for a reason the first run of this probe found: left to the shipped
## table the element goes through the maze in a COLUMN, and a column has zero frontage, so A8 correctly does nothing
## (`fit_to_corridor` returns the identity when `natural <= 0`). **The doctrine table already solves a defile
## discretely, by picking a column for close terrain.** What A8 is for is the case where the element is in a shape
## that HAS frontage — a player-ordered wedge, or an element in contact holding a line — and must narrow without
## dissolving. So the default here is `wedge`, and the report carries the formation and its natural frontage so no
## number can be read without knowing which case it came from.
##
## `--tube=on` turns A1's brain-half state-error tube on (`TankBrain.TUBE_ENABLED`) and the report carries
## `redecides` and `skips` summed over the element's brains, so the flip is gated on a counted before/after in the
## layer the tube actually lives in. nav's A1 split counts ROUTE re-plans in `Movement._next_waypoint`; this counts
## BRAIN re-decides. Different layers, different populations — nav's sliding-goal fix does not touch this one, which is
## why its number cannot gate this flag.
##
##   DEFILE_PROBE {"arm": ..., "deform": ..., "seed": ..., "crossings": ..., ...}

## The maze band the element is sent through, and the gap in it. Band z = 10, containers at x = -44 and -22, so the
## drivable gap is centred on -33 and about 11 m wide. Start and finish are in the open ground either side of it,
## clear of the neighbouring bands at z = 30 and z = -10.
const GAP_X := -33.0
const START_Z := 26.0
const FINISH_Z := -4.0
## Two units count as ABREAST when their separation along the heading is under this (metres): a crossing is a pair
## that swapped sides while level with each other, which is the pair that would actually have collided.
const ABREAST_M := 6.0
## A member is back in formation within this many metres of its slot; recovery is when every member is.
const RECOVERED_M := 8.0
## Sampling: every tick is read, but a pair's order has to hold for this many samples before a flip counts, so a
## single tick of jitter across the line is not a crossing.
const FLIP_HOLD := 6

## The wheeled arm and the tracked control, both Condemned so the doctrine table and the faction are held fixed.
const ARMS := {
	"wheeled": ["ifv", "lancer", "artillery", "burner", "scout"],
	"tracked": ["tank", "tank", "tank", "tank", "tank"],
}


var case: TestCase


func _initialize() -> void:
	_run_probe.call_deferred()


func _run_probe() -> void:
	var arm := _flag("arm", "wheeled")
	var deform := _flag("deform", "on") != "off"
	var seed_value := int(_flag("seed", "3"))
	var seconds := float(_flag("seconds", "40"))
	var technique := _flag("technique", "")
	var formation := _flag("formation", "wedge")
	TankBrain.TUBE_ENABLED = _flag("tube", "off") == "on"
	if not ARMS.has(arm):
		print("DEFILE_PROBE_ERROR unknown arm %s (have %s)" % [arm, ARMS.keys()])
		quit(1)
		return
	TacticsFormation.DEFORM_ENABLED = deform
	case = TestCase.new()
	case.tree = self
	var report := await _run(arm, deform, seed_value, seconds, technique, formation)
	print("DEFILE_PROBE " + JSON.stringify(report))
	print("DEFILE_PROBE_DONE")
	case.teardown()
	quit(0)


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run(arm: String, deform: bool, seed_value: int, seconds: float, technique: String,
		formation: String) -> Dictionary:
	# TacticsLab is the proven harness: the real arena and Match, brain tanks under a doctrine table, seeded and
	# ordered by unit name. It also waits for THIS arena's navmesh rather than a previous test's (lesson 36), which
	# matters here more than anywhere: a corridor measured off the wrong navmesh is worse than no corridor.
	var lab := TacticsLab.create(case, seed_value, "maze")
	var game_match := lab.game_match
	var names: Array = []
	var ids: Array = ARMS[arm]
	for i in ids.size():
		# A column in the open ground north of the band, already lined up on the gap: the element's own formation
		# decision is what is being measured, not its ability to find the gap from the far side of the map.
		var tank := lab.unit(Match.Team.GREEN, "Green_D_%d" % (i + 1),
				Vector3(GAP_X, 0.0, START_Z + 10.0 + i * 8.0), PI, String(ids[i]))
		names.append(String(tank.name))
	# A lab table that forces the shape and the technique. Both matter: the shipped table picks a COLUMN for the
	# maze's close terrain (nothing for A8 to squeeze) and `traveling` on an empty map (nothing for A9 to phase).
	var table := TacticsLab.table_of(formation, technique if technique != "" else "traveling")
	var element := lab.element(names, "Delta", table)
	await lab.start()
	# NOT `"drills": false`, and that distinction is load-bearing. A task with drills off takes `_plan_form_up` — the
	# plain-move path, whose slots are the FINAL formation standing at the destination rather than a transit shape —
	# and that path sets `corridor_m` to INF on purpose, so A8 never engages. The first run of this probe reported
	# `file 0` for exactly that reason, with a 5 m corridor measured and a 28.8 m wedge frontage sitting in it. With
	# drills on the task runs the leg-based movement A8 deforms. There are no enemies on the map, so no drill fires
	# and the traverse is still clean.
	element.assign({"verb": "move", "to": [GAP_X, FINISH_Z]})

	var samples := {}          # pair key -> {"side": int, "order": int, "side_hold": int, "order_hold": int}
	var crossings := {}
	var inversions := {}
	var arrived := {}
	var off_slot: Array = []
	var stationary_min := 1.0
	var bounding_ticks := 0
	var gaps := 0
	var was_north := true
	var cleared_tick := -1
	var recovered_tick := -1
	# The NARROWEST corridor the element passed through and the FURTHEST it filed, not the values it happens to hold
	# at the end. The first run of this probe reported `corridor_m -1` and `file 0` for a passage that demonstrably
	# went through an 11 m gap (`gaps 1`), because by the last tick the element was past the band with open ground
	# ahead: it was reading the end state and calling it the passage.
	var narrowest := INF
	var filed := 0.0
	var ticks := int(seconds * SimClock.TICK_RATE)
	for tick in ticks:
		await lab.step()
		var at := {}
		for unit_name: String in names:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				at[unit_name] = Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		if at.size() < 2:
			break
		var heading: Vector3 = TacticsFormation.flat(element.heading)
		var right := Vector3(-heading.z, 0.0, heading.x)
		# Crossings and inversions, held for FLIP_HOLD samples so a tick of jitter is not a crossing.
		var sorted_names: Array = at.keys()
		sorted_names.sort()
		for a in sorted_names.size():
			for b in range(a + 1, sorted_names.size()):
				var key := "%s|%s" % [sorted_names[a], sorted_names[b]]
				var delta: Vector3 = (at[sorted_names[a]] as Vector3) - (at[sorted_names[b]] as Vector3)
				var side := signi(int(signf(delta.dot(right))))
				var order := signi(int(signf(delta.dot(heading))))
				var abreast: bool = absf(delta.dot(heading)) < ABREAST_M
				var seen: Dictionary = samples.get_or_add(key, {"side": side, "order": order, "hold_side": 0,
						"hold_order": 0})
				if side != 0 and side != int(seen["side"]):
					seen["hold_side"] = int(seen["hold_side"]) + 1
					if int(seen["hold_side"]) >= FLIP_HOLD:
						seen["side"] = side
						seen["hold_side"] = 0
						if abreast:
							crossings[key] = int(crossings.get(key, 0)) + 1
				else:
					seen["hold_side"] = 0
				if order != 0 and order != int(seen["order"]):
					seen["hold_order"] = int(seen["hold_order"]) + 1
					if int(seen["hold_order"]) >= FLIP_HOLD:
						seen["order"] = order
						seen["hold_order"] = 0
						inversions[key] = int(inversions.get(key, 0)) + 1
				else:
					seen["hold_order"] = 0
		# Off-slot, and when the element has recovered after the gap.
		var worst := 0.0
		for unit_name: String in at:
			var slot: Variant = element.slots.get(unit_name)
			if slot is Vector3:
				var gap_m: float = (at[unit_name] as Vector3).distance_to(slot)
				off_slot.append(gap_m)
				worst = maxf(worst, gap_m)
		# Bands are crossed when the element's centre passes z = 10 going south.
		var centre := Vector3.ZERO
		for unit_name: String in at:
			centre += at[unit_name] as Vector3
		centre /= float(at.size())
		if was_north and centre.z < 10.0:
			was_north = false
			gaps += 1
			cleared_tick = tick
		if cleared_tick >= 0 and recovered_tick < 0 and tick > cleared_tick + SimClock.TICK_RATE / 2 \
				and worst <= RECOVERED_M:
			recovered_tick = tick
		if is_finite(element.corridor_m):
			narrowest = minf(narrowest, element.corridor_m)
		filed = maxf(filed, element.file)
		# A9: the share of the element that is stationary during a bounding phase.
		var bound: Dictionary = element.bound
		if not bound.is_empty():
			bounding_ticks += 1
			stationary_min = minf(stationary_min, float(bound.get("stationary_share", 1.0)))
		# Arrival at the objective line.
		for unit_name: String in at:
			if not arrived.has(unit_name) and (at[unit_name] as Vector3).z <= FINISH_Z + 6.0:
				arrived[unit_name] = tick

	off_slot.sort()
	var report := {
		"arm": arm, "deform": "on" if deform else "off", "tube": "on" if TankBrain.TUBE_ENABLED else "off",
		"redecides": _redecides(game_match, names), "skips": _skips(game_match, names),
		"technique": technique if technique != "" else "traveling",
		"formation": element.formation, "asked_formation": formation,
		"natural_frontage_m": snappedf(TacticsFormation.frontage(element.formation, names.size(),
				element.pitch.x), 0.1),
		"seed": seed_value, "units": names.size(),
		"crossings": _total(crossings), "crossing_pairs": crossings.size(),
		"inversions": _total(inversions), "inversion_pairs": inversions.size(),
		"gaps": gaps,
		"recovery_s": snappedf((recovered_tick - cleared_tick) / float(SimClock.TICK_RATE), 0.01) \
				if recovered_tick > 0 and cleared_tick >= 0 else -1.0,
		"arrived": arrived.size(),
		"dispersion_s": snappedf(_dispersion(arrived), 0.01),
		# Per vehicle, and who was last: an aggregate dispersion tells nav a squad was strung out, a named vehicle
		# and its unit id tells it WHICH plant was late, which is what A11/A4 can act on.
		"arrivals_s": _arrivals(arrived, ids, names), "last_in": _last_in(arrived, ids, names),
		"stationary_min": snappedf(stationary_min, 0.001) if bounding_ticks > 0 else -1.0,
		"bounding_ticks": bounding_ticks,
		"off_slot_p90_m": snappedf(_percentile(off_slot, 0.9), 0.01),
		"off_slot_max_m": snappedf(off_slot[-1] if not off_slot.is_empty() else 0.0, 0.01),
		"corridor_m": snappedf(narrowest, 0.1) if is_finite(narrowest) else -1.0,
		"file": snappedf(filed, 0.001),
		"pitch_m": [snappedf(element.pitch.x, 0.01), snappedf(element.pitch.y, 0.01)],
	}
	lab.dispose()
	return report


## A1: motion decisions taken and skipped, summed over the element's own brains. A brain that never fought produces
## zeros rather than being left out, so the two arms always sum over the same population.
static func _redecides(game_match: Match, names: Array) -> int:
	return _counter(game_match, names, "redecides")


static func _skips(game_match: Match, names: Array) -> int:
	return _counter(game_match, names, "skips")


static func _counter(game_match: Match, names: Array, key: String) -> int:
	var total := 0
	for unit_name: Variant in names:
		var brain := game_match.brains.get_node_or_null("Brain_" + String(unit_name)) as TankBrain
		if brain != null:
			total += int((brain.redecide_counts() as Dictionary).get(key, 0))
	return total


static func _total(tally: Dictionary) -> int:
	var sum := 0
	for value: int in tally.values():
		sum += value
	return sum


## {unit name: "unit_id @ seconds"} for every member that arrived, plus "-" for one that never did.
static func _arrivals(arrived: Dictionary, ids: Array, names: Array) -> Dictionary:
	var result := {}
	for i in names.size():
		var unit_name := String(names[i])
		var id := String(ids[i]) if i < ids.size() else "?"
		result[unit_name] = "%s @ %s" % [id, snappedf(float(arrived[unit_name]) / SimClock.TICK_RATE, 0.01)] \
				if arrived.has(unit_name) else "%s @ never" % id
	return result


## The member that arrived last, as "name (unit_id) @ seconds", or the one that never arrived.
static func _last_in(arrived: Dictionary, ids: Array, names: Array) -> String:
	var worst := ""
	var worst_tick := -1
	for i in names.size():
		var unit_name := String(names[i])
		if not arrived.has(unit_name):
			return "%s (%s) never arrived" % [unit_name, String(ids[i]) if i < ids.size() else "?"]
		if int(arrived[unit_name]) > worst_tick:
			worst_tick = int(arrived[unit_name])
			worst = "%s (%s) @ %s s" % [unit_name, String(ids[i]) if i < ids.size() else "?",
					snappedf(float(worst_tick) / SimClock.TICK_RATE, 0.01)]
	return worst


static func _dispersion(arrived: Dictionary) -> float:
	if arrived.size() < 2:
		return -1.0
	var low := 1 << 30
	var high := -1
	for tick: int in arrived.values():
		low = mini(low, tick)
		high = maxi(high, tick)
	return (high - low) / float(SimClock.TICK_RATE)


static func _percentile(sorted_values: Array, share: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(int(floor(share * (sorted_values.size() - 1))), 0, sorted_values.size() - 1)])
