extends TestCase
## C34.7 (round 34, native; R33.25): a player host whose relay session ends while a shell is in flight. The host keeps
## simulating (its bots fight on), the shell lands, and `_shell_hit`'s show_impact.rpc() used to go to a peer that is no
## longer connected: Godot logs "Trying to call an RPC via a multiplayer peer which is not connected" (relay-smoke's
## red under a full check's load). The runner fails any test that logs an engine error, so this test is red without
## the guard. The host still sees its own impact (call_local), and the rules still score the hit.


func teardown() -> void:
	tree.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	super.teardown()


## A seated relay host (the broker's "hosted"), with a grace of 0 so a drop ends the session on the next poll.
func _seated_host() -> RelayPeer:
	var peer := RelayPeer.new()
	peer.role = RelayPeer.Role.HOST
	peer.on_control({"op": "hosted", "room": "K7QX2", "peer_id": 1, "token": "t", "grace_ms": 0})
	return peer


func test_a_shell_landing_after_the_relay_session_ended_sends_no_rpc() -> void:
	var peer := _seated_host()
	tree.get_multiplayer().multiplayer_peer = peer
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN, "tank")
	var victim := game_match.spawn_tank("Victim", 0, Match.Team.RUST, "tank")
	shooter.respawn(Vector3(0, 0.6, 0), 0.0)
	victim.respawn(Vector3(0, 0.6, -15), 0.0)
	await wait_physics_frames(1)
	var impacts: Array[Dictionary] = []
	Watch.on(game_match.projectile_impact, func(event: Dictionary) -> void: impacts.append(event))
	var health := victim.health
	shooter.fired.emit(shooter.muzzle_position(), -shooter.global_basis.z)
	assert_eq(game_match.shells.get_child_count(), 1, "the shell is in flight")
	peer.simulate_drop(60.0)  # the socket goes; the 0 ms grace ends the session at the next poll
	await wait_physics_frames(2)
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "the relay session has ended")
	assert_eq(impacts.size(), 0, "the shell was still in flight when the session ended")
	for i in 30:
		if not impacts.is_empty():
			break
		await wait_physics_frames(1)
	assert_eq(impacts.size(), 1, "the shell landed after the drop")
	assert_eq(String(impacts[0].get("target", "")), "Victim", "it hit the victim (%s)" % [impacts[0]])
	assert_true(victim.health < health, "the host's rules still scored the hit (%d -> %d)" % [health, victim.health])
