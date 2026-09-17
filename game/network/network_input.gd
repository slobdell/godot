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
## Owning client send policy (measured 2026-09-14: one command per 60 Hz tick was 3.0 KB/s up
## per player): send when the command changes, at most every MIN_SEND_TICKS ticks, a trigger
## pull at once, and otherwise a keepalive every KEEPALIVE_MSEC so the server's stale check holds.
const MIN_SEND_TICKS := maxi(1, SimClock.TICK_RATE / 30)  # at most ~30 sends a second at any tick rate
const KEEPALIVE_MSEC := 100
## Aim movement smaller than this (meters) isn't worth a packet on its own.
const AIM_EPSILON := 0.1
## If the owner goes quiet this long (lag spike, tab in background), stop the tank.
const STALE_AFTER_MSEC := 500

var tank: Tank
var owner_peer_id := 0
## Server-side count of dropped messages, for logs and tests.
var rejected_count := 0
## Client-side count of commands sent, for tests and measurements.
var sent_count := 0

var _latest := TankCommand.new()
## Client side: a copy of the last command sent, and when.
var _sent: TankCommand = null
var _sent_msec := 0
var _ticks_since_send := 0
var _last_accepted_msec := -1_000_000
## When this peer last read the network (commands can only arrive then). Staleness is measured
## from here, not from the physics tick: on a slow host (a phone, a busy tab) a whole frame can pass
## between reading a command and simulating it, and a fresh command must not look stale.
var _last_poll_msec := 0
var _window_start_msec := 0
var _window_count := 0


func _ready() -> void:
	set_process(false)
	if multiplayer.is_server() and owner_peer_id == multiplayer.get_unique_id():
		set_physics_process(false)  # the host's own tank: its local controller drives it directly
	elif multiplayer.is_server():
		process_physics_priority = -10  # before the Tank consumes its command
		set_process(true)
	elif owner_peer_id == multiplayer.get_unique_id():
		process_physics_priority = -5  # after the local controller (-10) wrote tank.command
	else:
		set_physics_process(false)


func _process(_delta: float) -> void:
	# SceneMultiplayer polls (and delivers RPCs) just before nodes process, in the same frame.
	note_poll(Time.get_ticks_msec())


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		tank.command = command_for_tick()
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var cmd := tank.command
	if should_send(cmd, Time.get_ticks_msec()):
		submit_command.rpc_id(1, cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_command(throttle: float, turn: float, aim_point: Vector3, fire: bool) -> void:
	if not multiplayer.is_server():
		return
	accept(multiplayer.get_remote_sender_id(), Time.get_ticks_msec(),
			TankCommand.new(throttle, turn, aim_point, fire))


## Client-side send policy, called once per physics tick with the local controller's command.
## Records the send when it returns true. Time is passed in so tests can drive it.
func should_send(cmd: TankCommand, now_msec: int) -> bool:
	_ticks_since_send += 1
	var send := _sent == null \
			or (cmd.fire and not _sent.fire) \
			or now_msec - _sent_msec >= KEEPALIVE_MSEC \
			or (_ticks_since_send >= MIN_SEND_TICKS and _differs(cmd, _sent))
	if send:
		_sent = TankCommand.new(cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire)
		_sent_msec = now_msec
		_ticks_since_send = 0
		sent_count += 1
	return send


static func _differs(a: TankCommand, b: TankCommand) -> bool:
	return a.throttle != b.throttle or a.turn != b.turn or a.fire != b.fire \
			or a.aim_point.distance_squared_to(b.aim_point) > AIM_EPSILON * AIM_EPSILON


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


func note_poll(now_msec: int) -> void:
	_last_poll_msec = now_msec


## The command to simulate this physics tick, judged fresh or stale as of the last network read.
func command_for_tick() -> TankCommand:
	return current_command(_last_poll_msec)


## What the server should apply: the latest accepted command, or a stop (keeping the aim) if
## the owner had gone quiet by `now_msec` (the time input was last read).
func current_command(now_msec: int) -> TankCommand:
	if now_msec - _last_accepted_msec > STALE_AFTER_MSEC:
		return TankCommand.new(0.0, 0.0, _latest.aim_point, false)
	return _latest


func _reject() -> bool:
	rejected_count += 1
	return false
