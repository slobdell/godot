extends TestCase
## Round 18, brains D1 (open ground): a formation's crews keep their guns on their SECTORS while it moves. Measured on the
## bare plate (settle probe, four tanks, 150 m): guns on their sectors in transit — line 100 %, wedge 50 %, column 25 %:
## a wedge's wingmen and a column's flank and tail crews looked forward until the halt, which in the open is the flank
## the lead's ambush comes from. A sector is TacticsFormation.sectors' azimuth off the heading; "on" = within half of
## SECTOR_WIDTH (45 degrees). A crew with a target fights it; this is about the guns with nothing to shoot.

const PLATE := "res://tests/tactics/plate.json"


## Share of crew-ticks, while the squad is on its way, with the turret within 45 degrees of the crew's sector.
func _guns_on_arc(shape: String, drills: bool) -> float:
	var lab := TacticsLab.create(self, 3, PLATE)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 4:
		var at := home + right * ((i - 1.5) * 8.0)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_W_%d" % (i + 1), at, yaw, "law_tank").name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var goal := home + toward * 150.0
	var task := {"verb": "move", "to": [goal.x, goal.z], "formation": shape}
	if not drills:
		task["drills"] = false
	element.assign(task)
	var on_arc := 0
	var counted := 0
	for tick in SimClock.TICK_RATE * 30:
		await lab.step()
		if element.arrived:
			break
		if tick < SimClock.TICK_RATE * 3:
			continue  # the squad forming and turning off its start: not yet "on the move"
		var heading := TacticsFormation.flat(element.transit.get("heading", element.heading) if element.in_transit() else element.heading)
		var sectors := TacticsFormation.sectors(element.formation, names.size())
		for unit_name: String in names:
			var seat: Variant = element.seats.get(unit_name)
			var t := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if t == null or not (seat is Array) or int(seat[2]) >= sectors.size():
				continue
			var want := TacticsFormation.rotate(heading, deg_to_rad(sectors[int(seat[2])]))
			counted += 1
			if rad_to_deg(TacticsFormation.flat(t.turret_forward()).angle_to(want)) <= TacticsFormation.SECTOR_WIDTH * 0.5:
				on_arc += 1
	lab.dispose()
	return float(on_arc) / maxf(counted, 1.0)


func test_a_moving_wedge_watches_its_flanks() -> void:
	var plain := await _guns_on_arc("wedge", false)
	var tasked := await _guns_on_arc("wedge", true)
	var line := await _guns_on_arc("line", false)
	print("MEASURE sectors_on_the_move plate: wedge plain %.2f, wedge tasked %.2f, line plain %.2f" % [plain, tasked, line])
	assert_true(line >= 0.9, "control: a line's sectors are all forward, so its guns are on them (%.2f)" % line)
	assert_true(plain >= 0.8, "a wedge moved by his right-click keeps its guns on its sectors (%.2f)" % plain)
	assert_true(tasked >= 0.8, "and so does a wedge on a task (%.2f)" % tasked)


func test_a_moving_column_watches_both_flanks_and_its_tail() -> void:
	var column := await _guns_on_arc("column", false)
	print("MEASURE sectors_on_the_move plate: column plain %.2f" % column)
	assert_true(column >= 0.8, "a column's middle crews watch the flanks and its tail watches behind (%.2f)" % column)
