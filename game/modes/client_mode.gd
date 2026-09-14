class_name ClientMode
extends GameMode
## Networked client: displays replicated state, sends its local controller's commands.
##   --connect[=ws://host:port]         a dedicated server (ServerMode)
##   --join=CODE [--relay=ws://broker]  a player-hosted room through the relay (HostMode)
## Owned by the netcode workstream (_agents/streams/netcode.md).


func role_name() -> String:
	return "CLIENT"


## Where we connect (for status text).
var _url := ""


func start() -> void:
	var game_match := main.game_match
	game_match.simulate = false
	game_match.networked = true
	main.create_local_controller()
	_url = connect_url()
	var peer: MultiplayerPeer
	var err: Error
	if flags.has("join"):
		# A player-hosted match through the broker's relay (HostMode on the other end).
		_url = HostMode.relay_url(flags)
		var relay := RelayPeer.new()
		err = relay.join(_url, flags.text("join"))
		relay.relay_event.connect(_on_relay_event)
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


func _on_connected() -> void:
	var peer_id := main.multiplayer.get_unique_id()
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
			main.hud.set_status("Match ended: %s" % data.get("reason", ""))
