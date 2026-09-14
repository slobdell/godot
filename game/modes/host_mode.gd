class_name HostMode
extends ServerMode
## A PLAYER hosts the match through the broker's relay (netcode phase N1): this process runs the
## authoritative simulation like ServerMode, but opens a room on the broker instead of listening
## on a port, so it works from a browser or a phone. Friends join with the room code.
##   --host [--relay=ws://broker]   (browser: ?host, the relay defaults to /relay on the page's host)
##   --no-player                    host without a tank of your own (a relayed dedicated host)
##   --demo / --agent-port          drive the host's tank like OfflineMode
##   --relay-latency=MS --relay-jitter=MS   delay packets we receive (testing bad links; also on --join)
##   --stats-every=SECONDS          TANK_SQUAD_HOST_STATS interval (default 5, 0 = off)
## Prints TANK_SQUAD_ROOM code=XXXXX when the room is open (smoke tests read it).
## Owned by the netcode workstream (_agents/streams/archive/round1/netcode.md).

## `make broker` listens here by default (NET_PORT 9080 + 5).
const DEFAULT_BROKER_PORT := 9085
## A player who drops for good (app killed, grace period over) and returns within this long gets
## their tank back where it was, with the health it had: leaving can't be used to heal or relocate.
const REJOIN_WINDOW_MSEC := 5 * 60 * 1000

## Player key → {team, position, yaw, health, msec} of tanks whose players left.
var _departed := {}


func role_name() -> String:
	return "HOST"


func create_peer() -> MultiplayerPeer:
	var peer := RelayPeer.new()
	var url := relay_url(flags)
	apply_link_flags(peer, flags)
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
		var badge := RoomBadge.new()
		badge.name = "RoomBadge"
		badge.code = code
		main.hud.add_child(badge)
		print("TANK_SQUAD_ROOM code=%s" % code))
	relay.relay_event.connect(_on_relay_event)  # no .bind(relay): the peer holding itself is a leak
	_report_stats_every(relay, flags.integer("stats-every", 5))
	if not flags.has("no-player"):
		main.game_match.has_local_player = true
		main.create_local_controller()
		main.game_match.add_player(main.multiplayer.get_unique_id())


func _on_peer_disconnected(peer_id: int) -> void:
	var relay := main.multiplayer.multiplayer_peer as RelayPeer
	var key := relay.player_key_of(peer_id) if relay != null else ""
	var tank := main.game_match.tanks.get_node_or_null("Tank_%d" % peer_id) as Tank
	if key != "" and tank != null:
		_departed[key] = {"team": tank.team, "position": tank.global_position, "yaw": tank.rotation.y,
				"health": tank.health, "msec": Time.get_ticks_msec()}
	super._on_peer_disconnected(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	var relay := main.multiplayer.multiplayer_peer as RelayPeer
	var key := relay.player_key_of(peer_id) if relay != null else ""
	var saved: Dictionary = _departed.get(key, {})
	_departed.erase(key)
	if saved.is_empty() or Time.get_ticks_msec() - int(saved["msec"]) > REJOIN_WINDOW_MSEC:
		super._on_peer_connected(peer_id)
		return
	var tank := main.game_match.spawn_tank("Tank_%d" % peer_id, peer_id, saved["team"])
	tank.respawn(saved["position"], saved["yaw"])
	var lost: int = tank.max_health - int(saved["health"])
	if lost > 0:
		tank.apply_damage(lost)
	print("peer %d rejoined -> %s (team %s, health %d, same place)" % [peer_id, tank.name,
			Match.TEAM_NAMES[tank.team], tank.health])


func _on_relay_event(event: String, data: Dictionary) -> void:
	var relay := main.multiplayer.multiplayer_peer as RelayPeer
	print("TANK_SQUAD_RELAY event=%s %s" % [event, data])
	match event:
		"away":
			main.hud.set_status("Connection to the relay lost: reconnecting…")
		"back":
			main.hud.set_status("Hosting room %s" % (relay.room_code if relay != null else ""))
		"closed":
			main.hud.set_status("Room closed: %s" % data.get("reason", ""))


## Prints TANK_SQUAD_HOST_STATS every `seconds` (0 = never): frame rate, simulated ticks, and relay
## traffic, for bandwidth measurements and to spot a host that can't keep up (a slow phone or tab).
func _report_stats_every(relay: RelayPeer, seconds: int) -> void:
	if seconds <= 0:
		return
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.autostart = true
	main.add_child(timer)
	var last := {"msec": Time.get_ticks_msec(), "tick": main.game_match.tick, "bytes_out": 0, "bytes_in": 0}
	timer.timeout.connect(func() -> void:
		var now := Time.get_ticks_msec()
		var elapsed := maxf((now - int(last["msec"])) / 1000.0, 0.001)
		print("TANK_SQUAD_HOST_STATS " + JSON.stringify({
				"fps": Engine.get_frames_per_second(),
				"ticks_per_sec": snappedf((main.game_match.tick - int(last["tick"])) / elapsed, 0.1),
				"players": main.multiplayer.get_peers().size(), "tanks": main.game_match.tanks.get_child_count(),
				"out_bytes_per_sec": roundi((int(relay.stats["bytes_out"]) - int(last["bytes_out"])) / elapsed),
				"in_bytes_per_sec": roundi((int(relay.stats["bytes_in"]) - int(last["bytes_in"])) / elapsed)}))
		last["msec"] = now
		last["tick"] = main.game_match.tick
		last["bytes_out"] = relay.stats["bytes_out"]
		last["bytes_in"] = relay.stats["bytes_in"])


## Testing bad links: delay every packet this process receives by --relay-latency ms plus up to
## --relay-jitter ms. Set on host and players alike, the round trip is about twice the latency.
static func apply_link_flags(relay: RelayPeer, p_flags: LaunchFlags) -> void:
	relay.latency_msec = p_flags.integer("relay-latency", 0)
	relay.jitter_msec = p_flags.integer("relay-jitter", 0)


## Where the broker is: --relay=URL, else the page's own host under /relay in a browser.
static func relay_url(p_flags: LaunchFlags) -> String:
	var url := p_flags.text("relay")
	if not url.is_empty():
		return url
	if OS.has_feature("web"):
		var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
		return "%s://%s/relay" % ["wss" if secure else "ws", str(JavaScriptBridge.eval("window.location.host", true))]
	return "ws://127.0.0.1:%d" % DEFAULT_BROKER_PORT

