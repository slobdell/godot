extends TestCase
## Round 8: how big a vehicle is the standing army actually able to hold?
##
## The spawn grid does NOT answer this. `Match.load_doctrine` ends with `ArmyLayout.deploy`, which TELEPORTS every
## unit (`tank.global_position = ...`, `reset_physics_interpolation()`) inside the same call, at tick 0, before any
## physics step -- so a spawn slot is a holding position that is overwritten before two hulls can ever coexist in a
## simulated frame. Reasoning about `SPAWN_ROW_SPACING` gives a real number that constrains nothing anyone sees.
##
## What constrains vehicle size is the formation the army STANDS in: ArmyLayout's spacings, which are hull-agnostic
## (ASSEMBLY_SPACING_M 8.0 centre-to-centre, MIN_SPACING_M 5.0 when a rank compresses) under comments that say
## "hulls are ~4 m long". This measures the gap the layout actually leaves, so a size change is argued against the
## geometry that decides it.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _army_of(archetype: String, faction: String) -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var loaded := Army.load_army("cpu:%s" % archetype, 1, 5200, faction)
	assert_eq(String(loaded.get("error", "")), "", "%s army loads" % archetype)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, loaded["doctrine"]), "", "and deploys")
	return game_match


## Nearest neighbour, and the clearance each pair actually has once both hulls are accounted for.
func _closest(game_match: Match) -> Dictionary:
	var tanks := game_match.sorted_team_tanks(Match.Team.GREEN)
	var worst := INF
	var worst_pair := ""
	var gaps: Array[float] = []
	for a in tanks:
		var nearest := INF
		for b in tanks:
			if a == b:
				continue
			nearest = minf(nearest, a.global_position.distance_to(b.global_position))
		if nearest < INF:
			gaps.append(nearest)
			var size: Array = Units.stat(a.unit_id, "hull_size")
			# Conservative: two hulls of this length, nose to tail, need this much centre-to-centre.
			var needed := float(size[2])
			if nearest - needed < worst:
				worst = nearest - needed
				worst_pair = "%s (%.1f m long) had %.1f m to its nearest neighbour" % [a.unit_id, size[2], nearest]
	gaps.sort()
	return {"count": tanks.size(), "min": gaps[0] if gaps.size() > 0 else 0.0,
			"median": gaps[gaps.size() / 2] if gaps.size() > 0 else 0.0,
			"worst_clearance": worst, "worst_pair": worst_pair}


func _report(archetype: String, faction: String) -> Dictionary:
	var game_match := _army_of(archetype, faction)
	await wait_physics_frames(2)
	var m := _closest(game_match)
	print("MEASURE army_footprint %s: %d vehicles, nearest neighbour min %.1f m, median %.1f m; tightest: %s"
			% [archetype, m["count"], m["min"], m["median"], m["worst_pair"]])
	return m


func test_a_large_army_is_measured_even_though_the_bar_is_not_mine_to_set() -> void:
	# THE FINDING, round 8, and it has nothing to do with the semi: a gang_ram army of 41 vehicles stands with its
	# hulls INSIDE each other. Measured here: nearest neighbour 0.2 m, and a 5.0 m Resupply Tanker with 0.9 m of
	# room -- roughly four metres of interpenetration before the match starts. The small-army control below gets
	# 7.4 m from the same code, so the defect is ArmyLayout COMPRESSING a rank to fit the spawn zone
	# (MIN_SPACING_M 5.0) with no reference to hull length, not the formation geometry.
	#
	# WHY THERE IS NO ASSERTION ON THIS ARMY. The number has three owners and none of them is only me: the spacing
	# is squad's (ArmyLayout), the zone is arena's (`spawn_zones`, 150 x 32), and how many vehicles a budget buys is
	# mine (Army archetypes and Units costs). An assertion here would fail `check` for five other streams over a
	# defect I cannot fix in my own files, and verification.md is explicit that downgrading it to a warning instead
	# would be "the invisible-skip failure in another costume". So it is MEASURED here and the assertion is written
	# out in the report to squad, to land in the same commit as the fix.
	var m := await _report("gang_ram", "gangs")
	assert_true(m["count"] > 30, "the measurement ran on a large army (%d vehicles)" % m["count"])


func test_a_smaller_army_has_room() -> void:
	# The control, and it is what makes the finding above a defect rather than a fact of life: the same layout code
	# with 18 vehicles leaves 7.4 m. Nothing about the formation is wrong; the compression is.
	var m := await _report("syndicate_standoff", "syndicate")
	assert_true(m["min"] >= 1.4,
			"a small army stands clear -- no two vehicles closer than half the shortest hull in the game (min %.1f m)"
			% m["min"])
