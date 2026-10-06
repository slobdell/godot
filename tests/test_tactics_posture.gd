extends TestCase
## Round 19 (brains B2): the posture rule. A side that is ahead on points, or whose zone is threatened, HOLDS; a side that
## holds nothing, or is behind with its zone quiet, ATTACKS (as every round before 19).

const GREEN := Match.Team.GREEN
const RUST := Match.Team.RUST


func _zones(west_owner: int, east_owner: int) -> Array:
	return [{"name": "west", "position": Vector3(-36, 0, 24), "radius": 15.0, "owner": west_owner},
			{"name": "east", "position": Vector3(36, 0, -24), "radius": 15.0, "owner": east_owner}]


func _contact(at: Vector3) -> Dictionary:
	return {"name": "Green_1", "position": at}


func test_ahead_on_points_and_holding_a_zone_holds_it() -> void:
	var decided := Posture.decide(RUST, [3, 10], _zones(-1, RUST), [], Vector3(0, 0, 90))
	assert_eq(String(decided["posture"]), "hold", "ahead and holding: hold (%s)" % decided)
	assert_eq(String(decided["zone"]["name"]), "east", "the zone it holds")


func test_behind_with_a_quiet_zone_attacks() -> void:
	var decided := Posture.decide(RUST, [10, 3], _zones(GREEN, RUST), [_contact(Vector3(-30, 0, 60))], Vector3(-30, 0, 60))
	assert_eq(String(decided["posture"]), "attack", "behind, nobody near its zone (%s)" % decided)


func test_a_threatened_zone_is_held_even_when_behind() -> void:
	var decided := Posture.decide(RUST, [10, 3], _zones(GREEN, RUST), [_contact(Vector3(20, 0, 10))], Vector3(20, 0, 10))
	assert_eq(String(decided["posture"]), "hold", "an enemy %.0f m from its zone (%s)" % [Vector3(20, 0, 10).distance_to(Vector3(36, 0, -24)), decided])
	assert_eq(String(decided["zone"]["name"]), "east", "the threatened zone")


func test_holding_nothing_attacks_even_when_ahead() -> void:
	var decided := Posture.decide(RUST, [0, 30], _zones(-1, GREEN), [], Vector3(0, 0, 90))
	assert_eq(String(decided["posture"]), "attack", "nothing to defend (%s)" % decided)


func test_level_on_points_with_a_quiet_zone_attacks() -> void:
	var decided := Posture.decide(GREEN, [5, 5], _zones(GREEN, RUST), [], Vector3(0, 0, -90))
	assert_eq(String(decided["posture"]), "attack", "level is not ahead (%s)" % decided)


func test_holding_both_it_holds_the_one_nearer_the_enemy() -> void:
	var decided := Posture.decide(RUST, [0, 40], _zones(RUST, RUST), [], Vector3(-40, 0, 90))
	assert_eq(String(decided["zone"]["name"]), "west", "the front zone (%s)" % decided)


func test_the_rule_is_the_same_for_either_side() -> void:
	var rust := Posture.decide(RUST, [3, 10], _zones(-1, RUST), [], Vector3(0, 0, 90))
	var green := Posture.decide(GREEN, [10, 3], _zones(GREEN, -1), [], Vector3(0, 0, -90))
	assert_eq(String(rust["posture"]), String(green["posture"]), "mirrored situations, the same posture")
