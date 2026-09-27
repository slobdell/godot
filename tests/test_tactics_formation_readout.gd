extends TestCase
## Round 12, squad S1 (C12.4): the Formation button shows the shape the squad is actually forming. The lead, playing:
## *"they were in auto formation (which I assume is a wedge based on the UI)"* -- the AUTO glyph was a hard-coded wedge
## while the doctrine picked a COLUMN on both maps he plays (they classify as dense). Now: under AUTO the glyph and label
## read the leader's pick (`Element.state()["formation"]`), under a G choice the shape he asked for, and with no element
## yet the word "Auto" on its own glyph -- never a wedge it has not chosen.


## Q1's dense row: set by the paired series (squad.md Status, pre-registered rule).
const YARD_DEFAULT := "wedge"


func test_a_chosen_formation_reads_as_itself_whatever_the_leader_picked() -> void:
	var readout := CommandIcons.formation_readout("wedge", {"formation": "column"})
	assert_eq(readout["shape"], "wedge", "his G choice is the glyph")
	assert_eq(readout["label"], "Wedge", "and the label")


func test_auto_reads_the_leaders_pick() -> void:
	var readout := CommandIcons.formation_readout(UnitCommand.AUTO, {"formation": "column"})
	assert_eq(readout["shape"], "column", "AUTO with an element: the glyph is the leader's pick")
	assert_eq(readout["label"], "Auto: Column", "and the label says both that it is auto and what auto chose")
	var echelon := CommandIcons.formation_readout(UnitCommand.AUTO, {"formation": "echelon_left"})
	assert_eq(echelon["label"], "Auto: Echelon Left", "a two-word shape reads as words")


func test_auto_with_no_element_is_the_word_not_a_wedge() -> void:
	var readout := CommandIcons.formation_readout(UnitCommand.AUTO, {})
	assert_eq(readout["shape"], UnitCommand.AUTO, "no element yet: the auto glyph")
	assert_eq(readout["label"], "Auto", "and the word")
	var junk := CommandIcons.formation_readout(UnitCommand.AUTO, {"formation": "not_a_shape"})
	assert_eq(junk["shape"], UnitCommand.AUTO, "an unknown shape is not drawn as one")
	# The auto glyph is its own picture, not the wedge's (the lie this item exists to remove).
	var auto_image := CommandIcons.formation_texture(UnitCommand.AUTO).get_image()
	var wedge_image := CommandIcons.formation_texture("wedge").get_image()
	assert_true(auto_image.get_data() != wedge_image.get_data(), "the AUTO glyph is not a wedge")


## The integration: a real element on a real map, ordered the way his right-click orders it. A tank/ifv squad fights
## by the CONDEMNED table (Elements._table_for, the units' faction); the standard table decides for no squad the player
## fields. `make tactics-terrain`: the yard's spawns are DENSE, the Terminus's are LANES.
## Round 12 pinned a column on both maps (the Condemned catch-all was "column in any terrain"). Round 13 (the lead,
## answer 2: *"Default wedge."*): a plain move with nothing in sight is a WEDGE, and the card says it is the default.
func _auto_pick_on(arena_name: String, seconds: float = 2.0) -> Dictionary:
	var lab := TacticsLab.create(self, 3, arena_name)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var names: Array = []
	for i in 4:
		var tank := lab.unit(Match.Team.GREEN, "Green_R_%d" % (i + 1), home + right * ((i - 1.5) * 8.0),
				atan2(-toward.x, -toward.z), "tank" if i < 2 else "ifv")
		names.append(String(tank.name))
	await lab.start()
	var terrain := ElementSituation.terrain_at(home)
	var element := lab.elements.form(names, "Alpha")
	var goal := home + toward * 80.0
	# The player's right-click on a whole squad: a plain move, AUTO (no formation key), no drills.
	element.assign({"verb": "move", "to": [goal.x, goal.z], "drills": false})
	for tick in int(SimClock.TICK_RATE * seconds):
		await lab.step()
	var state := element.state()
	var line := element.describe()
	lab.dispose()
	return {"terrain": terrain, "state": state, "line": line}


func test_an_auto_squad_on_the_yard_reads_its_default() -> void:
	var run: Dictionary = await _auto_pick_on("yard")
	assert_eq(run["terrain"], "dense", "setup: the yard's spawn classifies as dense")
	assert_eq(String(run["state"]["formation"]), YARD_DEFAULT, "the Condemned plain move in dense ground")
	var readout := CommandIcons.formation_readout(UnitCommand.AUTO, run["state"])
	assert_eq(readout["shape"], YARD_DEFAULT, "the AUTO icon draws the shape the squad forms")
	assert_eq(readout["label"], "Auto: %s" % YARD_DEFAULT.capitalize(), "and says so")


func test_a_condemned_plain_move_on_the_terminus_is_a_wedge_at_ten_seconds() -> void:
	var run: Dictionary = await _auto_pick_on("terminus", 10.0)
	assert_eq(run["terrain"], "lanes", "setup: the Terminus spawn classifies as LANES, not dense (make tactics-terrain)")
	assert_eq(String(run["state"]["formation"]), "wedge", "ten seconds into his right-click, the squad is a wedge")
	var readout := CommandIcons.formation_readout(UnitCommand.AUTO, run["state"])
	assert_eq(readout["shape"], "wedge", "so the AUTO icon draws a wedge")
	assert_eq(readout["label"], "Auto: Wedge", "and says so")
	assert_true(String(run["line"]).contains("wedge (default)"),
			"the card's doctrine line says it is the default: %s" % run["line"])
