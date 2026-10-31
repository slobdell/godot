extends TestCase
## R47.48 (engage E10): OUTRANGED. The memory (Outranged) reads what the rounds themselves say: two damaging hits in 4 s
## fired from beyond the crew's reach, or by a gun it cannot see, or one heavy one. The staged case is spotter's class E in
## his shape (his Crossing complaint): short guns on an attack, two lancers out of their reach burning them down; with
## `--outranged` on, the crews close instead of sitting in the open.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _memory_with(hits: Array) -> Outranged:
	var memory := Outranged.new()
	var id := 0
	for hit: Dictionary in hits:
		memory.note_fired(id, String(hit.get("shooter", "Rust_G_1")), hit["from"], int(hit["tick"]) - 3)
		memory.note_hit(id, "Green_O_1", float(hit.get("damage", 30.0)), int(hit["tick"]))
		id += 1
	return memory


func test_two_hits_from_beyond_its_reach_read_as_outranged() -> void:
	var memory := _memory_with([{"from": Vector3(0, 0, -80), "tick": 10}, {"from": Vector3(0, 0, -80), "tick": 40}])
	var read := memory.read("Green_O_1", Vector3.ZERO, 50.0, 41, {"Rust_G_1": true})
	assert_true(not read.is_empty(), "two hits from 80 m on a 50 m gun")
	assert_true(absf(float(read["distance"]) - 80.0) < 0.01, "from where the rounds came (%s)" % [read])


func test_hits_from_inside_its_reach_by_a_gun_it_sees_are_not_outranged() -> void:
	var memory := _memory_with([{"from": Vector3(0, 0, -40), "tick": 10}, {"from": Vector3(0, 0, -40), "tick": 40}])
	assert_true(memory.read("Green_O_1", Vector3.ZERO, 50.0, 41, {"Rust_G_1": true}).is_empty(), "it can answer: not outranged")


func test_a_gun_it_cannot_see_counts_as_out_of_reach() -> void:
	var memory := _memory_with([{"from": Vector3(0, 0, -40), "tick": 10}, {"from": Vector3(0, 0, -40), "tick": 40}])
	assert_true(not memory.read("Green_O_1", Vector3.ZERO, 50.0, 41, {}).is_empty(), "nothing to answer: outranged")


func test_one_light_hit_is_not_enough_but_one_heavy_one_is() -> void:
	var memory := _memory_with([{"from": Vector3(0, 0, -90), "tick": 10, "damage": 20.0}])
	assert_true(memory.read("Green_O_1", Vector3.ZERO, 50.0, 11, {}, 400.0).is_empty(), "one 20 hp hit of 400")
	var heavy := _memory_with([{"from": Vector3(0, 0, -90), "tick": 10, "damage": 80.0}])
	assert_true(not heavy.read("Green_O_1", Vector3.ZERO, 50.0, 11, {}, 400.0).is_empty(), "one 80 hp hit of 400")


func test_old_hits_are_forgotten() -> void:
	var memory := _memory_with([{"from": Vector3(0, 0, -80), "tick": 10}, {"from": Vector3(0, 0, -80), "tick": 40}])
	assert_true(memory.read("Green_O_1", Vector3.ZERO, 50.0, 40 + int(Outranged.WINDOW_S * 30.0) + 1, {}).is_empty(),
			"4 s later it is over")


func test_its_own_rounds_and_rounds_never_fired_do_not_count() -> void:
	var memory := Outranged.new()
	memory.note_fired(1, "Green_O_1", Vector3(0, 0, -80), 0)
	memory.note_hit(1, "Green_O_1", 50.0, 2)
	memory.note_hit(2, "Green_O_1", 50.0, 3)  # never fired (a wall's splinter, a round from before the memory)
	assert_true(memory.read("Green_O_1", Vector3.ZERO, 50.0, 4, {}, 400.0).is_empty(), "nothing it can read")


## The staged case: three gang tanks (scrap cannon, 50 m) on an attack, two lancers (laser, 90 m) 66 m off in the open.
## Returns {"closed": metres the squad's centre came toward the guns, "dealt": damage on the guns, "lost": crews dead}.
func _staged(on: bool) -> Dictionary:
	var was := Outranged.ON
	Outranged.ON = on
	var lab := TacticsLab.create(self, 7004, "locks")
	var game_match := lab.game_match
	var guns_at := Vector3(10.0, 0.0, -10.0)
	var toward := Vector3(0.0, 0.0, 1.0)
	var names: Array = []
	for i in 3:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_O_%d" % (i + 1), guns_at + toward * 66.0 + Vector3((i - 1) * 7.0, 0, 0),
				0.0, "gang_tank").name))
	var guns: Array = []
	for i in 2:
		guns.append(lab.gun(Match.Team.RUST, "Rust_G_%d" % (i + 1), guns_at + Vector3((i - 0.5) * 8.0, 0, 0), PI, "syn_lancer"))
	var dealt := [0.0]
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if String(event.get("target", "")).begins_with("Rust_"):
			dealt[0] += float(event.get("damage", 0.0)))
	await lab.start()
	var element := lab.elements.form(names, "Oscar")
	element.assign({"verb": "attack", "target": String((guns[0] as Tank).name), "formation": "line"})
	var start := Vector3.ZERO
	for n: String in names:
		start += lab.tank_of(n).global_position / 3.0
	var last := start
	for tick in 30 * 30:
		await lab.step()
		var alive := names.filter(func(n: String) -> bool: return lab.tank_of(n) != null and lab.tank_of(n).is_alive())
		if alive.is_empty():
			break
		last = Vector3.ZERO
		for n: String in alive:
			last += lab.tank_of(n).global_position / float(alive.size())
	var lost := names.filter(func(n: String) -> bool: return lab.tank_of(n) == null or not lab.tank_of(n).is_alive()).size()
	lab.dispose()
	Outranged.ON = was
	return {"closed": start.distance_to(guns_at) - last.distance_to(guns_at), "dealt": dealt[0], "lost": lost}


func test_outranged_crews_on_an_attack_close_instead_of_sitting_in_the_open() -> void:
	var off := await _staged(false)
	var on := await _staged(true)
	print("MEASURE outranged_staged off %s on %s" % [off, on])
	assert_true(float(on["closed"]) - float(off["closed"]) >= 10.0, "with the rule the squad closes on the guns (off %s, on %s)" % [off, on])
	assert_true(float(on["dealt"]) > float(off["dealt"]), "and hurts them more than it did sitting (off %s, on %s)" % [off, on])
