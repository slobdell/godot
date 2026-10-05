extends TestCase
## Finale E3 (round 18): the shader warm-up draws every material once at load, unlit then lit, and leaves nothing changed.
## Its effect (no first-use compile mid-match) needs a GPU: `make end-trace END_TRACE_COLD=1`, warm-up against
## `--no-shader-warmup`. Here: the two frames' state and the restore, headless.


func _world() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.process_mode = Node.PROCESS_MODE_DISABLED  # the test drives the warm-up's frames itself
	fx.warmup.require_controls = false  # a bare node stands for the match (the played-match rule has its own test)
	var camera: Camera3D = add_to_tree(Camera3D.new())
	var near: MeshInstance3D = add_to_tree(MeshInstance3D.new())
	near.mesh = BoxMesh.new()
	near.visibility_range_end = 50.0
	near.extra_cull_margin = 1.5
	var hidden: MeshInstance3D = add_to_tree(MeshInstance3D.new())
	hidden.mesh = BoxMesh.new()
	hidden.visible = false
	var game_match: Node = add_to_tree(Node.new())  # the warm-up only needs to know WHICH match is attached
	return [fx, camera, near, hidden, game_match]


## Steps until the warm-up has set up its first (unlit) frame; with no live feed it waits WAIT_FRAMES_MAX frames.
func _begin(warmup: ShaderWarmup, camera: Camera3D, game_match: Node) -> int:
	var steps := 0
	while int(warmup.get("_phase")) < 0 and steps < ShaderWarmup.WAIT_FRAMES_MAX + 2:
		warmup.step(camera, game_match)
		steps += 1
	return steps


func test_frame_one_widens_every_visible_instance_with_the_pool_off() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var near: MeshInstance3D = world[2]
	var hidden: MeshInstance3D = world[3]
	var steps := _begin(fx.warmup, world[1], world[4])
	assert_eq(steps, ShaderWarmup.WAIT_FRAMES_MAX, "with no live feed it waits its cap, then warms anyway")
	assert_eq(near.extra_cull_margin, ShaderWarmup.MARGIN, "frustum and light culling see it wherever it is")
	assert_eq(near.visibility_range_end, 0.0, "its visibility range is off for the frame")
	assert_eq(hidden.extra_cull_margin, 0.0, "a hidden instance is not drawn by the warm-up")
	assert_true(not fx.lights.enabled, "frame one is UNLIT: the pool is off (even a 0.5 m light reaches a widened box)")
	assert_true(int(fx.warmup.touched["instances"]) >= 1, "it says what it touched (the arm assertion)")


func test_frame_two_lights_everything_then_everything_goes_back() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var camera: Camera3D = world[1]
	var near: MeshInstance3D = world[2]
	_begin(fx.warmup, camera, world[4])
	fx.warmup.step(camera, world[4])  # frame two: lit
	assert_true(fx.lights.enabled, "frame two is LIT")
	fx.lights.commit(camera.global_position, 0.0)
	var wide := 0
	for light in fx.lights.lights:
		if light.visible and light.omni_range >= ShaderWarmup.LIGHT_RANGE:
			wide += 1
	assert_eq(wide, fx.lights.lights.size(), "every pooled light reaches everything, above any other request")
	fx.warmup.step(camera, world[4])  # frame three: restore
	assert_true(fx.warmup.done, "two frames, then done")
	assert_eq(near.extra_cull_margin, 1.5, "the margin is back")
	assert_eq(near.visibility_range_end, 50.0, "the visibility range is back")
	assert_eq(int(fx.warmup.touched["lights"]), fx.lights.lights.size(), "the arm assertion read the lights it lit")
	fx.warmup.step(camera, world[4])
	assert_eq(near.extra_cull_margin, 1.5, "and it never runs again")


func test_a_node_freed_during_the_warm_up_is_skipped() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var camera: Camera3D = world[1]
	var shell: MeshInstance3D = add_to_tree(MeshInstance3D.new())
	shell.mesh = BoxMesh.new()
	_begin(fx.warmup, camera, world[4])
	shell.free()  # a shell's visual that lived for a frame
	fx.warmup.step(camera, world[4])
	fx.warmup.step(camera, world[4])
	assert_true(fx.warmup.done, "the restore finished without touching the freed node")


func test_the_pool_comes_back_as_it_was() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var camera: Camera3D = world[1]
	fx.lights.enabled = false  # e.g. a no_pool_lights removal arm
	_begin(fx.warmup, camera, world[4])
	fx.warmup.step(camera, world[4])
	assert_true(not fx.lights.enabled, "a pool that was off stays off for the lit frame")
	fx.warmup.step(camera, world[4])
	assert_true(not fx.lights.enabled, "and after it")


