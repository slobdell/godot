class_name RelayPeer
extends MultiplayerPeerExtension
## Godot's high-level multiplayer tunnelled through the Tank Squad broker (server/broker), so a
## PLAYER can host: `MultiplayerSpawner`, `MultiplayerSynchronizer` and RPC code work unchanged,
## and nobody needs an open port (browsers and phones can't accept connections).
##
##   var peer := RelayPeer.new()
##   peer.host("ws://broker/relay")          # or peer.join("ws://broker/relay", "K7QX2")
##   multiplayer.multiplayer_peer = peer
##   peer.room_ready.connect(func(code): show the code to friends)
##
## The host is always peer 1. Players only ever talk to the host (star topology, enforced by the
## broker). Wire format: _agents/streams/archive/round1/netcode.md "N0 broker" (server/broker/src/protocol.mjs).
##
## Surviving flaky links: if the socket drops, the peer stays CONNECTED to Godot and quietly
## reconnects with its resume token for up to the broker's grace period. Reliable packets are kept
## until the broker acknowledges them and are resent after a resume; unreliable ones sent while
## away are dropped (a fresher snapshot is coming anyway).

## Emitted on the host when the broker assigns the room's join code.
signal room_ready(code: String)
## Link events for the UI and logs: "away", "back" (our own socket), "host_away", "host_back",
## "peer_away", "peer_back" (data.peer_id), "closed" (data.reason).
signal relay_event(event: String, data: Dictionary)

const PROTOCOL_VERSION := 1
const HEADER_BYTES := 9
const HOST_ID := 1
const MAX_FRAME_BYTES := 64 * 1024
## Unacknowledged reliable bytes we keep for retransmission before giving up on the link.
const RETAIN_LIMIT_BYTES := 4 * 1024 * 1024
const ACK_EVERY_MSEC := 250
## With nothing received for this long, ask the broker for a pong...
const PING_AFTER_QUIET_MSEC := 2000
## ...and with nothing for this long, assume the socket is dead and reconnect.
const DEAD_AFTER_QUIET_MSEC := 8000
const RECONNECT_EVERY_MSEC := 1000
## Used until the broker tells us its grace period.
const DEFAULT_GRACE_MSEC := 30000
## Broker close codes after which reconnecting is pointless (protocol.mjs CLOSE).
const FATAL_CLOSE_CODES := [4000, 4001, 4003, 4004, 4005, 4007, 4008, 4009, 4010]

enum Role { NONE, HOST, CLIENT }

var role := Role.NONE
## Client: an opaque key kept across sessions (see ClientMode), sent on join so the host can give
## a returning player their old tank. Host: see player_key_of().
var player_key := ""
var url := ""
var room_code := ""
## Why the session ended ("" while it's alive).
var close_reason := ""

## Testing aid: extra delay (ms) and random jitter (0..ms) applied to every packet we receive.
## Order is preserved (it's a WebSocket). With both peers set to L, round trip ≈ 2L.
var latency_msec := 0
var jitter_msec := 0

## Counters for bandwidth measurements (frames and bytes, including our 9-byte header).
var stats := {"frames_in": 0, "bytes_in": 0, "frames_out": 0, "bytes_out": 0, "resumes": 0, "dropped_out": 0}

var _recording: FileAccess
var _recording_start_msec := 0

var _ws: WebSocketPeer
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _unique_id := 0
var _token := ""
var _seated := false
var _greeted := false
var _refusing := false
var _target_peer := 0
var _transfer_mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _transfer_channel := 0
## Host: ids of connected players.
var _peers := {}
## Host: peer id → player key (from the broker).
var _players := {}

## Received packets waiting for Godot: [sender, flags, payload], consumed from _incoming_head.
var _incoming: Array = []
var _incoming_head := 0
## Latency injection queue: [release_msec, packet].
var _delayed: Array = []
var _last_release_msec := 0
var _rng := RandomNumberGenerator.new()

var _out_seq := 0
## [seq, frame] of reliable frames the broker hasn't acknowledged.
var _retained: Array = []
var _retained_bytes := 0
var _in_seq := 0
var _acked_in_seq := 0
var _last_ack_msec := 0
var _last_receive_msec := 0
var _last_ping_msec := 0

var _away := false
var _away_since_msec := 0
var _next_reconnect_msec := 0
var _grace_msec := DEFAULT_GRACE_MSEC
## Testing aid: don't reconnect before this time (see simulate_drop).
var _hold_reconnect_until_msec := 0


