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


# ---- Round 20 (brains M2): the opening. A side that spawns nearer a ring than the enemy, on a map that gives it an ambush
# site there, takes that ring first and HOLDS it from the start, instead of racing to the centre and turning to hold only
# when an enemy is 33-35 m off (round 19's census: by then its line was in contact and no ambush was ever laid).

## Rust spawns north-east (36, -90), Green south-west: Rust's near ring is "east".
func _opening(site := true) -> Dictionary:
	return {"name": Posture.near_ring(_zones(-1, -1), Vector3(36, 0, -90), Vector3(-36, 0, 90)), "site": site}


func test_the_near_ring_is_the_one_nearer_our_spawn_than_theirs() -> void:
	assert_eq(Posture.near_ring(_zones(-1, -1), Vector3(36, 0, -90), Vector3(-36, 0, 90)), "east", "Rust's near ring")
	assert_eq(Posture.near_ring(_zones(-1, -1), Vector3(-36, 0, 90), Vector3(36, 0, -90)), "west", "Green's near ring")
	var centre := [{"name": "centre", "position": Vector3(0, 0, 0), "radius": 15.0, "owner": -1}]
	assert_eq(Posture.near_ring(centre, Vector3(36, 0, -90), Vector3(-36, 0, 90)), "", "a centre ring is nobody's near ring")


func test_at_the_start_a_side_with_a_near_ring_and_a_site_takes_it_and_holds() -> void:
	var decided := Posture.decide(RUST, [0, 0], _zones(-1, -1), [], Vector3(-36, 0, 90), _opening())
	assert_eq(String(decided["posture"]), "hold", "0-0, nothing held yet: the opening holds (%s)" % decided)
	assert_eq(String(decided["zone"]["name"]), "east", "its near ring")
	assert_true(String(decided["why"]).begins_with("opening"), "and says why (%s)" % decided["why"])
	var held := Posture.decide(RUST, [0, 4], _zones(-1, RUST), [], Vector3(-36, 0, 90), _opening())
	assert_eq(String(held["zone"]["name"]), "east", "once taken, still the near ring (%s)" % held)


func test_the_opening_needs_a_site_and_is_given_up_when_behind_or_the_ring_is_lost() -> void:
	var no_site := Posture.decide(RUST, [0, 0], _zones(-1, -1), [], Vector3(-36, 0, 90), _opening(false))
	assert_eq(String(no_site["posture"]), "attack", "no bay or flank site: attack as before (%s)" % no_site)
	var behind := Posture.decide(RUST, [6, 2], _zones(GREEN, RUST), [], Vector3(-36, 0, 90), _opening())
	assert_eq(String(behind["posture"]), "attack", "behind on points: go and get them (%s)" % behind)
	var lost := Posture.decide(RUST, [0, 0], _zones(-1, GREEN), [], Vector3(-36, 0, 90), _opening())
	assert_eq(String(lost["posture"]), "attack", "the enemy holds our near ring: attack (%s)" % lost)
	var none := Posture.decide(RUST, [0, 0], _zones(-1, -1), [], Vector3(-36, 0, 90))
	assert_eq(String(none["posture"]), "attack", "no opening given (the control arm): round 19's rule (%s)" % none)


# ---- Round 38 (doctrine D2): DEFEND. D1 (stream/doctrine Status): in the blob line 75 % of the CPU's damage was fired in
# ATTACK posture from its own half, "holds no objective": the blob reached its near ring before the CPU had taken it, so
# the CPU met it as an attacker. With `near` (the side's near ring, handed only when the switch is on) a side whose near
# ring is not the enemy's and has a known enemy within THREAT_M of it HOLDS that ring.

func _near(zones: Array) -> Dictionary:
	var name := Posture.near_ring(zones, Vector3(36, 0, -90), Vector3(-36, 0, 90))
	for zone: Dictionary in zones:
		if String(zone["name"]) == name:
			return zone
	return {}


func test_without_the_near_ring_holding_nothing_still_attacks() -> void:
	var zones := _zones(-1, -1)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(20, 0, -10))], Vector3(20, 0, -10))
	assert_eq(String(decided["posture"]), "attack", "switch off: today's rule (%s)" % decided)


func test_an_enemy_at_our_unowned_near_ring_is_defended() -> void:
	var zones := _zones(-1, -1)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(20, 0, -10))], Vector3(20, 0, -10), {}, _near(zones))
	assert_eq(String(decided["posture"]), "hold", "enemy %.0f m from our near ring (%s)" % [Vector3(20, 0, -10).distance_to(
			Vector3(36, 0, -24)), decided])
	assert_eq(String(decided["zone"]["name"]), "east", "our near ring")
	assert_true(String(decided["why"]).begins_with("defend"), "and says why (%s)" % decided["why"])


func test_a_far_enemy_does_not_make_us_defend() -> void:
	var zones := _zones(-1, -1)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(-36, 0, 70))], Vector3(-36, 0, 70), {}, _near(zones))
	assert_eq(String(decided["posture"]), "attack", "nobody near our ring: go and take things (%s)" % decided)


func test_a_near_ring_the_enemy_owns_is_attacked_not_defended() -> void:
	var zones := _zones(-1, GREEN)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(30, 0, -20))], Vector3(30, 0, -20), {}, _near(zones))
	assert_eq(String(decided["posture"]), "attack", "theirs now: take it back (%s)" % decided)


func test_defending_is_the_same_rule_for_either_side() -> void:
	var zones := _zones(-1, -1)
	var rust := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(20, 0, -10))], Vector3(20, 0, -10), {}, _near(zones))
	var green_near := {}
	for zone: Dictionary in zones:
		if String(zone["name"]) == Posture.near_ring(zones, Vector3(-36, 0, 90), Vector3(36, 0, -90)):
			green_near = zone
	var green := Posture.decide(GREEN, [0, 0], zones, [_contact(Vector3(-20, 0, 10))], Vector3(-20, 0, 10), {}, green_near)
	assert_eq(String(rust["posture"]), String(green["posture"]), "mirrored: both defend")
	assert_eq(String(green["zone"]["name"]), "west", "Green's near ring")


func test_a_threatened_held_zone_still_comes_first() -> void:
	var zones := _zones(RUST, -1)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(-30, 0, 30)), _contact(Vector3(20, 0, -10))],
			Vector3(0, 0, 10), {}, _near(zones))
	assert_eq(String(decided["zone"]["name"]), "west", "the zone we hold, threatened, before the near ring (%s)" % decided)
