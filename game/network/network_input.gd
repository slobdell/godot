class_name NetworkInput
extends Node
## Carries one tank's TankCommand from its owning client to the server.
##
## Added under every networked Tank on EVERY peer, because an RPC is addressed by
## node path and that path must exist on both ends. What it does depends on
## where it runs:
##   owning client  after the local controller writes tank.command, send it up
##   server         accept only the owner's messages, validate, rate-limit, and
##                  apply the latest to the tank before the tank simulates
##   other clients  nothing
##
## The client is never trusted: it sends *intent*, the server decides outcomes.

const MAX_COMMANDS_PER_SEC := 120
## If the owner goes quiet this long (lag spike, tab in background), stop the tank.
const STALE_AFTER_MSEC := 500

var tank: Tank
var owner_peer_id := 0
## Server-side count of dropped messages, for logs and tests.
var rejected_count := 0

var _latest := TankCommand.new()
var _last_accepted_msec := -1_000_000
var _window_start_msec := 0
var _window_count := 0


func _ready() -> void:
	if multiplayer.is_server() and owner_peer_id == multiplayer.get_unique_id():
		set_physics_process(false)  # the host's own tank: its local controller drives it directly
	elif multiplayer.is_server():
		process_physics_priority = -10  # before the Tank consumes its command
	elif owner_peer_id == multiplayer.get_unique_id():
		process_physics_priority = -5  # after the local controller (-10) wrote tank.command
	else:
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		tank.command = current_command(Time.get_ticks_msec())
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var cmd := tank.command
	submit_command.rpc_id(1, cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_command(throttle: float, turn: float, aim_point: Vector3, fire: bool) -> void:
	if not multiplayer.is_server():
		return
	accept(multiplayer.get_remote_sender_id(), Time.get_ticks_msec(),
			TankCommand.new(throttle, turn, aim_point, fire))


## Server-side gate for one incoming command. Time is passed in so tests can
## drive it without a network or a clock.
func accept(sender_id: int, now_msec: int, cmd: TankCommand) -> bool:
	if sender_id != owner_peer_id:
		return _reject()  # someone else trying to drive this tank
	if not cmd.is_finite_command():
		return _reject()
	if now_msec - _window_start_msec >= 1000:
		_window_start_msec = now_msec
		_window_count = 0
	_window_count += 1
	if _window_count > MAX_COMMANDS_PER_SEC:
		return _reject()
	_latest = cmd.sanitized()
	_last_accepted_msec = now_msec
	return true


## What the server should apply this tick: the latest accepted command, or a
## stop (keeping the aim) if the owner has gone quiet.
func current_command(now_msec: int) -> TankCommand:
	if now_msec - _last_accepted_msec > STALE_AFTER_MSEC:
		return TankCommand.new(0.0, 0.0, _latest.aim_point, false)
	return _latest


func _reject() -> bool:
	rejected_count += 1
	return false
