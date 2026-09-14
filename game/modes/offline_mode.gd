class_name OfflineMode
extends GameMode
## Your tank (keyboard/mouse, --demo, or --agent-port) against --bots server bots. No network.

const DEFAULT_BOTS := 1


func role_name() -> String:
	return "OFFLINE"


func start() -> void:
	main.create_local_controller()
	main.hud.set_status("Offline")
	# The offline MultiplayerPeer is its own server, so the normal spawn path works.
	main.game_match.add_player(main.multiplayer.get_unique_id())
	for i in flags.integer("bots", DEFAULT_BOTS):
		main.game_match.add_bot()
