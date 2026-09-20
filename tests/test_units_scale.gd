extends TestCase
## Contract S1 (scale, round 9): THE ROSTER AT REAL RELATIVE SCALE. The lead, after playing the resized War Rig:
## *"We resized the semi trucks for the gang and this makes the game much cooler and awesome. We need to do
## proportional, real-world relative sizing for all of our vehicles."*
##
## What these guard, in one line each: every hull's LENGTH is its reference vehicle's real length times one world
## factor; that factor is DERIVED from the War Rig's reference rather than typed; and every hull's BOX is what the
## approved art actually draws at that length. Nothing here asserts a size directly -- an assertion that repeated a
## number from `units.gd` would pass for the same reason the number was wrong (Invariant 0).
##
## The "before", recorded on `f49aa08a`'s numbers so the treatment is known to be distinguishable (lesson 147):
## `test_every_hull_is_its_reference_length_times_k` failed for **21 of 21** units and
## `test_every_drawn_hull_fills_its_box` for **19 of 19** with art, by up to 106% on an axis.

const LENGTH_TOLERANCE_M := 0.01
## The drawn-vs-box tolerance feel used for the War Rig in round 8. It is loose because a hull whose gun was baked
## into the mesh (FactionArt.GUN_CUTS) gives that gun to a pivot of its own, and the pivot is excluded here while
## `SizeLook.natural_size` measured the model with it still attached.
const DRAWN_TOLERANCE := 0.05


func test_scale_k_is_derived_from_the_war_rigs_reference() -> void:
	var reference: Dictionary = Units.PROFILES[Units.RIG_UNIT]["scale_reference"]
	assert_true(is_finite(Units.SCALE_K), "SCALE_K is a number (NAN means the rig lost its reference)")
	assert_near(Units.SCALE_K, Units.RIG_LENGTH_M / float(reference["length_m"]), 1e-9,
			"SCALE_K is the ruled rig length over its reference vehicle's real length")
	assert_near(float(Units.PROFILES[Units.RIG_UNIT]["hull_size"][2]), Units.RIG_LENGTH_M, LENGTH_TOLERANCE_M,
			"the anchor itself is at the length the lead ruled (14.0 m)")
	# Mutation check, the direction that matters: if the derivation ever stopped reading the rig's reference, every
	# other unit's length would still look right while meaning nothing. Move the reference and K must move with it.
	# (PROFILES is a const and therefore read-only, which is why `_derive_scale_k` takes the rig as a parameter.)
	var doubled := {"scale_reference": {"length_m": float(reference["length_m"]) * 2.0}}
	assert_near(Units._derive_scale_k(doubled), Units.SCALE_K / 2.0, 1e-9,
			"K is read from the rig's reference, not remembered")
	# The other direction -- a reference that is renamed or removed -- must NOT quietly produce a plausible K. It is
	# checked where it can be checked without an engine error in the middle of a passing suite: `Units` push_errors
	# and returns NAN (every derived length then fails loudly), `tools/roster_scale.py` raises, and
	# `test_every_unit_carries_a_reference_vehicle` above goes red the moment the key is gone.


func test_every_unit_carries_a_reference_vehicle() -> void:
	for unit_id: String in Units.PROFILES:
		var reference: Variant = Units.PROFILES[unit_id].get("scale_reference")
		assert_true(reference is Dictionary, "%s says which real vehicle it is drawn as" % unit_id)
		for key in ["vehicle", "length_m", "source"]:
			assert_true((reference as Dictionary).has(key), "%s's scale_reference has %s" % [unit_id, key])
		assert_true(float(reference["length_m"]) > 0.0, "%s's reference has a real length" % unit_id)


func test_every_hull_is_its_reference_length_times_k() -> void:
	for unit_id: String in Units.PROFILES:
		var wanted := Units.target_length_m(unit_id)
		assert_near(float(Units.PROFILES[unit_id]["hull_size"][2]), wanted, LENGTH_TOLERANCE_M,
				"%s is %.2f m x K = %.2f m" % [unit_id, float(Units.PROFILES[unit_id]["scale_reference"]["length_m"]), wanted])


