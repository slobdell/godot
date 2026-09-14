class_name AgentBridge
extends Node
## Lets an external agent (Claude, via tools/agent.py) command this peer's tank.
##
## A deliberately tiny HTTP/1.1 server bound to 127.0.0.1. It turns requests
## into standing orders on an OrderController and answers with observations
## built only from what this peer can see. See _agents/agent_bridge.md.
##
##   GET  /state       observation JSON (me, other tanks, score, orders)
##   GET  /map         arena bounds + obstacle boxes
##   POST /orders      {"move": {...}, "weapon": {...}, "reflexes": [...]}  (any may be omitted)
##   POST /screenshot  save the current frame (windowed clients only), returns its path

const DEFAULT_PORT := 8765
const MAX_REQUEST_BYTES := 16384
const REQUEST_TIMEOUT_MSEC := 3000

var port := DEFAULT_PORT
var orders: OrderController
var game_match: Match
## The Arena node, for /map.
var arena: Node3D

var _server := TCPServer.new()
## Each entry: {"peer": StreamPeerTCP, "buffer": PackedByteArray, "since": int}
var _pending: Array[Dictionary] = []


func _ready() -> void:
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("agent bridge: cannot listen on 127.0.0.1:%d: %s" % [port, error_string(err)])
		return
	print("TANK_SQUAD_AGENT_BRIDGE http://127.0.0.1:%d" % port)


func _exit_tree() -> void:
	_server.stop()


# Served from the physics step: observations run line-of-sight queries.
func _physics_process(_delta: float) -> void:
	while _server.is_connection_available():
		_pending.append({"peer": _server.take_connection(), "buffer": PackedByteArray(),
				"since": Time.get_ticks_msec()})
	for entry in _pending.duplicate():
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_pending.erase(entry)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			entry["buffer"].append_array(peer.get_data(available)[1])
		var request := _parse_request(entry["buffer"])
		var response: Array
		if not request.is_empty():
			response = _handle(request)
		elif entry["buffer"].size() > MAX_REQUEST_BYTES:
			response = [413, {"error": "request too large"}]
		elif Time.get_ticks_msec() - int(entry["since"]) > REQUEST_TIMEOUT_MSEC:
			response = [408, {"error": "request timeout"}]
		else:
			continue
		_respond(peer, response[0], response[1])
		_pending.erase(entry)


# ---- Routing ----------------------------------------------------------------------

func _handle(request: Dictionary) -> Array:
	# A web page in the user's browser can also reach 127.0.0.1. Browsers always send
	# Origin on cross-site POSTs, and a DNS-rebinding attack shows up as a foreign Host.
	var headers: Dictionary = request["headers"]
	if headers.has("origin"):
		return [403, {"error": "browser requests are not allowed"}]
	var host := str(headers.get("host", ""))
	if not ["127.0.0.1:%d" % port, "localhost:%d" % port].has(host):
		return [403, {"error": "unexpected Host header"}]

	match [request["method"], request["path"]]:
		["GET", "/"]:
			return [200, {"endpoints": ["GET /state", "GET /map", "POST /orders", "POST /screenshot"],
					"doc": "_agents/agent_bridge.md"}]
		["GET", "/state"]:
			return [200, observe()]
		["GET", "/map"]:
			return [200, describe_map()]
		["POST", "/orders"]:
			var body: Variant = JSON.parse_string(request["body"])
			if typeof(body) != TYPE_DICTIONARY:
				return [400, {"error": "body must be a JSON object"}]
			var error := orders.set_orders(body.get("move"), body.get("weapon"), body.get("reflexes"))
			if error != "":
				return [400, {"error": error}]
			return [200, {"ok": true, "move": orders.move_order, "weapon": orders.weapon_order,
					"reflexes": orders.reflexes}]
		["POST", "/screenshot"]:
			return _screenshot()
	return [404, {"error": "unknown endpoint %s %s" % [request["method"], request["path"]]}]


# ---- Observations -----------------------------------------------------------------

func observe() -> Dictionary:
	var me := orders.tank
	var observation := {
		"time": snappedf(Time.get_ticks_msec() / 1000.0, 0.1),
		"score": {"green": game_match.score_green, "rust": game_match.score_rust},
		"orders": {"move": orders.move_order, "weapon": orders.weapon_order, "reflexes": orders.reflexes},
		"events": orders.events,
		"engaged": orders.engaged_target,
		"me": null,
		"tanks": [],
	}
	if me == null or not is_instance_valid(me):
		return observation
	var mine := _describe(me, null)
	mine["reload"] = snappedf(me.reload_fraction(), 0.01)
	observation["me"] = mine
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank != me:
			observation["tanks"].append(_describe(tank, me))
	return observation


