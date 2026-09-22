extends TestCase
## Contract R5 (round 10, feel): THE TURRET MOUNT. The lead: *"The turret placement on our vehicles is wrong (at least
## with the condemned and the gangs)."* `tank.tscn` put `Turret` at (0, 1.22, +0.2) and `_apply_hull_size` wrote only
## its height, so every hull from 2.9 m to 14 m carried its turret in the same place.
##
## `turret_mount: [x, y, z]` is in the Tank node's own frame: x right, y up, **+z toward the REAR** (Godot's forward is
## −Z, trip-up 2; `tank.tscn`'s +0.2 was always 0.2 m aft of centre). Two parts of it land in two places, because the
## `Turret` node is simulation, not decoration (`muzzle_position`, `Match`'s shell ray and friendly-fire origin and
## `Gunnery` all read it):
##   * x and z move the PIVOT, so a round leaves from under the gun that is drawn;
##   * y does NOT: the pivot stays at `muzzle_height − MUZZLE_ABOVE_PIVOT` (rounds fly flat at muzzle height and the
##     ceiling rule in test_units_scale holds), and only the turret's and weapon's ART rise to the ring. A vertical
##     offset cannot orbit when the turret yaws about +Y.
##
## Mutation-checked, both directions (recorded in the brief's Status): with the x/z write removed the "3 m aft" test
## fails at 0.2; with the lift removed the roof-ring test fails at 0.0; with the default changed the "unchanged" test
## fails.

const EPS := 0.001


func _profile(extra: Dictionary) -> Dictionary:
	var base := {"muzzle_height": 1.14}
	base.merge(extra, true)
	return base


func test_a_unit_without_a_mount_draws_where_it_does_today() -> void:
	var pose := Tank.turret_pose(_profile({}))
	assert_near((pose["pivot"] as Vector3).distance_to(Vector3(0.0, 1.14 - Tank.MUZZLE_ABOVE_PIVOT, 0.2)), 0.0, EPS,
			"no turret_mount: the pivot is today's (0, muzzle − 0.05, +0.2), got %s" % pose["pivot"])
	assert_near(float(pose["lift"]), 0.0, EPS, "and the art sits on the pivot")


func test_a_unit_with_a_mount_three_metres_aft_draws_its_turret_three_metres_aft() -> void:
	var pose := Tank.turret_pose(_profile({"turret_mount": [0.0, 1.09, 3.0]}))
	assert_near((pose["pivot"] as Vector3).z, 3.0, EPS, "z is written: 3 m aft")
	var sideways := Tank.turret_pose(_profile({"turret_mount": [0.6, 1.09, 0.0]}))
	assert_near((sideways["pivot"] as Vector3).x, 0.6, EPS, "x is written too")


func test_a_roof_ring_lifts_the_art_and_leaves_the_muzzle_where_rounds_fly() -> void:
	var pose := Tank.turret_pose(_profile({"turret_mount": [0.0, 4.2, -1.0]}))
	assert_near((pose["pivot"] as Vector3).y, 1.14 - Tank.MUZZLE_ABOVE_PIVOT, EPS,
			"the pivot stays at muzzle height: rounds still fly at 1.14 m")
	assert_near(float(pose["lift"]), 4.2 - (1.14 - Tank.MUZZLE_ABOVE_PIVOT), EPS, "the art rises to the 4.2 m ring")


## The same thing through a real Tank, so the write in `_apply_hull_size` is what is tested and not only the pure
## function: the art's world height is the ring's, whatever the turret's scale is.
func test_a_spawned_tank_places_its_turret_art_at_the_mount() -> void:
	for unit_id: String in Units.PROFILES:
		var tank: Tank = (load("res://game/tank/tank.tscn") as PackedScene).instantiate()
		tank.set("unit_id", unit_id)
		tank.set("simulate", false)
		add_to_tree(tank)
		var pose := Tank.turret_pose(Units.PROFILES[unit_id])
		var pivot := pose["pivot"] as Vector3
		assert_near(tank.turret.position.distance_to(pivot), 0.0, EPS, "%s: the pivot is its pose's" % unit_id)
		var art := tank.get_node("Turret/TurretVisual") as Node3D
		var art_y := tank.to_local(art.global_position).y
		assert_near(art_y, pivot.y + float(pose["lift"]), EPS, "%s: the turret art stands at the ring" % unit_id)
		var weapon := tank.get_node("Turret/WeaponVisual") as Node3D
		assert_near(tank.to_local(weapon.global_position).y, art_y, EPS, "%s: and the weapon with it" % unit_id)
