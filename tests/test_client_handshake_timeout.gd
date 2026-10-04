extends TestCase
## Round 17 (sim, for ship's web-net-smoke): the client's WebSocket waits long enough for a browser booting at ~2 fps
## (Godot's 3 s default dropped connections the server had accepted).


func test_the_client_socket_waits_for_a_slow_browser() -> void:
	var socket := ClientMode.new_socket()
	assert_eq(socket.handshake_timeout, ClientMode.HANDSHAKE_TIMEOUT, "the socket the client connects with")
	assert_true(ClientMode.HANDSHAKE_TIMEOUT >= 10.0, "well past the 3 s default (%.0f s)" % ClientMode.HANDSHAKE_TIMEOUT)
