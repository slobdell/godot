extends TestCase
## Round 47 (engage E2b, R47.13): A LINE UNDER HIS ATTACK. His Crossing match (staged from his census at tick 2070): his War
## Rig Green_Guns_4 sat 26-46 m from Rust_Hunters_2 with Block_1 between for ~5.5 s under his attack order, never firing:
## ENGAGE's "no line of fire: going round" drove it at the target's own spot, into the building (wedged, k-turning).
##
## Staged here on his arena: a War Rig west of Block_1, the IFV east of it inside the rig's 50 m reach with no line between
## (asserted, lesson 350), his attack order on it through the element. The target holds its fire (this measures the rig).
## `--attack-line` OFF is today's (pinned as the control: it does not fire inside the window); ON it drives to a spot with
## a line and fires.

const RIG_AT := Vector3(-66.0, 0.0, -22.0)
const TARGET_AT := Vector3(-41.0, 0.0, -9.0)
const SECONDS := 12.0
## A squadmate of his that sees the target (in his match Guns_3 and the team's intel did): it holds its fire.
const SPOTTER_AT := Vector3(-41.0, 0.0, -34.0)


func teardown() -> void:
	TankBrain.ATTACK_LINE = false
	super.teardown()


## [first shot second (or -1), the rig's farthest drive, whether the staged line was blocked at the start]
func _run(attack_line: bool) -> Array:
	TankBrain.ATTACK_LINE = attack_line
	var lab := TacticsLab.create(self, 101, "crossing")
	var rig := lab.unit(Match.Team.GREEN, "Green_Guns_4", RIG_AT, -PI / 2.0, "gang_tank")  # facing +x (east)
	var target := lab.gun(Match.Team.RUST, "Rust_Hunters_2", TARGET_AT, PI / 2.0, "syn_ifv")  # facing west
	var spotter := lab.gun(Match.Team.GREEN, "Green_Eyes_1", SPOTTER_AT, 0.0, "gang_scout")
	await lab.start()
	(lab.game_match.brains.get_node("Orders_Rust_Hunters_2") as OrderController).set_orders({"type": "stop"}, {"type": "hold_fire"})
	(lab.game_match.brains.get_node("Orders_Green_Eyes_1") as OrderController).set_orders({"type": "stop"}, {"type": "hold_fire"})
	var blocked_at_start := not Perception.has_line_of_sight(rig, target) and Perception.has_line_of_sight(spotter, target)
	var element := lab.element(["Green_Guns_4"], "Guns")
	element.assign({"verb": "attack", "target": "Rust_Hunters_2"})
	var shots: Array = []
	rig.fired.connect(func(_m: Vector3, _d: Vector3) -> void: shots.append(lab.game_match.tick))
	var start_tick := lab.game_match.tick
	var farthest := 0.0
	for i in int(SECONDS * SimClock.TICK_RATE):
		await lab.step()
		farthest = maxf(farthest, Vector2(rig.global_position.x - RIG_AT.x, rig.global_position.z - RIG_AT.z).length())
		if not shots.is_empty():
			break
	var first := (int(shots[0]) - start_tick) / float(SimClock.TICK_RATE) if not shots.is_empty() else -1.0
	var brain := lab.game_match.brains.get_node_or_null("Brain_Green_Guns_4") as TankBrain
	print("ATTACK_LINE arm %s: first shot %.2f s, drove %.1f m, staged %s, rig at %s, seen by team %s, choice %s, why %s" % [
			"on" if attack_line else "off", first, farthest, blocked_at_start, rig.global_position.snappedf(0.1),
			lab.game_match.is_visible_to(Match.Team.GREEN, target), brain.choice.get("option", "") if brain != null else "?",
			brain.why if brain != null else "?"])
	lab.dispose()
	return [first, farthest, blocked_at_start]


func test_today_the_rig_behind_the_building_does_not_fire_in_the_window() -> void:
	var off: Array = await _run(false)
	assert_true(off[2], "the stage: Block_1 blocks the rig's line at the start and the spotter sees the target (else this case tests nothing)")
	assert_true(float(off[0]) < 0.0, "--attack-line=off is today's: no shot in %.0f s (first %.2f s)" % [SECONDS, off[0]])


func test_under_the_rule_it_drives_to_a_line_and_fires() -> void:
	var on: Array = await _run(true)
	assert_true(on[2], "the stage: Block_1 blocks the rig's line at the start")
	assert_true(float(on[0]) >= 0.0, "ON: the rig finds a line and fires inside %.0f s (first %.2f s, drove %.1f m)" % [
			SECONDS, on[0], on[1]])
