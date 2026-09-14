class_name LobbyMode
extends GameMode
## Touch-first multiplayer entry (netcode): `--lobby` (browser `?lobby`). Shows LobbyPanel; HOST
## turns this process into HostMode, JOIN into ClientMode with --join=CODE, in place (no reload).
## A failed join (no such room, room full) comes back to the lobby with the reason.
## Owned by the netcode workstream (_agents/streams/archive/round1/netcode.md).

var panel: LobbyPanel


func role_name() -> String:
	return "LOBBY"


func start() -> void:
	main.game_match.has_local_player = false
	main.hud.set_status("Multiplayer lobby")
	_show_panel("")


func _show_panel(status: String) -> void:
	panel = LobbyPanel.new()
	panel.name = "Lobby"
	main.hud.add_child(panel)
	panel.set_status(status)
	panel.host_requested.connect(_host)
	panel.join_requested.connect(_join)


func _host() -> void:
	flags.values["host"] = ""
	_switch_to(HostMode.new())


func _join(code: String) -> void:
	flags.values["join"] = code
	var client := ClientMode.new()
	_switch_to(client)
	var on_failed := _on_join_failed.bind(code)
	main.multiplayer.connection_failed.connect(on_failed, CONNECT_ONE_SHOT)
	# Once in, later reconnection failures belong to ClientMode (it rejoins), not the lobby.
	main.multiplayer.connected_to_server.connect(func() -> void:
		if main.multiplayer.connection_failed.is_connected(on_failed):
			main.multiplayer.connection_failed.disconnect(on_failed), CONNECT_ONE_SHOT)


func _switch_to(next: GameMode) -> void:
	# Modes are RefCounted and main.mode is about to point elsewhere: keep the lobby alive so a
	# failed join can come back to it.
	main.set_meta("lobby_mode", self)
	panel.queue_free()
	next.main = main
	next.flags = flags
	main.mode = next
	next.start()
	print("TANK_SQUAD_READY role=%s flags=%s" % [next.role_name(), flags.values])


func _on_join_failed(code: String) -> void:
	var relay := main.multiplayer.multiplayer_peer as RelayPeer
	var reason := relay.close_reason if relay != null else "connection_failed"
	main.multiplayer.multiplayer_peer = null
	flags.values.erase("join")
	if main.local_controller != null:
		main.local_controller.queue_free()
		main.local_controller = null
	main.mode = self
	var messages := {"room_not_found": "No room %s. Check the code with your host." % code,
			"room_full": "Room %s is full." % code, "room_closed": "Room %s isn't taking players." % code}
	_show_panel(messages.get(reason, "Couldn't join %s (%s)." % [code, reason]))
