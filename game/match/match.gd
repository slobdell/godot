class_name Match
extends Node
## The rules of a match: teams, spawning, shells, damage, death, respawn, score.
##
## Rule decisions (damage, death, scoring) happen only on the simulating peer
## (server or offline). The spawn functions run on EVERY peer, so replicated
## tanks and shells are built identically everywhere (node paths must match).

signal local_tank_spawned(tank: Tank)

enum Team { GREEN, RUST }

const TEAM_NAMES := ["Green", "Rust"]
const RUST_PAINT := Color(0.55, 0.27, 0.2)
const TANK_SCENE := preload("res://game/tank/tank.tscn")
const SHELL_SCENE := preload("res://game/combat/shell.tscn")
const BASE_DAMAGE := 34.0
## Bases sit this far north/south of center; slots spread along x.
const BASE_Z := 42.0
const SLOT_X := [0.0, -12.0, 12.0, -24.0, 24.0, -6.0, 6.0, -18.0, 18.0]

@export var respawn_seconds := 4.0

## Replicated by ScoreSync.
@export var score_green := 0
@export var score_rust := 0

## True on the server/offline (rules run here); false on networked clients.
var simulate := true
## True when this process has networked peers (adds NetworkInput to player tanks).
var networked := false
## False on a dedicated server (nobody sits at this machine).
var has_local_player := true

var _next_shell_id := 0
var _next_bot_id := 1

@onready var tanks: Node3D = $Tanks
@onready var shells: Node3D = $Shells
@onready var effects: Node3D = $Effects
@onready var brains: Node = $Brains
@onready var tank_spawner: MultiplayerSpawner = $TankSpawner
@onready var shell_spawner: MultiplayerSpawner = $ShellSpawner


func _ready() -> void:
	# Must be assigned on every peer before the server's first spawn message arrives.
	tank_spawner.spawn_function = _build_tank
	shell_spawner.spawn_function = _build_shell


# ---- Joining and leaving (simulating peer only) ---------------------------------------

func add_player(peer_id: int) -> Tank:
	return spawn_tank("Tank_%d" % peer_id, peer_id)


func remove_player(peer_id: int) -> void:
	var tank := tanks.get_node_or_null("Tank_%d" % peer_id)
	if tank != null:
		tank.queue_free()  # the spawner removes it on every client too


## A server-controlled tank with a BotController brain.
func add_bot() -> Tank:
	var tank := spawn_tank("Bot_%d" % _next_bot_id, 0)
	_next_bot_id += 1
	var brain := BotController.new()
	brain.name = "Brain_" + tank.name
	brain.tank = tank
	brain.tanks_root = tanks
	brains.add_child(brain)
	return tank


## Spawn a tank on `team` (-1 = whichever team is smaller) at its team's next free slot.
func spawn_tank(tank_name: String, owner_peer_id: int, team: int = -1) -> Tank:
	if team < 0:
		team = _smaller_team()
	var slot := _free_slot(team)
	return tank_spawner.spawn({"name": tank_name, "owner": owner_peer_id, "team": team,
			"slot": slot, "position": spawn_position(team, slot), "yaw": spawn_yaw(team)})


static func spawn_position(team: int, slot: int) -> Vector3:
	var z := BASE_Z if team == Team.GREEN else -BASE_Z
	var x: float = SLOT_X[slot % SLOT_X.size()]
	return Vector3(x if team == Team.GREEN else -x, 0.0, z)


## Green starts in the south facing north (−Z); Rust in the north facing south.
static func spawn_yaw(team: int) -> float:
	return 0.0 if team == Team.GREEN else PI


func team_tanks(team: int) -> Array[Tank]:
	var result: Array[Tank] = []
	for node in tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == team and not tank.is_queued_for_deletion():
			result.append(tank)
	return result


func _smaller_team() -> int:
	return Team.RUST if team_tanks(Team.RUST).size() < team_tanks(Team.GREEN).size() else Team.GREEN


func _free_slot(team: int) -> int:
	var used := []
	for tank in team_tanks(team):
		used.append(tank.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


# ---- Spawn functions (EVERY peer, identical data) ----------------------------------

func _build_tank(data: Dictionary) -> Node:
	var tank: Tank = TANK_SCENE.instantiate()
	tank.name = data["name"]
	tank.team = data["team"]
	tank.slot = data["slot"]
	tank.owner_peer_id = data["owner"]
	tank.position = data["position"]
	tank.rotation.y = data["yaw"]
	tank.simulate = simulate
	var is_local: bool = has_local_player and tank.owner_peer_id != 0 \
			and tank.owner_peer_id == multiplayer.get_unique_id()
	tank.display_name = "YOU" if is_local else tank.name
	if tank.team == Team.RUST:
		tank.set_paint.call_deferred(RUST_PAINT)  # needs its child meshes ready
	if simulate:
		tank.fired.connect(_on_tank_fired.bind(tank))
		tank.died.connect(_on_tank_died.bind(tank))
	if networked and tank.owner_peer_id != 0:
		var input := NetworkInput.new()
		input.name = "NetworkInput"
		input.tank = tank
		input.owner_peer_id = tank.owner_peer_id
		tank.add_child(input)
	if is_local:
		local_tank_spawned.emit.call_deferred(tank)
	return tank


func _build_shell(data: Dictionary) -> Node:
	var shell: Shell = SHELL_SCENE.instantiate()
	shell.name = "Shell_%d" % data["id"]
	shell.position = data["muzzle"]
	shell.ray_start = data["ray_start"]
	shell.direction = data["direction"]
	shell.team = data["team"]
	shell.shooter_name = data["shooter"]
	shell.simulate = simulate
	if simulate:
		var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
		if shooter != null:
			shell.exclude = [shooter.get_rid()]
		shell.hit.connect(_on_shell_hit)
		shell.expired.connect(func(expired_shell: Shell) -> void: expired_shell.queue_free())
	return shell


# ---- Rules (simulating peer only) ----------------------------------------------------

func _on_tank_fired(muzzle: Vector3, direction: Vector3, tank: Tank) -> void:
	shell_spawner.spawn({"id": _next_shell_id, "muzzle": muzzle, "ray_start": tank.turret.global_position,
			"direction": direction, "team": tank.team, "shooter": String(tank.name)})
	_next_shell_id += 1


func _on_shell_hit(shell: Shell, collider: Object, point: Vector3) -> void:
	var killed := false
	var victim := collider as Tank
	if victim != null and victim.is_alive() and victim.team != shell.team:
		var damage := Armor.damage(BASE_DAMAGE, -victim.global_basis.z, shell.direction)
		killed = victim.apply_damage(damage)
		if killed:
			if shell.team == Team.GREEN:
				score_green += 1
			else:
				score_rust += 1
			print("%s destroyed %s (score Green %d : %d Rust)" % [shell.shooter_name, victim.name,
					score_green, score_rust])
	show_impact.rpc(point, killed)
	shell.queue_free()


func _on_tank_died(tank: Tank) -> void:
	await get_tree().create_timer(respawn_seconds).timeout
	if is_instance_valid(tank) and not tank.is_queued_for_deletion():
		tank.respawn(spawn_position(tank.team, tank.slot), spawn_yaw(tank.team))


# ---- Effects (every peer with a screen) ----------------------------------------------

@rpc("authority", "call_local", "unreliable")
func show_impact(point: Vector3, big: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var impact := Impact.new()
	impact.big = big
	effects.add_child(impact)
	impact.global_position = point
