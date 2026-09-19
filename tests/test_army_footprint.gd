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


func _army_of(archetype: String, faction: String, arena_name := "") -> Match:
	var arena_node := ARENA.instantiate() as Node3D
	if arena_name != "":
		arena_node.set("layout_name", arena_name)
	var arena: Node3D = add_to_tree(arena_node)
	# Round 8 (squad): deploy with the navigation mesh baked, as the game does, so SlotGround really pushes slots off
	# obstacles — that push is where two hulls were landing on the same spot.
	for frame in 600:
		if Pathing.is_ready(arena):
			break
		await wait_physics_frames(1)
	assert_true(Pathing.is_ready(arena), "setup: the arena's navigation is baked before the army deploys")
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
				var other := ""
				for b in tanks:
					if a != b and absf(a.global_position.distance_to(b.global_position) - nearest) < 0.001:
						other = "%s/%s at %s" % [b.name, game_match.squad_of(b), b.global_position.snapped(Vector3.ONE * 0.1)]
				worst_pair = "%s (%.1f m long) had %.1f m to its nearest neighbour [%s/%s at %s vs %s]" % [a.unit_id, size[2],
						nearest, a.name, game_match.squad_of(a), a.global_position.snapped(Vector3.ONE * 0.1), other]
	# The defect itself: two hull boxes (everyone faces the same way at the start) that overlap.
	var overlaps := 0
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			var sa: Array = Units.stat(tanks[i].unit_id, "hull_size")
			var sb: Array = Units.stat(tanks[j].unit_id, "hull_size")
			var d := tanks[i].global_position - tanks[j].global_position
			var local := Vector2(d.dot(tanks[i].global_basis.x), d.dot(tanks[i].global_basis.z))
			if absf(local.x) < (float(sa[0]) + float(sb[0])) * 0.5 and absf(local.y) < (float(sa[2]) + float(sb[2])) * 0.5:
				overlaps += 1
	gaps.sort()
	return {"count": tanks.size(), "overlaps": overlaps, "min": gaps[0] if gaps.size() > 0 else 0.0,
			"median": gaps[gaps.size() / 2] if gaps.size() > 0 else 0.0,
			"worst_clearance": worst, "worst_pair": worst_pair}


func _report(archetype: String, faction: String, arena_name := "") -> Dictionary:
	var game_match: Match = await _army_of(archetype, faction, arena_name)
	await wait_physics_frames(2)
	var m := _closest(game_match)
	print("MEASURE army_footprint %s%s: %d vehicles, %d overlapping hull pairs, nearest neighbour min %.1f m, median %.1f m; tightest: %s"
			% [archetype, " on " + arena_name if arena_name != "" else "", m["count"], m["overlaps"], m["min"], m["median"], m["worst_pair"]])
	return m


## Round 8: this file is combat's measurement (stream/combat 286f8b1c), landed on squad's tree with the bars. Its first
## finding (gang_ram min 0.2 m) was measured on a tree before squad's f1c3afcb (hull-length spacing) and is stale; on
## squad 90bd2212+ (laptop, navmesh baked) every large army deploys with 0 overlapping hulls, min 3.7-4.6 m.
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


func _assert_clear(archetype: String, faction: String) -> void:
	var m := await _report(archetype, faction)
	assert_true(m["count"] > 20, "setup: a large army (%d vehicles)" % m["count"])
	assert_eq(int(m["overlaps"]), 0, "%s: no two hulls stand inside each other at the start" % archetype)
	assert_true(m["min"] >= 1.4,
			"%s: no two vehicles may be closer than half the shortest hull in the game (min %.1f m): %s"
			% [archetype, m["min"], m["worst_pair"]])


## combat's bar (round 8), landed with the fix: it fails on OVERLAP and asserts no spacing policy.
func test_a_gang_ram_army_stands_clear() -> void:
	await _assert_clear("gang_ram", "gangs")


func test_a_gang_pack_army_stands_clear() -> void:
	await _assert_clear("gang_pack", "gangs")


func test_a_law_line_army_stands_clear() -> void:
	await _assert_clear("law_line", "law")

