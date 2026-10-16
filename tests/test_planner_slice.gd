extends TestCase
## Round 32 (planner, C32.7): **SLICE per hardware preset.** The laptop preset plans SLICE_LAPTOP (1) expansions a tick,
## every other machine SLICE (2); the hold is re-sized so a crew's expansion allowance is unchanged (PENDING_TICKS x
## SLICE = 180 expansions either way); the slice is read ONCE per match; a run's `--planner-slice=N` (the host's value,
## carried as a launch flag as `--seed` is) wins over the local preset, so two peers with different GPUs plan alike; a
## headless run (every check, baseline and judged series) is the desktop preset: SLICE 2, 90 ticks, today's bits. In a
## Terminus street a War Rig's face-about plans THE SAME LEGS at either slice (the slice proof), lands later at 1, and
## two runs at 1 are identical.

const SECONDS := 12.0


func test_the_flag_wins_then_the_preset_then_the_default() -> void:
	assert_eq(PlannerSeam.resolve_slice("", "desktop"), [PlannerSeam.SLICE, "default"], "desktop: SLICE")
	assert_eq(PlannerSeam.resolve_slice("", "laptop"), [PlannerSeam.SLICE_LAPTOP, "preset"], "laptop preset: SLICE_LAPTOP")
	assert_eq(PlannerSeam.resolve_slice("", "custom"), [PlannerSeam.SLICE, "default"], "a custom lever set is not the laptop")
	# Two peers: a laptop client and a desktop host. Both run the host's flag, whatever their own preset.
	assert_eq(PlannerSeam.resolve_slice("2", "laptop"), [2, "flag"], "the host's 2 on a laptop peer")
	assert_eq(PlannerSeam.resolve_slice("1", "desktop"), [1, "flag"], "the host's 1 on a desktop peer")
	assert_eq(PlannerSeam.resolve_slice("0", "laptop"), [PlannerSeam.SLICE_LAPTOP, "preset"], "a bad flag is ignored")
	assert_eq(PlannerSeam.resolve_slice("x", "desktop"), [PlannerSeam.SLICE, "default"], "a bad flag is ignored")


func test_the_hold_keeps_the_expansions_a_crew_gets() -> void:
	var was := PlannerSeam.slice()
	assert_eq(PlannerSeam.EXPANSIONS_PER_HOLD, PlannerSeam.PENDING_TICKS * PlannerSeam.SLICE, "180 = 90 x 2")
	PlannerSeam.set_slice(PlannerSeam.SLICE, "default")
	assert_eq(PlannerSeam.pending_cap(), PlannerSeam.PENDING_TICKS, "SLICE 2: today's 90 ticks")
	PlannerSeam.set_slice(PlannerSeam.SLICE_LAPTOP, "test")
	assert_eq(PlannerSeam.pending_cap(), PlannerSeam.PENDING_TICKS * 2, "SLICE 1: 180 ticks")
	assert_eq(PlannerSeam.pending_cap() * PlannerSeam.slice(), PlannerSeam.EXPANSIONS_PER_HOLD, "the same expansions")
	PlannerSeam.set_slice(was, "default")


func test_a_headless_run_is_the_desktop_slice() -> void:
	assert_eq(RenderLevers.preset(), "desktop", "headless: the desktop preset")
	var got := PlannerSeam.resolve_slice(LaunchFlags.from_environment().text(PlannerSeam.SLICE_FLAG), RenderLevers.preset())
	assert_eq(got[0], PlannerSeam.SLICE, "the default path plans at SLICE (2): baselines unmoved")


func _rig_face(seed_value: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, "terminus")
	var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "gang_tank")
	await lab.start()
	var ctl: OrderController = null
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			ctl = child
	ctl.set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
	return {"lab": lab, "tank": tank, "ctl": ctl}


## One run at `slice`: the first plan (legs, expansions), the hold before it, the rig's pose at the end; the latch
## checked mid-match (the override changed: this match keeps its slice).
func _run(slice: int) -> Dictionary:
	PlannerSeam.reset()
	PlannerSeam.slice_override = slice
	var scene: Dictionary = await _rig_face(31)
	var lab: TacticsLab = scene["lab"]
	var tank: Tank = scene["tank"]
	var latched := -1
	for tick in int(SimClock.TICK_RATE * SECONDS):
		await lab.step()
		if latched < 0 and PlannerSeam.requests >= 1:
			latched = PlannerSeam.slice()
			PlannerSeam.slice_override = 3 - slice   # a preset flipped mid-match: never read again this match
	var plans := PlannerSeam.last_plans.duplicate(true)
	for plan: Dictionary in plans:
		plan.erase("tick")   # the engine's frame count runs on across matches in one process
	var out := {"slice": latched, "after": PlannerSeam.slice(), "plans": plans,
			"holds": Array(PlannerSeam.holds), "abandoned": PlannerSeam.abandoned,
			"pos": [snappedf(tank.global_position.x, 0.001), snappedf(tank.global_position.z, 0.001)]}
	lab.dispose()
	PlannerSeam.slice_override = 0
	PlannerSeam.reset()
	return out


func test_the_laptop_slice_plans_the_same_legs_later_and_deterministically() -> void:
	if not PlannerSeam.on():
		print("planner seam OFF on this tree: the slice is not exercised")
		return
	var two := await _run(2)
	var one := await _run(1)
	var one_again := await _run(1)
	print("MEASURE planner_slice: slice 2 holds %s plans %d | slice 1 holds %s plans %d | host %s" % [
			str(two["holds"]), (two["plans"] as Array).size(), str(one["holds"]), (one["plans"] as Array).size(),
			_host()])
	assert_eq(two["slice"], 2, "the first match latched 2")
	assert_eq(one["slice"], 1, "the second latched 1")
	assert_eq(one["after"], 1, "a mid-match change is not read: the match keeps its slice")
	assert_true((two["plans"] as Array).size() >= 1 and (one["plans"] as Array).size() >= 1, "both planned")
	var p2: Dictionary = (two["plans"] as Array)[0]
	var p1: Dictionary = (one["plans"] as Array)[0]
	assert_eq(p1["legs"], p2["legs"], "the same legs at either slice")
	assert_eq(p1["expansions"], p2["expansions"], "the same search")
	assert_true(int((one["holds"] as Array)[0]) >= int((two["holds"] as Array)[0]), "the laptop's hold is no shorter")
	assert_eq(one["abandoned"], 0, "nothing abandoned at 1 (the hold re-sized)")
	assert_eq(one_again, one, "two runs at the laptop slice are identical (deterministic: counted, never timed)")


## The machine every number here is quoted with (HOSTNAME is unset in some shells: /etc/hostname then).
static func _host() -> String:
	var host := OS.get_environment("HOSTNAME")
	if host == "" and FileAccess.file_exists("/etc/hostname"):
		host = FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	return host if host != "" else "unknown-host"
