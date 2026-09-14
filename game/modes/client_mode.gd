class_name ClientMode
extends GameMode
## Networked client: displays replicated state, sends its local controller's commands.
##   --connect[=ws://host:port]         a dedicated server (ServerMode)
##   --join=CODE [--relay=ws://broker]  a player-hosted room through the relay (HostMode)
##     --player-key=KEY                 who we are across sessions (browser: kept per tab in
##                                      sessionStorage; else random per process). If our seat is lost
##                                      (gone longer than the broker's grace), we rejoin automatically
##                                      and the host gives this key its old tank back.
##     --record=PATH                    save everything the host sends us, for --replay
##   --replay=PATH [--replay-speed=2]   watch a recording from the recorded player's seat
## Owned by the netcode workstream (_agents/streams/netcode.md).


func role_name() -> String:
	return "CLIENT"


## Seat lost (away past the broker's grace): rejoin the room with the same player key.
const REJOIN_REASONS := ["grace_expired", "resume_failed"]
const REJOIN_ATTEMPTS := 15
const REJOIN_DELAY_SEC := 1.0
const PLAYER_KEY_STORAGE := "tank_squad_player_key"

## Where we connect (for status text).
var _url := ""
var _player_key := ""
var _rejoin_attempts_left := 0


func start() -> void:
	var game_match := main.game_match
	game_match.simulate = false
	game_match.networked = true
	main.create_local_controller()
	_url = connect_url()
	var peer: MultiplayerPeer
	var err: Error
	if flags.has("replay"):
		var replay := ReplayPeer.new()
		err = replay.open(flags.text("replay"))
		replay.speed = maxf(float(flags.text("replay-speed", "1")), 0.1)
		if err == OK:
			print("TANK_SQUAD_REPLAY %d packets, %.1f s, seat %d" % [replay.record_count(),
					replay.duration_msec() / 1000.0, int(replay.metadata.get("peer_id", 0))])
			replay.finished.connect(func() -> void: print("TANK_SQUAD_REPLAY_FINISHED"))
		_url = flags.text("replay")
		peer = replay
	elif flags.has("join"):
		# A player-hosted match through the broker's relay (HostMode on the other end).
		_url = HostMode.relay_url(flags)
		var relay := _new_relay()
		err = relay.join(_url, flags.text("join"))
		peer = relay
	else:
		var socket := WebSocketMultiplayerPeer.new()
		err = socket.create_client(_url)
		peer = socket
	if err != OK:
		main.hud.set_status("Cannot connect to %s: %s" % [_url, error_string(err)])
		return
	# Methods, not lambdas: a lambda capturing the (refcounted) SceneMultiplayer it's connected to
	# is a reference cycle, reported as leaked resources at exit.
	var multiplayer := main.multiplayer
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	main.hud.set_status("Connecting to %s…" % _url)


func _new_relay() -> RelayPeer:
	var relay := RelayPeer.new()
	HostMode.apply_link_flags(relay, flags)
	relay.player_key = player_key()
	relay.relay_event.connect(_on_relay_event)
	return relay


## Who this player is across sessions (so a host can give a returning player their tank back).
func player_key() -> String:
	if not _player_key.is_empty():
		return _player_key
	_player_key = flags.text("player-key")
	if _player_key.is_empty() and OS.has_feature("web"):
		# Per tab: several tabs in one browser are different players, and a reloaded or restored
		# tab (a phone that killed it) is the same one.
		_player_key = str(JavaScriptBridge.eval("sessionStorage.getItem('%s') || ''" % PLAYER_KEY_STORAGE, true))
	if _player_key.is_empty() or _player_key == "null":
		_player_key = Crypto.new().generate_random_bytes(16).hex_encode()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("sessionStorage.setItem('%s', '%s')" % [PLAYER_KEY_STORAGE, _player_key], true)
	return _player_key


func _rejoin() -> void:
	var relay := _new_relay()
	var err := relay.join(_url, flags.text("join"))
	print("TANK_SQUAD_REJOIN attempt (%s)" % error_string(err))
	main.multiplayer.multiplayer_peer = relay


func _on_connected() -> void:
	_rejoin_attempts_left = 0
	var peer_id := main.multiplayer.get_unique_id()
	var relay := main.multiplayer.multiplayer_peer as RelayPeer
	if relay != null and flags.has("record"):
		var err := relay.start_recording(flags.text("record"))
		print("TANK_SQUAD_RECORDING %s (%s)" % [flags.text("record"), error_string(err)])
	if flags.has("replay"):
		main.hud.set_status("Replay of %s (seat %d)" % [_url.get_file(), peer_id])
	else:
		main.hud.set_status("Connected to %s as peer %d" % [_url, peer_id])
	print("TANK_SQUAD_CONNECTED peer=%d" % peer_id)


func _on_connection_failed() -> void:
	main.hud.set_status("Connection to %s failed" % _url)
	print("TANK_SQUAD_CONNECTION_FAILED")


func _on_server_disconnected() -> void:
	main.hud.set_status("Disconnected from server")
	print("TANK_SQUAD_DISCONNECTED")
	for tank in main.game_match.tanks.get_children():
		tank.queue_free()


func connect_url() -> String:
	var url := flags.text("connect")
	if not url.is_empty():
		return url
	if OS.has_feature("web"):
		# Same origin as the page: works on any host/port, and becomes wss:// under https.
		var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
		return "%s://%s/ws" % ["wss" if secure else "ws", str(JavaScriptBridge.eval("window.location.host", true))]
	return "ws://127.0.0.1:%d" % ServerMode.DEFAULT_PORT


func _on_relay_event(event: String, data: Dictionary) -> void:
	print("TANK_SQUAD_RELAY event=%s %s" % [event, data])
	match event:
		"away":
			main.hud.set_status("Connection lost: reconnecting…")
		"back", "host_back":
			main.hud.set_status("Connected")
		"host_away":
			main.hud.set_status("The host's connection dropped: waiting for them…")
		"closed":
			var reason := String(data.get("reason", ""))
			if flags.has("join") and (reason in REJOIN_REASONS or (_rejoin_attempts_left > 0
					and reason in ["connection_failed", "cannot_connect"])):
				if reason in REJOIN_REASONS:
					_rejoin_attempts_left = REJOIN_ATTEMPTS
				_rejoin_attempts_left -= 1
				if _rejoin_attempts_left >= 0:
					print("TANK_SQUAD_REJOINING reason=%s attempts_left=%d" % [reason, _rejoin_attempts_left])
					main.hud.set_status("Seat lost: rejoining room %s…" % flags.text("join"))
					main.get_tree().create_timer(REJOIN_DELAY_SEC).timeout.connect(_rejoin)
					return
			main.hud.set_status("Match ended: %s" % reason)
			if reason.begins_with("host_"):
				main.hud.show_banner("HOST LEFT")
