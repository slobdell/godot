class_name DetSim
extends RefCounted
## Deterministic tank simulation spike (netcode phase N2): integer/fixed-point tank movement,
## collision with the real arena's walls and crates, shells, grid line of sight, and a simple
## turret brain, all in GDScript ints (Fixed). The question it answers: does the same command log
## produce bit-identical state on native and WebAssembly builds (and later ARM phones), and what
## does a tick cost? If yes, lockstep (N3) is feasible with a core like this.
##
## Deliberately NOT the real game: no Godot physics, no NavigationServer, no floats. Rules are a
## simplified copy of today's numbers (tank.gd, weapons.gd "cannon", shell.gd) at 30 ticks per second.
##
##   var sim := DetSim.new(20)                          # 20 tanks
##   var commands := DetSim.command_log(12345, 20, 3600)  # seed, tanks, ticks
##   sim.run(commands, 3600); sim.state_hash()

const TICKS_PER_SEC := 30
const F := Fixed.ONE

# Movement (per tick, Q16.16 meters; angles in binary units per tick).
const MAX_FORWARD := 9 * F / TICKS_PER_SEC
const MAX_REVERSE := 4 * F / TICKS_PER_SEC
const ACCEL := 14 * F / (TICKS_PER_SEC * TICKS_PER_SEC)
const HULL_TURN := 80 * Fixed.TURN / 360 / TICKS_PER_SEC
const TURRET_TURN := 110 * Fixed.TURN / 360 / TICKS_PER_SEC
const TANK_RADIUS := 2 * F + F / 5
const ARENA_LIMIT := 118 * F

# Combat.
const MAX_HEALTH := 400
const DAMAGE := 34
const RELOAD_TICKS := 5 * TICKS_PER_SEC / 2
const RANGE := 70 * F
const AIM_TOLERANCE := 5 * Fixed.TURN / 2 / 360
const SHELL_SPEED := 70 * F / TICKS_PER_SEC
const SHELL_LIFE := 75 * F / SHELL_SPEED + 1
const MUZZLE := 3 * F
const SENSOR_RANGE := 75 * F
const INTEL_EVERY := 3
const RESPAWN_TICKS := 4 * TICKS_PER_SEC

# Line-of-sight grid over the arena: 2 m cells.
const CELL := 2 * F
const GRID := 122
const GRID_ORIGIN := -122 * F

# Obstacles from game/arena/arena.tscn as [center_x, center_z, half_x, half_z] in QUARTER meters
# (walls 18 × 1.5 m, crates 4.5 × 4.5 m; the two 45° crates are approximated by their unrotated box).
const OBSTACLES_Q := [
	[0, 0, 9, 9], [-144, -80, 36, 3], [144, 80, 36, 3],
	[-288, 96, 3, 36], [288, -96, 3, 36], [-112, 240, 36, 3], [112, -240, 36, 3],
	[96, -48, 9, 9], [-96, 48, 9, 9], [-240, -208, 9, 9], [240, 208, 9, 9],
	[48, -224, 9, 9], [-48, 224, 9, 9], [-320, 256, 9, 9], [320, -256, 9, 9],
	[-352, -80, 3, 36], [352, 80, 3, 36], [-160, -120, 9, 9], [160, 120, 9, 9],
]

var tick := 0
var count := 0
# Tank state, one entry per tank (index order is the iteration order everywhere).
var team := PackedInt64Array()
var pos_x := PackedInt64Array()
var pos_z := PackedInt64Array()
var heading := PackedInt64Array()
var turret := PackedInt64Array()
var speed := PackedInt64Array()
var health := PackedInt64Array()
var reload := PackedInt64Array()
var respawn := PackedInt64Array()
var target := PackedInt64Array()
var throttle := PackedInt64Array()  # command: -127..127
var turn := PackedInt64Array()  # command: -127..127
# Shells.
var shell_x := PackedInt64Array()
var shell_z := PackedInt64Array()
var shell_vx := PackedInt64Array()
var shell_vz := PackedInt64Array()
var shell_team := PackedInt64Array()
var shell_life := PackedInt64Array()
# Counters.
var shots := 0
var hits := 0
var kills := 0

