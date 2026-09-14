class_name DetSpikeMode
extends GameMode
## Netcode phase N2: run the deterministic-core spike (game/network/detcore/) and print its state
## hash, so native and WebAssembly builds can be compared (`make det-spike`).
##   --det-spike [--tanks=20] [--ticks=3600] [--seed=12345]    (browser: ?det-spike&tanks=20)
## Prints DET_SPIKE_CHECKPOINT tick=N hash=H every 300 ticks, then DET_SPIKE_RESULT {json}.
## Owned by the netcode workstream (_agents/streams/netcode.md).

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
	var commands := DetSim.command_log(seed_value, tanks, ticks)
	var sim := DetSim.new(tanks)
	var busy_usec := 0
	var worst_frame_usec_per_tick := 0
	while sim.tick < ticks:
		var begin := Time.get_ticks_usec()
		var batch := mini(TICKS_PER_FRAME, ticks - sim.tick)
		for i in batch:
			sim.step(commands)
			if sim.tick % CHECKPOINT_EVERY == 0:
				print("DET_SPIKE_CHECKPOINT tick=%d hash=%s" % [sim.tick, sim.state_hash()])
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
	print("DET_SPIKE_RESULT " + JSON.stringify(result))
	main.hud.set_status("Deterministic spike: %s (%d µs per tick)" % [result["hash"], result["usec_per_tick"]])
	if not OS.has_feature("web") and DisplayServer.get_name() == "headless":
		main.get_tree().quit()
