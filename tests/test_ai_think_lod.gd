extends TestCase
## Round 24 (brains L1, C24.7): the think rate by what a crew is doing, from simulation state only. A crew in reach of an
## enemy thinks at the fight rate while it is in the shooting (fired, hit or a round on its way within 2 s), at the
## QUIET rate when it is not, at the SETTLED rate when its choice has held for 3 thinks and nothing hit it; with every
## knob off it is the fight rate it always was. And a crew that is hit is back at the fight rate at the next re-rate.

const QUIET := 2.0
const SETTLED := 5.0


func teardown() -> void:
	TankBrain.QUIET_THINK_HZ = TankBrain.L1_QUIET_HZ
	TankBrain.SETTLED_THINK_HZ = TankBrain.L1_SETTLED_HZ
	TankBrain.ENGAGED_THINK_HZ = TankBrain.L1_ENGAGED_HZ
	super.teardown()


func test_l1_ships_off() -> void:
	assert_near(TankBrain.QUIET_THINK_HZ, 0.0, 0.001, "quiet off (round 23's rates)")
	assert_eq(TankBrain.QUIET_STRIDE, 1, "no stride")
	assert_near(TankBrain.SETTLED_THINK_HZ, 0.0, 0.001, "settled off")
	assert_near(TankBrain.ENGAGED_THINK_HZ, 0.0, 0.001, "engaged off")
	assert_eq(Elements.REPLAN_TICKS, 3, "leaders re-plan every 3 ticks")


func _brain_in_reach() -> Array:
	var lab := TacticsLab.create(self, 1, "yard")
	var mine := lab.unit(Match.Team.GREEN, "Green_L_1", Vector3(0, 0, 30), PI, "law_tank")
	lab.gun(Match.Team.RUST, "Rust_L_1", Vector3(0, 0, -10), 0.0, "law_tank")
	await lab.start()
	for tick in 20:
		await lab.step()  # the intel has the enemy in reach
	var brain := lab.game_match.brains.get_node(NodePath("Brain_" + String(mine.name))) as TankBrain
	return [lab, brain, mine]


func test_the_rate_by_what_the_crew_is_doing() -> void:
	var parts: Array = await _brain_in_reach()
	var lab: TacticsLab = parts[0]
	var brain: TankBrain = parts[1]
	var tank: Tank = parts[2]
	var fight_hz := brain._contact_think_hz(BrainVariants.for_team(tank.team))
	# Knobs off: the fight rate, whatever the crew is doing (round 23's game).
	TankBrain.QUIET_THINK_HZ = 0.0
	TankBrain.SETTLED_THINK_HZ = 0.0
	TankBrain.ENGAGED_THINK_HZ = 0.0
	brain.ticks_since_fire = 1000
	tank.ticks_since_hit = 1000
	brain._incoming_count = 0
	assert_near(brain._think_rate(), fight_hz, 0.001, "knobs off: the fight rate")
	assert_eq(brain._lod, "fight", "knobs off: lod fight")
	TankBrain.QUIET_THINK_HZ = QUIET
	TankBrain.SETTLED_THINK_HZ = SETTLED
	# Quiet: in reach, no shot, no hit, no round.
	assert_near(brain._think_rate(), QUIET, 0.001, "in reach but quiet: the quiet rate")
	assert_eq(brain._lod, "fight_quiet", "quiet")
	# It fires: the fight rate (not settled: its choice has not held).
	brain.ticks_since_fire = 0
	brain._kept_thinks = 0
	assert_near(brain._think_rate(), fight_hz, 0.001, "firing: the fight rate")
	TankBrain.ENGAGED_THINK_HZ = 7.5
	assert_near(brain._think_rate(), minf(7.5, fight_hz), 0.001, "firing, shipped: the engaged rate (never above the variant's)")
	TankBrain.ENGAGED_THINK_HZ = 0.0
	# Its choice held for 3 thinks and nothing hit it: settled.
	brain._kept_thinks = TankBrain.SETTLED_THINKS
	assert_near(brain._think_rate(), SETTLED, 0.001, "settled: the settled rate")
	# Hit: back to the fight rate.
	tank.ticks_since_hit = 0
	assert_near(brain._think_rate(), fight_hz, 0.001, "hit: the fight rate")
	# A quiet crew hit: the fight rate too (in the shooting).
	brain.ticks_since_fire = 1000
	assert_near(brain._think_rate(), fight_hz, 0.001, "a quiet crew that is hit: the fight rate")
	lab.dispose()
