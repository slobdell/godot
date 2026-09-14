extends TestCase
## RelayPeer (game/network/relay_peer.gd) without a socket: broker messages are fed straight into
## on_control()/on_frame(). The real round trip is `make relay-smoke` / `make relay-drop-smoke`.


func _client() -> RelayPeer:
	var peer := RelayPeer.new()
	peer.role = RelayPeer.Role.CLIENT
	peer.on_control({"op": "joined", "room": "K7QX2", "peer_id": 4242, "token": "t", "grace_ms": 5000})
	return peer


func _host() -> RelayPeer:
	var peer := RelayPeer.new()
	peer.role = RelayPeer.Role.HOST
	peer.on_control({"op": "hosted", "room": "K7QX2", "peer_id": 1, "token": "t"})
	return peer


func _frame(sender: int, mode: int, channel: int, seq: int, payload: Array) -> PackedByteArray:
	return RelayPeer.encode_frame(sender, mode | (channel << 2), seq, PackedByteArray(payload))


func test_frame_header_matches_the_broker_wire_format() -> void:
	# Same bytes as server/broker/src/protocol.mjs encodeFrame(-2, flagsFor(2, 1), 7, [0xAB]).
	var frame := RelayPeer.encode_frame(-2, 2 | (1 << 2), 7, PackedByteArray([0xAB]))
	assert_eq(frame, PackedByteArray([0xFE, 0xFF, 0xFF, 0xFF, 0x06, 0x07, 0x00, 0x00, 0x00, 0xAB]),
			"int32 LE target, flags byte, uint32 LE sequence, then the payload")


func test_joining_connects_to_the_host_with_the_brokers_peer_id() -> void:
	var peer := RelayPeer.new()
	peer.role = RelayPeer.Role.CLIENT
	var connected: Array[int] = []
	peer.peer_connected.connect(func(id: int) -> void: connected.append(id))
	peer.on_control({"op": "joined", "room": "K7QX2", "peer_id": 4242, "token": "t"})
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED, "joined means connected")
	assert_eq(peer.get_unique_id(), 4242, "the broker's id wins (it replaces a taken proposal)")
	assert_eq(connected, [1] as Array[int], "Godot is told the server (peer 1) connected")
	assert_true(not peer._is_server(), "a player is not the server")


func test_host_learns_about_players_joining_and_leaving() -> void:
	var peer := _host()
	var events: Array[String] = []
	peer.peer_connected.connect(func(id: int) -> void: events.append("+%d" % id))
	peer.peer_disconnected.connect(func(id: int) -> void: events.append("-%d" % id))
	peer.on_control({"op": "peer_joined", "peer_id": 9})
	peer.on_control({"op": "peer_joined", "peer_id": 9})
	peer.on_control({"op": "peer_left", "peer_id": 9, "reason": "left"})
	assert_eq(events, ["+9", "-9"] as Array[String], "one join and one leave, duplicates ignored")
	assert_true(peer._is_server(), "the host is the server")
	assert_eq(peer.room_code, "K7QX2", "the host knows its room code")


func test_packets_come_out_in_order_with_sender_mode_and_channel() -> void:
	var peer := _client()
	peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, 3, 1, [10]))
	peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 2, [20, 21]))
	assert_eq(peer.get_available_packet_count(), 2, "both packets are queued")
	assert_eq(peer.get_packet_peer(), 1, "the sender is the host")
	assert_eq(peer.get_packet_mode(), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "mode of the first packet")
	assert_eq(peer.get_packet_channel(), 3, "channel of the first packet")
	assert_eq(peer.get_packet(), PackedByteArray([10]), "first payload")
	assert_eq(peer.get_packet_mode(), MultiplayerPeer.TRANSFER_MODE_RELIABLE, "mode now describes the second")
	assert_eq(peer.get_packet(), PackedByteArray([20, 21]), "second payload")
	assert_eq(peer.get_available_packet_count(), 0, "queue drained")


func test_a_frame_seen_before_a_resume_is_not_delivered_twice() -> void:
	var peer := _client()
	peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 5, [1]))
	peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 5, [1]))
	peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 4, [0]))
	assert_eq(peer.get_available_packet_count(), 1, "sequence numbers at or below the last one are dropped")


func test_injected_latency_holds_packets_and_keeps_their_order() -> void:
	var peer := _client()
	peer.latency_msec = 150
	peer.jitter_msec = 100
	for seq in range(1, 21):
		peer.on_frame(_frame(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, seq, [seq]), 1000 + seq)
	peer._release_delayed(1100)
	assert_eq(peer.get_available_packet_count(), 0, "nothing arrives before the latency has passed")
	peer._release_delayed(1000 + 20 + 150 + 100)
	assert_eq(peer.get_available_packet_count(), 20, "everything has arrived after latency + max jitter")
	var order: Array[int] = []
	while peer.get_available_packet_count() > 0:
		order.append(peer.get_packet()[0])
	var sorted := order.duplicate()
	sorted.sort()
	assert_eq(order, sorted, "jitter never reorders packets (it's a WebSocket)")


func test_reliable_packets_are_kept_until_acknowledged() -> void:
	var peer := _host()
	peer.set_target_peer(0)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	for i in 3:
		peer.put_packet(PackedByteArray([i]))
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.put_packet(PackedByteArray([99]))
	assert_eq(peer.retained_count(), 3, "three reliable packets await an ack; the unreliable one isn't kept")
	assert_eq(peer.stats["dropped_out"], 1, "an unreliable packet with no link is dropped, not queued")
	peer.on_control({"op": "ack", "seq": 2})
	assert_eq(peer.retained_count(), 1, "an ack releases everything up to its sequence number")


func test_host_resume_reconciles_players_who_came_and_went_while_away() -> void:
	var peer := _host()
	peer.on_control({"op": "peer_joined", "peer_id": 5})
	peer.on_control({"op": "peer_joined", "peer_id": 6})
	var events: Array[String] = []
	peer.peer_connected.connect(func(id: int) -> void: events.append("+%d" % id))
	peer.peer_disconnected.connect(func(id: int) -> void: events.append("-%d" % id))
	peer.on_control({"op": "resumed", "room": "K7QX2", "peer_id": 1, "last_seq": 0, "peers": [6, 7]})
	events.sort()
	assert_eq(events, ["+7", "-5"] as Array[String], "7 joined and 5 left during the outage")


func test_host_leaving_ends_the_session_for_a_player() -> void:
	var peer := _client()
	var gone: Array[int] = []
	peer.peer_disconnected.connect(func(id: int) -> void: gone.append(id))
	peer.on_control({"op": "host_left", "reason": "host_timeout"})
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "the match is over")
	assert_eq(gone, [1] as Array[int], "Godot is told the server went away")
	assert_eq(peer.close_reason, "host_timeout", "the reason is kept for the UI")


func test_packets_from_a_player_who_left_are_discarded() -> void:
	var peer := _host()
	peer.on_control({"op": "peer_joined", "peer_id": 5})
	peer.on_control({"op": "peer_joined", "peer_id": 6})
	peer.on_frame(_frame(5, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 1, [1]))
	peer.on_frame(_frame(6, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 2, [2]))
	peer.on_frame(_frame(5, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0, 3, [3]))
	peer.on_control({"op": "peer_left", "peer_id": 5, "reason": "left"})
	assert_eq(peer.get_available_packet_count(), 1, "only the remaining player's packet is left")
	assert_eq(peer.get_packet_peer(), 6, "Godot never reads a packet from a peer it was told is gone")
