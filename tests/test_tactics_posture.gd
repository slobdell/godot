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


func test_defend_reaches_further_than_a_held_zones_threat() -> void:
	var zones := _zones(-1, -1)
	var at := Vector3(36, 0, 61)  # 85 m from our near ring
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(at)], at, {}, _near(zones))
	assert_eq(String(decided["posture"]), "hold", "%.0f m out: in place before its guns reach the posts (%s)" % [
			at.distance_to(Vector3(36, 0, -24)), decided])


# D2b: an enemy sitting on a zone its side owns is home, not coming, even within DEFEND_M of our ring (the turtle line).
func test_an_enemy_sitting_on_its_own_zone_is_attacked_not_defended_against() -> void:
	var zones := _zones(GREEN, -1)
	var home := Vector3(-30, 0, 20)  # on Green's west zone, ~80 m from our near ring
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(home)], home, {}, _near(zones))
	assert_true(home.distance_to(Vector3(36, 0, -24)) < Posture.DEFEND_M, "inside DEFEND_M, so D2 alone would defend")
	assert_eq(String(decided["posture"]), "attack", "the turtle at home: go and get it (%s)" % decided)


func test_an_enemy_coming_for_our_ring_is_defended_though_its_side_owns_a_zone() -> void:
	var zones := _zones(GREEN, -1)
	var coming := Vector3(20, 0, -10)
	var decided := Posture.decide(RUST, [0, 0], zones, [_contact(Vector3(-36, 0, 24)), _contact(coming)], coming, {},
			_near(zones))
	assert_eq(String(decided["posture"]), "hold", "one sits at home, one comes for us: defend (%s)" % decided)
	assert_eq(String(decided["zone"]["name"]), "east", "our near ring")


func test_with_defend_on_a_held_zone_is_not_threatened_by_an_enemy_at_home() -> void:
	var zones := [{"name": "west", "position": Vector3(-36, 0, 24), "radius": 15.0, "owner": GREEN},
			{"name": "mid", "position": Vector3(10, 0, 0), "radius": 15.0, "owner": RUST},
			{"name": "east", "position": Vector3(36, 0, -24), "radius": 15.0, "owner": -1}]
	var home := Vector3(-30, 0, 20)  # on Green's west zone, ~45 m from our mid zone
	var off := Posture.decide(RUST, [0, 0], zones, [_contact(home)], home)
	assert_true(String(off["why"]).begins_with("zone threatened"), "switch off: today's rule (%s)" % off)
	var on := Posture.decide(RUST, [0, 0], zones, [_contact(home)], home, {}, zones[2])
	assert_eq(String(on["posture"]), "attack", "switch on: the enemy is home, not coming (%s)" % on)


# DEFEND (e): an element in contact near its post stands where it is; one far off drives to its post.
func test_an_element_in_contact_near_its_post_stands_where_it_is() -> void:
	var post := Vector3(10, 0, 10)
	assert_eq(ElementCommander.stand_post(post, Vector3(30, 0, 10), true, null), Vector3(30, 0, 10), "20 m off, in contact: stand")
	assert_eq(ElementCommander.stand_post(post, Vector3(60, 0, 10), true, null), post, "50 m off: drive to the post")
	assert_eq(ElementCommander.stand_post(post, Vector3(30, 0, 10), false, null), post, "no contact: take the post")
	assert_eq(ElementCommander.stand_post(post, Vector3(5, 0, 5), true, Vector3(30, 0, 10)), Vector3(30, 0, 10),
			"a stand point is kept while the post is where it was")
	assert_eq(ElementCommander.stand_post(Vector3(120, 0, 10), Vector3(5, 0, 5), false, Vector3(30, 0, 10)), Vector3(120, 0, 10),
			"posts laid elsewhere: the old stand point is dropped")


# D2c (2): with CLOSING on (`closing` is the names closing on the ring, [] = none), only an enemy closing makes us defend;
# one that stopped 85 m out does not hold the side.
func test_with_closing_on_only_a_closing_enemy_makes_us_defend() -> void:
	var zones := _zones(-1, -1)
	var at := Vector3(36, 0, 61)  # 85 m from our near ring
	var still := Posture.decide(RUST, [0, 0], zones, [_contact(at)], at, {}, _near(zones), [])
	assert_eq(String(still["posture"]), "attack", "it stopped out there: go on as before (%s)" % still)
	var closing := Posture.decide(RUST, [0, 0], zones, [_contact(at)], at, {}, _near(zones), ["Green_1"])
	assert_eq(String(closing["posture"]), "hold", "it is coming: defend (%s)" % closing)
	assert_eq(int(closing.get("coming", 0)), 1, "the defend decision counts what is coming (%s)" % closing)


# D2c (2)+(3): a contact is closing once its distance to the ring has fallen CLOSING_M over a CLOSING_WINDOW, and stays
# closing for DEFEND_LAPSE after the last time it did; one standing still never is.
func test_a_contact_is_closing_for_a_lapse_after_it_last_closed() -> void:
	var w := Posture.CLOSING_WINDOW_TICKS
	var track := Posture.track_closing([], 0, 90.0)
	assert_true(not Posture.is_closing(track, 0), "first seen: not yet")
	track = Posture.track_closing(track, w / 2, 70.0)
	assert_true(not Posture.is_closing(track, w / 2), "inside the window: not judged yet")
	track = Posture.track_closing(track, w, 70.0)
	assert_true(Posture.is_closing(track, w), "20 m nearer over a window: closing")
	var lapse := w + Posture.DEFEND_LAPSE_TICKS
	track = Posture.track_closing(track, lapse - 1, 70.0)
	assert_true(Posture.is_closing(track, lapse - 1), "stopped since: still closing until the lapse")
	track = Posture.track_closing(track, lapse + 1, 70.0)
	assert_true(not Posture.is_closing(track, lapse + 1), "DEFEND_LAPSE without closing: the defend lapses")
	track = Posture.track_closing(track, lapse + 1 + w, 50.0)
	assert_true(Posture.is_closing(track, lapse + 1 + w), "closing again: re-armed")
	var still := Posture.track_closing([], 0, 90.0)
	for k in range(1, 6):
		still = Posture.track_closing(still, w * k, 90.0 - 2.0 * k)
		assert_true(not Posture.is_closing(still, w * k), "a crawl under CLOSING_M a window is not closing")


# D2c (1): defend takes only the elements the coming threat needs, nearest first, at least one and at most half the line.
func test_defend_takes_only_the_elements_the_threat_needs() -> void:
	assert_eq(ElementCommander.defenders_needed([4, 4, 4, 4], 3), 1, "three coming: one element of four")
	assert_eq(ElementCommander.defenders_needed([4, 4, 4, 4], 6), 2, "six coming: two")
	assert_eq(ElementCommander.defenders_needed([4, 4, 4, 4], 20), 2, "a blob: at most half the line")
	assert_eq(ElementCommander.defenders_needed([4, 4, 4], 20), 2, "half of three, rounded up")
	assert_eq(ElementCommander.defenders_needed([2, 4, 4], 3), 2, "the nearest is short: two")
	assert_eq(ElementCommander.defenders_needed([4, 4], 0), 1, "nothing counted: still one on the ring")
	assert_eq(ElementCommander.defenders_needed([4], 9), 1, "one element: it holds")
