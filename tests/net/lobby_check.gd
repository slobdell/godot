extends SceneTree
## `make lobby-smoke`: the real game with --lobby against a running broker (--relay=ws://...).
## Taps through the touch lobby like a player: types a room code that doesn't exist and taps JOIN
## (the lobby must come back saying so), then taps HOST A MATCH (a room must open, with the badge).
## Prints LOBBY_CHECK PASS/FAIL.

const TIMEOUT_MSEC := 20000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var hud: Node = main.get_node("HUD")
	var panel := await _wait_for_panel(hud, null)
	if panel == null:
		return _finish(false, "no lobby panel")
	for character in "ZZZZZ":
		panel.key_buttons[LobbyPanel.ALPHABET.find(character)].pressed.emit()
	panel.join_button.pressed.emit()
	var back := await _wait_for_panel(hud, panel)
	if back == null:
		return _finish(false, "the lobby didn't come back after joining a room that doesn't exist")
	var status: String = back._status_label.text
	if not status.contains("No room ZZZZZ"):
		return _finish(false, "unexpected lobby message: %s" % status)
	print("LOBBY_CHECK wrong code -> back in the lobby: %s" % status)
	back.host_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var badge := hud.get_node_or_null("RoomBadge") as RoomBadge
		if badge != null and badge.code.length() == 5:
			var tanks: Node = main.get_node("Match/Tanks")
			return _finish(tanks.get_child_count() >= 1,
					"hosting room %s with the badge shown, tanks=%d" % [badge.code, tanks.get_child_count()])
	_finish(false, "HOST never opened a room")


func _wait_for_panel(hud: Node, not_this: Variant) -> LobbyPanel:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for child in hud.get_children():
			if child is LobbyPanel and child != not_this and not child.is_queued_for_deletion():
				return child
	return null


func _finish(ok: bool, summary: String) -> void:
	print("LOBBY_CHECK %s %s" % ["PASS" if ok else "FAIL", summary])
	if root.multiplayer.multiplayer_peer != null:
		root.multiplayer.multiplayer_peer.close()
	root.multiplayer.multiplayer_peer = null
	quit(0 if ok else 1)
