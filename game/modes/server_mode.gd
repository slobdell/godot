class_name ServerMode
extends GameMode
## Dedicated authoritative server over WebSockets: one tank per connecting client, plus --bots.
## Owned by the netcode workstream (_agents/streams/netcode.md). HostMode reuses it through the relay.

const DEFAULT_PORT := 9080


func role_name() -> String:
	return "SERVER"


func start() -> void:
	var game_match := main.game_match
	var multiplayer := main.multiplayer
	game_match.networked = true
	game_match.has_local_player = false
	var peer := create_peer()
	if peer == null:
		main.get_tree().quit(1)
		return
	# Clients may only talk to the server, never relay messages to each other.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(peer_id: int) -> void:
		var tank := game_match.add_player(peer_id)
		print("peer %d joined -> %s (team %s)" % [peer_id, tank.name, Match.TEAM_NAMES[tank.team]]))
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void:
		game_match.remove_player(peer_id)
		print("peer %d left" % peer_id))
	started(peer)
	for i in flags.integer("bots", 0):
		game_match.add_bot()


## The transport. Returns null (after reporting why) if it can't be created.
func create_peer() -> MultiplayerPeer:
	var port := flags.integer("server", DEFAULT_PORT)
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("server: cannot listen on port %d: %s" % [port, error_string(err)])
		return null
	return peer


## Called once the peer is installed, before bots spawn.
func started(_peer: MultiplayerPeer) -> void:
	var port := flags.integer("server", DEFAULT_PORT)
	main.hud.set_status("Server on port %d" % port)
	print("TANK_SQUAD_LISTENING port=%d" % port)
	print("  (WebSocket only. Browsers: `make play`, or `make serve-web` and open http://localhost:8060/?connect)")
