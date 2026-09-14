class_name ClientMode
extends GameMode
## Networked client: displays replicated state, sends its local controller's commands.
## Owned by the netcode workstream (_agents/streams/netcode.md).


func role_name() -> String:
	return "CLIENT"


func start() -> void:
	var game_match := main.game_match
	var multiplayer := main.multiplayer
	game_match.simulate = false
	game_match.networked = true
	main.create_local_controller()
	var url := connect_url()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		main.hud.set_status("Cannot connect to %s: %s" % [url, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		main.hud.set_status("Connected to %s as peer %d" % [url, multiplayer.get_unique_id()])
		print("TANK_SQUAD_CONNECTED peer=%d" % multiplayer.get_unique_id()))
	multiplayer.connection_failed.connect(func() -> void:
		main.hud.set_status("Connection to %s failed" % url))
	multiplayer.server_disconnected.connect(func() -> void:
		main.hud.set_status("Disconnected from server")
		for tank in game_match.tanks.get_children():
			tank.queue_free())
	main.hud.set_status("Connecting to %s…" % url)


func connect_url() -> String:
	var url := flags.text("connect")
	if not url.is_empty():
		return url
	if OS.has_feature("web"):
		# Same origin as the page: works on any host/port, and becomes wss:// under https.
		var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
		return "%s://%s/ws" % ["wss" if secure else "ws", str(JavaScriptBridge.eval("window.location.host", true))]
	return "ws://127.0.0.1:%d" % ServerMode.DEFAULT_PORT
