extends TestCase
## Round 30 (traffic T4, manoeuvre's M4b trace, Terminus mixed seed 21): ORCA's neighbour table reads every hull at its
## REAL velocity (C30.6's Tank.real_velocity), not the slide's asked one. A hull pinned nose-on into a friend keeps
## estimated_velocity ~12 m/s while it goes nowhere; read that way it is a ghost to every crew steering round it, and a
## crew that backed off it was steered straight back in. Round 31: OPT-IN (R31.1), naming `ghost` turns it ON; the
## default is the old reading. GDScript table.

var _lab: TacticsLab
var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	Traffic.set_off("ghost", Traffic.OPT_IN.has("ghost"))  # back to the default, whichever it is (native, round 31)
	if _lab != null:
		_lab.dispose()  # each case's lab (undisposed, the shard leaked 14 ObjectDB instances at exit: engine-log-gate)
		_lab = null
	super.teardown()


func _table_velocity(tanks_root: Node, name: String) -> Vector2:
	Avoidance._table_frame = -1  # force this tick's table to be rebuilt
	Avoidance.refresh(tanks_root)
	var i: int = Avoidance._index[name]
	return Vector2(Avoidance._vxs[i], Avoidance._vzs[i])


func _pinned() -> Tank:
	_saved_native = BrainSwitches.native
	BrainSwitches.native = false
	Traffic.set_off("ghost", false)  # named: ON
	_lab = TacticsLab.create(self, 7, "yard_open")
	var pinned := _lab.unit(Match.Team.GREEN, "Green_Pinned", Vector3(0.0, 0.0, 0.0), 0.0, "law_ifv")
	_lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 12.0), 0.0, "law_tank")
	await _lab.start()
	await _lab.step()
	# Pressed nose-on into something: the slide asks 12 m/s, the hull moves nowhere.
	pinned.estimated_velocity = Vector3(0.0, 0.0, -12.0)
	pinned.real_velocity = Vector3.ZERO
	return pinned


func test_a_pinned_hull_is_read_at_its_real_velocity() -> void:
	var pinned: Tank = await _pinned()
	var v := _table_velocity(_lab.game_match.tanks, String(pinned.name))
	assert_true(v.length() < 0.01, "the neighbour table sees it standing still: %s" % v)


func test_the_default_is_the_old_ghost() -> void:
	var pinned: Tank = await _pinned()
	Traffic.set_off("ghost", true)
	var v := _table_velocity(_lab.game_match.tanks, String(pinned.name))
	assert_near(v.length(), 12.0, 0.01, "not named (main's default): the asked 12 m/s, as before")



func test_a_moving_hull_reads_the_same_either_way() -> void:
	var pinned: Tank = await _pinned()
	pinned.estimated_velocity = Vector3(3.0, 0.0, -4.0)
	pinned.real_velocity = Vector3(3.0, 0.0, -4.0)
	assert_near(_table_velocity(_lab.game_match.tanks, String(pinned.name)).length(), 5.0, 0.01, "moving freely: 5 m/s")