var _obstacles: Array[PackedInt64Array] = []  # [min_x, min_z, max_x, max_z] Q16.16
var _solid := PackedByteArray()
var _log_cursor := 0


func _init(tank_count: int) -> void:
	count = tank_count
	for o in OBSTACLES_Q:
		var cx: int = o[0] * F / 4
		var cz: int = o[1] * F / 4
		var hx: int = o[2] * F / 4
		var hz: int = o[3] * F / 4
		_obstacles.append(PackedInt64Array([cx - hx, cz - hz, cx + hx, cz + hz]))
	_build_grid()
	# Packed arrays are values in GDScript: resizing a copy from a loop would do nothing.
	team.resize(count)
	pos_x.resize(count)
	pos_z.resize(count)
	heading.resize(count)
	turret.resize(count)
	speed.resize(count)
	health.resize(count)
	reload.resize(count)
	respawn.resize(count)
	target.resize(count)
	throttle.resize(count)
	turn.resize(count)
	for i in count:
		team[i] = i % 2
		_spawn(i)


## A seeded stream of player orders: every 1.5-4 s each tank gets a new [throttle, turn].
## Integer xorshift32 only, so every platform generates the identical log.
## Returns [[tick, tank, throttle, turn], ...] sorted by tick then tank.
static func command_log(seed_value: int, tank_count: int, ticks: int) -> Array:
	var state := (seed_value & 0xFFFFFFFF) | 1
	var entries: Array = []
	for i in tank_count:
		var t := 0
		while t < ticks:
			state = _xorshift(state)
			var throttle_value: int = [127, 127, 90, 0, -80][state % 5]
			state = _xorshift(state)
			var turn_value := int(state % 255) - 127
			entries.append([t, i, throttle_value, turn_value])
			state = _xorshift(state)
			t += 45 + int(state % 76)
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return entries


static func _xorshift(x: int) -> int:
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	return x & 0xFFFFFFFF


## Advance one tick, applying log entries scheduled for it.
func step(commands: Array) -> void:
	while _log_cursor < commands.size() and int(commands[_log_cursor][0]) <= tick:
		var entry: Array = commands[_log_cursor]
		throttle[entry[1]] = entry[2]
		turn[entry[1]] = entry[3]
		_log_cursor += 1
	if tick % INTEL_EVERY == 0:
		_pick_targets()
	for i in count:
		_step_tank(i)
	_separate_tanks()
	_step_shells()
	tick += 1


func run(commands: Array, ticks: int) -> void:
	for t in ticks:
		step(commands)


## SHA-256 of every integer of state, first 16 hex chars (same shape as Match.state_hash()).
func state_hash() -> String:
	var ints := PackedInt64Array([tick, count, shots, hits, kills, shell_x.size()])
	for arr in [team, pos_x, pos_z, heading, turret, speed, health, reload, respawn, target,
			shell_x, shell_z, shell_vx, shell_vz, shell_team, shell_life]:
		ints.append_array(arr)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(ints.to_byte_array())
	return hashing.finish().hex_encode().left(16)


# ---- Rules ------------------------------------------------------------------------------

func _spawn(i: int) -> void:
	var slot := i / 2
	var south := team[i] == 0
	pos_x[i] = (slot * 12 - 54) * F * (1 if south else -1)
	pos_z[i] = 90 * F * (1 if south else -1)
	heading[i] = Fixed.TURN * 3 / 4 if south else Fixed.QUARTER_TURN  # facing the other base
	turret[i] = heading[i]
	speed[i] = 0
	health[i] = MAX_HEALTH
	reload[i] = RELOAD_TICKS
	respawn[i] = 0
	target[i] = -1


