extends SceneTree
## Network smoke-test client, run by `make net-smoke`, `combat-smoke`, `relay-smoke`, `relay-drop-smoke`.
##
## Boots the REAL game (main.tscn) as a client using the flags after `--`, e.g.
##   --connect=ws://127.0.0.1:9181 --demo --expect-tanks=2
##   --join=K7QX2 --relay=ws://127.0.0.1:9186 --demo --expect-tanks=4   (player-hosted, via the broker)
## and checks, over real WebSockets against a real headless server or host, that:
##   1. the server spawned a tank for us,
##   2. we can see --expect-tanks tanks in total (other players replicate to us),
##   3. our tank's replicated position moves: our commands reached the server,
##      the server simulated them, and the new state came back (--min-travel=M, default 3),
##   4. with --expect-damage: our tank's replicated health drops (someone shot us and
##      the server's damage reached us), e.g. against a server bot (--bots=1),
##      or with --expect-any-damage: some tank's replicated health drops (combat is replicating),
##   5. with --drop-after=S --drop-seconds=D (relay only): S seconds after spawning, our socket is
##      cut for D seconds (a phone losing signal); we must resume the same seat, keep our tank, and
##      see it move again (--min-travel-after-drop=M, default 2) with no errors.
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
	var url: String = flags.get("relay", "") if flags.has("join") else flags.get("connect", "")
	var expect_tanks := int(flags.get("expect-tanks", "1"))
	var min_travel := float(flags.get("min-travel", str(DEFAULT_MIN_TRAVEL_M)))
	var expect_damage := flags.has("expect-damage")
	var expect_any_damage := flags.has("expect-any-damage")
	var drop_after := float(flags.get("drop-after", "-1"))
	var drop_seconds := float(flags.get("drop-seconds", "10"))
	var min_travel_after_drop := float(flags.get("min-travel-after-drop", "2"))
	if not url.begins_with("ws://"):
		_finish(false, "pass --connect=ws://host:port, or --join=CODE --relay=ws://host:port")
		return

	# The server is launched alongside us; wait until it accepts TCP connections.
	var host_port := url.trim_prefix("ws://").split("/")[0].split(":")
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
	var any_damaged := false
	var start: Variant = null
	var travel := 0.0
	var seen := 0
	var spawned_msec := 0
	# Drop test state: "pending" → "away" → "back" (resumed) → measured travel since.
	var drop_state := "none" if drop_after < 0.0 else "pending"
	var back_position: Variant = null
	var travel_after_drop := 0.0
	var away_msec := 0
	var relay: RelayPeer = null
	var my_id := 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		seen = maxi(seen, tanks.get_child_count())
		for node in tanks.get_children():
			var tank := node as Tank
			if tank != null and tank.sync_health < tank.max_health:
				any_damaged = true
		my_id = root.multiplayer.get_unique_id()
		var mine: Tank = tanks.get_node_or_null("Tank_%d" % my_id)
		if mine == null:
			if drop_state == "back":
				_finish(false, "our tank disappeared after the socket drop")
				return
			continue
		if start == null:
			start = mine.sync_position
			spawned_msec = Time.get_ticks_msec()
			relay = root.multiplayer.multiplayer_peer as RelayPeer
		travel = maxf(travel, mine.sync_position.distance_to(start))
		lowest_health = mini(lowest_health, mine.sync_health)
		full_health = mine.max_health
		if drop_state == "pending" and Time.get_ticks_msec() - spawned_msec > drop_after * 1000.0:
			if relay == null:
				_finish(false, "--drop-after needs a relay connection (--join)")
				return
			print("NET_CHECK dropping our socket for %.0f s" % drop_seconds)
			relay.simulate_drop(drop_seconds)
			away_msec = Time.get_ticks_msec()
			drop_state = "away"
		elif drop_state == "away" and not relay.is_away():
			if root.multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
				_finish(false, "the relay session ended instead of resuming: %s" % relay.close_reason)
				return
			away_msec = Time.get_ticks_msec() - away_msec
			print("NET_CHECK resumed after %.1f s away (same peer id %d)" % [away_msec / 1000.0, my_id])
			drop_state = "back"
		elif drop_state == "back":
			if back_position == null:
				back_position = mine.sync_position
			travel_after_drop = maxf(travel_after_drop, mine.sync_position.distance_to(back_position))
		var damaged := lowest_health < mine.max_health
		if seen >= expect_tanks and travel >= min_travel and (damaged or not expect_damage) \
				and (any_damaged or not expect_any_damage) \
				and (drop_state == "none" or (drop_state == "back" and travel_after_drop >= min_travel_after_drop)):
			break

	var damaged := start != null and lowest_health < full_health
	var drop_ok := drop_state == "none" or (drop_state == "back" and travel_after_drop >= min_travel_after_drop)
	var summary := "peer=%d got_tank=%s tanks_seen=%d/%d travel=%.1fm/%.1fm lowest_health=%s%s%s" % [
			my_id, start != null, seen, expect_tanks, travel, min_travel,
			lowest_health if start != null else "-", " (damage expected)" if expect_damage else "",
			" any_damage=%s" % any_damaged if expect_any_damage else ""]
	if drop_state != "none":
		summary += " drop=%s away=%.1fs travel_after=%.1fm/%.1fm" % [drop_state, away_msec / 1000.0,
				travel_after_drop, min_travel_after_drop]
	if relay != null:
		summary += " relay_in=%dB/%df out=%dB/%df" % [relay.stats["bytes_in"], relay.stats["frames_in"],
				relay.stats["bytes_out"], relay.stats["frames_out"]]
	_finish(start != null and seen >= expect_tanks and travel >= min_travel
			and (damaged or not expect_damage) and (any_damaged or not expect_any_damage) and drop_ok, summary)


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
	# Leave politely (a relay host sees "left", not "away"), and uninstall the peer: a script-based
	# peer (RelayPeer) still installed at exit is reported as leaked resources.
	if root.multiplayer.multiplayer_peer != null:
		root.multiplayer.multiplayer_peer.close()
	root.multiplayer.multiplayer_peer = null
	quit(0 if ok else 1)
