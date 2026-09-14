extends SceneTree
## Network smoke-test client, run by `make net-smoke`.
##
## Boots the REAL game (main.tscn) as a client using the flags after `--`, e.g.
##   --connect=ws://127.0.0.1:9181 --demo --expect-tanks=2
## and checks, over real WebSockets against a real headless server, that:
##   1. the server spawned a tank for us,
##   2. we can see --expect-tanks tanks in total (other players replicate to us),
##   3. our tank's replicated position moves: our commands reached the server,
##      the server simulated them, and the new state came back (--min-travel=M, default 3),
##   4. with --expect-damage: our tank's replicated health drops (someone shot us and
##      the server's damage reached us), e.g. against a server bot (--bots=1).
## Exits 0 on success, 1 on failure, printing NET_CHECK PASS/FAIL.

const TIMEOUT_SEC := 25.0
const PORT_WAIT_SEC := 15.0
const DEFAULT_MIN_TRAVEL_M := 3.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := {}
	for flag in OS.get_cmdline_user_args():
		var parts := flag.trim_prefix("--").split("=", true, 1)
		flags[parts[0]] = parts[1] if parts.size() > 1 else ""
	var url: String = flags.get("connect", "")
	var expect_tanks := int(flags.get("expect-tanks", "1"))
	var min_travel := float(flags.get("min-travel", str(DEFAULT_MIN_TRAVEL_M)))
	var expect_damage := flags.has("expect-damage")
	if not url.begins_with("ws://"):
		_finish(false, "pass --connect=ws://host:port")
		return

	# The server is launched alongside us; wait until it accepts TCP connections.
	var host_port := url.trim_prefix("ws://").split(":")
	if not await _wait_for_port(host_port[0], int(host_port[1])):
		_finish(false, "server never opened %s" % url)
		return

	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)

	var tanks: Node = main.get_node("Match/Tanks")
	var timeout_sec := float(flags.get("timeout", str(TIMEOUT_SEC)))
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000)
	var lowest_health := 1_000_000
	var full_health := 1_000_000
	var start: Variant = null
	var travel := 0.0
	var seen := 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		seen = maxi(seen, tanks.get_child_count())
		var mine: Tank = tanks.get_node_or_null("Tank_%d" % root.multiplayer.get_unique_id())
		if mine == null:
			continue
		if start == null:
			start = mine.sync_position
		travel = maxf(travel, mine.sync_position.distance_to(start))
		lowest_health = mini(lowest_health, mine.sync_health)
		full_health = mine.max_health
		var damaged := lowest_health < mine.max_health
		if seen >= expect_tanks and travel >= min_travel and (damaged or not expect_damage):
			break

	var peer_id := root.multiplayer.get_unique_id()
	var damaged := start != null and lowest_health < full_health
	var summary := "peer=%d got_tank=%s tanks_seen=%d/%d travel=%.1fm/%.1fm lowest_health=%s%s" % [
			peer_id, start != null, seen, expect_tanks, travel, min_travel,
			lowest_health if start != null else "-", " (damage expected)" if expect_damage else ""]
	_finish(start != null and seen >= expect_tanks and travel >= min_travel
			and (damaged or not expect_damage), summary)


func _wait_for_port(host: String, port: int) -> bool:
	var deadline := Time.get_ticks_msec() + int(PORT_WAIT_SEC * 1000)
	while Time.get_ticks_msec() < deadline:
		var tcp := StreamPeerTCP.new()
		if tcp.connect_to_host(host, port) == OK:
			var attempt_deadline := Time.get_ticks_msec() + 500
			while Time.get_ticks_msec() < attempt_deadline:
				tcp.poll()
				var status := tcp.get_status()
				if status == StreamPeerTCP.STATUS_CONNECTED:
					tcp.disconnect_from_host()
					return true
				if status != StreamPeerTCP.STATUS_CONNECTING:
					break
				await process_frame
		await create_timer(0.2).timeout
	return false


func _finish(ok: bool, summary: String) -> void:
	print("NET_CHECK %s %s" % ["PASS" if ok else "FAIL", summary])
	quit(0 if ok else 1)
