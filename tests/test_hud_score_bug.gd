extends TestCase
## Round 19 (board, S2): the score bug and the zone rings read the one snapshot (C19.4), react to what changed, and
## sleep when nothing moves (the HUD's per-frame cost on his laptop is a known line; the board adds nothing at rest).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _snap(points: Array, owners: Array, kills := [0, 0], progress: Array = []) -> Dictionary:
	var zones: Array = []
	for i in owners.size():
		var p: float = progress[i] if i < progress.size() else (1.0 if owners[i] == 0 else (-1.0 if owners[i] == 1 else 0.0))
		zones.append({"name": "z%d" % i, "label": ["the west ring", "the east ring"][i], "owner": owners[i], "progress": p,
				"position": Vector3(-75 + 150 * i, 0, 0), "radius": 15.0, "present": [0, 0], "contested": false})
	var sides: Array = []
	for t in 2:
		var held: int = owners.count(t)
		sides.append({"team": t, "faction": "", "name": ["HOME", "AWAY"][t], "points": points[t], "points_to_win": 90,
				"to_win": 90 - int(points[t]), "rate": float(held) / float(maxi(1, owners.size())), "zones": [],
				"zones_held": held, "kills": kills[t], "credits": int(kills[t]) * 100, "units_alive": 5})
	return {"version": 1, "tick": 0, "seconds": 0.0, "control": true, "finished": false, "points_to_win": 90,
			"leader": MatchScore.leader(sides, true), "objectives": zones, "sides": sides}


func test_the_bug_sleeps_at_rest_and_wakes_on_a_change() -> void:
	var bug := ScoreBug.new()
	add_to_tree(bug)
	bug.set_snapshot(_snap([0, 0], [-1, -1]))
	bug._animate(10.0)
	assert_true(not bug.is_animating(), "a level match with nobody scoring: nothing to animate")
	bug.set_snapshot(_snap([0, 0], [0, -1]))
	assert_true(bug.is_animating(), "a zone taken: awake")
	assert_true(not bug._flare.is_empty(), "and the moment is called on the bug")
	assert_true(String(bug._flare["text"]).contains("WEST RING"), "by the zone's name: %s" % bug._flare.get("text", ""))
	bug.set_snapshot(_snap([1, 0], [0, -1]))
	assert_true(bug._pop[0] > 0.0, "a point: the +1 pops off the number")
	bug.set_snapshot(_snap([1, 0], [-1, -1]))
	bug._animate(10.0)
	assert_true(not bug.is_animating(), "nobody scoring again, the animations done: asleep")


func test_a_lead_change_is_called() -> void:
	var bug := ScoreBug.new()
	add_to_tree(bug)
	bug.set_snapshot(_snap([40, 39], [-1, 1]))
	bug._animate(10.0)
	bug.set_snapshot(_snap([40, 41], [-1, 1]))
	assert_true(bug._lead_flare > 0.0, "the lead changed hands")
	bug.set_snapshot(_snap([40, 42], [-1, 1]))
	bug._animate(10.0)
	bug.set_snapshot(_snap([41, 42], [0, 1], [0, 0]))
	assert_true(String(bug._flare.get("text", "")).contains("TAKE"), "a zone taken outranks the lead line")


func test_a_kill_flashes_the_tally() -> void:
	var bug := ScoreBug.new()
	add_to_tree(bug)
	bug.set_snapshot(_snap([0, 0], [-1, -1]))
	bug.set_snapshot(_snap([0, 0], [-1, -1], [1, 0]))
	assert_true(bug._kill_flash[0] > 0.0, "the side that scored the kill flashes")
	assert_near(bug._kill_flash[1], 0.0, 0.0001, "the other does not")


func test_zone_letters() -> void:
	var zones := [{"label": "the west ring"}, {"label": "the east ring"}]
	assert_eq(ScoreBug._zone_letter("the west ring", zones, 0), "W", "west")
	assert_eq(ScoreBug._zone_letter("the east ring", zones, 1), "E", "east")
	var same := [{"label": "the depot"}, {"label": "the far depot"}]
	assert_eq(ScoreBug._zone_letter("the depot", same, 0), "D", "depot")
	assert_eq(ScoreBug._zone_letter("the far depot", same, 1), "F", "far depot")
	assert_eq(ScoreBug._thousands(12345), "12,345", "credits read with a separator")


func test_the_hud_shows_the_bug_and_the_rings_in_a_control_match() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	game_match.elimination = true
	add_to_tree(game_match)
	var hud: Hud = add_to_tree(load("res://game/ui/hud.tscn").instantiate())
	hud.game_match = game_match
	game_match.spawn_tank("Green_1", 0, Match.Team.GREEN).global_position = Vector3(5, 0, 5)
	game_match.spawn_tank("Rust_1", 0, Match.Team.RUST).global_position = Vector3(0, 0, -90)
	await wait_physics_frames(3)
	await tree.process_frame
	assert_true(hud.score_bug != null, "the bug is up")
	assert_eq(hud.scoreboard.text, "", "the old units-vs-units line is gone")
	assert_true(hud.zone_rings != null, "the rings are on the floor")
	if hud.zone_rings == null or hud.score_bug == null:
		return
	assert_eq(hud.zone_rings._materials.size(), game_match.objectives.size(), "one ring per scoring zone")
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * float(SimClock.TICK_RATE)) + SimClock.TICK_RATE)
	assert_eq(game_match.control_owner, Match.Team.GREEN, "setup: Green took it")
	assert_near(float(hud.zone_rings._materials[0].get_shader_parameter("held")), 1.0, 0.001, "the ring shows it held")
	assert_eq(int(hud.score_bug.snapshot["objectives"][0]["owner"]), Match.Team.GREEN, "the bug read the same snapshot")
	assert_true(hud.zone_rings._labels[0].text.contains("SCORING"), "and the ring says it is scoring")


func test_a_ghastly_kill_gets_the_broadcasts_graphic() -> void:
	assert_eq(ScoreBug.stinger(["kill"], {}, "LAW", "CONDEMNED"), "", "an ordinary kill: the tally only")
	assert_eq(ScoreBug.stinger(["streak", "rear"], {"streak": 4}, "LAW", "CONDEMNED"), "LAW: 4 STRAIGHT KILLS", "a streak first")
	assert_eq(ScoreBug.stinger(["last_unit"], {}, "LAW", "CONDEMNED"), "CONDEMNED DOWN TO THEIR LAST VEHICLE", "a last unit")
	assert_eq(ScoreBug.stinger(["final_kill", "rear"], {}, "LAW", "CONDEMNED"), "", "the last kill is the banner's")
	var bug := ScoreBug.new()
	add_to_tree(bug)
	bug.set_snapshot(_snap([0, 0], [-1, -1]))
	bug._animate(10.0)
	bug.on_cue({"moment": "kill", "team": "rust", "intensity": 3, "_moment": {"tags": ["kill", "rear"]}, "slots": {}})
	assert_eq(String(bug._flare.get("text", "")), "AWAY: KILL FROM BEHIND", "the graphic goes up for the killer's side")
	assert_true(bug._scale[1] > 1.0, "and an intense call makes the celebration bigger")
	bug.set_snapshot(_snap([0, 0], [-1, -1], [0, 1]))
	assert_true(float(bug._credit_pop[1][1]) > 0.0, "the credits pop off the tally")
	assert_eq(int(bug._credit_pop[1][0]), 100, "by what the kill was worth")
