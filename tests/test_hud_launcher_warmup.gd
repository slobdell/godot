extends TestCase
## Round 18 (picker, for finale): the loading screen stays up until FxWorld's shader warm-up has drawn its frames, so the
## first explosion, light and shield of a match do not compile mid-fight (finale measured 1-2.8 s frozen frames on a cold
## shader cache, and through the real launcher the warm-up landed 8 ms after the screen faded). Bounded by a frame cap,
## so a run with no FxWorld, no match or no feed never hangs on the screen.


func _flags() -> LaunchFlags:
	var flags := LaunchFlags.new()
	flags.values = {"arena": "yard"}
	return flags


func test_the_warmup_is_a_stage_after_the_first_frame() -> void:
	var ids: Array = LoadingScreen.STAGES.map(func(s: Array) -> String: return s[0])
	assert_eq(ids.find("warmup"), ids.find("first_frame") + 1, "warm-up comes after the first frame (%s)" % [ids])
	assert_eq(ids.back(), "warmup", "and is the last stage before the screen fades")


func test_the_screen_is_still_up_on_the_frame_the_warmup_finishes() -> void:
	var screen := LoadingScreen.show_for(tree, _flags())
	var seen: Array[String] = []
	var left := [3]
	var holding := func() -> bool:
		seen.append(screen.stage)
		left[0] -= 1
		return left[0] >= 0
	var frames: int = await GameLauncher.hold_for_warmup(tree, screen, holding)
	assert_eq(frames, 3, "it waited exactly the frames the warm-up held")
	assert_eq(seen.back(), "warmup", "and the screen was up, on the warm-up stage, when it let go")
	assert_eq(screen.stage, "warmup", "the launcher, not the hold, fades it (done() comes after)")
	screen.queue_free()
	await tree.process_frame


func test_a_warmup_that_never_finishes_releases_at_the_cap() -> void:
	var screen := LoadingScreen.show_for(tree, _flags())
	var frames: int = await GameLauncher.hold_for_warmup(tree, screen, func() -> bool: return true)
	assert_eq(frames, GameLauncher.WARMUP_CAP_FRAMES, "a stuck warm-up holds no longer than the cap")
	screen.queue_free()
	await tree.process_frame


func test_with_no_fx_world_it_releases_at_once() -> void:
	assert_true(FxWorld.existing() == null, "setup: headless tests have no FxWorld")
	var screen := LoadingScreen.show_for(tree, _flags())
	var frames: int = await GameLauncher.hold_for_warmup(tree, screen)
	assert_eq(frames, 0, "nothing to warm: the screen goes at once")
	screen.queue_free()
	await tree.process_frame


## Finale's cdef3fae: the warm-up warms only a match with controls. A menu's backdrop match (the faction menu, the title)
## has none, so it never holds the loading screen; the match FIGHT starts holds it until its warm-up is done.
func test_a_menu_backdrop_never_holds_and_a_played_match_holds_until_warmed() -> void:
	var camera := Camera3D.new()
	add_to_tree(camera)
	var backdrop := Node3D.new()
	add_to_tree(backdrop)
	var warmup := ShaderWarmup.new()
	warmup.enabled = true
	add_to_tree(warmup)
	for i in 3:
		warmup.step(camera, backdrop)
		await tree.process_frame
	assert_true(not GameLauncher.warmup_holds(warmup), "a backdrop with no controls does not hold the screen")
	var screen := LoadingScreen.show_for(tree, _flags())
	var frames: int = await GameLauncher.hold_for_warmup(tree, screen, GameLauncher.warmup_holds.bind(warmup))
	assert_eq(frames, 0, "so the menu never waits on it")
	# A played match (here: the controls rule off, as finale's own tests drive a bare node).
	var played := Node3D.new()
	add_to_tree(played)
	warmup.require_controls = false
	warmup.step(camera, played)
	assert_true(GameLauncher.warmup_holds(warmup), "the match FIGHT starts holds the screen while it warms")
	warmup.done = true
	assert_true(not GameLauncher.warmup_holds(warmup), "and lets go once the warm-up is done")
	assert_true(not GameLauncher.warmup_holds(null), "no warm-up holds nothing")
	screen.queue_free()
	await tree.process_frame
