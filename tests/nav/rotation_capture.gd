extends SceneTree
## `make nav-rotation` (nav, round 7): how a hull ROTATES, seen from the lead's camera (pitch 21, 49 m, FOV 35 — the
## telephoto that makes rotation visible). Stills of a fight can't show it; this captures three shapes as frame
## strips and logs every hull's heading every tick:
##   pivot   a tracked tank told to face 120 degrees to its right (a `face` order: turn in place)
##   car     a wheeled scout sent to a point behind it and to the left (inside its turning circle: a K-turn)
##   wheel   a squad of four ordered to a spot 25 m ahead, facing 90 degrees to the right (arrive, then swing)
##   truck   (round 8) the gangs' semi (gang_tank, wheels, 12 m turning circle) told to face 90 degrees to its right
## Pre-registered for round 8, before its first run — "yawing in place" (the lead: "the semi trucks are yawing in place
## (should be impossible, they're not a tracker vehicle)"): a WHEELED hull that rotates >= 30 degrees while its centre
## stays within 1.5 m of where it started. Printed as NAV_ROTATION_INPLACE.
## Pre-registered (before the first run) — "robotic" means any of:
##   (a) instant start or stop: angular rate going 0 -> >= 90% of its peak, or >= 90% -> 0, within ONE tick
##   (b) a snap at the end: overshooting the final heading, or the last tick's turn being > 30% of the peak
##   (c) rotating about a point it isn't driving around (read from the frames)
## (a) and (b) are printed per hull as NAV_ROTATION lines; (c) is for a human looking at build/nav-rotation/*.png.
## Needs a display (builder0's, via `make remote T=nav-rotation`).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SIZE := Vector2i(960, 540)
const PITCH := 21.0
const DISTANCE := 49.0
const FOV := 35.0
const FRAME_EVERY := 10  # ticks between captured frames (1/3 s at 30 Hz)