func test_off_does_nothing() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var near: MeshInstance3D = world[2]
	fx.warmup.enabled = false
	for i in ShaderWarmup.WAIT_FRAMES_MAX + 4:
		fx.warmup.step(world[1], world[4])
	assert_eq(near.extra_cull_margin, 1.5, "--no-shader-warmup: nothing widened")
	assert_true(not fx.warmup.done, "and nothing ran")


func test_no_match_no_warm_up() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	for i in ShaderWarmup.WAIT_FRAMES_MAX + 4:
		fx.warmup.step(world[1], null)
	assert_eq(int(fx.warmup.get("_phase")), -1, "the title and the galleries are not warmed (no match attached)")


func test_a_new_match_is_warmed_again() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var camera: Camera3D = world[1]
	var near: MeshInstance3D = world[2]
	_begin(fx.warmup, camera, world[4])
	fx.warmup.step(camera, world[4])
	fx.warmup.step(camera, world[4])
	assert_true(fx.warmup.done, "the first match is warmed")
	var rematch: Node = add_to_tree(Node.new())
	_begin(fx.warmup, camera, rematch)
	assert_eq(near.extra_cull_margin, ShaderWarmup.MARGIN, "a rematch (maybe another arena, other materials) warms again")
	fx.warmup.step(camera, rematch)
	fx.warmup.step(camera, rematch)
	assert_eq(near.extra_cull_margin, 1.5, "and puts everything back")


func test_the_effects_prewarm_is_held_only_while_a_match_warms() -> void:
	var world := _world()
	var fx: FxWorld = world[0]
	var camera: Camera3D = world[1]
	fx.warmup.step(camera, null)
	assert_true(not fx.warmup.holding(), "the title screen: no hold, the effects prewarm ends after its own frames")
	_begin(fx.warmup, camera, world[4])
	assert_true(fx.warmup.holding(), "while the world warms, the effects stay up so both frames and the feed draw them")
	fx.warmup.step(camera, world[4])
	fx.warmup.step(camera, world[4])
	assert_true(not fx.warmup.holding(), "released when the warm-up is done")


func test_a_menu_backdrop_match_is_not_warmed() -> void:
	# The faction menu and the title have a match behind them but no controls, and no loading screen in front: warming
	# there froze the menu (5.2 s + 5.1 s, cold, measured on his path).
	var world := _world()
	var fx: FxWorld = world[0]
	var near: MeshInstance3D = world[2]
	fx.warmup.require_controls = true
	for i in ShaderWarmup.WAIT_FRAMES_MAX + 4:
		fx.warmup.step(world[1], world[4])
	assert_eq(near.extra_cull_margin, 1.5, "no controls in the scene: a menu's backdrop, left alone")
	assert_true(not fx.warmup.done, "and not marked done: the played match that follows is warmed")
	assert_true(not fx.warmup.holding(), "nor is the effects prewarm held up behind a menu")


## The contract (round 18): the launcher's first read for a played match holds, whatever MatchFxLink's search interval.
## Before it, a 0.5 s search let the hold read the menu's state and let go (his path, cold, N=3: warmup=0, then 1.3-1.8 s
## compiles after the screen); only an every-frame search hid that.
func test_the_launchers_first_read_holds_a_played_match_whatever_the_search_interval() -> void:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	fx.process_mode = Node.PROCESS_MODE_DISABLED  # the link never searches by itself here: the race at its worst
	fx.link.search_every = 0.5
	var previous_scene := tree.current_scene
	var menu: Node = add_to_tree(Node.new())
	var menu_match := Node.new()
	menu_match.name = "Match"
	menu.add_child(menu_match)
	fx.warmup.played_probe = func(m: Node) -> bool: return m != menu_match  # the menu's backdrop has no controls
	tree.current_scene = menu
	var menu_held := fx.warmup.holding()
	# FIGHT: the played scene replaces the menu, and the launcher asks in that same frame, before any search.
	var main: Node = add_to_tree(Node.new())
	var played := Node.new()
	played.name = "Match"
	main.add_child(played)
	tree.current_scene = main
	var played_held := fx.warmup.holding()
	var attached := fx.link.attached_match()
	tree.current_scene = previous_scene
	assert_true(not menu_held, "a menu's backdrop match is not held (no controls, no loading screen in front of it)")
	assert_true(played_held, "the played match holds on the launcher's FIRST read, with a 0.5 s search that never ran")
	assert_eq(attached, played, "holding() attached the current match itself")
