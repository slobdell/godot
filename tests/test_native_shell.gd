extends TestCase
## Round 28 (native N7.1c): Shell._fly natively (NativeShell -> shell_native.cpp) against the LIVE GDScript. Real shells
## (the match's scene) fired across a baked Sumps between hulls -- into walls, crates and tanks, past them, out of
## range -- each flown tick by tick through _fly both ways from one snapshot: the position, _travelled, hit_normal,
## _first_step, whether it still flies, its visibility and every signal it emitted (hit with its collider and point,
## expired) compared bit for bit after every tick; simulating and display-only shells; the shooter excluded or not.

const MATCH := preload("res://game/match/match.tscn")
const HULLS := 10
const SHOTS := 300
const TICKS := 60

var _events: Array = []


func _on_hit(shell: Shell, collider: Object, point: Vector3) -> void:
	_events.append(["hit", shell.name, collider.get_instance_id() if collider != null else 0, point])


func _on_expired(shell: Shell) -> void:
	_events.append(["expired", shell.name])


func _state(shell: Shell) -> Array:
	return [shell.global_position, shell._travelled, shell.hit_normal, shell._first_step, shell.is_physics_processing(),
			shell.visible]


func _fly(shell: Shell, native: bool, delta: float) -> Array:
	BrainSwitches.native_shell = native
	_events = []
	var trace: Array = []
	for t in TICKS:
		if not shell.is_physics_processing():
			break
		shell._fly(delta)
		trace.append([_state(shell), _events.duplicate()])
		_events.clear()
	return trace


func test_the_flight_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the shell equality is not exercised in this run")
		return
	assert_true(NativeShell.configure(), "the native flight takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array = Units.PROFILES.keys()
	units.sort()
	var tanks: Array[Tank] = []
	for i in HULLS:
		tanks.append(game_match.spawn_tank("Fly%02d" % i, 0, Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST,
				String(units[(i * 3) % units.size()])))
	await wait_physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2833
	var was := BrainSwitches.native_shell
	var mismatches := 0
	var first := ""
	var hits := 0
	var expiries := 0
	var ticks := 0
	for n in SHOTS:
		if n % 20 == 0:
			var centre := Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0))
			for tank in tanks:
				tank.global_position = centre + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
			await wait_physics_frames(1)  # the hulls' bodies where the rays look
		var shooter := tanks[rng.randi_range(0, HULLS - 1)]
		var target := tanks[rng.randi_range(0, HULLS - 1)].global_position + Vector3(rng.randf_range(-6.0, 6.0), 1.0,
				rng.randf_range(-6.0, 6.0))
		var muzzle := shooter.global_position + Vector3(0.0, 1.6, 0.0)
		var shell: Shell = game_match.SHELL_SCENE.instantiate()
		shell.name = "Flight_%d" % n
		shell.position = muzzle
		shell.ray_start = shooter.global_position + Vector3(0.0, 1.2, 0.0)
		shell.direction = (target - muzzle).normalized() if rng.randf() < 0.85 else \
				Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.1, 0.05), rng.randf_range(-1.0, 1.0)).normalized()
		shell.speed = rng.randf_range(30.0, 140.0)
		shell.max_range = rng.randf_range(10.0, 90.0)
		shell.simulate = rng.randf() < 0.85
		if rng.randf() < 0.8:
			shell.exclude = [shooter.get_rid()]
		game_match.shells.add_child(shell)
		# flown by hand below (_fly), between physics frames: the engine never steps it
		shell.hit.connect(_on_hit)
		shell.expired.connect(_on_expired)
		var start := [shell.global_position, shell._travelled, shell.hit_normal, shell._first_step, shell.visible]
		var delta := [SimClock.TICK_SECONDS, 1.0 / 60.0][rng.randi_range(0, 1)] as float
		_resume(shell, start)
		var live := _fly(shell, false, delta)
		_resume(shell, start)
		var native := _fly(shell, true, delta)
		ticks += live.size()
		for step: Array in live:
			for event: Array in step[1]:
				hits += 1 if event[0] == "hit" else 0
				expiries += 1 if event[0] == "expired" else 0
		if var_to_bytes(live) != var_to_bytes(native):
			mismatches += 1
			if first == "":
				first = "shot %d: live %s\nnative %s" % [n, live.slice(-2), native.slice(-2)]
		game_match.shells.remove_child(shell)
		shell.free()
	BrainSwitches.native_shell = was
	print("native shell: %d shots, %d ticks flown, %d hits, %d burnt out, %d mismatches" % [SHOTS, ticks, hits, expiries,
			mismatches])
	assert_eq(mismatches, 0, "the native flight is the live GDScript: %s" % first)
	assert_true(hits >= 60 and expiries >= 30, "a real sample (%d hits, %d burnt out)" % [hits, expiries])


## Puts a shell back where it started: in flight (processing, for in_flight's sake, though the engine never steps it --
## the test calls _fly itself, between physics frames).
func _resume(shell: Shell, start: Array) -> void:
	shell.global_position = start[0]
	shell._travelled = start[1]
	shell.hit_normal = start[2]
	shell._first_step = start[3]
	shell.visible = start[4]
	shell.set_physics_process(true)