var out := "/tmp/nav-rotation"
## --no-frames: numbers only (headless, seconds instead of minutes); --cases=pivot,car,wheel,truck picks cases.
var frames_on := true
var cases := PackedStringArray(["pivot", "car", "wheel", "truck"])
var game_match: Match
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--no-frames":
			frames_on = false
		elif arg.begins_with("--cases="):
			cases = arg.trim_prefix("--cases=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	GameTheme.use("cyberpunk")
	root.size = SIZE
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "yard"
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	root.add_child(sun)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 600.0
	root.add_child(camera)
	camera.current = true
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	if cases.has("pivot"):
		await _pivot()
	if cases.has("car"):
		await _car()
	if cases.has("wheel"):
		await _wheel()
	if cases.has("truck"):
		await _truck()
	print("NAV_ROTATION_DONE %s" % out)
	quit()


func _controller(tank: Tank) -> OrderController:
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	game_match.brains.add_child(orders)
	return orders


func _pivot() -> void:
	var tank := game_match.spawn_tank("Pivot", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(-40, 0, 100)
	tank.rotation.y = 0.0  # facing -z
	var orders := _controller(tank)
	var look := tank.global_position + Vector3(-sin(deg_to_rad(-120.0)), 0, -cos(deg_to_rad(-120.0))) * 20.0
	orders.set_orders({"type": "face", "x": look.x, "z": look.z}, {"type": "hold_fire"})
	await _film("pivot", [tank], tank.global_position, SimClock.TICK_RATE * 4)
	tank.queue_free()
	orders.queue_free()


func _car() -> void:
	var tank := game_match.spawn_tank("Car", 1, Match.Team.GREEN, "scout")
	tank.global_position = Vector3(10, 0, 100)
	tank.rotation.y = 0.0
	var orders := _controller(tank)
	orders.set_orders({"type": "move_to", "x": 2.0, "z": 108.0}, {"type": "hold_fire"})
	await _film("car", [tank], tank.global_position, SimClock.TICK_RATE * 7)
	tank.queue_free()
	orders.queue_free()


func _truck() -> void:
	var tank := game_match.spawn_tank("Truck", 6, Match.Team.GREEN, "gang_tank")
	tank.global_position = Vector3(-10, 0, 60)
	tank.rotation.y = 0.0
	var start := tank.global_position
	var orders := _controller(tank)
	var look := tank.global_position + Vector3(1, 0, 0) * 20.0
	orders.set_orders({"type": "face", "x": look.x, "z": look.z}, {"type": "hold_fire"})
	var heading0 := _heading(tank)
	var in_place_turn := 0.0
	var farthest := 0.0
	var series := {String(tank.name): PackedFloat32Array()}
	for tick in SimClock.TICK_RATE * 12:
		_log_heading(series, tank)
		var moved := Vector2(tank.global_position.x - start.x, tank.global_position.z - start.z).length()
		farthest = maxf(farthest, moved)
		if moved <= 1.5:
			in_place_turn = maxf(in_place_turn, absf(wrapf(_heading(tank) - heading0, -180.0, 180.0)))
		await _frame("truck", tick, start)
	_report("truck", series)
	print("NAV_ROTATION_INPLACE truck gang_tank (wheels, r=%.0f m): turned %.0f deg while within 1.5 m of its start, farthest %.1f m -> %s" % [
			float(Units.stat("gang_tank", "min_turn_radius_m")), in_place_turn, farthest,
			"YAWING IN PLACE" if in_place_turn >= 30.0 else "ok"])
	tank.queue_free()
	orders.queue_free()


func _wheel() -> void:
	var tanks: Array[Tank] = []
	for i in 4:
		var tank := game_match.spawn_tank("Wheel_%d" % i, 2 + i, Match.Team.GREEN, "tank")
		tank.global_position = Vector3(50 + i * 7.0, 0, 104)
		tank.rotation.y = 0.0
		tanks.append(tank)
		var orders := _controller(tank)
		# A squad's move-with-facing as the brains now execute it: drive to the slot, then face the ordered way.
		var slot := Vector3(50 + i * 7.0, 0, 79)
		orders.set_meta("slot", slot)
		orders.set_orders({"type": "move_to", "x": slot.x, "z": slot.z}, {"type": "hold_fire"})
	var centre := Vector3(60.5, 0, 92)
	var face_right := Vector3(1, 0, 0)
	var frames := SimClock.TICK_RATE * 9
	var series := {}
	for tank in tanks:
		series[String(tank.name)] = PackedFloat32Array()
	for tick in frames:
		for tank in tanks:
			var orders: OrderController = null
			for node in game_match.brains.get_children():
				if node is OrderController and (node as OrderController).tank == tank:
					orders = node
			if orders != null and orders.move_order.get("type") == "move_to" and Movement.state(tank).get("phase") == "arrived":
				var look := tank.global_position + face_right * 20.0
				orders.set_orders({"type": "face", "x": look.x, "z": look.z}, null)
			_log_heading(series, tank)
		await _frame("wheel", tick, centre)
	_report("wheel", series)
	for tank in tanks:
		tank.queue_free()


## Run `ticks`, capturing a frame every FRAME_EVERY ticks from the lead's pose, logging headings.
func _film(case: String, tanks: Array, centre: Vector3, ticks: int) -> void:
	var series := {}
	for tank: Tank in tanks:
		series[String(tank.name)] = PackedFloat32Array()
	for tick in ticks:
		for tank: Tank in tanks:
			_log_heading(series, tank)
			if tick == SimClock.TICK_RATE:
				var controller: OrderController = null
				for node in game_match.brains.get_children():
					if node is OrderController and (node as OrderController).tank == tank:
						controller = node
				print("NAV_ROTATION_DEBUG %s t=1s simulate=%s alive=%s move=%s cmd throttle=%.2f turn=%.2f heading=%.1f" % [
						tank.name, tank.simulate, tank.is_alive(), controller.move_order if controller else "no controller",
						tank.command.throttle, tank.command.turn, _heading(tank)])
		await _frame(case, tick, centre)
	_report(case, series)


func _frame(case: String, tick: int, centre: Vector3) -> void:
	# From the arena side (the spawn aprons back onto the stands; a camera behind them looks through the railing).
	camera.global_transform = RtsCamera.pose_at(centre, deg_to_rad(150.0), DISTANCE, PITCH)
	await physics_frame
	if frames_on and tick % FRAME_EVERY == 0:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s_%03d.png" % [case, tick]))


## Packed arrays are values (trip-up 48): append to a copy and put it back. (The first run of this capture reported
## "never turned" for every hull because the cast-and-append wrote to a copy.)
func _log_heading(series: Dictionary, tank: Tank) -> void:
	var headings: PackedFloat32Array = series[String(tank.name)]
	headings.append(_heading(tank))
	series[String(tank.name)] = headings


## The hull's heading in degrees (0 = -z, positive = turning left), unwrapped by the caller.
func _heading(tank: Tank) -> float:
	var forward := -tank.global_basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


## (a) and (b) per hull, from its heading series.
func _report(case: String, series: Dictionary) -> void:
	for name: String in series:
		var headings: PackedFloat32Array = series[name]
		var rates := PackedFloat32Array()
		for i in range(1, headings.size()):
			rates.append(absf(wrapf(headings[i] - headings[i - 1], -180.0, 180.0)) * SimClock.TICK_RATE)
		var peak := 0.0
		for r in rates:
			peak = maxf(peak, r)
		if peak < 1.0:
			print("NAV_ROTATION %s %s never turned" % [case, name])
			continue
		var first := -1
		var last := -1
		for i in rates.size():
			if rates[i] > 0.02 * peak:
				if first < 0:
					first = i
				last = i
		var start_ticks := 0
		for i in range(first, rates.size()):
			if rates[i] >= 0.9 * peak:
				start_ticks = i - first + 1
				break
		var stop_ticks := 0
		for i in range(last, -1, -1):
			if rates[i] >= 0.9 * peak:
				stop_ticks = last - i + 1
				break
		# Unwrapped: the heading summed tick by tick. Round 8 found round 7's "20.7 degree overshoot" on the car was this
		# measurement wrapping a 201-degree turn to -159 (the car's heading never reversed).
		var turned_by := PackedFloat32Array([0.0])
		for i in range(1, headings.size()):
			turned_by.append(turned_by[i - 1] + wrapf(headings[i] - headings[i - 1], -180.0, 180.0))
		var total := turned_by[turned_by.size() - 1]
		var furthest := 0.0
		for turned in turned_by:
			if absf(turned) > absf(furthest) and signf(turned) == signf(total):
				furthest = turned
		var overshoot := absf(furthest) - absf(total)
		var last_share := rates[last] / peak
		print("NAV_ROTATION %s %s turned %.0f deg, peak %.0f deg/s, reaches 90%% of peak in %d ticks, falls from it in %d, overshoot %.1f deg, last tick %.0f%% of peak -> %s" % [
				case, name, total, peak, start_ticks, stop_ticks, overshoot, last_share * 100.0,
				"ROBOTIC(a)" if start_ticks <= 1 or stop_ticks <= 1 else ("ROBOTIC(b)" if overshoot > 1.0 or last_share > 0.3 else "smooth")])
