extends TestCase
## Round 21 (brains P0, C21.5; the lead, 2026-10-06 evening: *"yes let's just go ahead and add the cpu leaders
## feature"*). The computer's squads are run by their squad leaders (ElementCommander: posture, ambush, the hidden line)
## in his skirmish and the garage's fight with no flag; `--no-element-cpu` keeps the brains-only CPU for A/B.

const MAIN := preload("res://game/main.tscn")


func _cpu_leads(raw: Array) -> bool:
	return SkirmishMode.cpu_runs_elements(LaunchFlags.parse(PackedStringArray(raw)))


func test_his_launch_lines_run_the_cpu_squad_leaders_with_no_flag() -> void:
	assert_true(SkirmishMode.ELEMENT_CPU_DEFAULT, "on by default (his answer)")
	# `make skirmish` with no CPU_LEADERS (mk/play.mk's line, less the per-run seed and arena).
	assert_true(_cpu_leads(["--skirmish", "--enemy=cpu", "--seed=3", "--arena=random", "--announcer=voice",
			"--music=on", "--camera-readout=on"]), "make skirmish")
	# The garage's FIGHT hands over to SkirmishMode with these values (GarageMode._start_skirmish).
	assert_true(_cpu_leads(["--skirmish", "--no-pick-faction", "--player=user://army_fight/a.json", "--budget=1000",
			"--enemy=user://army_fight/b.json", "--seed=1"]), "the garage's fight")


func test_the_control_arm_and_no_elements_still_turn_it_off() -> void:
	assert_true(not _cpu_leads(["--skirmish", "--no-element-cpu"]), "--no-element-cpu: the brains-only CPU")
	assert_true(not _cpu_leads(["--skirmish", "--no-elements"]), "no elements at all: no element CPU")
	assert_true(_cpu_leads(["--skirmish", "--element-cpu"]), "--element-cpu still accepted")


## The real launch, in process: a flagless skirmish installs the CPU's commander and forms its squads as elements;
## the control arm does not.
func test_a_flagless_skirmish_installs_the_cpu_commander_and_the_control_arm_does_not() -> void:
	var launch := ["--skirmish", "--enemy=cpu", "--seed=3", "--no-pick-faction", "--mute", "--no-record"]
	var flagless: Array = await _commanders(launch)
	var control: Array = await _commanders(launch + ["--no-element-cpu"])
	assert_eq(flagless,
			["ElementCommander_%d" % Match.Team.RUST], "flagless: the CPU's squad leaders run (and only the CPU's)")
	assert_eq(control, [], "--no-element-cpu: no commander")


## Boots the real scene with `raw` and lists the CPU commanders it installed. The skirmish opens in its planning PAUSE
## (the whole tree) and main caps the headless frame rate: both are put back, or every test after this one in the
## process runs a frozen world (the first check of this file: 22 later tests failed, "1 s at full throttle ... z=0.00").
func _commanders(raw: Array) -> Array:
	var max_fps := Engine.max_fps
	Main.next_flags = LaunchFlags.parse(PackedStringArray(raw))
	var main: Node = add_to_tree(MAIN.instantiate())
	await wait_physics_frames(2)
	var found: Array = []
	for child in main.get_node("Match").get_children():
		if child is ElementCommander:
			found.append(String(child.name))
	main.queue_free()
	tree.paused = false
	Engine.max_fps = max_fps
	await wait_physics_frames(2)
	return found