## feel's round-8 finding, made roster-wide and permanent: every art unit's box was more than 5% away from its own
## mesh on some axis. The box is now the mesh's proportions at the derived length BY CONSTRUCTION, so this is the
## assertion that keeps it so -- and it is written against `SizeLook.box_at_length`, the function that produced the
## numbers, so editing a box by hand fails here rather than in a playtest.
func test_every_box_is_its_meshs_proportions_at_that_length() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	for unit_id: String in Units.PROFILES:
		if SizeLook.natural_size(unit_id).z <= 0.01:
			continue
		var box: Array = Units.PROFILES[unit_id]["hull_size"]
		var mesh: Array = SizeLook.box_at_length(unit_id, float(box[2]))
		for axis in 3:
			assert_near(float(box[axis]), float(mesh[axis]), 0.011,
					"%s axis %d: catalog %s, the mesh at %.2f m %s" % [unit_id, axis, box, float(box[2]), mesh])
	GameTheme.use(previous)


## The two units with no `unit.<id>.hull` art of their own wear the shared dozer, which Tank stretches to their box
## on every axis, so they take a LENGTH from the rule and keep the width and height the catalog already had.
## Pinned by name in both directions: a unit that gains art must take its proportions from that art, and a unit that
## silently LOSES its art must not keep a box nothing draws.
func test_only_the_two_known_units_have_no_art_of_their_own() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var without: Array = []
	for unit_id: String in Units.PROFILES:
		if SizeLook.natural_size(unit_id).z <= 0.01:
			without.append(unit_id)
	GameTheme.use(previous)
	without.sort()
	assert_eq(without, ["burner", "tank"], "the roster's units without hull art of their own")


## Rounds fly flat at muzzle height and the ceiling is MUZZLE_CLEARANCE under the SHORTEST hull in the catalog, so
## the resize moved it: the Rat Rod's box is now its mesh's 1.24 m instead of a hand-held 1.40 m floor. This says the
## same thing `test_every_muzzle_clears_under_every_hull_top` does, from the other end -- that the ceiling is real
## and something is actually against it, so the check cannot pass by everything being comfortably low (a guard that
## cannot go red is decoration).
func test_the_muzzle_ceiling_is_the_shortest_hull_and_something_reaches_it() -> void:
	var lowest_top := INF
	var highest_muzzle := 0.0
	for unit_id: String in Units.PROFILES:
		lowest_top = minf(lowest_top, float(Units.PROFILES[unit_id]["hull_size"][1]))
		highest_muzzle = maxf(highest_muzzle, float(Units.PROFILES[unit_id]["muzzle_height"]))
	assert_near(highest_muzzle, lowest_top - Units.MUZZLE_CLEARANCE, 0.011,
			"the tallest muzzle sits exactly at the ceiling the shortest hull (%.2f m) allows" % lowest_top)


## The whole point of the round, as one assertion: a semi has to look like a semi next to a car.
func test_the_roster_reads_as_vehicles_of_different_kinds() -> void:
	var lengths := {}
	for unit_id: String in Units.PROFILES:
		lengths[unit_id] = float(Units.PROFILES[unit_id]["hull_size"][2])
	for faction: String in Units.FACTIONS:
		var by_role := {}
		for unit_id in Units.roster(faction):
			by_role[Units.role_of(unit_id)] = unit_id
		assert_true(by_role.has("scout") and by_role.has("tank"), "%s fields a scout and a tank" % faction)
		var scout := float(lengths[by_role["scout"]])
		var tank := float(lengths[by_role["tank"]])
		assert_true(scout < tank, "%s: the scout (%.2f m) is shorter than the tank (%.2f m)" % [faction, scout, tank])
	assert_true(float(lengths["gang_tank"]) / float(lengths["gang_scout"]) > 4.0,
			"the War Rig is more than four Rat Rods long (%.2f / %.2f)" % [lengths["gang_tank"], lengths["gang_scout"]])


# ------------------------------------------------------------------------------------------------------------------
# The two mirrors `Tank._apply_hull_size` used to carry (round 9, scale). Both were the kind that fail WITHOUT a
# symptom, so both get a test that can only pass by reading the real source -- and each is mutation-checked by
# moving that source and watching the answer move (Invariant 0: check the reader in both directions).
# ------------------------------------------------------------------------------------------------------------------