func _pick_targets() -> void:
	for i in count:
		target[i] = -1
		if health[i] <= 0:
			continue
		var best := -1
		var best_d2 := SENSOR_RANGE * SENSOR_RANGE
		for j in count:
			if team[j] == team[i] or health[j] <= 0:
				continue
			var dx := pos_x[j] - pos_x[i]
			var dz := pos_z[j] - pos_z[i]
			var d2 := dx * dx + dz * dz
			if d2 < best_d2 and has_line_of_sight(pos_x[i], pos_z[i], pos_x[j], pos_z[j]):
				best = j
				best_d2 = d2
		target[i] = best


func _step_tank(i: int) -> void:
	if health[i] <= 0:
		respawn[i] -= 1
		if respawn[i] <= 0:
			_spawn(i)
		return
	# Drive.
	var wanted := throttle[i] * (MAX_FORWARD if throttle[i] >= 0 else MAX_REVERSE) / 127
	speed[i] = clampi(wanted, speed[i] - ACCEL, speed[i] + ACCEL)
	heading[i] = (heading[i] + turn[i] * HULL_TURN / 127) & (Fixed.TURN - 1)
	var cs := Fixed.cos_sin(heading[i])
	pos_x[i] += Fixed.mul(speed[i], cs[0])
	pos_z[i] += Fixed.mul(speed[i], cs[1])
	_collide_static(i)
	# Aim and shoot.
	if reload[i] > 0:
		reload[i] -= 1
	var j := target[i]
	if j < 0 or health[j] <= 0:
		return
	var dx := pos_x[j] - pos_x[i]
	var dz := pos_z[j] - pos_z[i]
	var desired := Fixed.atan2(dz, dx)
	var diff := Fixed.wrap_angle(desired - turret[i])
	turret[i] = (turret[i] + clampi(diff, -TURRET_TURN, TURRET_TURN)) & (Fixed.TURN - 1)
	if reload[i] == 0 and absi(diff) <= AIM_TOLERANCE and dx * dx + dz * dz <= RANGE * RANGE:
		_fire(i)


func _fire(i: int) -> void:
	var cs := Fixed.cos_sin(turret[i])
	shell_x.append(pos_x[i] + Fixed.mul(MUZZLE, cs[0]))
	shell_z.append(pos_z[i] + Fixed.mul(MUZZLE, cs[1]))
	shell_vx.append(Fixed.mul(SHELL_SPEED, cs[0]))
	shell_vz.append(Fixed.mul(SHELL_SPEED, cs[1]))
	shell_team.append(team[i])
	shell_life.append(SHELL_LIFE)
	reload[i] = RELOAD_TICKS
	shots += 1


func _collide_static(i: int) -> void:
	pos_x[i] = clampi(pos_x[i], -ARENA_LIMIT, ARENA_LIMIT)
	pos_z[i] = clampi(pos_z[i], -ARENA_LIMIT, ARENA_LIMIT)
	for box in _obstacles:
		# Closest point on the box to the tank's center; push out along the separating direction.
		var cx := clampi(pos_x[i], box[0], box[2])
		var cz := clampi(pos_z[i], box[1], box[3])
		var dx := pos_x[i] - cx
		var dz := pos_z[i] - cz
		var d2 := dx * dx + dz * dz
		if d2 >= TANK_RADIUS * TANK_RADIUS:
			continue
		if d2 == 0:
			# Center inside the box: leave by the nearest face.
			var exits := [pos_x[i] - box[0], box[2] - pos_x[i], pos_z[i] - box[1], box[3] - pos_z[i]]
			var face := exits.find(exits.min())
			match face:
				0: pos_x[i] = box[0] - TANK_RADIUS
				1: pos_x[i] = box[2] + TANK_RADIUS
				2: pos_z[i] = box[1] - TANK_RADIUS
				_: pos_z[i] = box[3] + TANK_RADIUS
			speed[i] = 0
			continue
		var d := Fixed.isqrt(d2)
		var push := TANK_RADIUS - d
		pos_x[i] += dx * push / d
		pos_z[i] += dz * push / d
		speed[i] = speed[i] * 3 / 4


