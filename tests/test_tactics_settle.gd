extends TestCase
## Round 10, squad item 3: a plain move's slots are seated by the least total driving, the LEADER included, so no
## crew drives through its own squad. Round 9 pinned the leader to the head of the shape: a squad abreast told to move
## 20 m to its side put the leader (at one end of the line) 46.8 m from its slot, through the other three
## (make squad-settle DIR=side, default arena, laptop). The falsifier is geometric and cheap: no two crews' straight
## paths from where they stand to their slots cross, and nobody's slot is further than the move plus the shape.

const MEMBERS := ["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"]


func _abreast(scenario: AiScenario) -> void:
	for i in MEMBERS.size():
		scenario.brain_tank(Match.Team.GREEN, MEMBERS[i], Vector3(-12.0 + i * 8.0, 0.0, 40.0), 0.0, {},
				"tank" if i < 2 else "ifv")


## Pairs of crews that pass each other on the way to their slots ([] when none do): their order ALONG the move
## reverses (one drives through the other's place in the file), or their paths properly cross side to side. Collinear
## paths that keep their order are crews following one another, which is fine.
static func crossings(from: Dictionary, to: Dictionary, direction: Vector3) -> Array:
	var names: Array = to.keys()
	names.sort()
	var along := Vector2(direction.x, direction.z).normalized()
	var found: Array = []
	for a in names.size():
		for b in range(a + 1, names.size()):
			var p1 := Vector2(from[names[a]].x, from[names[a]].z)
			var p2 := Vector2(to[names[a]].x, to[names[a]].z)
			var q1 := Vector2(from[names[b]].x, from[names[b]].z)
			var q2 := Vector2(to[names[b]].x, to[names[b]].z)
			var before := (p1 - q1).dot(along)
			var after := (p2 - q2).dot(along)
			var inverted: bool = absf(before) > 0.5 and absf(after) > 0.5 and signf(before) != signf(after)
			var d1 := p2 - p1
			var d2 := q2 - q1
			var parallel: bool = absf(d1.cross(d2)) < 0.05 * d1.length() * d2.length()
			var crossed: bool = not parallel and Geometry2D.segment_intersects_segment(p1, p2, q1, q2) != null
			if inverted or crossed:
				found.append("%s x %s" % [names[a], names[b]])
	return found


func _seated(direction: Vector3, pin: bool) -> Dictionary:
	var scenario := AiScenario.create(self)
	_abreast(scenario)
	var elements := Elements.install(scenario.game_match, scenario.orders())
	await scenario.start()
	var before := ElementPlan.PIN_LEADER_ON_PLAIN_MOVE
	ElementPlan.PIN_LEADER_ON_PLAIN_MOVE = pin
	var alpha := elements.form(MEMBERS, "Alpha")
	var from := {}
	for member: String in MEMBERS:
		from[member] = (scenario.game_match.tanks.get_node(member) as Node3D).global_position
	var goal := Vector3(0.0, 0.0, 40.0) + direction * 20.0
	alpha.assign({"verb": "move", "to": [goal.x, goal.z], "drills": false})
	for i in Element.UPDATE_TICKS + 1:
		await scenario.step()
	ElementPlan.PIN_LEADER_ON_PLAIN_MOVE = before
	var slots := alpha.slots.duplicate()
	var farthest := 0.0
	for member: String in slots:
		farthest = maxf(farthest, Vector3(from[member].x, 0.0, from[member].z).distance_to(slots[member]))
	var result := {"crossings": crossings(from, slots, direction), "farthest": farthest, "formation": alpha.formation,
			"slots": slots.size()}
	scenario.dispose()
	return result


func test_a_sideways_plain_move_seats_every_crew_without_crossing_paths() -> void:
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		var seated := await _seated(direction, false)
		assert_eq(int(seated["slots"]), 4, "setup: every crew has a slot (%s)" % str(direction))
		print("MEASURE settle_seating dir %s formation %s farthest %.1f m crossings %s" \
				% [str(direction), seated["formation"], seated["farthest"], str(seated["crossings"])])
		assert_eq(seated["crossings"], [], "no crew drives through another to its slot (%s)" % str(direction))


func test_the_pinned_leader_was_the_crossing() -> void:
	# The positive control (B12): the round-9 arm, same scenario, must show the defect the fix removes, or the test
	# above proves nothing about the pin.
	var crossed := 0
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		var seated := await _seated(direction, true)
		crossed += (seated["crossings"] as Array).size()
	assert_true(crossed > 0, "with the leader pinned to the head, some crews' paths cross (%d)" % crossed)
