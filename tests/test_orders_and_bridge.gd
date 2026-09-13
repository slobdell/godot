extends TestCase
## Order validation (orders may come from an external process) and the agent
## bridge's HTTP parsing + browser/DNS-rebinding protection.


func test_valid_orders_are_accepted() -> void:
	var orders := OrderController.new()
	assert_eq(orders.set_orders({"type": "move_to", "x": 10, "z": -20.5}, {"type": "target", "name": "Bot_1"}),
			"", "well-formed move_to + target are accepted")
	assert_eq(orders.move_order["type"], "move_to", "move order replaced")
	assert_eq(orders.weapon_order["name"], "Bot_1", "weapon order replaced")
	orders.free()


func test_invalid_orders_are_rejected_without_side_effects() -> void:
	var orders := OrderController.new()
	assert_true(orders.set_orders({"type": "teleport"}, null) != "", "unknown move type is rejected")
	assert_true(orders.set_orders({"type": "move_to", "x": 1}, null) != "", "move_to without z is rejected")
	assert_true(orders.set_orders({"type": "drive", "throttle": "fast", "turn": 0, "seconds": 1}, null) != "",
			"non-numeric throttle is rejected")
	assert_true(orders.set_orders(null, {"type": "target", "name": 7}) != "", "target needs a string name")
	assert_true(orders.set_orders({"type": "stop"}, {"type": "nuke"}) != "",
			"a bad weapon order rejects the whole request")
	assert_eq(orders.move_order["type"], "stop", "rejected requests change nothing")
	assert_eq(orders.weapon_order["type"], "hold_fire", "rejected requests change nothing")
	orders.free()


func test_http_request_parsing_waits_for_the_full_body() -> void:
	var head := "POST /orders HTTP/1.1\r\nHost: 127.0.0.1:8765\r\nContent-Length: 17\r\n\r\n"
	assert_true(AgentBridge._parse_request((head + "{\"move\":").to_ascii_buffer()).is_empty(),
			"a partial body is not a request yet")
	var request := AgentBridge._parse_request((head + "{\"move\": {}}     trailing").to_ascii_buffer())
	assert_eq(request.get("method"), "POST", "method parsed")
	assert_eq(request.get("path"), "/orders", "path parsed")
	assert_eq(request.get("headers", {}).get("host"), "127.0.0.1:8765", "headers are lower-cased keys")
	assert_eq(request.get("body"), "{\"move\": {}}     ", "body is exactly Content-Length (17) bytes")


func test_bridge_refuses_browser_and_foreign_host_requests() -> void:
	var bridge := AgentBridge.new()
	bridge.port = 8765
	bridge.orders = OrderController.new()
	var ok_headers := {"host": "127.0.0.1:8765"}
	assert_eq(bridge._handle({"method": "GET", "path": "/", "headers": ok_headers, "body": ""})[0], 200,
			"a local tool may call the bridge")
	var from_browser := {"host": "127.0.0.1:8765", "origin": "https://evil.example"}
	assert_eq(bridge._handle({"method": "POST", "path": "/orders", "headers": from_browser, "body": "{}"})[0], 403,
			"a web page can't drive your tank (Origin header present)")
	var rebinding := {"host": "evil.example:8765"}
	assert_eq(bridge._handle({"method": "GET", "path": "/state", "headers": rebinding, "body": ""})[0], 403,
			"DNS rebinding is refused (foreign Host header)")
	bridge.orders.free()
	bridge.free()