func _describe(tank: Tank, viewer: Tank) -> Dictionary:
	var info := {
		"name": String(tank.name),
		"team": Match.TEAM_NAMES[tank.team],
		"pos": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
		"heading": _compass(-tank.global_basis.z),
		"turret": _compass(tank.turret_forward()),
		"health": tank.sync_health,
		"shield": tank.sync_shield,
		"alive": tank.is_alive(),
	}
	if viewer != null:
		var offset := tank.global_position - viewer.global_position
		var bearing := _compass(offset)
		info["distance"] = snappedf(offset.length(), 0.1)
		info["bearing"] = bearing
		info["relative_bearing"] = snappedf(wrapf(bearing - _compass(-viewer.global_basis.z), -180.0, 180.0), 1.0)
		info["visible"] = tank.is_alive() and viewer.is_alive() and Perception.has_line_of_sight(viewer, tank)
		if tank.team != viewer.team:
			# Which of its armor faces a shot from here would strike right now.
			var facing := Armor.facing(-tank.global_basis.z, offset)
			info["exposed_face"] = Armor.FACING_NAMES[facing]
			# Is its gun already pointed at me? (The first shot usually wins an even duel.)
			info["aiming_at_me"] = Ballistics.aim_error(tank.global_position, tank.turret_forward(),
					viewer.global_position) <= deg_to_rad(10.0)
	return info


func describe_map() -> Dictionary:
	var obstacles := []
	if arena != null:
		for body in arena.find_children("*", "StaticBody3D", true, false):
			for shape_node in body.find_children("*", "CollisionShape3D", false, false):
				var box := (shape_node as CollisionShape3D).shape as BoxShape3D
				if box == null:
					continue
				var xform: Transform3D = shape_node.global_transform
				# World-space axis-aligned footprint: unambiguous even for rotated walls.
				var bounds := xform * AABB(-box.size / 2.0, box.size)
				if bounds.end.y <= 0.05:
					continue  # the ground slab: under the floor, not an obstacle
				obstacles.append({"name": String(body.name),
						"x": [snappedf(bounds.position.x, 0.1), snappedf(bounds.end.x, 0.1)],
						"z": [snappedf(bounds.position.z, 0.1), snappedf(bounds.end.z, 0.1)],
						"height": snappedf(box.size.y, 0.1)})
	return {
		"coordinates": "meters; x grows east, z grows south; compass 0=north(-z) 90=east(+x)",
		"bounds": {"x": [-Match.ARENA_HALF_SIZE, Match.ARENA_HALF_SIZE], "z": [-Match.ARENA_HALF_SIZE, Match.ARENA_HALF_SIZE]},
		"bases": {"Green": [0, Match.BASE_Z], "Rust": [0, -Match.BASE_Z]},
		"shell_speed": Shell.SPEED, "shell_range": Shell.MAX_RANGE,
		"armor_multipliers": {"front": 0.5, "side": 1.0, "rear": 1.5},
		"obstacles": obstacles,
	}


func _screenshot() -> Array:
	if DisplayServer.get_name() == "headless":
		return [409, {"error": "headless client has no picture; run the agent client windowed"}]
	var path := ProjectSettings.globalize_path("res://build/screenshots/agent_%d.png" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		return [500, {"error": error_string(err)}]
	return [200, {"path": path}]


## Compass degrees of a horizontal direction: 0 = north (-Z), 90 = east (+X).
static func _compass(direction: Vector3) -> float:
	return snappedf(fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0), 1.0)


# ---- Minimal HTTP -----------------------------------------------------------------

## Returns {} until a complete request (headers + Content-Length body) has arrived.
static func _parse_request(buffer: PackedByteArray) -> Dictionary:
	var text := buffer.get_string_from_ascii()
	var header_end := text.find("\r\n\r\n")
	if header_end < 0:
		return {}
	var lines := text.substr(0, header_end).split("\r\n")
	var request_line := lines[0].split(" ")
	if request_line.size() < 2:
		return {"method": "BAD", "path": "", "headers": {}, "body": ""}
	var headers := {}
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon > 0:
			headers[lines[i].substr(0, colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()
	var body_length := int(headers.get("content-length", "0"))
	var body_start := header_end + 4  # header bytes are ASCII, so string index == byte index
	if buffer.size() < body_start + body_length:
		return {}
	return {"method": request_line[0], "path": request_line[1].split("?")[0], "headers": headers,
			"body": buffer.slice(body_start, body_start + body_length).get_string_from_utf8()}


static func _respond(peer: StreamPeerTCP, status: int, payload: Variant) -> void:
	var reasons := {200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found",
			408: "Request Timeout", 409: "Conflict", 413: "Payload Too Large", 500: "Internal Server Error"}
	var body := JSON.stringify(payload).to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
			status, reasons.get(status, "Error"), body.size()]
	peer.put_data(head.to_ascii_buffer())
	peer.put_data(body)
	peer.disconnect_from_host()
