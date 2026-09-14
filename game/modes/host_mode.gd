class_name HostMode
extends ServerMode
## A PLAYER hosts the match through the broker's relay (netcode phase N1): this process runs the
## authoritative simulation like ServerMode, but opens a room on the broker instead of listening
## on a port, so it works from a browser or a phone. Friends join with the room code.
##   --host [--relay=ws://broker]   (browser: ?host, the relay defaults to /relay on the page's host)
##   --no-player                    host without a tank of your own (a relayed dedicated host)
##   --demo / --agent-port          drive the host's tank like OfflineMode
## Prints TANK_SQUAD_ROOM code=XXXXX when the room is open (smoke tests read it).
## Owned by the netcode workstream (_agents/streams/netcode.md).

## `make broker` listens here by default (NET_PORT 9080 + 5).
const DEFAULT_BROKER_PORT := 9085


func role_name() -> String:
	return "HOST"


func create_peer() -> MultiplayerPeer:
	var peer := RelayPeer.new()
	var url := relay_url(flags)
	var err := peer.host(url)
	if err != OK:
		push_error("host: cannot reach the broker at %s: %s" % [url, error_string(err)])
		return null
	return peer


func started(peer: MultiplayerPeer) -> void:
	var relay := peer as RelayPeer
	main.hud.set_status("Opening a room on %s…" % relay.url)
	relay.room_ready.connect(func(code: String) -> void:
		main.hud.set_status("Hosting room %s: friends join with this code" % code)
		print("TANK_SQUAD_ROOM code=%s" % code))
	relay.relay_event.connect(_on_relay_event.bind(relay))
	if not flags.has("no-player"):
		main.game_match.has_local_player = true
		main.create_local_controller()
		main.game_match.add_player(main.multiplayer.get_unique_id())


func _on_relay_event(event: String, data: Dictionary, relay: RelayPeer) -> void:
	print("TANK_SQUAD_RELAY event=%s %s" % [event, data])
	match event:
		"away":
			main.hud.set_status("Connection to the relay lost: reconnecting…")
		"back":
			main.hud.set_status("Hosting room %s" % relay.room_code)
		"closed":
			main.hud.set_status("Room closed: %s" % data.get("reason", ""))


## Where the broker is: --relay=URL, else the page's own host under /relay in a browser.
static func relay_url(p_flags: LaunchFlags) -> String:
	var url := p_flags.text("relay")
	if not url.is_empty():
		return url
	if OS.has_feature("web"):
		var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
		return "%s://%s/relay" % ["wss" if secure else "ws", str(JavaScriptBridge.eval("window.location.host", true))]
	return "ws://127.0.0.1:%d" % DEFAULT_BROKER_PORT

