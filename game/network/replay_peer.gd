class_name ReplayPeer
extends MultiplayerPeerExtension
## Plays back a match recorded by a relay player (`--join=CODE --record=PATH`): every packet the
## host sent that player, at its original time. Godot's replication rebuilds the match exactly as
## that player saw it (tanks, shells, damage), so a recording can be watched later from the same
## seat (`--replay=PATH`). Anything the local game tries to send is dropped.
##
## Recording format (RelayPeer.start_recording): "TSQREC1\n", one JSON line of metadata
## {"peer_id", "room"}, then records of int32 msec | int32 sender | uint8 flags | int32 length | payload.

signal finished

const MAGIC := "TSQREC1"

var metadata := {}
## Playback speed (2.0 = twice as fast).
var speed := 1.0
var error := ""

var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _records: Array = []  # [msec, sender, flags, payload]
var _next := 0
var _incoming: Array = []
var _start_msec := -1
var _announced := false


func open(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "cannot open %s" % path
		return FileAccess.get_open_error()
	if file.get_line() != MAGIC:
		error = "%s is not a Tank Squad recording" % path
		return ERR_FILE_UNRECOGNIZED
	var parsed: Variant = JSON.parse_string(file.get_line())
	metadata = parsed if parsed is Dictionary else {}
	while file.get_position() + 13 <= file.get_length():
		var msec := file.get_32()
		var sender := file.get_32()
		var flags := file.get_8()
		var length := file.get_32()
		_records.append([msec, sender, flags, file.get_buffer(length)])
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	return OK


func record_count() -> int:
	return _records.size()


func duration_msec() -> int:
	return int(_records[-1][0]) if not _records.is_empty() else 0


func _poll() -> void:
	if _status == MultiplayerPeer.CONNECTION_CONNECTING:
		_status = MultiplayerPeer.CONNECTION_CONNECTED
		_start_msec = Time.get_ticks_msec()
		peer_connected.emit(1)
		return
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var now := int((Time.get_ticks_msec() - _start_msec) * speed)
	while _next < _records.size() and int(_records[_next][0]) <= now:
		_incoming.append(_records[_next])
		_next += 1
	if _next >= _records.size() and not _announced:
		_announced = true
		finished.emit()


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	return _incoming.pop_front()[3] if not _incoming.is_empty() else PackedByteArray()


func _get_packet_peer() -> int:
	return int(_incoming[0][1]) if not _incoming.is_empty() else 1


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	if _incoming.is_empty():
		return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return (int(_incoming[0][2]) & 0b11) as MultiplayerPeer.TransferMode


func _get_packet_channel() -> int:
	return int(_incoming[0][2]) >> 2 if not _incoming.is_empty() else 0


func _put_packet_script(_buffer: PackedByteArray) -> Error:
	return OK  # a replay can't be influenced


func _get_max_packet_size() -> int:
	return RelayPeer.MAX_FRAME_BYTES


func _set_transfer_channel(_channel: int) -> void:
	pass


func _get_transfer_channel() -> int:
	return 0


func _set_transfer_mode(_mode: MultiplayerPeer.TransferMode) -> void:
	pass


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _set_target_peer(_peer: int) -> void:
	pass


func _is_server() -> bool:
	return false


func _get_unique_id() -> int:
	return int(metadata.get("peer_id", 2))


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(_enable: bool) -> void:
	pass


func _is_refusing_new_connections() -> bool:
	return true


func _disconnect_peer(_peer: int, _force: bool) -> void:
	pass


func _close() -> void:
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
