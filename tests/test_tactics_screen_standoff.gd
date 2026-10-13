extends TestCase
## Round 28, brains B3 (DECLARED): RECON SCREENS AT A SPOTTER'S DISTANCE. The CPU commander sent its recon to screen a
## point 45 m short of the enemy focus and held it while the enemy drove onto it (scout's census: most fixed-gun hull
## contacts with the enemy were under an ordered MOVE). Now, with an enemy known, the screen stands
## ElementCommander.SCREEN_STANDOFF_M from the enemy nearest it, on its own side; `--screen-standoff=off` is the old rule.


func teardown() -> void:
	ElementCommander.SCREEN_STANDOFF_ENABLED = true
	super.teardown()


func test_the_nearest_contact_is_found() -> void:
	var contacts := [{"name": "A", "position": Vector3(100, 0, 0)}, {"name": "B", "position": Vector3(10, 0, 5)}]
	assert_eq(String(ElementCommander._nearest_to(contacts, Vector3.ZERO)["name"]), "B", "the nearer one")
	assert_true(ElementCommander._nearest_to([], Vector3.ZERO).is_empty(), "none known: {}")


## Three scouts (a recon element) 120 m south of an enemy tank the team has seen, under the CPU's commander.
func _screen_point(standoff_on: bool) -> Dictionary:
	ElementCommander.SCREEN_STANDOFF_ENABLED = standoff_on
	var lab := TacticsLab.create(self, 3, "yard_open")
	var names: Array = []
	for i in 3:
		names.append(String(lab.unit(Match.Team.RUST, "Rust_Eyes_%d" % (i + 1), Vector3(i * 8.0 - 8.0, 0.0, 60.0), 0.0,
				"law_scout").name))
	var enemy := lab.gun(Match.Team.GREEN, "Green_T_1", Vector3(0.0, 0.0, -60.0), PI)
	var element := lab.elements.form(names, "Eyes", DoctrineTable.load_table("law")["table"])
	await lab.start()
	ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	for tick in SimClock.TICK_RATE * 3:
		await lab.step()
	var task := element.task.duplicate(true)
	var at := enemy.global_position
	lab.dispose()
	return {"task": task, "enemy": at}


func test_the_screen_stands_a_spotters_distance_off_the_enemy() -> void:
	var on := await _screen_point(true)
	var task: Dictionary = on["task"]
	assert_eq(String(task.get("verb", "")), "screen", "recon screens (%s)" % task)
	if not (task.get("to") is Array):
		return
	var point := Vector3(float(task["to"][0]), 0.0, float(task["to"][1]))
	var enemy: Vector3 = on["enemy"]
	var off := Vector2(point.x - enemy.x, point.z - enemy.z).length()
	assert_near(off, ElementCommander.SCREEN_STANDOFF_M, 10.0, "the screen is a spotter's distance off the enemy (%.1f m)" % off)
	assert_true(point.z > enemy.z, "on its own side of it (%s)" % point)
	var old := await _screen_point(false)
	var old_task: Dictionary = old["task"]
	if old_task.get("to") is Array:
		var old_point := Vector3(float(old_task["to"][0]), 0.0, float(old_task["to"][1]))
		var old_off := Vector2(old_point.x - enemy.x, old_point.z - enemy.z).length()
		assert_true(old_off < off - 20.0, "control: the old screen stood much closer (%.1f m)" % old_off)
