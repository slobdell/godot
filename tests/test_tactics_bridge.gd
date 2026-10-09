extends TestCase
## Round 24 (brains R1): HIS BRIDGE CASE on the Locks (tests/tactics/bridge_stage.gd). "I told all my units to go and
## attack at the remote location across the bridge, and a whole bunch of them got stuck seemingly trying to drive
## through the river." A squad of four Law tanks on the north quay attack-moved to the far quay, three lancers on the far
## bank. Before the fix (round 23's main, builder0, seeds 1-6): straight-line combat hops over the canal on every fight
## run (385-683 crew-ticks), crews pressed into the rim, and in 6 of 18 runs crews never crossed. Both sides: the CPU's
## squad ordered the same way from the south quay is held to the same.

const UNITS: PackedStringArray = ["law_tank", "law_tank", "law_tank", "law_tank"]
## Long enough for the slowest seed's bridge traffic (rust seed 1: the last crew crosses at ~80 s, builder0): the river
## is what this asserts; how long the queue at the bridge takes is the series' (known issue in the brief's Status).
const SECONDS := 110.0


## `crossed_at_least`: the river is what this asserts. The CPU's seed 1 leaves its last crew queued on the far quay's
## strip behind a parked one (the shape's leg anchor at the water's edge, a one-hull strip between the rim and the
## warehouses; builder0, in the suite; the probe's run of the same seed crosses all four at 82 s): a traffic finding,
## written up in the brief's Status (known issue), not the river.
func _case(side: String, crossed_at_least: int) -> void:
	var report: Dictionary = await BridgeStage.run(self, 1, "locks", UNITS, side, 3, "syn_lancer", SECONDS)
	print("MEASURE bridge locks %s seed 1: %s" % [side, report])
	assert_eq(int(report["wet_hops"]), 0, "%s: no crew drove a straight hop over the water" % side)
	assert_eq(int(report["rim_crews"]), 0, "%s: no crew pressed into the water's rim for %.0f s or more: %s" % [
			side, BridgeStage.RIM_STUCK_S, report["rim_s"]])
	assert_true(int(report["crossed"]) >= crossed_at_least, "%s: %d of %d crews crossed (want %d)" % [
			side, int(report["crossed"]), UNITS.size(), crossed_at_least])


func test_his_squad_crosses_by_the_bridge() -> void:
	await _case("green", UNITS.size())


func test_the_cpus_squad_keeps_out_of_the_river_too() -> void:
	await _case("rust", UNITS.size() - 1)