## Open a room on the broker at `broker_url`; `room_ready` fires with its code.
func host(broker_url: String) -> Error:
	role = Role.HOST
	_unique_id = HOST_ID
	return _start(broker_url)


## Join the room `code` on the broker at `broker_url`.
func join(broker_url: String, code: String) -> Error:
	role = Role.CLIENT
	room_code = code.strip_edges().to_upper()
	_unique_id = generate_unique_id()  # proposed; the broker keeps it unless it's taken
	return _start(broker_url)


func _start(broker_url: String) -> Error:
	url = broker_url
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	return _open_socket()


## Record every packet the host sends us from now on, for ReplayPeer (`--record=PATH`).
func start_recording(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_recording = FileAccess.open(path, FileAccess.WRITE)
	if _recording == null:
		return FileAccess.get_open_error()
	_recording_start_msec = Time.get_ticks_msec()
	_recording.store_line(ReplayPeer.MAGIC)
	_recording.store_line(JSON.stringify({"peer_id": _unique_id, "room": room_code}))
	return OK


## Testing aid: cut our socket now (as if the phone lost signal) and stay offline `seconds`.
func simulate_drop(seconds: float) -> void:
	_hold_reconnect_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	if _ws != null:
		_ws.close(4100, "simulated drop")
	_go_away()


func is_away() -> bool:
	return _away


# ---- MultiplayerPeerExtension ---------------------------------------------------------

func _poll() -> void:
	var now := Time.get_ticks_msec()
	if _ws != null:
		_ws.poll()
		match _ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				_on_socket_open(now)
			WebSocketPeer.STATE_CLOSED:
				_on_socket_closed(_ws.get_close_code(), now)
	elif _away and now >= _next_reconnect_msec and now >= _hold_reconnect_until_msec:
		_next_reconnect_msec = now + RECONNECT_EVERY_MSEC
		_open_socket()
	if _away and _status != MultiplayerPeer.CONNECTION_DISCONNECTED and now - _away_since_msec > _grace_msec:
		_end_session("grace_expired")
	_release_delayed(now)


func _get_available_packet_count() -> int:
	return _incoming.size() - _incoming_head


func _get_packet_script() -> PackedByteArray:
	if _incoming_head >= _incoming.size():
		return PackedByteArray()
	var packet: Array = _incoming[_incoming_head]
	_incoming[_incoming_head] = null
	_incoming_head += 1
	if _incoming_head >= 256 and _incoming_head * 2 >= _incoming.size():
		_incoming = _incoming.slice(_incoming_head)
		_incoming_head = 0
	return packet[2]


func _get_packet_peer() -> int:
	return _incoming[_incoming_head][0] if _incoming_head < _incoming.size() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	if _incoming_head >= _incoming.size():
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return (_incoming[_incoming_head][1] & 0b11) as MultiplayerPeer.TransferMode


func _get_packet_channel() -> int:
	return _incoming[_incoming_head][1] >> 2 if _incoming_head < _incoming.size() else 0


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	if buffer.size() > _get_max_packet_size():
		return ERR_INVALID_PARAMETER
	# Players only have a link to the host, like Godot's own client peers.
	var target := HOST_ID if role == Role.CLIENT else _target_peer
	var flags := (_transfer_mode & 0b11) | ((_transfer_channel & 0b111111) << 2)
	var reliable := _transfer_mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE
	if not reliable and not _link_up():
		stats["dropped_out"] += 1
		return OK
	_out_seq += 1
	var frame := encode_frame(target, flags, _out_seq, buffer)
	if reliable:
		_retained.append([_out_seq, frame])
		_retained_bytes += frame.size()
		if _retained_bytes > RETAIN_LIMIT_BYTES:
			_end_session("retransmit_buffer_full")
			return ERR_OUT_OF_MEMORY
	if _link_up():
		_send_frame(frame)
	return OK


func _get_max_packet_size() -> int:
	return MAX_FRAME_BYTES - HEADER_BYTES


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode


func _set_target_peer(peer: int) -> void:
	_target_peer = peer


func _is_server() -> bool:
	return role == Role.HOST


func _get_unique_id() -> int:
	return _unique_id


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable
	if role == Role.HOST and _link_up():
		_send_control({"op": "set_open", "open": not enable})


func _is_refusing_new_connections() -> bool:
	return _refusing


func _disconnect_peer(peer: int, force: bool) -> void:
	if role != Role.HOST or not _peers.has(peer):
		return
	if _link_up():
		_send_control({"op": "kick", "peer_id": peer})
	if force:
		_forget_peer(peer)


func _close() -> void:
	if _link_up():
		_send_control({"op": "leave"})
	if _ws != null:
		_ws.close(1000, "leaving")
	_end_session("closed")


# ---- Socket lifecycle ----------------------------------------------------------------

func _open_socket() -> Error:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = RETAIN_LIMIT_BYTES
	_ws.outbound_buffer_size = RETAIN_LIMIT_BYTES
	_ws.max_queued_packets = 16384
	_greeted = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		if not _seated:
			_end_session("cannot_connect")
	return err


func _on_socket_open(now: int) -> void:
	if not _greeted:
		_greeted = true
		_last_receive_msec = now
		if _seated:
			_send_control({"op": "resume", "token": _token, "last_seq": _in_seq})
		elif role == Role.HOST:
			_send_control({"op": "host", "version": PROTOCOL_VERSION})
		else:
			_send_control({"op": "join", "version": PROTOCOL_VERSION, "room": room_code, "peer_id": _unique_id,
					"player": player_key})
	while _ws != null and _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		_last_receive_msec = now
		if _ws.was_string_packet():
			var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if parsed is Dictionary:
				on_control(parsed)
		else:
			on_frame(packet, now)
	if _ws == null or not _link_up():
		return
	if _in_seq != _acked_in_seq and now - _last_ack_msec >= ACK_EVERY_MSEC:
		_acked_in_seq = _in_seq
		_last_ack_msec = now
		_send_control({"op": "ack", "seq": _in_seq})
	var quiet := now - _last_receive_msec
	if quiet > DEAD_AFTER_QUIET_MSEC:
		_ws.close(4101, "no traffic")
		_ws = null
		_go_away()
	elif quiet > PING_AFTER_QUIET_MSEC and now - _last_ping_msec > PING_AFTER_QUIET_MSEC:
		_last_ping_msec = now
		_send_control({"op": "ping", "t": now})


func _on_socket_closed(code: int, now: int) -> void:
	_ws = null
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if not _seated:
		_end_session("connection_failed" if code != 4003 else "refused")
	elif code in FATAL_CLOSE_CODES:
		_end_session("closed_by_broker_%d" % code)
	else:
		_go_away()
		_next_reconnect_msec = maxi(_next_reconnect_msec, now)


func _go_away() -> void:
	_ws = null
	if _away or not _seated:
		return
	_away = true
	_away_since_msec = Time.get_ticks_msec()
	_next_reconnect_msec = _away_since_msec
	relay_event.emit("away", {})


func _link_up() -> bool:
	return _ws != null and _seated and not _away and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _end_session(reason: String) -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	close_reason = reason
	_away = false
	if _ws != null:
		_ws.close(1000, reason)
		_ws = null
	var was_connected := _status == MultiplayerPeer.CONNECTION_CONNECTED
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if was_connected:
		if role == Role.HOST:
			for peer_id in _peers.keys():
				_forget_peer(peer_id)
		else:
			peer_disconnected.emit(HOST_ID)
	_retained.clear()
	_retained_bytes = 0
	if _recording != null:
		_recording.close()
		_recording = null
	relay_event.emit("closed", {"reason": reason})


# ---- Broker messages (public so tests can feed them without a socket) --------------------

func on_control(msg: Dictionary) -> void:
	match String(msg.get("op", "")):
		"hosted":
			_seat(msg)
			room_code = String(msg.get("room", ""))
			room_ready.emit(room_code)
		"joined":
			_seat(msg)
			room_code = String(msg.get("room", room_code))
			peer_connected.emit(HOST_ID)
		"resumed":
			_on_resumed(msg)
		"ack":
			_trim_retained(int(msg.get("seq", 0)))
		"peer_joined":
			_players[int(msg.get("peer_id", 0))] = String(msg.get("player", ""))
			_add_peer(int(msg.get("peer_id", 0)))
		"peer_left":
			_forget_peer(int(msg.get("peer_id", 0)))
		"peer_away", "peer_back":
			relay_event.emit(String(msg["op"]), {"peer_id": int(msg.get("peer_id", 0))})
		"host_away", "host_back":
			relay_event.emit(String(msg["op"]), {})
		"host_left":
			_end_session(String(msg.get("reason", "host_left")))
		"error":
			push_warning("relay: broker error %s: %s" % [msg.get("code", "?"), msg.get("message", "")])
			if String(msg.get("code", "")) == "resume_failed":
				_end_session("resume_failed")
			elif not _seated:
				_end_session(String(msg.get("code", "refused")))


func on_frame(frame: PackedByteArray, now: int = Time.get_ticks_msec()) -> void:
	if frame.size() < HEADER_BYTES:
		return
	stats["frames_in"] += 1
	stats["bytes_in"] += frame.size()
	var seq := frame.decode_u32(5)
	if seq <= _in_seq:
		return  # already delivered before a resume
	_in_seq = seq
	var packet := [frame.decode_s32(0), frame.decode_u8(4), frame.slice(HEADER_BYTES)]
	if _recording != null:
		_recording.store_32(now - _recording_start_msec)
		_recording.store_32(packet[0])
		_recording.store_8(packet[1])
		_recording.store_32((packet[2] as PackedByteArray).size())
		_recording.store_buffer(packet[2])
	if latency_msec <= 0 and jitter_msec <= 0 and _delayed.is_empty():
		_incoming.append(packet)
		return
	var release := now + latency_msec + (_rng.randi_range(0, jitter_msec) if jitter_msec > 0 else 0)
	_last_release_msec = maxi(_last_release_msec, release)
	_delayed.append([_last_release_msec, packet])


func _seat(msg: Dictionary) -> void:
	_seated = true
	_token = String(msg.get("token", ""))
	_unique_id = int(msg.get("peer_id", _unique_id))
	_grace_msec = int(msg.get("grace_ms", DEFAULT_GRACE_MSEC))
	_status = MultiplayerPeer.CONNECTION_CONNECTED
	if _refusing and role == Role.HOST:
		_send_control({"op": "set_open", "open": false})


func _on_resumed(msg: Dictionary) -> void:
	var was_away := _away
	_away = false
	stats["resumes"] += 1
	var broker_has := int(msg.get("last_seq", 0))
	_trim_retained(broker_has)
	for entry in _retained:
		_send_frame(entry[1])
	for peer_id in msg.get("players", {}):
		_players[int(peer_id)] = String(msg["players"][peer_id])
	if role == Role.HOST and msg.has("peers"):
		# Joins and leaves while we were away were never delivered to us: reconcile.
		var present := {}
		for peer_id in msg["peers"]:
			present[int(peer_id)] = true
			_add_peer(int(peer_id))
		for peer_id in _peers.keys():
			if not present.has(peer_id):
				_forget_peer(peer_id)
	if was_away:
		relay_event.emit("back", {"away_msec": Time.get_ticks_msec() - _away_since_msec})


func _add_peer(peer_id: int) -> void:
	if role != Role.HOST or peer_id <= HOST_ID or _peers.has(peer_id):
		return
	_peers[peer_id] = true
	peer_connected.emit(peer_id)


func _forget_peer(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	_peers.erase(peer_id)
	# Control messages act immediately but packets wait in queues: drop the departed peer's packets,
	# or Godot would read packets from a peer it was just told is gone.
	var kept: Array = []
	for i in range(_incoming_head, _incoming.size()):
		if _incoming[i][0] != peer_id:
			kept.append(_incoming[i])
	_incoming = kept
	_incoming_head = 0
	_delayed = _delayed.filter(func(entry: Array) -> bool: return entry[1][0] != peer_id)
	peer_disconnected.emit(peer_id)


func _trim_retained(acked_seq: int) -> void:
	var drop := 0
	while drop < _retained.size() and int(_retained[drop][0]) <= acked_seq:
		_retained_bytes -= (_retained[drop][1] as PackedByteArray).size()
		drop += 1
	if drop > 0:
		_retained = _retained.slice(drop)


## Host: the player key a player joined with ("" if none). Still valid inside peer_disconnected.
func player_key_of(peer_id: int) -> String:
	return String(_players.get(peer_id, ""))


func retained_count() -> int:
	return _retained.size()


func _release_delayed(now: int) -> void:
	var released := 0
	while released < _delayed.size() and int(_delayed[released][0]) <= now:
		_incoming.append(_delayed[released][1])
		released += 1
	if released > 0:
		_delayed = _delayed.slice(released)


func _send_frame(frame: PackedByteArray) -> void:
	stats["frames_out"] += 1
	stats["bytes_out"] += frame.size()
	_ws.send(frame, WebSocketPeer.WRITE_MODE_BINARY)


func _send_control(msg: Dictionary) -> void:
	if _ws != null:
		_ws.send_text(JSON.stringify(msg))


static func encode_frame(peer: int, flags: int, seq: int, payload: PackedByteArray) -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(HEADER_BYTES)
	frame.encode_s32(0, peer)
	frame.encode_u8(4, flags)
	frame.encode_u32(5, seq)
	frame.append_array(payload)
	return frame
