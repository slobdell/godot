extends TestCase
## S9 (round 16, CP2): the lead, 2026-10-02: "For the law's tracked APC if it is now a tracked vehicle it should behave
## as one." The Law's Retired APC (law_ifv, round 15's tracked model) drives on tracks: it pivots on the spot, it does
## not need speed to turn, and it does not slide -- the Condemned dozer tank's handling, the one tracked precedent.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_the_catalog_puts_the_law_apc_on_tracks() -> void:
	var unit := Units.profile("law_ifv")
	assert_eq(unit["locomotion"], "tracks", "the Retired APC is tracked")
	assert_eq(float(unit["min_turn_radius_m"]), 0.0, "a tracked hull has no turning circle (it pivots)")
	assert_eq(float(unit["lateral_grip"]), 1.0, "and no sideways slide")
	assert_eq(Units.profile("ifv")["locomotion"], "wheels", "control: the Condemned IFV is still wheeled")


func test_the_law_apc_pivots_in_place_on_open_ground() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var apc := game_match.spawn_tank("Apc", 0, Match.Team.GREEN, "law_ifv")
	apc.global_position = Vector3(-100.0, 0.0, 30.0)
	await wait_physics_frames(3)
	var start := apc.global_position
	var start_forward := -apc.global_basis.z
	for tick in SimClock.TICK_RATE:
		apc.command = TankCommand.new(0.0, 1.0, Vector3.ZERO, false)
		await tree.physics_frame
	var moved := Vector2(apc.global_position.x - start.x, apc.global_position.z - start.z).length()
	var turned := rad_to_deg(absf(start_forward.signed_angle_to(-apc.global_basis.z, Vector3.UP)))
	assert_true(moved < 0.3, "a pivot stays on its spot (%.2f m)" % moved)
	assert_true(turned > 45.0, "and turns from a standstill (%.1f deg in a second)" % turned)