func _separate_tanks() -> void:
	var min_d := TANK_RADIUS * 2
	for i in count:
		if health[i] <= 0:
			continue
		for j in range(i + 1, count):
			if health[j] <= 0:
				continue
			var dx := pos_x[j] - pos_x[i]
			var dz := pos_z[j] - pos_z[i]
			var d2 := dx * dx + dz * dz
			if d2 >= min_d * min_d:
				continue
			var d := Fixed.isqrt(d2)
			if d == 0:
				dx = F
				dz = 0
				d = F
			var push := (min_d - d) / 2
			pos_x[i] -= dx * push / d
			pos_z[i] -= dz * push / d
			pos_x[j] += dx * push / d
			pos_z[j] += dz * push / d


func _step_shells() -> void:
	var s := 0
	while s < shell_x.size():
		shell_x[s] += shell_vx[s]
		shell_z[s] += shell_vz[s]
		shell_life[s] -= 1
		var gone := shell_life[s] <= 0 or _is_solid(shell_x[s], shell_z[s])
		if not gone:
			for i in count:
				if team[i] == shell_team[s] or health[i] <= 0:
					continue
				var dx := pos_x[i] - shell_x[s]
				var dz := pos_z[i] - shell_z[s]
				if dx * dx + dz * dz <= TANK_RADIUS * TANK_RADIUS:
					hits += 1
					health[i] -= DAMAGE
					if health[i] <= 0:
						kills += 1
						respawn[i] = RESPAWN_TICKS
					gone = true
					break
		if gone:
			_remove_shell(s)
		else:
			s += 1


func _remove_shell(s: int) -> void:
	# Order-preserving removal keeps iteration order identical everywhere. (Packed arrays are values:
	# each field must be edited directly, not through a loop variable.)
	shell_x.remove_at(s)
	shell_z.remove_at(s)
	shell_vx.remove_at(s)
	shell_vz.remove_at(s)
	shell_team.remove_at(s)
	shell_life.remove_at(s)


# ---- Grid line of sight ----------------------------------------------------------------------

func _build_grid() -> void:
	_solid.resize(GRID * GRID)
	for gz in GRID:
		for gx in GRID:
			var cx := GRID_ORIGIN + gx * CELL + CELL / 2
			var cz := GRID_ORIGIN + gz * CELL + CELL / 2
			var solid := 0
			for box in _obstacles:
				if cx >= box[0] and cx <= box[2] and cz >= box[1] and cz <= box[3]:
					solid = 1
					break
			_solid[gz * GRID + gx] = solid


func _cell(v: int) -> int:
	return clampi((v - GRID_ORIGIN) / CELL, 0, GRID - 1)


func _is_solid(x: int, z: int) -> bool:
	return _solid[_cell(z) * GRID + _cell(x)] == 1


## Bresenham over grid cells: false if any solid cell lies between the two points.
func has_line_of_sight(ax: int, az: int, bx: int, bz: int) -> bool:
	var x0 := _cell(ax)
	var z0 := _cell(az)
	var x1 := _cell(bx)
	var z1 := _cell(bz)
	var dx := absi(x1 - x0)
	var dz := -absi(z1 - z0)
	var sx := 1 if x0 < x1 else -1
	var sz := 1 if z0 < z1 else -1
	var err := dx + dz
	while true:
		if _solid[z0 * GRID + x0] == 1:
			return false
		if x0 == x1 and z0 == z1:
			return true
		var e2 := 2 * err
		if e2 >= dz:
			err += dz
			x0 += sx
		if e2 <= dx:
			err += dx
			z0 += sz
	return true
