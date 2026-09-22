extends TestCase
## Arena item 4 (round 10): the spawn grid gives a hull room to TURN. What stands on the grid is the bare-spawn unit
## (`Units.DEFAULT`; a doctrine army is re-laid by `ArmyLayout.deploy()` before any physics step, which
## tests/test_spawn_grid.gd asserts). Its first turn sweeps its TURNING ENVELOPE -- the disc of its half-diagonal --
## and squad measured that two hulls dressing together sweep the full diagonal at once (tests/test_tactics_pitch.gd),
## so two bare spawns are turning-clear when their centres are at least the diagonal + TURN_MARGIN_M apart at the
## WORST jitter. The zone cannot give all SPAWN_SLOTS that (see Match.spawn_cell), so the grid fills the turning-clear
## cells FIRST: this asserts every pair among them, and that there are enough of them to matter.

## Squad's measured margin for two hulls turning together (the orchestrator's relay, 2026-09-22).
const TURN_MARGIN_M := 0.30


static func envelope_m() -> float:
	var hull: Array = Units.stat(Units.DEFAULT, "hull_size")
	return Vector2(float(hull[0]), float(hull[2])).length() + TURN_MARGIN_M


## The closest two centres can come, both jittered to their worst toward each other.
static func worst_distance(a: Vector3, b: Vector3) -> float:
	var dx := maxf(absf(a.x - b.x) - 2.0 * Match.SPAWN_JITTER_MAX_X, 0.0)
	var dz := maxf(absf(a.z - b.z) - 2.0 * Match.SPAWN_JITTER_MAX_Z, 0.0)
	return Vector2(dx, dz).length()


func test_the_first_slots_give_every_bare_spawn_room_to_turn() -> void:
	var clear := Match.turning_clear_slots()
	var previous := Arena.active
	Arena.active = {}
	var spots: Array = []
	for slot in clear:
		spots.append(Match.spawn_position(Match.Team.GREEN, slot))
	Arena.active = previous
	var need := envelope_m()
	var worst := INF
	var pair := ""
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var d := worst_distance(spots[i], spots[j])
			if d < worst:
				worst = d
				pair = "%s and %s" % [spots[i], spots[j]]
	print("MEASURE spawn_envelope %s" % JSON.stringify({"unit": Units.DEFAULT, "envelope_m": need,
			"turning_clear_slots": clear, "worst_centre_distance_m": worst, "at": pair}))
	assert_true(clear >= 20, "at least 20 bare spawns get turning room before the grid packs tighter (%d)" % clear)
	assert_true(worst >= need - 0.01, "the first %d slots are turning-clear at worst jitter: closest %.2f m (%s) against the %s's %.2f m"
			% [clear, worst, pair, Units.DEFAULT, need])


## Positive control (B12): the old row-major order puts slots 0 and 1 7.5 m apart, which is inside the envelope.
func test_row_major_neighbours_would_not_be_turning_clear() -> void:
	var a := Vector3(Match.SLOT_X[0], 0.0, Match.BASE_Z)
	var b := Vector3(Match.SLOT_X[1], 0.0, Match.BASE_Z)
	assert_true(worst_distance(a, b) < envelope_m(), "adjacent columns (%.2f m at worst jitter) cannot both turn (%.2f m)"
			% [worst_distance(a, b), envelope_m()])


func test_every_slot_is_still_a_distinct_lattice_point() -> void:
	var previous := Arena.active
	Arena.active = {}
	var seen := {}
	for slot in Match.SPAWN_SLOTS:
		var p := Match.spawn_position(Match.Team.GREEN, slot)
		var key := "%.2f,%.2f" % [p.x, p.z]
		assert_true(not seen.has(key), "slot %d at %s repeats slot %s" % [slot, key, seen.get(key)])
		seen[key] = slot
	Arena.active = previous
	assert_eq(seen.size(), Match.SPAWN_SLOTS, "57 distinct points, the same lattice as before")