func _spawn(unit_id: String) -> Node3D:
	var tank: Node3D = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	add_to_tree(tank)
	return tank


func _collider(tank: Node3D) -> Vector3:
	return ((tank.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size


## MIRROR 1. `_apply_hull_size` used to return early whenever a unit's box equalled `Units.PROFILES[DEFAULT]`'s,
## which is the Condemned tank's own entry -- so that unit alone kept tank.tscn's authored BoxShape3D (2.4 x 1.6 x
## 3.6) while the catalog said 2.4 x 2.4 x 3.6, and had since round 2. The scene WON, silently, for the one unit
## `sim-baseline` fields. Nothing about a box equalling another box may skip the catalog again.
func test_the_default_units_collider_comes_from_the_catalog_not_from_the_scene() -> void:
	var catalog: Array = Units.stat(Units.DEFAULT, "hull_size")
	var box := _collider(_spawn(Units.DEFAULT))
	assert_near(box.x, float(catalog[0]), 0.011, "%s's collider width is the catalog's" % Units.DEFAULT)
	assert_near(box.y, float(catalog[1]), 0.011, "%s's collider HEIGHT is the catalog's, not tank.tscn's" % Units.DEFAULT)
	assert_near(box.z, float(catalog[2]), 0.011, "%s's collider length is the catalog's" % Units.DEFAULT)
	# Mutation check: move the catalog entry and the collider must move with it. Without this the assertion above
	# would also pass on a build that happened to author the same box in the scene -- green by coincidence.
	Units.tuning[Units.DEFAULT + ".hull_size"] = [3.0, 1.9, 9.5]
	var moved := _collider(_spawn(Units.DEFAULT))
	Units.tuning.erase(Units.DEFAULT + ".hull_size")
	assert_near(moved.y, 1.9, 0.011, "the collider follows the catalog (height)")
	assert_near(moved.z, 9.5, 0.011, "the collider follows the catalog (length)")
	# And the same box on a DIFFERENT unit, which is the shape the old early return actually keyed on.
	Units.tuning["burner.hull_size"] = catalog.duplicate()
	var twin := _collider(_spawn("burner"))
	Units.tuning.erase("burner.hull_size")
	assert_near(twin.y, float(catalog[1]), 0.011,
			"a unit whose box equals the DEFAULT profile's still gets that box as its collider")


## MIRROR 2. The shared hull art (`tank.hull`, worn by every unit with no `unit.<id>.hull` of its own) was fitted
## against the DEFAULT UNIT'S CATALOG BOX on the unwritten assumption that the two were equal. They never were --
## the mesh is 2.18 x 2.30 x 3.85 against a 2.4 x 2.4 x 3.6 entry -- and the moment the Condemned tank stopped being
## 3.6 m long, every unit wearing that art would have been drawn at the wrong size in silence. It now fits to the
## mesh, so `hull_size` is what is DRAWN for these units too.
func test_a_unit_wearing_the_shared_hull_art_is_drawn_at_its_own_box() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var shared := Tank.shared_hull_size()
	assert_true(shared.z > 0.01, "the shared hull art measures as something (%s)" % shared)
	assert_true(absf(shared.z - float(Units.PROFILES[Units.DEFAULT]["hull_size"][2])) > 0.05,
			"and it is NOT the DEFAULT unit's catalog length -- which is why assuming they were equal was a mirror")
	for box: Array in [[2.4, 2.4, 6.89], [3.1, 2.0, 11.0]]:
		Units.tuning["burner.hull_size"] = box
		var tank := _spawn("burner")
		await wait_physics_frames(2)
		var drawn: Vector3 = (tank.get_node("HullVisual") as Node3D).scale * shared
		Units.tuning.erase("burner.hull_size")
		for axis in 3:
			assert_near(drawn[axis], float(box[axis]), 0.02,
					"a shared-art hull is drawn at its box on axis %d (box %s, drew %s)" % [axis, box, drawn])
	GameTheme.use(previous)
