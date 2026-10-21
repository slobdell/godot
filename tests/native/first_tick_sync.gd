extends SceneTree
## Round 36 (native, E4b; `make native-first-tick-sync`): where a setup runs decides what the physics space holds at its
## bodies' first tick. The bodies and the verdict are first_tick_sync_scene.gd's; --arm= names WHERE the setup runs, each
## after three warm iterations so no first-iteration state is in play:
##   physics_signal  resumed from `await physics_frame` (a test's body after an await)
##   process_signal  resumed from `await process_frame` (an input or UI callback)
##   process_flush   a call_deferred flushed in the idle frame
##   physics_flush   a call_deferred flushed inside the physics frame (run_tests.gd's `_initialize -> _run.call_deferred()`,
##                   so the first test of a process, before brains' warm-up)
##   in_tick         from a node's _physics_process (the game's in-tick spawns)
## Only physics_flush and in_tick are synced (laptop, Godot 4.7.2, Jolt).

const Scene := preload("res://tests/native/first_tick_sync_scene.gd")

var _arm := ""
var _at := ""
var _driver: Scene.Driver


class Spawner:
	extends Node
	var on_tick: Callable
	var _done := false

	func _physics_process(_delta: float) -> void:
		if not _done:
			_done = true
			on_tick.call()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arm="):
			_arm = arg.trim_prefix("--arm=")
	_run.call_deferred()


func _run() -> void:
	for i in 3:
		await physics_frame
	match _arm:
		"physics_signal":
			await physics_frame
			_setup()
		"process_signal":
			await process_frame
			_setup()
		"process_flush":
			await process_frame
			_setup.call_deferred()
		"physics_flush":
			await physics_frame
			_setup.call_deferred()
		"in_tick":
			var spawner := Spawner.new()
			spawner.on_tick = _setup
			root.add_child(spawner)
		_:
			print("FIRST_TICK_SYNC unknown --arm=%s" % _arm)
			quit(2)
			return
	for i in 8:
		await process_frame
	Scene.report(_arm, _at, _driver)
	quit()


func _setup() -> void:
	_at = Scene.context()
	_driver = Scene.build(root)
