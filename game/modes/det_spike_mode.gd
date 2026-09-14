class_name DetSpikeMode
extends GameMode
## Netcode phase N2: run the deterministic-core spike (game/network/detcore/) and print its state
## hash, so native and WebAssembly builds can be compared (`make det-spike`).
##   --det-spike [--tanks=20] [--ticks=3600] [--seed=12345]    (browser: ?det-spike&tanks=20)
##   --save-replay=PATH    also write the command log + checkpoint hashes (CommandReplay)
##   --replay-log=PATH     run a saved log instead of generating one, and verify every hash:
##                         prints DET_REPLAY VERIFIED or DET_REPLAY DIVERGED (exit code 1 headless)
## Prints DET_SPIKE_CHECKPOINT tick=N hash=H every 300 ticks, then DET_SPIKE_RESULT {json}.
## Owned by the netcode workstream (_agents/streams/archive/round1/netcode.md).

const CHECKPOINT_EVERY := 300
## Ticks simulated per rendered frame, so a browser tab stays responsive.
const TICKS_PER_FRAME := 150


func role_name() -> String:
	return "DET_SPIKE"


func caps_headless_fps() -> bool:
	return false


func start() -> void:
	main.game_match.has_local_player = false
	# Nothing to see, and a software-rendered browser (the smoke test's SwiftShader) spends ~0.5 s
	# per 3D frame, which would stretch the run to minutes.
	main.get_viewport().disable_3d = true
	main.hud.set_status("Deterministic core spike running…")
	_run.call_deferred()


func _run() -> void:
	var tanks := flags.integer("tanks", 20)
	var ticks := flags.integer("ticks", 3600)
	var seed_value := flags.integer("seed", 12345)
	var replay := {}
	if flags.has("replay-log"):
		replay = CommandReplay.load_file(flags.text("replay-log"))
		if replay.has("error"):
			push_error("DET_REPLAY " + String(replay["error"]))
			_quit(2)
			return
		tanks = replay["tanks"]
		ticks = replay["ticks"]
		seed_value = int(replay.get("seed", 0))
	var commands: Array = replay["commands"] if replay.has("commands") else DetSim.command_log(seed_value, tanks, ticks)
	var checkpoints := {}
	var diverged := ""
	var sim := DetSim.new(tanks)
	var busy_usec := 0
	var worst_frame_usec_per_tick := 0
	while sim.tick < ticks:
		var begin := Time.get_ticks_usec()
		var batch := mini(TICKS_PER_FRAME, ticks - sim.tick)
		for i in batch:
			sim.step(commands)
			if sim.tick % CHECKPOINT_EVERY == 0:
				var tick_hash := sim.state_hash()
				checkpoints[str(sim.tick)] = tick_hash
				print("DET_SPIKE_CHECKPOINT tick=%d hash=%s" % [sim.tick, tick_hash])
				var expected := String(replay.get("checkpoints", {}).get(str(sim.tick), tick_hash))
				if diverged == "" and expected != tick_hash:
					diverged = "tick=%d expected=%s got=%s" % [sim.tick, expected, tick_hash]
		var spent := Time.get_ticks_usec() - begin
		busy_usec += spent
		worst_frame_usec_per_tick = maxi(worst_frame_usec_per_tick, spent / batch)
		await main.get_tree().process_frame
	var usec_per_tick := float(busy_usec) / ticks
	var result := {
		"hash": sim.state_hash(), "ticks": ticks, "tanks": tanks, "seed": seed_value,
		"commands": commands.size(), "shots": sim.shots, "hits": sim.hits, "kills": sim.kills,
		"platform": "web" if OS.has_feature("web") else OS.get_name(),
		"usec_per_tick": roundi(usec_per_tick), "worst_batch_usec_per_tick": worst_frame_usec_per_tick,
		# Fraction of a 30 Hz tick budget (33.3 ms) one tick uses.
		"budget_used_at_30hz": snappedf(usec_per_tick / (1000000.0 / DetSim.TICKS_PER_SEC), 0.001),
	}
	for kind in ["basic", "trig"]:
		print("FLOAT_PROBE kind=%s hash=%s" % [kind, FloatProbe.run(kind, 200000)])
	print("DET_SPIKE_RESULT " + JSON.stringify(result))
	main.hud.set_status("Deterministic spike: %s (%d µs per tick)" % [result["hash"], result["usec_per_tick"]])
	if flags.has("save-replay"):
		var path := flags.text("save-replay")
		var err := CommandReplay.save(path, {"version": CommandReplay.VERSION, "tanks": tanks, "ticks": ticks,
				"seed": seed_value, "commands": commands, "checkpoints": checkpoints, "hash": result["hash"]})
		print("DET_REPLAY saved %s (%s)" % [path, error_string(err)])
	var status := 0
	if flags.has("replay-log"):
		if diverged == "" and String(replay.get("hash", "")) != result["hash"]:
			diverged = "final expected=%s got=%s" % [replay.get("hash", ""), result["hash"]]
		print("DET_REPLAY VERIFIED %d checkpoints, final %s" % [checkpoints.size(), result["hash"]] if diverged == ""
				else "DET_REPLAY DIVERGED " + diverged)
		status = 0 if diverged == "" else 1
	_quit(status)


func _quit(status: int) -> void:
	if not OS.has_feature("web") and DisplayServer.get_name() == "headless":
		main.get_tree().quit(status)
